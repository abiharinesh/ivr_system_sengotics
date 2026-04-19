import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { GeoVerificationServiceController } from './geo-verification-service.controller'
import { GeoVerificationServiceService } from './geo-verification-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
    ],
    controllers: [GeoVerificationServiceController],
    providers: [GeoVerificationServiceService],
})
export class GeoVerificationServiceModule {}
