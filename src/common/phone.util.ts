import { BadRequestException } from '@nestjs/common'

/**
 * Normalize an Indian phone number to E.164 (`+91XXXXXXXXXX`).
 *
 * Accepts: `+91 98765 43210`, `91-98765-43210`, `09876543210`, `9876543210`, etc.
 * Returns the canonical E.164 string or throws BadRequestException on failure.
 */
export function normalizePhoneE164(input: string | undefined | null): string {
    if (!input) throw new BadRequestException('phone is required')
    const digits = String(input).replace(/[^0-9]/g, '')
    if (!digits) throw new BadRequestException('phone must contain digits')

    let local: string
    if (digits.length === 10) {
        local = digits
    } else if (digits.length === 11 && digits.startsWith('0')) {
        local = digits.slice(1)
    } else if (digits.length === 12 && digits.startsWith('91')) {
        local = digits.slice(2)
    } else if (digits.length === 13 && digits.startsWith('091')) {
        local = digits.slice(3)
    } else {
        throw new BadRequestException(`phone "${input}" is not a valid Indian number`)
    }

    if (!/^[6-9]\d{9}$/.test(local)) {
        throw new BadRequestException(`phone "${input}" is not a valid Indian mobile number`)
    }
    return `+91${local}`
}

/** Cheap, stable hash used for rate-limit bucket keys (NOT cryptographic). */
export function phoneHash(phoneE164: string): string {
    let h = 0
    for (let i = 0; i < phoneE164.length; i++) {
        h = ((h << 5) - h + phoneE164.charCodeAt(i)) | 0
    }
    return `p${(h >>> 0).toString(36)}`
}
