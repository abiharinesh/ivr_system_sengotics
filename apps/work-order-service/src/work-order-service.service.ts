import {
    Injectable,
    BadRequestException,
    NotFoundException,
    ForbiddenException,
} from '@nestjs/common'
import { createHash, randomBytes } from 'crypto'
import * as exifr from 'exifr'
import { PrismaService, LocalFilesService } from '@app/shared'
import type { UploadedImageFile } from '@app/shared'
import { distanceMeters } from '@app/shared'

/** Inline geo-verification (kept in-process for performance). */
interface CandidatePole {
    poleId: number
    complaintId: number
    latitude: number | null
    longitude: number | null
}

interface GeoInput {
    uploadLat: number
    uploadLng: number
    exifLat?: number | null
    exifLng?: number | null
    capturedAt?: Date | null
    now?: Date
}

@Injectable()
export class WorkOrderServiceService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly files: LocalFilesService,
    ) {}

    // ── Award quotation & create work order ──────────────────────────────
    async awardQuotationAndCreateWorkOrder(
        panchayatId: number,
        tenderId: number,
        quotationId: number,
        approvedByUserId: number,
        dueDate?: string,
    ) {
        const tender = await this.assertTenderScope(panchayatId, tenderId)
        if (tender.status === 'awarded') {
            throw new BadRequestException('Tender already awarded.')
        }

        const quotation = await this.prisma.quotation.findFirst({
            where: { id: quotationId, tender_id: tenderId }
        })
        if (!quotation) throw new NotFoundException('Quotation not found for tender.')

        const items = await this.prisma.tenderComplaint.findMany({
            where: { tender_id: tenderId },
            select: { complaint_id: true }
        })
        const complaints = await this.prisma.complaint.findMany({
            where: { id: { in: items.map((i) => i.complaint_id) } },
            select: { id: true, pole_id: true, status: true }
        })
        if (complaints.some((c) => !c.pole_id)) {
            throw new BadRequestException('All complaints in tender must have mapped poles.')
        }

        const workOrderCode = await this.generateWorkOrderCode()
        const link = this.generateTokenPayload()

        const workOrder = await this.prisma.$transaction(async (tx) => {
            await tx.quotation.updateMany({
                where: { tender_id: tenderId, status: { in: ['submitted', 'shortlisted'] } },
                data: { status: 'rejected' }
            })
            await tx.quotation.update({
                where: { id: quotation.id },
                data: { status: 'awarded' }
            })
            await tx.tender.update({
                where: { id: tenderId },
                data: { status: 'awarded' }
            })

            const created = await tx.workOrder.create({
                data: {
                    work_order_code: workOrderCode,
                    tender_id: tenderId,
                    quotation_id: quotation.id,
                    panchayat_id: panchayatId,
                    approved_by_user_id: approvedByUserId,
                    assigned_vendor_name: quotation.company_name,
                    assigned_vendor_phone: quotation.mobile_number,
                    quantity: quotation.quantity,
                    status: 'created',
                    due_date: dueDate ? new Date(dueDate) : null,
                    items: {
                        createMany: {
                            data: complaints.map((c) => ({
                                complaint_id: c.id,
                                pole_id: c.pole_id as number,
                            }))
                        }
                    }
                },
                include: { items: true }
            })

            await tx.tenderInviteLink.create({
                data: {
                    tender_id: tenderId,
                    purpose: 'work_upload',
                    token_hash: link.hash,
                    token_hint: link.hint,
                    expires_at: dueDate ? new Date(dueDate) : new Date(Date.now() + 1000 * 60 * 60 * 24 * 14),
                    max_submissions: Math.max(quotation.quantity * 2, 20),
                    work_order_id: created.id,
                }
            })

            return created
        })

        return {
            work_order: workOrder,
            upload_link: `/api/procurement/public/work-upload/${link.token}`,
        }
    }

    // ── Submit work proof by token ──────────────────────────────────────
    async submitWorkProofByToken(
        token: string,
        file: UploadedImageFile,
        input: {
            latitude: number
            longitude: number
            capturedAt: Date
            submitter_name?: string
            submitter_phone?: string
            complaint_id?: number
            note?: string
        },
    ) {
        const invite = await this.resolveInviteByToken(token, 'work_upload')
        if (!invite.work_order_id) {
            throw new BadRequestException('Upload link is not tied to a work order.')
        }

        const workOrder = await this.prisma.workOrder.findUnique({
            where: { id: invite.work_order_id },
            include: {
                items: {
                    include: {
                        complaint: { include: { pole: true } }
                    }
                }
            }
        })
        if (!workOrder) throw new NotFoundException('Work order not found.')

        const imageHash = createHash('sha256').update(file.buffer).digest('hex')
        const existingHash = await this.prisma.workProof.findUnique({ where: { image_hash: imageHash } })
        if (existingHash) {
            throw new BadRequestException('This image was already uploaded.')
        }

        const exif = await exifr.parse(file.buffer, { gps: true }).catch(() => null as any)
        const exifLat = exif?.latitude ?? null
        const exifLng = exif?.longitude ?? null

        const imageUrl = await this.files.saveBuffer('work-orders/proofs', file.buffer, file.originalname)
        const candidates: CandidatePole[] = workOrder.items
            .filter((item) => item.complaint.pole?.latitude != null && item.complaint.pole?.longitude != null && item.complaint.status !== 'resolved')
            .map((item) => ({
                poleId: item.pole_id,
                complaintId: item.complaint_id,
                latitude: item.complaint.pole?.latitude ?? null,
                longitude: item.complaint.pole?.longitude ?? null,
            }))

        const verification = this.verifyNearestCandidate(candidates, {
            uploadLat: input.latitude,
            uploadLng: input.longitude,
            exifLat,
            exifLng,
            capturedAt: input.capturedAt,
        })

        const preferredComplaintId = input.complaint_id
        const selectedComplaintId = preferredComplaintId && candidates.some((c) => c.complaintId === preferredComplaintId)
            ? preferredComplaintId
            : verification.nearestComplaintId

        const selectedPoleId = selectedComplaintId
            ? candidates.find((c) => c.complaintId === selectedComplaintId)?.poleId ?? verification.nearestPoleId
            : verification.nearestPoleId

        const proof = await this.prisma.$transaction(async (tx) => {
            const created = await tx.workProof.create({
                data: {
                    work_order_id: workOrder.id,
                    complaint_id: selectedComplaintId,
                    pole_id: selectedPoleId,
                    image_url: imageUrl,
                    captured_at: input.capturedAt,
                    latitude: input.latitude,
                    longitude: input.longitude,
                    exif_latitude: exifLat,
                    exif_longitude: exifLng,
                    distance_meters: verification.distanceMeters,
                    adaptive_radius_meters: verification.adaptiveRadiusMeters,
                    match_confidence: verification.confidence,
                    image_hash: imageHash,
                    submitted_by_name: input.submitter_name?.trim() || null,
                    submitted_by_phone: input.submitter_phone?.trim() || null,
                    verification_note: input.note?.trim() || verification.note,
                    status: verification.matched ? 'matched' : 'unmatched_manual_review',
                }
            })

            await tx.tenderInviteLink.update({
                where: { id: invite.id },
                data: { used_count: { increment: 1 } }
            })

            if (selectedComplaintId) {
                const targetStatus = verification.matched ? 'resolved' : 'resolved_pending_confirmation'
                await tx.complaint.update({
                    where: { id: selectedComplaintId },
                    data: {
                        status: targetStatus,
                        resolved_at: verification.matched ? new Date() : null,
                        resolution_image_url: imageUrl,
                        resolution_image_latitude: input.latitude,
                        resolution_image_longitude: input.longitude,
                        resolution_image_captured_at: input.capturedAt,
                        resolution_distance_meters: verification.distanceMeters,
                        resolution_location_valid: verification.matched,
                    }
                })
                await tx.complaintResolutionAudit.create({
                    data: {
                        complaint_id: selectedComplaintId,
                        work_proof_id: created.id,
                        action: verification.matched ? 'auto_resolved' : 'manual_review_required',
                        actor_type: 'system',
                        note: verification.note,
                        metadata: {
                            adaptive_radius_meters: verification.adaptiveRadiusMeters,
                            distance_meters: verification.distanceMeters,
                            confidence: verification.confidence,
                        }
                    }
                })
            }

            const totalItems = await tx.workOrderItem.count({ where: { work_order_id: workOrder.id } })
            const matchedCount = await tx.workProof.count({
                where: { work_order_id: workOrder.id, status: 'matched' }
            })
            if (matchedCount >= totalItems && totalItems > 0) {
                await tx.workOrder.update({
                    where: { id: workOrder.id },
                    data: { status: 'completed', completed_at: new Date() }
                })
            } else if (matchedCount > 0) {
                await tx.workOrder.update({
                    where: { id: workOrder.id },
                    data: { status: 'in_progress' }
                })
            }

            return created
        })

        return { work_order_id: workOrder.id, proof, verification }
    }

    // ── Review queue ────────────────────────────────────────────────────
    async listWorkOrderProofsForReview(panchayatId: number, status?: 'matched' | 'unmatched_manual_review') {
        return this.prisma.workProof.findMany({
            where: {
                status: status ?? 'unmatched_manual_review',
                work_order: { panchayat_id: panchayatId },
            },
            include: {
                work_order: { select: { id: true, work_order_code: true, status: true } },
                complaint: { select: { id: true, status: true } },
                pole: { select: { id: true, pole_number: true, keypad_id: true } },
            },
            orderBy: { uploaded_at: 'desc' },
        })
    }

    // ── Manual approval ─────────────────────────────────────────────────
    async approveProofManual(panchayatId: number, proofId: number, adminUserId: number, approve: boolean, note?: string) {
        const proof = await this.prisma.workProof.findUnique({
            where: { id: proofId },
            include: { work_order: true }
        })
        if (!proof) throw new NotFoundException('Proof not found.')
        if (proof.work_order.panchayat_id !== panchayatId) throw new ForbiddenException('Proof is outside your panchayat.')
        if (!proof.complaint_id) throw new BadRequestException('Proof has no complaint mapping.')

        const nextStatus = approve ? 'matched' : 'rejected'
        const complaintStatus = approve ? 'resolved' : 'resolved_pending_confirmation'
        await this.prisma.$transaction([
            this.prisma.workProof.update({
                where: { id: proofId },
                data: {
                    status: nextStatus,
                    verification_note: note?.trim() || proof.verification_note,
                }
            }),
            this.prisma.complaint.update({
                where: { id: proof.complaint_id },
                data: {
                    status: complaintStatus,
                    resolved_at: approve ? new Date() : null,
                    resolution_location_valid: approve,
                }
            }),
            this.prisma.complaintResolutionAudit.create({
                data: {
                    complaint_id: proof.complaint_id,
                    work_proof_id: proof.id,
                    action: approve ? 'manual_approved' : 'manual_rejected',
                    actor_type: 'admin',
                    actor_id: adminUserId,
                    note: note?.trim() || null,
                }
            }),
        ])
        return { success: true }
    }

    // ── Dashboard metrics ───────────────────────────────────────────────
    async getDashboardMetrics(panchayatId: number) {
        const [activeTenders, openQuotes, openWorkOrders, completedWorkOrders, pendingReview] = await Promise.all([
            this.prisma.tender.count({
                where: { panchayat_id: panchayatId, status: { in: ['open_for_quotations'] } }
            }),
            this.prisma.quotation.count({
                where: { tender: { panchayat_id: panchayatId }, status: { in: ['submitted', 'shortlisted'] } }
            }),
            this.prisma.workOrder.count({
                where: { panchayat_id: panchayatId, status: { in: ['created', 'in_progress'] } }
            }),
            this.prisma.workOrder.count({
                where: { panchayat_id: panchayatId, status: 'completed' }
            }),
            this.prisma.workProof.count({
                where: {
                    work_order: { panchayat_id: panchayatId },
                    status: 'unmatched_manual_review'
                }
            }),
        ])

        return {
            active_tenders: activeTenders,
            open_quotations: openQuotes,
            active_work_orders: openWorkOrders,
            completed_work_orders: completedWorkOrders,
            pending_geo_reviews: pendingReview,
        }
    }

    // ── Inline Geo Verification ─────────────────────────────────────────
    private verifyNearestCandidate(candidates: CandidatePole[], input: GeoInput) {
        const valid = candidates.filter((c) => Number.isFinite(c.latitude) && Number.isFinite(c.longitude))
        const adaptiveRadius = this.computeAdaptiveRadius(valid, input)
        if (valid.length === 0) {
            return { matched: false, nearestPoleId: null, nearestComplaintId: null, distanceMeters: null, adaptiveRadiusMeters: adaptiveRadius, confidence: 0, note: 'No candidate poles with coordinates.' }
        }
        let nearest: { poleId: number; complaintId: number; distance: number } | null = null
        for (const c of valid) {
            const d = distanceMeters(input.uploadLat, input.uploadLng, c.latitude as number, c.longitude as number)
            if (!nearest || d < nearest.distance) nearest = { poleId: c.poleId, complaintId: c.complaintId, distance: d }
        }
        if (!nearest) {
            return { matched: false, nearestPoleId: null, nearestComplaintId: null, distanceMeters: null, adaptiveRadiusMeters: adaptiveRadius, confidence: 0, note: 'Unable to identify nearest pole.' }
        }
        const matched = nearest.distance <= adaptiveRadius
        const confidence = this.computeConfidence(nearest.distance, adaptiveRadius, input)
        return {
            matched, nearestPoleId: nearest.poleId, nearestComplaintId: nearest.complaintId,
            distanceMeters: Number(nearest.distance.toFixed(3)), adaptiveRadiusMeters: adaptiveRadius, confidence,
            note: matched ? 'Proof location matched to nearest targeted defective pole.' : 'Nearest pole outside adaptive radius; manual review required.',
        }
    }

    private computeAdaptiveRadius(candidates: CandidatePole[], input: GeoInput): number {
        let radius = 15
        const avg = this.avgNearestNeighbor(candidates)
        if (avg != null) { if (avg < 25) radius -= 3; else if (avg > 60) radius += 3 }
        const hasExif = Number.isFinite(input.exifLat) && Number.isFinite(input.exifLng)
        if (hasExif) {
            const d = distanceMeters(input.uploadLat, input.uploadLng, input.exifLat as number, input.exifLng as number)
            if (d <= 5) radius -= 2; else if (d > 30) radius += 3
        } else { radius += 1 }
        const now = input.now ?? new Date()
        if (input.capturedAt) {
            const age = Math.abs(now.getTime() - input.capturedAt.getTime()) / 60000
            if (age <= 30) radius -= 1; else if (age > 24 * 60) radius += 2
        }
        return Math.max(10, Math.min(20, Number(radius.toFixed(2))))
    }

    private avgNearestNeighbor(candidates: CandidatePole[]): number | null {
        const v = candidates.filter((c) => Number.isFinite(c.latitude) && Number.isFinite(c.longitude))
        if (v.length < 2) return null
        const dists: number[] = []
        for (let i = 0; i < v.length; i++) {
            let n: number | null = null
            for (let j = 0; j < v.length; j++) {
                if (i === j) continue
                const d = distanceMeters(v[i].latitude as number, v[i].longitude as number, v[j].latitude as number, v[j].longitude as number)
                if (n == null || d < n) n = d
            }
            if (n != null) dists.push(n)
        }
        if (dists.length === 0) return null
        return dists.reduce((a, b) => a + b, 0) / dists.length
    }

    private computeConfidence(distance: number, radius: number, input: GeoInput): number {
        let c = Math.max(0, 1 - (distance / Math.max(radius, 1))) * 0.7
        const hasExif = Number.isFinite(input.exifLat) && Number.isFinite(input.exifLng)
        if (hasExif) {
            const d = distanceMeters(input.uploadLat, input.uploadLng, input.exifLat as number, input.exifLng as number)
            c += d <= 5 ? 0.2 : d <= 20 ? 0.1 : 0
        }
        if (input.capturedAt) {
            const age = Math.abs((input.now ?? new Date()).getTime() - input.capturedAt.getTime()) / 60000
            if (age <= 60) c += 0.1
        }
        return Number((Math.min(1, c) * 100).toFixed(2))
    }

    // ── Shared helpers ──────────────────────────────────────────────────
    private async assertTenderScope(panchayatId: number, tenderId: number) {
        const tender = await this.prisma.tender.findUnique({ where: { id: tenderId } })
        if (!tender) throw new NotFoundException('Tender not found.')
        if (tender.panchayat_id !== panchayatId) throw new ForbiddenException('Tender is outside your panchayat.')
        return tender
    }

    private async resolveInviteByToken(token: string, purpose: 'tender_submission' | 'work_upload') {
        const hash = createHash('sha256').update(token).digest('hex')
        const invite = await this.prisma.tenderInviteLink.findUnique({ where: { token_hash: hash } })
        if (!invite || invite.purpose !== purpose) throw new ForbiddenException('Invalid link token.')
        if (invite.is_revoked) throw new ForbiddenException('This link has been revoked.')
        if (invite.expires_at < new Date()) throw new ForbiddenException('This link has expired.')
        if (invite.max_submissions != null && invite.used_count >= invite.max_submissions) throw new ForbiddenException('Submission limit reached.')
        return invite
    }

    private generateTokenPayload() {
        const token = randomBytes(24).toString('hex')
        const hash = createHash('sha256').update(token).digest('hex')
        return { token, hash, hint: token.slice(0, 6) }
    }

    private async generateWorkOrderCode(): Promise<string> {
        const year = new Date().getUTCFullYear()
        const count = await this.prisma.workOrder.count()
        return `WO-${year}-${String(count + 1).padStart(3, '0')}`
    }
}
