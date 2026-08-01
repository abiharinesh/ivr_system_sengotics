import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
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
    return {
      id: payload.sub,
      email: payload.email,
      role: payload.role,
      is_super_admin: payload.is_super_admin ?? payload.role === 'super_admin',
      panchayat_id: payload.panchayat_id,
      tenant_id: payload.tenant_id,
      user_type: payload.user_type,
      employee_id: payload.employee_id,
      access_scope: payload.access_scope,
      // RBAC fields from enhanced JWT
      rbac_roles: payload.rbac_roles || [],
      permissions: payload.permissions || [],
    };
  }
}
