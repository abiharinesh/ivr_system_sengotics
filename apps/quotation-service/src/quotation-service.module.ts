import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule, SharedAuthModule, StorageModule } from '@app/shared'
import { QuotationServiceController } from './quotation-service.controller'
import { QuotationServiceService } from './quotation-service.service'
import { ScoringService } from './scoring.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule,
        SharedAuthModule,
        StorageModule,
    ],
    controllers: [QuotationServiceController],
    providers: [QuotationServiceService, ScoringService],
})
export class QuotationServiceModule {}
