import { Module } from '@nestjs/common'
import { PrismaModule } from '../prisma/prisma.module'
import { StorageModule } from '../storage/storage.module'
import { AuthModule } from '../auth/auth.module'
import { TenderController } from './tender.controller'
import { TenderService } from './tender.service'
import { VendorService } from './vendor.service'
import { MilestoneService } from './milestone.service'
import { TenderAuditService } from './audit.service'
import { TenderPdfService } from './pdf/pdf.service'
import { TenderPdfController } from './pdf/pdf.controller'
import { TenderPdfPublicController } from './pdf/pdf.public.controller'
import { TenderShareTokenService } from './pdf/share-token.service'
import { TenderPublicController } from './public.controller'
import { TenderPublicService } from './public.service'
import { FieldVerificationController } from './field-verification.controller'
import { FieldVerificationService } from './field-verification.service'
import { FieldVerificationPublicController } from './field-verification.public.controller'

@Module({
    imports: [PrismaModule, StorageModule, AuthModule],
    controllers: [
        TenderController,
        TenderPdfController,
        TenderPdfPublicController,
        TenderPublicController,
        FieldVerificationController,
        FieldVerificationPublicController,
    ],
    providers: [
        TenderService,
        VendorService,
        MilestoneService,
        TenderAuditService,
        TenderPdfService,
        TenderShareTokenService,
        TenderPublicService,
        FieldVerificationService,
    ],
    exports: [TenderService, VendorService, MilestoneService, TenderAuditService],
})
export class TenderModule {}
