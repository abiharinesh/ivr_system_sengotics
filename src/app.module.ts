import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { AppController } from './app.controller'
import { AppService } from './app.service'
import { PrismaModule } from './prisma/prisma.module'
import { IvrModule } from './ivr/ivr.module'
import { VoiceProcessingModule } from './voice-processing/voice-processing.module'
import { AdminModule } from './admin/admin.module'

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env'
    }),
    PrismaModule,
    IvrModule,
    VoiceProcessingModule,
    AdminModule
  ],
  controllers: [AppController],
  providers: [AppService]
})
export class AppModule { }
