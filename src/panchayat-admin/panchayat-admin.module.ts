import { Module } from '@nestjs/common'
import { PanchayatAdminService } from './panchayat-admin.service'
import { PanchayatAdminController } from './panchayat-admin.controller'
import { PrismaModule } from '../prisma/prisma.module'
import { AuthModule } from '../auth/auth.module'

@Module({
    imports: [PrismaModule, AuthModule],
    providers: [PanchayatAdminService],
    controllers: [PanchayatAdminController]
})
export class PanchayatAdminModule { }
