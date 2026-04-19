import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { PrismaModule, SharedAuthModule, StorageModule } from '@app/shared'
import { AgentServiceController } from './agent-service.controller'
import { AgentServiceService } from './agent-service.service'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        PrismaModule,
        SharedAuthModule,
        StorageModule,
    ],
    controllers: [AgentServiceController],
    providers: [AgentServiceService],
})
export class AgentServiceModule {}
