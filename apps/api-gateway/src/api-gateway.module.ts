import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { AuthRoutes } from './routes/auth.routes'
import { SuperAdminRoutes } from './routes/superadmin.routes'
import { AdminRoutes } from './routes/admin.routes'
import { ProcurementRoutes } from './routes/procurement.routes'
import { IvrRoutes } from './routes/ivr.routes'
import { WhatsappRoutes } from './routes/whatsapp.routes'
import { AgentRoutes } from './routes/agent.routes'
import { ElectricianRoutes } from './routes/electrician.routes'

@Module({
    imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
    ],
    controllers: [
        AuthRoutes,
        SuperAdminRoutes,
        AdminRoutes,
        ProcurementRoutes,
        IvrRoutes,
        WhatsappRoutes,
        AgentRoutes,
        ElectricianRoutes,
    ],
    providers: [],
})
export class ApiGatewayModule {}
