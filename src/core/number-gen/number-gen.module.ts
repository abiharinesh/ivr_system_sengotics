import { Module, Global } from '@nestjs/common';
import { NumberGenService } from './number-gen.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [NumberGenService],
  exports: [NumberGenService],
})
export class NumberGenModule {}
