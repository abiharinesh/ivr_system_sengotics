import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        ExtractJwt.fromAuthHeaderAsBearerToken(),
        ExtractJwt.fromUrlQueryParameter('token'),
      ]),
      ignoreExpiration: false,
      secretOrKey: (() => {
        const secret = configService.get<string>('JWT_SECRET');
        if (!secret)
          throw new Error(
            'FATAL: JWT_SECRET environment variable is not set. Cannot start server.',
          );
        return secret;
      })(),
    });
  }

  async validate(payload: any) {
    // A signed token proves who issued it, not that the account is still
    // allowed to use the system. Re-check lifecycle state so deactivation and
    // soft deletion take effect immediately instead of waiting for the 7-day
    // token to expire.
    const account = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        is_active: true,
        is_deleted: true,
        role: true,
        user_type: true,
      },
    });
    if (!account || !account.is_active || account.is_deleted) {
      throw new UnauthorizedException('This account is inactive');
    }

    return {
      id: payload.sub,
      email: payload.email,
      // Compatibility fields are sourced from the current account, never
      // trusted from the token. Authorization guards resolve permissions and
      // active role assignments from the database on every protected request.
      role: account.role,
      is_super_admin: false,
      org_unit_id: payload.org_unit_id,
      tenant_id: payload.tenant_id,
      user_type: account.user_type,
      employee_id: payload.employee_id,
      access_scope: payload.access_scope,
    };
  }
}
