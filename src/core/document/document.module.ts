import { Module, Global } from '@nestjs/common';
import { DocumentService, StorageAdapter, LocalStorageAdapter } from './document.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [
    DocumentService,
    {
      provide: StorageAdapter,
      useClass: LocalStorageAdapter,
    },
  ],
  exports: [DocumentService, StorageAdapter],
})
export class DocumentModule {}
