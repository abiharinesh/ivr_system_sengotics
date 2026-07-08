import { Module } from '@nestjs/common';
import { PenaltyService } from './penalty.service';
import { PenaltyController } from './penalty.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [PenaltyController],
  providers: [PenaltyService],
  exports: [PenaltyService],
})
export class PenaltyModule {}
