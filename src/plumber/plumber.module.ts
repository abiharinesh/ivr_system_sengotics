import { Module } from '@nestjs/common';
import { PlumberController } from './plumber.controller';
import { PlumberService } from './plumber.service';
import { PlumberOpsService } from './plumber-ops.service';

@Module({
  controllers: [PlumberController],
  providers: [PlumberService, PlumberOpsService],
  exports: [PlumberOpsService],
})
export class PlumberModule {}
