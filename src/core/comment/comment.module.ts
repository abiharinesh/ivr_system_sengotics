import { Module, Global } from '@nestjs/common';
import { CommentService } from './comment.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [CommentService],
  exports: [CommentService],
})
export class CommentModule {}
