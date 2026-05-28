import {
    BadRequestException,
    ForbiddenException,
    Injectable,
    Logger,
    NotFoundException,
} from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { randomBytes } from 'crypto'
import { PrismaService } from '../prisma/prisma.service'
import { DocumentStorageService } from '../storage/document-storage.service'
import { distanceMeters, DEFAULT_RESOLUTION_RADIUS_M } from '../common/geo.util'
import { TenderAuditService } from './audit.service'
import type { UploadedImageFile } from '../common/upload.types'
import * as exifr from 'exifr'
import { FieldOverlayOcrService } from './field-overlay-ocr.service'
import { fuseCoordinates, matchPoleFromOcrText, type CoordSource } from './field-coord.util'

export type MatchConfidence =
    | 'single_nearest'
    | 'verified_dual'
    | 'ambiguous'
    | 'unmatched'
    | 'manual'
    | 'conflict'

type PoleCandidate = { id: number; latitude: number | null; longitude: number | null; pole_number: string | null; keypad_id: string | null }

const CHECKLIST_ITEM_INCLUDE = {
    pole: true,
    line_item: true,
    verified_upload: {
        include: {
            matched_pole: true,
            manual_pole: true,
            session: { select: { id: true, label: true, token: true } },
        },
    },
} as const

@Injectable()
export class FieldVerificationService {
    private readonly logger = new Logger(FieldVerificationService.name)
    constructor(
        private readonly prisma: PrismaService,
        private readonly storage: DocumentStorageService,
        private readonly audit: TenderAuditService,
        private readonly overlayOcr: FieldOverlayOcrService,
        private readonly config: ConfigService,
    ) {}

    private matchRadiusM(): number {
        const raw = this.config.get<string>('FIELD_MATCH_RADIUS_M')
        const n = raw != null ? Number(raw) : DEFAULT_RESOLUTION_RADIUS_M
        return Number.isFinite(n) && n > 0 ? n : DEFAULT_RESOLUTION_RADIUS_M
    }

