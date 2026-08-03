import { Injectable, Logger } from '@nestjs/common';
import * as path from 'path';
import { DocumentStorageService } from '../../storage/document-storage.service';
import { StorageAdapter } from './document.service';

const MIME_BY_EXT: Record<string, string> = {
  '.pdf': 'application/pdf',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.tif': 'image/tiff',
  '.tiff': 'image/tiff',
  '.doc': 'application/msword',
  '.docx':
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.xls': 'application/vnd.ms-excel',
  '.xlsx':
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/**
 * Backs the shared DMS with the platform's real storage (Supabase when
 * configured, local disk otherwise).
 *
 * Replaces `LocalStorageAdapter`, which logged the filename and dropped the
 * bytes on the floor — `DocumentService` wrote a metadata row for every upload
 * but nothing was ever persisted, so any module that stored a file through the
 * DMS had a document list pointing at files that did not exist.
 */
@Injectable()
export class PlatformStorageAdapter extends StorageAdapter {
  private readonly logger = new Logger(PlatformStorageAdapter.name);

  constructor(private readonly storage: DocumentStorageService) {
    super();
  }

  private contentTypeFor(key: string): string {
    const ext = path.extname(key).toLowerCase();
    return MIME_BY_EXT[ext] ?? 'application/octet-stream';
  }

  async save(key: string, file: Buffer): Promise<void> {
    await this.storage.writeBuffer(key, file, this.contentTypeFor(key));
  }

  /**
   * Intentionally a no-op. `DocumentService.softDelete` marks the row deleted
   * but keeps it; in a government audit trail the underlying file has to remain
   * retrievable. Purging is a separate, deliberate retention-policy job.
   */
  async delete(key: string): Promise<void> {
    this.logger.log(
      `Soft delete only — retaining stored object ${key} for audit`,
    );
  }

  async getUrl(key: string): Promise<string> {
    return this.storage.publicUrl(key);
  }
}
