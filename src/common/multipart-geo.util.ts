import { BadRequestException } from '@nestjs/common'

function strField(body: Record<string, unknown>, key: string): string | undefined {
    const v = body[key]
    if (v === undefined || v === null) return undefined
    const s = String(v).trim()
    return s.length ? s : undefined
}

export function parseGeoFromBody(body: Record<string, unknown>): {
    latitude: number
    longitude: number
    capturedAt: Date
} {
    const lat = Number(strField(body, 'latitude'))
    const lng = Number(strField(body, 'longitude'))
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
        throw new BadRequestException('latitude and longitude must be valid numbers')
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        throw new BadRequestException('latitude/longitude out of range')
    }
    const raw = strField(body, 'capturedAt')
    if (!raw) throw new BadRequestException('capturedAt is required (ISO 8601)')
    const capturedAt = new Date(raw)
    if (Number.isNaN(capturedAt.getTime())) {
        throw new BadRequestException('capturedAt must be a valid ISO 8601 datetime')
    }
    return { latitude: lat, longitude: lng, capturedAt }
}

export function strFieldOptional(body: Record<string, unknown>, key: string): string | undefined {
    return strField(body, key)
}

export function normalizeLandmarksField(body: Record<string, unknown>): string[] {
    const v = body.landmarks
    if (Array.isArray(v)) {
        return v.map((x) => String(x).trim()).filter((s) => s.length > 0)
    }
    const s = strField(body, 'landmarks')
    if (s) return s.split(',').map((x) => x.trim()).filter(Boolean)
    return []
}
