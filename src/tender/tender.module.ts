import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { StorageModule } from '../storage/storage.module';
import { AuthModule } from '../auth/auth.module';
import { TenderController } from './tender.controller';
import { TenderService } from './tender.service';
import { ContractorDirectoryService } from './contractor-directory.service';
import { MilestoneService } from './milestone.service';
import { TenderAuditService } from './audit.service';
import { TenderPdfService } from './pdf/pdf.service';
import { TenderPdfController } from './pdf/pdf.controller';
import { TenderPdfPublicController } from './pdf/pdf.public.controller';
import { TenderShareTokenService } from './pdf/share-token.service';
import { DocumentTemplateSettingsService } from './pdf/document-template-settings.service';
import { PanchayatDocumentTemplateSettingsController } from './pdf/document-template-settings.controller';
import { TenderPublicController } from './public.controller';
import { TenderPublicLinksController } from './public-links.controller';
import { TenderPublicService } from './public.service';
import { FieldVerificationController } from './field-verification.controller';
import { FieldVerificationService } from './field-verification.service';
import { FieldOverlayOcrService } from './field-overlay-ocr.service';
import { FieldVerificationPublicController } from './field-verification.public.controller';
import { ContractorPortalController } from './contractor-portal.controller';
import { ContractorPortalService } from './contractor-portal.service';

@Module({
  imports: [PrismaModule, StorageModule, AuthModule],
  controllers: [
    TenderController,
    TenderPdfController,
    TenderPdfPublicController,
    TenderPublicController,
    TenderPublicLinksController,
    FieldVerificationController,
    FieldVerificationPublicController,
    PanchayatDocumentTemplateSettingsController,
    ContractorPortalController,
  ],
  providers: [
    TenderService,
    ContractorDirectoryService,
    MilestoneService,
    TenderAuditService,
    TenderPdfService,
    TenderShareTokenService,
    DocumentTemplateSettingsService,
    TenderPublicService,
    FieldVerificationService,
    FieldOverlayOcrService,
    ContractorPortalService,
  ],
  exports: [
    TenderService,
    ContractorDirectoryService,
    MilestoneService,
    TenderAuditService,
    DocumentTemplateSettingsService,
    TenderPdfService,
    FieldVerificationService,
    TenderShareTokenService,
  ],
})
export class TenderModule {}
