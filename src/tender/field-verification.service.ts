import {
    BadRequestException,
    ForbiddenException,
    Injectable,
    Logger,
    NotFoundException,
} from '@nestjs/common'
import { randomBytes } from 'crypto'
import { PrismaService } from '../prisma/prisma.service'
import { LocalFilesService } from '../storage/local-files.service'
import { distanceMeters, DEFAULT_RESOLUTION_RADIUS_M } from '../common/geo.util'
import { TenderAuditService } from './audit.service'
import type { UploadedImageFile } from '../common/upload.types'
import * as exifr from 'exifr'

export type MatchConfidence = 'single_nearest' | 'ambiguous' | 'unmatched' | 'manual'

@Injectable()
export class FieldVerificationService {
    private readonly logger = new Logger(FieldVerificationService.name)
    constructor(
        private readonly prisma: PrismaService,
        private readonly storage: LocalFilesService,
        private readonly audit: TenderAuditService,
    ) {}

    private async ensureTender(panchayatId: number, tenderId: number) {
        const t = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!t) throw new NotFoundException(`Tender #${tenderId} not found`)
        if (t.panchayat_id !== panchayatId) throw new ForbiddenException('Tender belongs to another panchayat')
        return t
    }

    // ── Officer endpoints ────────────────────────────────────────────────

    async createSession(
        panchayatId: number,
        tenderId: number,
        actorUserId: number,
        body: { pole_subset_ids?: number[]; expires_in_days?: number }
    ) {
        const t = await this.ensureTender(panchayatId, tenderId)
        if (t.status === 'closed') throw new BadRequestException('Cannot open verification on a closed tender')

        // Default subset = poles linked via line items.
        let subset = body.pole_subset_ids ?? []
        if (!subset.length) {
            const liPoles = await this.prisma.tenderLineItem.findMany({
                where: { tender_id: tenderId, pole_id: { not: null } },
                select: { pole_id: true },
            })
            subset = Array.from(new Set(liPoles.map((p) => p.pole_id!).filter((n): n is number => n != null)))
        }

        const expiresAt = new Date(Date.now() + (body.expires_in_days ?? 14) * 24 * 60 * 60 * 1000)
        const token = randomBytes(24).toString('hex')

        const session = await this.prisma.fieldVerificationSession.create({
            data: {
                tender_id: tenderId,
                token,
                expires_at: expiresAt,
                pole_subset_ids: subset,
                created_by_user_id: actorUserId,
            },
        })

        // Bring the tender into field_verification status if it isn't already.
        if (t.status === 'vendor_selected') {
            await this.prisma.tender.update({
                where: { id: tenderId },
                data: { status: 'field_verification' },
            })
        }

        // Seed checklist items from line items + linked poles (idempotent).
        const lineItems = await this.prisma.tenderLineItem.findMany({ where: { tender_id: tenderId } })
        for (const li of lineItems) {
            const exists = await this.prisma.tenderFieldChecklistItem.findFirst({
                where: { tender_id: tenderId, line_item_id: li.id },
            })
            if (!exists) {
                await this.prisma.tenderFieldChecklistItem.create({
                    data: {
                        tender_id: tenderId,
                        line_item_id: li.id,
                        pole_id: li.pole_id ?? null,
                    },
                })
            }
        }

        await this.audit.record({
            tenderId,
            actorUserId,
            event: 'verification:session_created',
            payload: { session_id: session.id, pole_count: subset.length },
        })
        return session
    }

    listSessions(panchayatId: number, tenderId: number) {
        return this.ensureTender(panchayatId, tenderId).then(() =>
            this.prisma.fieldVerificationSession.findMany({
                where: { tender_id: tenderId },
                orderBy: { id: 'desc' },
                include: { _count: { select: { uploads: true } } },
            }),
        )
    }

    async getChecklist(panchayatId: number, tenderId: number) {
        await this.ensureTender(panchayatId, tenderId)
        const items = await this.prisma.tenderFieldChecklistItem.findMany({
            where: { tender_id: tenderId },
            orderBy: { id: 'asc' },
            include: {
                pole: true,
                line_item: true,
                verified_upload: true,
            },
        })
        return items
    }

    async patchChecklistItem(
        panchayatId: number,
        tenderId: number,
        itemId: number,
        actorUserId: number,
        body: { is_done?: boolean; verified_upload_id?: number | null; notes?: string | null }
    ) {
        await this.ensureTender(panchayatId, tenderId)
        const item = await this.prisma.tenderFieldChecklistItem.findUnique({ where: { id: itemId } })
        if (!item || item.tender_id !== tenderId) {
            throw new NotFoundException(`Checklist item #${itemId} not on this tender`)
        }
        const data: Record<string, unknown> = {}
        if (body.is_done !== undefined) data.is_done = !!body.is_done
        if (body.verified_upload_id !== undefined) {
            if (body.verified_upload_id != null) {
                const upload = await this.prisma.fieldVerificationUpload.findUnique({
                    where: { id: body.verified_upload_id },
                    include: { session: true },
                })
                if (!upload || upload.session.tender_id !== tenderId) {
                    throw new BadRequestException('verified_upload_id not on this tender')
                }
            }
            data.verified_upload_id = body.verified_upload_id
        }
        if (body.notes !== undefined) data.notes = body.notes ?? null
        const updated = await this.prisma.tenderFieldChecklistItem.update({ where: { id: itemId }, data })
        await this.audit.record({
            tenderId,
            actorUserId,
            event: 'verification:checklist_patch',
            payload: { item_id: itemId, ...data },
        })
        return updated
    }

    /**
     * Officer confirms verification.
     *
     * Guards:
     *   - All checklist items must have is_done = true.
     *   - If `auto_resolve_linked_complaints` is on:
     *       - Each item must either have a verified_upload (with non-ambiguous match)
     *         OR `tender.officer_self_inspection` must be true.
     *       - Linked complaints get bulk-resolved with proof copied from the upload.
     */
    async confirmVerification(panchayatId: number, tenderId: number, actorUserId: number) {
        const t = await this.ensureTender(panchayatId, tenderId)
        if (t.status !== 'field_verification') {
            throw new BadRequestException(`Tender must be in field_verification (current: ${t.status})`)
        }

        const items = await this.prisma.tenderFieldChecklistItem.findMany({
            where: { tender_id: tenderId },
            include: { verified_upload: true, line_item: true, pole: true },
        })
        if (items.length === 0) {
            throw new BadRequestException('No checklist items exist; create a verification session first')
        }
        const incomplete = items.filter((it) => !it.is_done)
        if (incomplete.length > 0) {
            throw new BadRequestException(`Checklist incomplete: ${incomplete.length} item(s) not done`)
        }

        if (t.auto_resolve_linked_complaints) {
            for (const it of items) {
                if (it.verified_upload) {
                    if (it.verified_upload.match_confidence === 'ambiguous') {
                        throw new BadRequestException(
                            `Checklist item #${it.id} has an ambiguous match; reassign before confirming`,
                        )
                    }
                } else if (!t.officer_self_inspection) {
                    throw new BadRequestException(
                        `Checklist item #${it.id} has no upload; enable officer_self_inspection to allow attestations`,
                    )
                }
            }
        }

        // Bulk resolve linked complaints (only when flag on).
        let resolvedCount = 0
        if (t.auto_resolve_linked_complaints) {
            const lineItems = await this.prisma.tenderLineItem.findMany({
                where: { tender_id: tenderId, complaint_id: { not: null } },
            })
            for (const li of lineItems) {
                if (li.complaint_id == null) continue
                const itm = items.find((i) => i.line_item_id === li.id) ?? items.find((i) => i.pole_id === li.pole_id)
                const proof = itm?.verified_upload ?? null
                const data: Record<string, unknown> = {
                    status: 'resolved',
                    resolved_at: new Date(),
                    resolution_note: `Resolved via Tender #${tenderId}`,
                }
                if (proof) {
                    data.resolution_image_url = proof.image_url
                    data.resolution_image_latitude = proof.exif_lat
                    data.resolution_image_longitude = proof.exif_lng
                    data.resolution_image_captured_at = proof.captured_at
                    data.resolution_distance_meters = proof.distance_meters
                    data.resolution_location_valid = proof.match_confidence === 'single_nearest' || proof.match_confidence === 'manual'
                }
                try {
                    await this.prisma.complaint.update({ where: { id: li.complaint_id }, data })
                    resolvedCount++
                } catch (err: any) {
                    this.logger.warn(`Failed to bulk-resolve complaint #${li.complaint_id}: ${err?.message ?? err}`)
                }
            }
        }

        const updated = await this.prisma.tender.update({
            where: { id: tenderId },
            data: { inspection_done_at: new Date() },
        })
        await this.audit.record({
            tenderId,
            actorUserId,
            event: 'verification:confirmed',
            payload: {
                resolved_complaint_count: resolvedCount,
                auto_resolve: t.auto_resolve_linked_complaints,
            },
        })
        return { ok: true, tender: updated, resolved_complaint_count: resolvedCount }
    }

    // ── Public field-staff endpoints ─────────────────────────────────────

    private async loadSessionByToken(token: string) {
        const session = await this.prisma.fieldVerificationSession.findUnique({
            where: { token },
            include: { tender: { include: { panchayat: { select: { id: true, name: true } } } } },
        })
        if (!session) throw new NotFoundException('Session not found')
        if (session.expires_at && session.expires_at.getTime() < Date.now()) {
            throw new BadRequestException('Session expired')
        }
        return session
    }

    async readSessionPublic(token: string) {
        const session = await this.loadSessionByToken(token)
        const polesQ = session.pole_subset_ids.length
            ? this.prisma.electricPole.findMany({
                where: { id: { in: session.pole_subset_ids } },
                select: {
                    id: true, pole_number: true, latitude: true, longitude: true, landmarks: true,
                },
            })
            : Promise.resolve([])
        const poles = await polesQ
        return {
            session: {
                id: session.id,
                expires_at: session.expires_at,
                tender_id: session.tender_id,
                panchayat: session.tender.panchayat,
            },
            poles,
        }
    }

    async submitUpload(args: {
        token: string
        image: UploadedImageFile
        manualPoleId?: number | null
        notes?: string | null
    }) {
        const session = await this.loadSessionByToken(args.token)
        if (!args.image?.buffer?.length) throw new BadRequestException('image is required')

        // Read EXIF GPS (best-effort).
        let lat: number | null = null
        let lng: number | null = null
        let capturedAt: Date | null = null
        try {
            const exif = await exifr.parse(args.image.buffer, { gps: true, pick: ['DateTimeOriginal', 'CreateDate'] })
            if (exif?.latitude != null && exif?.longitude != null) {
                lat = Number(exif.latitude)
                lng = Number(exif.longitude)
            }
            const dt = exif?.DateTimeOriginal ?? exif?.CreateDate
            if (dt) capturedAt = new Date(dt)
        } catch (_err) { /* ignore */ }

        // Persist file under tenders/<id>/field/.
        const imageUrl = await this.storage.saveBuffer(
            `tenders/${session.tender_id}/field`,
            args.image.buffer,
            args.image.originalname,
        )

        // Match nearest pole.
        const candidatePoles = session.pole_subset_ids.length
            ? await this.prisma.electricPole.findMany({
                where: { id: { in: session.pole_subset_ids } },
                select: { id: true, latitude: true, longitude: true },
            })
            : await this.prisma.electricPole.findMany({
                where: { panchayat_id: session.tender.panchayat_id },
                select: { id: true, latitude: true, longitude: true },
            })

        let matchedPoleId: number | null = null
        let matchDist: number | null = null
        let confidence: MatchConfidence = 'unmatched'

        if (lat != null && lng != null && candidatePoles.length > 0) {
            const distances = candidatePoles
                .filter((p) => p.latitude != null && p.longitude != null)
                .map((p) => ({ id: p.id, d: distanceMeters(lat!, lng!, p.latitude!, p.longitude!) }))
                .sort((a, b) => a.d - b.d)

            const within = distances.filter((x) => x.d <= DEFAULT_RESOLUTION_RADIUS_M)
            if (within.length === 1) {
                matchedPoleId = within[0].id
                matchDist = within[0].d
                confidence = 'single_nearest'
            } else if (within.length >= 2) {
                matchedPoleId = within[0].id
                matchDist = within[0].d
                const gap = (within[1].d - within[0].d) / DEFAULT_RESOLUTION_RADIUS_M
                confidence = gap < 0.5 ? 'ambiguous' : 'single_nearest'
            } else if (distances.length > 0) {
                matchedPoleId = null
                matchDist = distances[0].d
                confidence = 'unmatched'
            }
        }

        if (args.manualPoleId) {
            confidence = 'manual'
        }

        const upload = await this.prisma.fieldVerificationUpload.create({
            data: {
                session_id: session.id,
                image_url: imageUrl,
                exif_lat: lat,
                exif_lng: lng,
                captured_at: capturedAt,
                matched_pole_id: matchedPoleId,
                manual_pole_id: args.manualPoleId ?? null,
                distance_meters: matchDist,
                match_confidence: confidence,
                notes: args.notes?.trim() || null,
            },
        })

        // Auto-attach to checklist item if a pole matched and item exists.
        const effectivePole = args.manualPoleId ?? matchedPoleId
        if (effectivePole) {
            const item = await this.prisma.tenderFieldChecklistItem.findFirst({
                where: { tender_id: session.tender_id, pole_id: effectivePole, verified_upload_id: null },
            })
            if (item) {
                await this.prisma.tenderFieldChecklistItem.update({
                    where: { id: item.id },
                    data: {
                        verified_upload_id: upload.id,
                        is_done: confidence === 'single_nearest' || confidence === 'manual',
                    },
                })
            }
        }

        await this.audit.record({
            tenderId: session.tender_id,
            actorUserId: null,
            event: 'verification:upload',
            payload: {
                upload_id: upload.id,
                match_confidence: confidence,
                matched_pole_id: matchedPoleId,
                manual_pole_id: args.manualPoleId ?? null,
            },
        })

        return {
            ok: true,
            upload_id: upload.id,
            match_confidence: confidence,
            matched_pole_id: matchedPoleId ?? args.manualPoleId ?? null,
            distance_meters: matchDist,
        }
    }
}
