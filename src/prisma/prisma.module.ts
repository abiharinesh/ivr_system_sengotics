import { Module, Global } from '@nestjs/common'
import { PrismaService } from './prisma.service'
import { DbSetupService } from './db-setup.service'

@Global()
@Module({
    providers: [PrismaService, DbSetupService],
    exports: [PrismaService, DbSetupService]
})
export class PrismaModule { }
