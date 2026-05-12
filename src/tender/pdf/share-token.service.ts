import { Injectable, UnauthorizedException } from '@nestjs/common'
import { JwtService } from '@nestjs/jwt'

export type ShareTokenKind = 'doc' | 'zip'

export interface ShareTokenPayload {
    sub: 'doc-download'
    kind: ShareTokenKind
    tenderId: number
    docId?: number
    /** ISO seconds since epoch (set automatically). */
    iat?: number
    /** ISO seconds since epoch (set automatically). */
    exp?: number
}

/** Server-side cap: an officer cannot mint a share link longer than this. */
export const SHARE_TOKEN_MAX_MINUTES = 60
export const SHARE_TOKEN_DEFAULT_MINUTES = 15

/**
 * Mints / verifies the short-lived JWT used by public document share links.
 * Reuses the existing AuthModule JWT_SECRET so a secret rotation invalidates
 * all live share links automatically.
 */
@Injectable()
export class TenderShareTokenService {
    constructor(private readonly jwt: JwtService) {}

    sign(payload: Omit<ShareTokenPayload, 'sub' | 'iat' | 'exp'>, ttlMinutes: number): {
        token: string
        expiresAt: Date
    } {
        const clamped = Math.min(
            SHARE_TOKEN_MAX_MINUTES,
            Math.max(1, Math.floor(ttlMinutes)),
        )
        const expiresAt = new Date(Date.now() + clamped * 60_000)
        const token = this.jwt.sign(
            { sub: 'doc-download', ...payload } satisfies ShareTokenPayload,
            { expiresIn: `${clamped}m` },
        )
        return { token, expiresAt }
    }

    /** Throws `UnauthorizedException` on any failure (expired, bad sig, wrong sub). */
    verify(token: string): ShareTokenPayload {
        try {
            const decoded = this.jwt.verify<ShareTokenPayload>(token)
            if (decoded?.sub !== 'doc-download') {
                throw new UnauthorizedException('Invalid token subject')
            }
            if (decoded.kind !== 'doc' && decoded.kind !== 'zip') {
                throw new UnauthorizedException('Invalid token kind')
            }
            if (!Number.isInteger(decoded.tenderId)) {
                throw new UnauthorizedException('Invalid tender claim')
            }
            if (decoded.kind === 'doc' && !Number.isInteger(decoded.docId)) {
                throw new UnauthorizedException('Invalid doc claim')
            }
            return decoded
        } catch (err) {
            if (err instanceof UnauthorizedException) throw err
            throw new UnauthorizedException('Invalid or expired share link')
        }
    }
}
