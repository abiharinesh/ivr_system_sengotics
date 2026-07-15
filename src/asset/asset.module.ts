import { Module } from '@nestjs/common';
import { AssetController } from './asset.controller';
import { AssetService } from './asset.service';
import { PrismaModule } from '../prisma/prisma.module';
import { TenantModule } from '../core/tenant/tenant.module';
import { NumberGenModule } from '../core/number-gen/number-gen.module';
import { AuditModule } from '../core/audit/audit.module';
import { DocumentModule } from '../core/document/document.module';

@Module({
  imports: [
    PrismaModule,
    TenantModule,
    NumberGenModule,
    AuditModule,
    DocumentModule,
  ],
  controllers: [AssetController],
  providers: [AssetService],
  exports: [AssetService],
})
export class AssetModule {}
