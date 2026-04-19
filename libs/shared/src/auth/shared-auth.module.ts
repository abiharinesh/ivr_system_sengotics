import { Module } from '@nestjs/common'
import { ConfigModule, ConfigService } from '@nestjs/config'
import { PassportModule } from '@nestjs/passport'
import { JwtModule } from '@nestjs/jwt'
import { JwtStrategy } from './jwt.strategy'
import { JwtAuthGuard } from './guards/jwt-auth.guard'
import { RolesGuard } from './guards/roles.guard'

/**
 * SharedAuthModule — import this in any microservice that needs
 * JWT-based authentication and role-based authorization.
 * It configures Passport + JWT using the same JWT_SECRET env var.
 */
@Module({
    imports: [
        ConfigModule,
        PassportModule,
        JwtModule.registerAsync({
            imports: [ConfigModule],
            inject: [ConfigService],
            useFactory: (configService: ConfigService) => {
                const secret = configService.get<string>('JWT_SECRET')
                if (!secret) throw new Error('FATAL: JWT_SECRET environment variable is not set.')
                return { secret, signOptions: { expiresIn: '7d' } }
            }
        })
    ],
    providers: [JwtStrategy, JwtAuthGuard, RolesGuard],
    exports: [JwtModule, JwtAuthGuard, RolesGuard, PassportModule],
})
export class SharedAuthModule {}
