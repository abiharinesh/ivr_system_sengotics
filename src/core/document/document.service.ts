import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Interface representing a file upload payload.
 */
export interface FileUploadDto {
  tenantId: string;
  branchId: number;
  title: string;
  fileName: string;
  buffer: Buffer;
  mimeType: string;
  uploadedBy: number;
  module?: string;
  entityType?: string;
  entityId?: number;
  folderId?: number;
}

/**
 * Storage adapter abstract class for file upload strategies.
 */
export abstract class StorageAdapter {
  abstract save(key: string, file: Buffer): Promise<void>;
  abstract delete(key: string): Promise<void>;
  abstract getUrl(key: string): Promise<string>;
}

/**
 * Default local storage adapter for development and on-premise setups.
 */
@Injectable()
export class LocalStorageAdapter extends StorageAdapter {
  // A mock local storage that prints actions
  private readonly logger = new Logger(LocalStorageAdapter.name);

  async save(key: string, _file: Buffer): Promise<void> {
    this.logger.log(`[LocalStorage] Saving file: ${key}`);
  }

  async delete(key: string): Promise<void> {
    this.logger.log(`[LocalStorage] Deleting file: ${key}`);
  }

  async getUrl(key: string): Promise<string> {
    return `/uploads/${key}`;
  }
}

/**
 * Reusable document management service. Handles version control,
 * digital signatures, folders, S3/local abstraction, and tagging.
 */
@Injectable()
export class DocumentService {
  private readonly logger = new Logger(DocumentService.name);

  constructor(
    private prisma: PrismaService,
    private storage: StorageAdapter,
  ) {}

  /**
   * Upload a new document or a new version of an existing document.
   */
  async upload(dto: FileUploadDto, parentDocId?: number): Promise<any> {
    const fileExtension = dto.fileName.split('.').pop() || '';
    const uniqueKey = `${dto.tenantId}/${dto.branchId}/${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExtension}`;

    // 1. Save to physical storage
    await this.storage.save(uniqueKey, dto.buffer);
    const fileUrl = await this.storage.getUrl(uniqueKey);

    let version = 1;
    if (parentDocId) {
      const parent = await this.prisma.document.findUnique({
        where: { id: parentDocId },
      });
      if (parent) {
        version = parent.version + 1;
      }
    }

    // 2. Save metadata to DB
    const doc = await this.prisma.document.create({
      data: {
        tenant_id: dto.tenantId,
        branch_id: dto.branchId,
        folder_id: dto.folderId ?? null,
        title: dto.title,
        file_name: dto.fileName,
        storage_key: uniqueKey,
        file_url: fileUrl,
        file_size_bytes: BigInt(dto.buffer.length),
        mime_type: dto.mimeType,
        version,
        parent_doc_id: parentDocId ?? null,
        module: dto.module ?? null,
        entity_type: dto.entityType ?? null,
        entity_id: dto.entityId ?? null,
        uploaded_by: dto.uploadedBy,
      },
    });

    this.logger.log(`Uploaded document "${dto.title}" (v${version}) with key ${uniqueKey}`);

    return {
      ...doc,
      file_size_bytes: doc.file_size_bytes?.toString(),
    };
  }

  /**
   * Fetch documents linked to a specific entity.
   */
  async getForEntity(
    tenantId: string,
    entityType: string,
    entityId: number,
  ) {
    const docs = await this.prisma.document.findMany({
      where: {
        tenant_id: tenantId,
        entity_type: entityType,
        entity_id: entityId,
        is_deleted: false,
      },
      orderBy: { version: 'desc' },
    });

    return docs.map((d) => ({
      ...d,
      file_size_bytes: d.file_size_bytes?.toString(),
    }));
  }

  /**
   * Apply a digital signature metadata block to a document.
   */
  async sign(
    documentId: number,
    signerName: string,
    certHash: string,
  ) {
    const signature = {
      signer: signerName,
      signed_at: new Date().toISOString(),
      cert_hash: certHash,
    };

    return this.prisma.document.update({
      where: { id: documentId },
      data: { digital_signature: signature },
    });
  }

  /**
   * Soft delete a document.
   */
  async softDelete(documentId: number, userId: number) {
    return this.prisma.document.update({
      where: { id: documentId },
      data: {
        is_deleted: true,
        deleted_at: new Date(),
        deleted_by: userId,
      },
    });
  }
}
