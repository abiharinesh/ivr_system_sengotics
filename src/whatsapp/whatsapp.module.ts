import { Module } from '@nestjs/common'
import { PrismaModule } from '../prisma/prisma.module'
import { ElectricianOpsModule } from '../field-ops/field-ops.module'
import { WhatsAppService } from './whatsapp.service'
import { WhatsAppWebhookController } from './whatsapp-webhook.controller'

@Module({
    imports: [PrismaModule, ElectricianOpsModule],
    controllers: [WhatsAppWebhookController],
    providers: [WhatsAppService],
    exports: [WhatsAppService],
})
export class WhatsAppModule {}
