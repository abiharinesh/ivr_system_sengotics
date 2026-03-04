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
    IvrModule,
    VoiceProcessingModule,
    AuthModule,
    SuperAdminModule,
    PanchayatAdminModule
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

