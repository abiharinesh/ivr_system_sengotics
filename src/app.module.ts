import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { EventEmitterModule } from '@nestjs/event-emitter';
import {
  TenantModule,
  AuditModule,
  NumberGenModule,
  CommentModule,
  WorkflowModule,
  NotificationModule,
  SlaModule,
  DocumentModule,
} from './core';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { IvrModule } from './ivr/ivr.module';
import { VoiceProcessingModule } from './voice-processing/voice-processing.module';
import { AuthModule } from './auth/auth.module';
import { SuperAdminModule } from './super-admin/super-admin.module';
import { PanchayatAdminModule } from './panchayat-admin/panchayat-admin.module';
import { StorageModule } from './storage/storage.module';
import { AgentModule } from './agent/agent.module';
import { ElectricianModule } from './electrician/electrician.module';
import { WhatsAppModule } from './whatsapp/whatsapp.module';
import { ElectricianOpsModule } from './field-ops/field-ops.module';
import { TenderModule } from './tender/tender.module';
import { ZoneModule } from './zone/zone.module';
import { ReportsModule } from './reports/reports.module';
import { WaterSupplyModule } from './water-supply/water-supply.module';
import { PlumberModule } from './plumber/plumber.module';
import { CitizenModule } from './citizen/citizen.module';
import { PublicReportModule } from './public-report/public-report.module';

// Revenue Generation Modules
import { AdCampaignModule } from './ad-campaign/ad-campaign.module';
import { PenaltyModule } from './penalty/penalty.module';
import { PropertyTaxModule } from './property-tax/property-tax.module';
import { CertificateModule } from './certificate/certificate.module';
import { AssetBookingModule } from './asset-booking/asset-booking.module';
import { MarketModule } from './market/market.module';
import { AssetModule } from './asset/asset.module';
import { FormModule } from './form/form.module';
import { ContractorModule } from './contractor/contractor.module';
import { InspectionModule } from './inspection/inspection.module';
import { SearchModule } from './search/search.module';
import { CitizenPortalModule } from './citizen-portal/citizen-portal.module';
import { SyncModule } from './sync/sync.module';
import { MunicipalityModule } from './municipality/municipality.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60000, // 60 seconds
        limit: 30, // 30 requests per 60s (generous default)
      },
    ]),
    ScheduleModule.forRoot(),
    PrismaModule,
    StorageModule,
    IvrModule,
    VoiceProcessingModule,
    AuthModule,
    WhatsAppModule,
    ElectricianOpsModule,
    SuperAdminModule,
    PanchayatAdminModule,
    AgentModule,
    ElectricianModule,
    TenderModule,
    ZoneModule,
    ReportsModule,
    WaterSupplyModule,
    PlumberModule,
    CitizenModule,
    PublicReportModule,
    
    // Revenue Generation Modules
    AdCampaignModule,
    PenaltyModule,
    PropertyTaxModule,
    CertificateModule,
    AssetBookingModule,
    MarketModule,
    AssetModule,
    FormModule,
    ContractorModule,
    InspectionModule,
    SearchModule,
    CitizenPortalModule,
    SyncModule,
    MunicipalityModule,

    // Core Platform Modules (Phase 0)
    EventEmitterModule.forRoot(),
    TenantModule,
    AuditModule,
    NumberGenModule,
    CommentModule,
    WorkflowModule,
    NotificationModule,
    SlaModule,
    DocumentModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
