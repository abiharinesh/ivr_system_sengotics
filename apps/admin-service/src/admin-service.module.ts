import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule, SharedAuthModule } from '@app/shared'
import { SuperAdminController, PanchayatAdminController } from './admin-service.controller'
import { AdminServiceService } from './admin-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule,
        SharedAuthModule,
    ],
    controllers: [SuperAdminController, PanchayatAdminController],
    providers: [AdminServiceService],
})
export class AdminServiceModule {}
