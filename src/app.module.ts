import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { APP_GUARD } from '@nestjs/core'
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler'
import { AppController } from './app.controller'
import { AppService } from './app.service'
import { PrismaModule } from './prisma/prisma.module'
import { IvrModule } from './ivr/ivr.module'
import { VoiceProcessingModule } from './voice-processing/voice-processing.module'
import { AuthModule } from './auth/auth.module'
import { SuperAdminModule } from './super-admin/super-admin.module'
import { PanchayatAdminModule } from './panchayat-admin/panchayat-admin.module'
import { StorageModule } from './storage/storage.module'
import { AgentModule } from './agent/agent.module'
import { ElectricianModule } from './electrician/electrician.module'
import { WhatsAppModule } from './whatsapp/whatsapp.module'
import { ElectricianOpsModule } from './field-ops/field-ops.module'
import { TenderModule } from './tender/tender.module'

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env'
    }),
    ThrottlerModule.forRoot([{
      ttl: 60000,   // 60 seconds
      limit: 30,    // 30 requests per 60s (generous default)
    }]),
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
    TenderModule
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    }
  ]
})
export class AppModule { }

