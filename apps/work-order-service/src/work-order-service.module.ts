import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule, SharedAuthModule, StorageModule } from '@app/shared'
import { WorkOrderServiceController } from './work-order-service.controller'
import { WorkOrderServiceService } from './work-order-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule,
        SharedAuthModule,
        StorageModule,
    ],
    controllers: [WorkOrderServiceController],
    providers: [WorkOrderServiceService],
})
export class WorkOrderServiceModule {}
