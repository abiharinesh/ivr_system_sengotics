import { Module, Global } from '@nestjs/common';
import { DocumentService, StorageAdapter } from './document.service';
import { PlatformStorageAdapter } from './platform-storage.adapter';
import { PrismaModule } from '../../prisma/prisma.module';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [
    DocumentService,
    {
      // Real persistence (Supabase, or local disk in dev) — `DocumentStorageService`
      // is provided by the @Global() StorageModule.
      provide: StorageAdapter,
      useClass: PlatformStorageAdapter,
    },
  ],
  exports: [DocumentService, StorageAdapter],
})
export class DocumentModule {}
