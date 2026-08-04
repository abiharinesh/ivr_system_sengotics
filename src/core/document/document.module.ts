import { Module, Global } from '@nestjs/common';
import { DocumentService, StorageAdapter } from './document.service';
import { DocumentBrowserService } from './document-browser.service';
import { DocumentController } from './document.controller';
import { PlatformStorageAdapter } from './platform-storage.adapter';
import { PrismaModule } from '../../prisma/prisma.module';

@Global()
@Module({
  imports: [PrismaModule],
  controllers: [DocumentController],
  providers: [
    DocumentService,
    DocumentBrowserService,
    {
      // Real persistence (Supabase, or local disk in dev) — `DocumentStorageService`
      // is provided by the @Global() StorageModule.
      provide: StorageAdapter,
      useClass: PlatformStorageAdapter,
    },
  ],
  exports: [DocumentService, DocumentBrowserService, StorageAdapter],
})
export class DocumentModule {}
