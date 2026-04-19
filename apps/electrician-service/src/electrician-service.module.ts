import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule, SharedAuthModule, StorageModule } from '@app/shared'
import { ElectricianServiceController, ElectricianInternalController, ElectricianOpsController } from './electrician-service.controller'
import { ElectricianServiceService } from './electrician-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule,
        SharedAuthModule,
        StorageModule,
    ],
    controllers: [ElectricianServiceController, ElectricianInternalController, ElectricianOpsController],
    providers: [ElectricianServiceService],
})
export class ElectricianServiceModule {}
