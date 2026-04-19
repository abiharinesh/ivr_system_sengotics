import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule, SharedAuthModule } from '@app/shared'
import { ComplaintServiceController } from './complaint-service.controller'
import { ComplaintServiceService } from './complaint-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule,
        SharedAuthModule,
    ],
    controllers: [ComplaintServiceController],
    providers: [ComplaintServiceService],
})
export class ComplaintServiceModule {}
