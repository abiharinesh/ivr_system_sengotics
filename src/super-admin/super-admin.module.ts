import { Module } from '@nestjs/common'
import { SuperAdminService } from './super-admin.service'
import { SuperAdminController } from './super-admin.controller'
import { PrismaModule } from '../prisma/prisma.module'
import { AuthModule } from '../auth/auth.module'

@Module({
    imports: [PrismaModule, AuthModule],
    providers: [SuperAdminService],
    controllers: [SuperAdminController]
})
export class SuperAdminModule { }
