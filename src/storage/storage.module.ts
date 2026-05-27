import { Global, Module } from '@nestjs/common'
import { LocalFilesService } from './local-files.service'
import { DocumentStorageService } from './document-storage.service'

@Global()
@Module({
    providers: [LocalFilesService, DocumentStorageService],
    exports: [LocalFilesService, DocumentStorageService],
})
export class StorageModule {}
