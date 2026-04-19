import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule } from '@app/shared'
import { WhatsappServiceController } from './whatsapp-service.controller'
import { WhatsappServiceService } from './whatsapp-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule,
    ],
    controllers: [WhatsappServiceController],
    providers: [WhatsappServiceService],
})
export class WhatsappServiceModule {}
