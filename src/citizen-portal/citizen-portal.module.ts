import { Module } from '@nestjs/common';
import { CitizenPortalController } from './citizen-portal.controller';
import { CitizenPortalService } from './citizen-portal.service';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    PrismaModule,
    AuthModule,
  ],
  controllers: [CitizenPortalController],
  providers: [CitizenPortalService],
  exports: [CitizenPortalService],
})
export class CitizenPortalModule {}
