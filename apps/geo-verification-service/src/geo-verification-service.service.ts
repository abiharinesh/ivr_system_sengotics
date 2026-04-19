import { Injectable } from '@nestjs/common'
import { distanceMeters } from '@app/shared'

export interface CandidatePole {
    poleId: number
    complaintId: number
    latitude: number | null
    longitude: number | null
}

export interface GeoVerificationInput {
    uploadLat: number
    uploadLng: number
    exifLat?: number | null
    exifLng?: number | null
    capturedAt?: Date | null
    now?: Date
}

export interface GeoVerificationResult {
    matched: boolean
    nearestPoleId: number | null
    nearestComplaintId: number | null
    distanceMeters: number | null
    adaptiveRadiusMeters: number
    confidence: number
    note: string
}

@Injectable()
export class GeoVerificationServiceService {
    verifyNearestCandidate(candidates: CandidatePole[], input: GeoVerificationInput): GeoVerificationResult {
        const validCandidates = candidates.filter((c) => Number.isFinite(c.latitude) && Number.isFinite(c.longitude))
        const adaptiveRadius = this.computeAdaptiveRadius(validCandidates, input)
        if (validCandidates.length === 0) {
            return {
                matched: false,
                nearestPoleId: null,
                nearestComplaintId: null,
                distanceMeters: null,
                adaptiveRadiusMeters: adaptiveRadius,
                confidence: 0,
                note: 'No candidate poles with coordinates.'
            }
        }

        let nearest: { poleId: number; complaintId: number; distance: number } | null = null
        for (const candidate of validCandidates) {
            const d = distanceMeters(
                input.uploadLat,
                input.uploadLng,
                candidate.latitude as number,
                candidate.longitude as number
            )
            if (!nearest || d < nearest.distance) {
                nearest = { poleId: candidate.poleId, complaintId: candidate.complaintId, distance: d }
            }
        }

        if (!nearest) {
            return {
                matched: false,
                nearestPoleId: null,
                nearestComplaintId: null,
                distanceMeters: null,
                adaptiveRadiusMeters: adaptiveRadius,
                confidence: 0,
                note: 'Unable to identify nearest pole.'
            }
        }

        const matched = nearest.distance <= adaptiveRadius
        const confidence = this.computeConfidence(nearest.distance, adaptiveRadius, input)
        return {
            matched,
            nearestPoleId: nearest.poleId,
            nearestComplaintId: nearest.complaintId,
            distanceMeters: Number(nearest.distance.toFixed(3)),
            adaptiveRadiusMeters: adaptiveRadius,
            confidence,
            note: matched
                ? 'Proof location matched to nearest targeted defective pole.'
                : 'Nearest pole outside adaptive radius; manual review required.'
        }
    }

    private computeAdaptiveRadius(candidates: CandidatePole[], input: GeoVerificationInput): number {
        let radius = 15

        const clusteredDistanceAvg = this.averageNearestNeighborDistance(candidates)
        if (clusteredDistanceAvg != null) {
            if (clusteredDistanceAvg < 25) radius -= 3
            else if (clusteredDistanceAvg > 60) radius += 3
        }

        const hasExif = Number.isFinite(input.exifLat) && Number.isFinite(input.exifLng)
        if (hasExif) {
            const exifDelta = distanceMeters(input.uploadLat, input.uploadLng, input.exifLat as number, input.exifLng as number)
            if (exifDelta <= 5) radius -= 2
            else if (exifDelta > 30) radius += 3
        } else {
            radius += 1
        }

        const now = input.now ?? new Date()
        if (input.capturedAt) {
            const ageMinutes = Math.abs(now.getTime() - input.capturedAt.getTime()) / 60000
            if (ageMinutes <= 30) radius -= 1
            else if (ageMinutes > 24 * 60) radius += 2
        }

        if (radius < 10) return 10
        if (radius > 20) return 20
        return Number(radius.toFixed(2))
    }

    private averageNearestNeighborDistance(candidates: CandidatePole[]): number | null {
        const valid = candidates.filter((c) => Number.isFinite(c.latitude) && Number.isFinite(c.longitude))
        if (valid.length < 2) return null

        const nearestDistances: number[] = []
        for (let i = 0; i < valid.length; i++) {
            let nearest: number | null = null
            for (let j = 0; j < valid.length; j++) {
                if (i === j) continue
                const d = distanceMeters(
                    valid[i].latitude as number,
                    valid[i].longitude as number,
                    valid[j].latitude as number,
                    valid[j].longitude as number
                )
                if (nearest == null || d < nearest) nearest = d
            }
            if (nearest != null) nearestDistances.push(nearest)
        }

        if (nearestDistances.length === 0) return null
        const total = nearestDistances.reduce((sum, d) => sum + d, 0)
        return total / nearestDistances.length
    }

    private computeConfidence(distance: number, radius: number, input: GeoVerificationInput): number {
        const distanceComponent = Math.max(0, 1 - (distance / Math.max(radius, 1)))
        let confidence = distanceComponent * 0.7

        const hasExif = Number.isFinite(input.exifLat) && Number.isFinite(input.exifLng)
        if (hasExif) {
            const exifDelta = distanceMeters(input.uploadLat, input.uploadLng, input.exifLat as number, input.exifLng as number)
            confidence += exifDelta <= 5 ? 0.2 : exifDelta <= 20 ? 0.1 : 0
        }

        if (input.capturedAt) {
            const ageMinutes = Math.abs((input.now ?? new Date()).getTime() - input.capturedAt.getTime()) / 60000
            if (ageMinutes <= 60) confidence += 0.1
        }

        if (confidence > 1) confidence = 1
        return Number((confidence * 100).toFixed(2))
    }
}
