import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule, SharedAuthModule } from '@app/shared'
import { PoleServiceController } from './pole-service.controller'
import { PoleServiceService } from './pole-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule, SharedAuthModule,
    ],
    controllers: [PoleServiceController],
    providers: [PoleServiceService],
})
export class PoleServiceModule {}
