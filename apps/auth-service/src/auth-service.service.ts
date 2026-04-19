import { Injectable, UnauthorizedException } from '@nestjs/common'
import { JwtService } from '@nestjs/jwt'
import * as bcrypt from 'bcrypt'
import { PrismaService } from '@app/shared'

@Injectable()
export class AuthServiceService {
    constructor(
        private prisma: PrismaService,
        private jwtService: JwtService,
    ) {}

    async login(email: string, password: string) {
        const user = await this.prisma.user.findUnique({ where: { email } })
        if (!user) throw new UnauthorizedException('Invalid credentials')

        const valid = await bcrypt.compare(password, user.password_hash)
        if (!valid) throw new UnauthorizedException('Invalid credentials')

        const payload = {
            sub: user.id,
            email: user.email,
            role: user.role,
            panchayat_id: user.panchayat_id,
        }

        return {
            access_token: this.jwtService.sign(payload),
            role: user.role,
            panchayat_id: user.panchayat_id,
        }
    }
}