    private async ensureTender(panchayatId: number, tenderId: number) {
        const t = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!t) throw new NotFoundException(`Tender #${tenderId} not found`)
        if (t.panchayat_id !== panchayatId) throw new ForbiddenException('Tender belongs to another panchayat')
        return t
    }

    private async allowedPoleIdsForTender(tenderId: number, panchayatId: number): Promise<Set<number>> {
        const lineItems = await this.prisma.tenderLineItem.findMany({
            where: { tender_id: tenderId, pole_id: { not: null } },
            select: { pole_id: true },
        })
        const ids = lineItems.map((li) => li.pole_id!).filter((n): n is number => n != null)
        if (ids.length === 0) return new Set()
        const poles = await this.prisma.electricPole.findMany({
            where: { id: { in: ids }, panchayat_id: panchayatId },
            select: { id: true },
        })
        return new Set(poles.map((p) => p.id))
    }

    async createSession(
        panchayatId: number,
        tenderId: number,
        actorUserId: number,
        body: { label?: string | null; pole_subset_ids?: number[]; expires_in_days?: number },
    ) {
        const t = await this.ensureTender(panchayatId, tenderId)
        if (t.status === 'closed') throw new BadRequestException('Cannot open verification on a closed tender')

        const allowed = await this.allowedPoleIdsForTender(tenderId, panchayatId)
        let subset = body.pole_subset_ids ?? []
        if (body.pole_subset_ids !== undefined && subset.length === 0) {
            throw new BadRequestException('pole_subset_ids must include at least one pole')
        }
        if (!subset.length) {
            subset = Array.from(allowed)
        }
        if (!subset.length) {
            throw new BadRequestException('No poles linked to this tender; add line items with poles first')
        }
        for (const poleId of subset) {
            if (!allowed.has(poleId)) {
                throw new BadRequestException(`Pole #${poleId} is not linked to this tender`)
            }
        }

        const label = body.label?.trim() || null
        const expiresAt = new Date(Date.now() + (body.expires_in_days ?? 14) * 24 * 60 * 60 * 1000)
        const token = randomBytes(24).toString('hex')

        const session = await this.prisma.fieldVerificationSession.create({
            data: {
                tender_id: tenderId,
                token,
                label,
                expires_at: expiresAt,
                pole_subset_ids: subset,
                created_by_user_id: actorUserId,
            },
        })

        if (t.status === 'vendor_selected') {
            await this.prisma.tender.update({
                where: { id: tenderId },
                data: { status: 'field_verification' },
            })
        }

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
            payload: { session_id: session.id, pole_count: subset.length, label },
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
        return this.prisma.tenderFieldChecklistItem.findMany({
            where: { tender_id: tenderId },
            orderBy: { id: 'asc' },
            include: CHECKLIST_ITEM_INCLUDE,
        })
    }

    async patchChecklistItem(
        panchayatId: number,
        tenderId: number,
        itemId: number,
        actorUserId: number,
        body: { is_done?: boolean; verified_upload_id?: number | null; notes?: string | null },
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
        await this.prisma.tenderFieldChecklistItem.update({ where: { id: itemId }, data })
        await this.audit.record({
            tenderId,
            actorUserId,
            event: 'verification:checklist_patch',
            payload: { item_id: itemId, ...data },
        })
        return this.prisma.tenderFieldChecklistItem.findUniqueOrThrow({
            where: { id: itemId },
            include: CHECKLIST_ITEM_INCLUDE,
        })
    }

    async assignUpload(
        panchayatId: number,
        tenderId: number,
        uploadId: number,
        actorUserId: number,
        body: { pole_id: number; approve?: boolean },
    ) {
        await this.ensureTender(panchayatId, tenderId)
        const poleId = body.pole_id
        if (!Number.isInteger(poleId)) {
            throw new BadRequestException('pole_id must be an integer')
        }

        const upload = await this.prisma.fieldVerificationUpload.findUnique({
            where: { id: uploadId },
            include: { session: true },
        })
        if (!upload || upload.session.tender_id !== tenderId) {
            throw new NotFoundException(`Upload #${uploadId} not on this tender`)
        }

        const allowed = await this.allowedPoleIdsForTender(tenderId, panchayatId)
        if (!allowed.has(poleId)) {
            throw new BadRequestException(`Pole #${poleId} is not linked to this tender`)
        }
        const subset = upload.session.pole_subset_ids
        if (subset.length > 0 && !subset.includes(poleId)) {
            throw new BadRequestException(`Pole #${poleId} is not in this upload section`)
        }

        const targetItem = await this.prisma.tenderFieldChecklistItem.findFirst({
            where: { tender_id: tenderId, pole_id: poleId },
            orderBy: { id: 'asc' },
        })
        if (!targetItem) {
            throw new BadRequestException(`No checklist item for pole #${poleId}`)
        }

        await this.prisma.$transaction(async (tx) => {
            await tx.tenderFieldChecklistItem.updateMany({
                where: { tender_id: tenderId, verified_upload_id: uploadId, id: { not: targetItem.id } },
                data: { verified_upload_id: null, is_done: false },
            })
            await tx.fieldVerificationUpload.update({
                where: { id: uploadId },
                data: {
                    manual_pole_id: poleId,
                    matched_pole_id: poleId,
                    match_confidence: 'manual',
                },
            })
            await tx.tenderFieldChecklistItem.update({
                where: { id: targetItem.id },
                data: {
                    verified_upload_id: uploadId,
                    is_done: body.approve === true,
                },
            })
        })

        await this.audit.record({
            tenderId,
            actorUserId,
            event: 'verification:upload_assigned',
            payload: { upload_id: uploadId, pole_id: poleId, approve: body.approve === true },
        })

        return this.prisma.tenderFieldChecklistItem.findUniqueOrThrow({
            where: { id: targetItem.id },
            include: CHECKLIST_ITEM_INCLUDE,
        })
    }

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
                    const mc = it.verified_upload.match_confidence
                    if (mc === 'ambiguous' || mc === 'conflict') {
                        throw new BadRequestException(
                            `Checklist item #${it.id} has a ${mc} match; reassign before confirming`,
                        )
                    }
                } else if (!t.officer_self_inspection) {
                    throw new BadRequestException(
                        `Checklist item #${it.id} has no upload; enable officer_self_inspection to allow attestations`,
                    )
                }
            }
        }

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
                    data.resolution_image_latitude = proof.matched_lat ?? proof.exif_lat ?? proof.ocr_lat
                    data.resolution_image_longitude = proof.matched_lng ?? proof.exif_lng ?? proof.ocr_lng
                    data.resolution_image_captured_at = proof.captured_at ?? proof.ocr_captured_at
                    data.resolution_distance_meters = proof.distance_meters
                    data.resolution_location_valid =
                        proof.match_confidence === 'single_nearest' ||
                        proof.match_confidence === 'verified_dual' ||
                        proof.match_confidence === 'manual'
                }
                try {
                    await this.prisma.complaint.update({ where: { id: li.complaint_id }, data })
                    resolvedCount++
                } catch (err: unknown) {
                    this.logger.warn(`Failed to bulk-resolve complaint #${li.complaint_id}: ${err instanceof Error ? err.message : err}`)
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
        const poleIds = session.pole_subset_ids

        const [poles, lineItems, uploadCount] = await Promise.all([
            poleIds.length
                ? this.prisma.electricPole.findMany({
                    where: { id: { in: poleIds } },
                    select: {
                        id: true, pole_number: true, latitude: true, longitude: true, landmarks: true,
                    },
                })
                : Promise.resolve([]),
            poleIds.length
                ? this.prisma.tenderLineItem.findMany({
                    where: { tender_id: session.tender_id, pole_id: { in: poleIds } },
                    select: {
                        id: true,
                        pole_id: true,
                        description_ta: true,
                        description_en: true,
                        quantity: true,
                        unit: true,
                    },
                })
                : Promise.resolve([]),
            this.prisma.fieldVerificationUpload.count({ where: { session_id: session.id } }),
        ])

        return {
            session: {
                id: session.id,
                label: session.label,
                expires_at: session.expires_at,
                tender_id: session.tender_id,
                panchayat: session.tender.panchayat,
                upload_count: uploadCount,
            },
            poles,
            work_items: lineItems.map((li) => ({
                line_item_id: li.id,
                pole_id: li.pole_id,
                description_ta: li.description_ta,
                description_en: li.description_en,
                quantity: li.quantity,
                unit: li.unit,
            })),
        }
    }

    private matchNearestPole(
        lat: number,
        lng: number,
        candidates: PoleCandidate[],
        radiusM: number,
    ): { matchedPoleId: number | null; matchDist: number | null; confidence: MatchConfidence } {
        const distances = candidates
            .filter((p) => p.latitude != null && p.longitude != null)
            .map((p) => ({ id: p.id, d: distanceMeters(lat, lng, p.latitude!, p.longitude!) }))
            .sort((a, b) => a.d - b.d)

        const within = distances.filter((x) => x.d <= radiusM)
        if (within.length === 1) {
            return { matchedPoleId: within[0].id, matchDist: within[0].d, confidence: 'single_nearest' }
        }
        if (within.length >= 2) {
            const gap = (within[1].d - within[0].d) / radiusM
            return {
                matchedPoleId: within[0].id,
                matchDist: within[0].d,
                confidence: gap < 0.5 ? 'ambiguous' : 'single_nearest',
            }
        }
        if (distances.length > 0) {
            return { matchedPoleId: null, matchDist: distances[0].d, confidence: 'unmatched' }
        }
        return { matchedPoleId: null, matchDist: null, confidence: 'unmatched' }
    }

    private autoDone(confidence: MatchConfidence): boolean {
        return confidence === 'single_nearest' || confidence === 'verified_dual' || confidence === 'manual'
    }

    private buildUploadMessage(args: {
        confidence: MatchConfidence
        matchedPoleId: number | null
        manualPoleId: number | null
        distanceMeters: number | null
        coordSource: CoordSource
        coordsFound: boolean
    }): string {
        const poleId = args.manualPoleId ?? args.matchedPoleId
        if (args.confidence === 'manual' && poleId) {
            return `Image has been uploaded. Pole #${poleId} selected manually.`
        }
        if (args.confidence === 'verified_dual' && poleId && args.distanceMeters != null) {
            return `Image has been uploaded. Location and tag both match Pole #${poleId} (${Math.round(args.distanceMeters)} m away).`
        }
        if (args.confidence === 'conflict') {
            return 'Image has been uploaded. Location and tag disagree — officer will review.'
        }
        if (args.confidence === 'single_nearest' && poleId && args.distanceMeters != null) {
            return `Image has been uploaded. Location matched to Pole #${poleId} (${Math.round(args.distanceMeters)} m away).`
        }
        if (args.confidence === 'ambiguous') {
            return 'Image has been uploaded. Multiple poles nearby — officer will confirm.'
        }
        if (args.coordsFound && args.confidence === 'unmatched') {
            return 'Image uploaded. Location recorded but no pole in your section is nearby — officer will review.'
        }
        return 'Image uploaded. Could not read location from photo — please retake with GPS Map Camera or select pole manually.'
    }

    async submitUpload(args: {
        token: string
        image: UploadedImageFile
        manualPoleId?: number | null
        notes?: string | null
    }) {
        const session = await this.loadSessionByToken(args.token)
        if (!args.image?.buffer?.length) throw new BadRequestException('image is required')

        if (args.manualPoleId != null) {
            if (!session.pole_subset_ids.includes(args.manualPoleId)) {
                throw new BadRequestException('manual_pole_id must be a pole in this section')
            }
        }

        // Run EXIF, OCR, image upload, and pole fetch in parallel to stay within Vercel's 60s limit.
        const exifPromise = (async () => {
            let exifLat: number | null = null
            let exifLng: number | null = null
            let capturedAt: Date | null = null
            try {
                const exif = await exifr.parse(args.image.buffer, { gps: true, pick: ['DateTimeOriginal', 'CreateDate'] })
                if (exif?.latitude != null && exif?.longitude != null) {
                    exifLat = Number(exif.latitude)
                    exifLng = Number(exif.longitude)
                }
                const dt = exif?.DateTimeOriginal ?? exif?.CreateDate
                if (dt) capturedAt = new Date(dt)
            } catch (_err) { /* ignore */ }
            return { exifLat, exifLng, capturedAt }
        })()

        // OCR with a timeout on Vercel to prevent blocking the whole upload
        const ocrTimeoutMs = process.env.VERCEL ? 10_000 : 30_000
        const ocrPromise = Promise.race([
            this.overlayOcr.extractOverlayCoords(args.image.buffer),
            new Promise<Awaited<ReturnType<typeof this.overlayOcr.extractOverlayCoords>>>((resolve) =>
                setTimeout(() => {
                    this.logger.warn('OCR timed out, using empty result')
                    resolve({ lat: null, lng: null, rawText: '', address: null, skipped: true })
                }, ocrTimeoutMs),
            ),
        ])

        const imageUrlPromise = this.storage.saveImageBuffer(
            `${session.tender_id}/field`,
            args.image.buffer,
            args.image.originalname,
        )

        const polesPromise: Promise<PoleCandidate[]> = session.pole_subset_ids.length
            ? this.prisma.electricPole.findMany({
                where: { id: { in: session.pole_subset_ids } },
                select: { id: true, latitude: true, longitude: true, pole_number: true, keypad_id: true },
            })
            : this.prisma.electricPole.findMany({
                where: { panchayat_id: session.tender.panchayat_id },
                select: { id: true, latitude: true, longitude: true, pole_number: true, keypad_id: true },
            })

        const [{ exifLat, exifLng, capturedAt }, ocrResult, imageUrl, candidatePoles] =
            await Promise.all([exifPromise, ocrPromise, imageUrlPromise, polesPromise])

        const fused = fuseCoordinates({
            exifLat,
            exifLng,
            ocrLat: ocrResult.lat,
            ocrLng: ocrResult.lng,
            manualPoleId: args.manualPoleId,
        })

        const radiusM = this.matchRadiusM()
        let matchedPoleId: number | null = null
        let matchDist: number | null = null
        let confidence: MatchConfidence = 'unmatched'

        if (args.manualPoleId) {
            matchedPoleId = args.manualPoleId
            confidence = 'manual'
        } else if (fused.lat != null && fused.lng != null) {
            const gpsMatch = this.matchNearestPole(fused.lat, fused.lng, candidatePoles, radiusM)
            matchedPoleId = gpsMatch.matchedPoleId
            matchDist = gpsMatch.matchDist
            confidence = gpsMatch.confidence
        }

        const tagMatch = matchPoleFromOcrText(ocrResult.rawText, candidatePoles)
        if (!args.manualPoleId && tagMatch.confidence === 'single' && tagMatch.poleId) {
            if (matchedPoleId && matchedPoleId !== tagMatch.poleId) {
                confidence = 'conflict'
            } else if (matchedPoleId && matchedPoleId === tagMatch.poleId) {
                confidence = 'verified_dual'
            } else if (!matchedPoleId) {
                matchedPoleId = tagMatch.poleId
                confidence = 'single_nearest'
            }
        }

        const upload = await this.prisma.fieldVerificationUpload.create({
            data: {
                session_id: session.id,
                image_url: imageUrl,
                exif_lat: exifLat,
                exif_lng: exifLng,
                captured_at: capturedAt,
                ocr_lat: ocrResult.lat,
                ocr_lng: ocrResult.lng,
                ocr_address: ocrResult.address,
                ocr_raw_text: ocrResult.rawText || null,
                ocr_pole_number: tagMatch.poleNumber,
                ocr_keypad_id: tagMatch.keypadId,
                ocr_matched_pole_id: tagMatch.poleId,
                ocr_match_confidence: tagMatch.confidence,
                coord_source: fused.coordSource,
                matched_lat: fused.lat,
                matched_lng: fused.lng,
                matched_pole_id: matchedPoleId,
                manual_pole_id: args.manualPoleId ?? null,
                distance_meters: matchDist,
                match_confidence: confidence,
                notes: args.notes?.trim() || null,
            },
        })

        const effectivePole = args.manualPoleId ?? matchedPoleId
        if (effectivePole) {
            const item = await this.prisma.tenderFieldChecklistItem.findFirst({
                where: {
                    tender_id: session.tender_id,
                    pole_id: effectivePole,
                    verified_upload_id: null,
                    is_done: false,
                },
                orderBy: { id: 'asc' },
            })
            if (item) {
                await this.prisma.tenderFieldChecklistItem.update({
                    where: { id: item.id },
                    data: {
                        verified_upload_id: upload.id,
                        is_done: this.autoDone(confidence),
                    },
                })
            }
        }

        const coordsFound = fused.lat != null && fused.lng != null
        const message = this.buildUploadMessage({
            confidence,
            matchedPoleId,
            manualPoleId: args.manualPoleId ?? null,
            distanceMeters: matchDist,
            coordSource: fused.coordSource,
            coordsFound,
        })

        await this.audit.record({
            tenderId: session.tender_id,
            actorUserId: null,
            event: 'verification:upload',
            payload: {
                upload_id: upload.id,
                match_confidence: confidence,
                matched_pole_id: matchedPoleId,
                manual_pole_id: args.manualPoleId ?? null,
                coord_source: fused.coordSource,
            },
        })

        return {
            ok: true,
            message,
            upload_id: upload.id,
            match_confidence: confidence,
            matched_pole_id: matchedPoleId ?? args.manualPoleId ?? null,
            distance_meters: matchDist,
            coord_source: fused.coordSource,
            lat: fused.lat,
            lng: fused.lng,
            ocr_pole_number: tagMatch.poleNumber,
        }
    }
}
