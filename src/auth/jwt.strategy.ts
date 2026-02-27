import { Injectable } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { PassportStrategy } from '@nestjs/passport'
import { ExtractJwt, Strategy } from 'passport-jwt'

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
    constructor(configService: ConfigService) {
        super({
            jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
            ignoreExpiration: false,
            secretOrKey: configService.get<string>('JWT_SECRET', 'ivr_secret_key_change_me')
        })
    }

    async validate(payload: { sub: number; email: string; role: string; panchayat_id: number | null }) {
        return {
            id: payload.sub,
            email: payload.email,
            role: payload.role,
            panchayat_id: payload.panchayat_id
        }
    }
}
