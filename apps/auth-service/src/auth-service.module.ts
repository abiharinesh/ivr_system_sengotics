import { Module } from '@nestjs/common'
import { ConfigModule, ConfigService } from '@nestjs/config'
import { JwtModule } from '@nestjs/jwt'
import { PassportModule } from '@nestjs/passport'
import { PrismaModule, JwtStrategy } from '@app/shared'
import { AuthServiceController } from './auth-service.controller'
import { AuthServiceService } from './auth-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule,
        PassportModule,
        JwtModule.registerAsync({
            imports: [ConfigModule],
            inject: [ConfigService],
            useFactory: (configService: ConfigService) => {
                const secret = configService.get<string>('JWT_SECRET')
                if (!secret) throw new Error('FATAL: JWT_SECRET is not set.')
                return { secret, signOptions: { expiresIn: '7d' } }
            }
        }),
    ],
    controllers: [AuthServiceController],
    providers: [AuthServiceService, JwtStrategy],
})
export class AuthServiceModule {}
