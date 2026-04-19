import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule, SharedAuthModule } from '@app/shared'
import { TenderServiceController } from './tender-service.controller'
import { TenderServiceService } from './tender-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule, SharedAuthModule,
    ],
    controllers: [TenderServiceController],
    providers: [TenderServiceService],
})
export class TenderServiceModule {}
