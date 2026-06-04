import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { randomUUID } from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';

const ALLOWED_IMAGE_EXT = new Set(['.jpg', '.jpeg', '.png', '.webp']);

@Injectable()
export class DocumentStorageService {
  private readonly logger = new Logger(DocumentStorageService.name);
  private readonly localRoot = process.env.VERCEL
    ? path.join('/tmp', 'uploads')
    : path.join(process.cwd(), 'uploads');
  private readonly supabaseUrl = process.env.SUPABASE_URL?.trim() ?? '';
  private readonly supabaseServiceKey =
    process.env.SUPABASE_SERVICE_ROLE_KEY?.trim() ?? '';
  private readonly bucket =
    process.env.SUPABASE_STORAGE_BUCKET?.trim() || 'tender-documents';
  private readonly remoteEnabled = Boolean(
    this.supabaseUrl && this.supabaseServiceKey,
  );
  private readonly supabase: SupabaseClient | null = this.remoteEnabled
    ? createClient(this.supabaseUrl, this.supabaseServiceKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      })
    : null;

  private toObjectKey(storagePath: string): string {
    return storagePath.replace(/^\/+/, '');
  }

  private localAbsolutePath(storagePath: string): string {
    const key = this.toObjectKey(storagePath);
    const withinUploads = key.startsWith('uploads/')
      ? key.slice('uploads/'.length)
      : key;
    return path.join(this.localRoot, withinUploads);
  }

  private async ensureLocalParent(storagePath: string): Promise<void> {
    const abs = this.localAbsolutePath(storagePath);
    await fs.mkdir(path.dirname(abs), { recursive: true });
  }

  private localFallbackReason(): string {
    if (!this.supabaseUrl) return 'SUPABASE_URL missing';
    if (!this.supabaseServiceKey) return 'SUPABASE_SERVICE_ROLE_KEY missing';
    return 'remote storage disabled';
  }

  private async writeRemote(
    storagePath: string,
    bytes: Buffer,
    contentType: string,
  ): Promise<void> {
    if (!this.supabase) throw new Error(this.localFallbackReason());
    const key = this.toObjectKey(storagePath);
    const { error } = await this.supabase.storage
      .from(this.bucket)
      .upload(key, bytes, {
        contentType,
        upsert: true,
      });
    if (error) {
      throw new Error(`Supabase upload failed for ${key}: ${error.message}`);
    }
  }

  async writeBuffer(
    storagePath: string,
    bytes: Buffer,
    contentType: string,
  ): Promise<void> {
    if (!bytes?.length) return;
    if (this.remoteEnabled) {
      try {
        await this.writeRemote(storagePath, bytes, contentType);
        return;
      } catch (err: any) {
        this.logger.error(
          `Remote write failed for ${storagePath}: ${err?.message ?? err}`,
        );
        if (process.env.VERCEL) {
          throw new Error(
            `Supabase upload failed: ${err?.message ?? err}. ` +
              `Check your SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and ensure the bucket "${this.bucket}" exists.`,
          );
        }
        this.logger.warn(`Using local disk fallback: ${err?.message ?? err}`);
      }
    } else if (process.env.VERCEL) {
      throw new Error(
        `Remote storage is not configured on Vercel (${this.localFallbackReason()}). ` +
          `Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in Vercel environment variables.`,
      );
    }
    await this.ensureLocalParent(storagePath);
    await fs.writeFile(this.localAbsolutePath(storagePath), bytes);
  }

  async writeUtf8(
    storagePath: string,
    content: string,
    contentType = 'text/html; charset=utf-8',
  ): Promise<void> {
    await this.writeBuffer(
      storagePath,
      Buffer.from(content, 'utf8'),
      contentType,
    );
  }

  /**
   * Save an image buffer and return a URL.
   * On Supabase: uploads to the bucket and returns a full public URL.
   * Locally: writes to disk and returns a `/uploads/...` relative path.
   */
  async saveImageBuffer(
    subdir: string,
    buffer: Buffer,
    originalName: string,
  ): Promise<string> {
    if (!buffer?.length) {
      throw new BadRequestException('Empty file');
    }
    const ext = path.extname(originalName || '').toLowerCase() || '.jpg';
    const safeExt = ALLOWED_IMAGE_EXT.has(ext) ? ext : '.jpg';
    const filename = `${randomUUID()}${safeExt}`;
    const safeSubdir = subdir.replace(/\\/g, '/');
    const objectKey = `${safeSubdir}/${filename}`;

    const mimeMap: Record<string, string> = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.webp': 'image/webp',
    };
    const contentType = mimeMap[safeExt] || 'image/jpeg';

    if (this.remoteEnabled && this.supabase) {
      try {
        await this.writeRemote(objectKey, buffer, contentType);
        const { data } = this.supabase.storage
          .from(this.bucket)
          .getPublicUrl(objectKey);
        return data.publicUrl;
      } catch (err: any) {
        this.logger.error(`Remote image upload failed: ${err?.message ?? err}`);
        if (process.env.VERCEL) {
          throw new Error(
            `Supabase image upload failed: ${err?.message ?? err}. ` +
              `Check SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and bucket "${this.bucket}".`,
          );
        }
        this.logger.warn('Falling back to local disk for image upload');
      }
    } else if (process.env.VERCEL) {
      throw new Error(
        `Cannot save images on Vercel without Supabase (${this.localFallbackReason()}). ` +
          `Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in Vercel environment variables.`,
      );
    }

    // Local disk fallback
    const dir = path.join(this.localRoot, subdir);
    await fs.mkdir(dir, { recursive: true });
    await fs.writeFile(path.join(dir, filename), buffer);
    return path.posix.join('/uploads', subdir.replace(/\\/g, '/'), filename);
  }

  async exists(storagePath: string): Promise<boolean> {
    if (this.remoteEnabled && this.supabase) {
      const key = this.toObjectKey(storagePath);
      const slash = key.lastIndexOf('/');
      const folder = slash === -1 ? '' : key.slice(0, slash);
      const fileName = slash === -1 ? key : key.slice(slash + 1);
      const { data, error } = await this.supabase.storage
        .from(this.bucket)
        .list(folder, {
          limit: 100,
          search: fileName,
        });
      if (!error) {
        return (data ?? []).some((it) => it.name === fileName);
      }
      this.logger.warn(
        `Remote exists check failed, falling back to local disk: ${error.message}`,
      );
    }
    try {
      await fs.access(this.localAbsolutePath(storagePath));
      return true;
    } catch {
      return false;
    }
  }

  async readBuffer(storagePath: string): Promise<Buffer> {
    if (this.remoteEnabled && this.supabase) {
      const key = this.toObjectKey(storagePath);
      const { data, error } = await this.supabase.storage
        .from(this.bucket)
        .download(key);
      if (!error && data) {
        return Buffer.from(await data.arrayBuffer());
      }
      this.logger.warn(
        `Remote read failed for ${key}, trying local disk: ${error?.message ?? 'unknown error'}`,
      );
    }
    try {
      return await fs.readFile(this.localAbsolutePath(storagePath));
    } catch (localErr: any) {
      const reason = this.remoteEnabled
        ? `Remote storage returned an error and local file also missing`
        : `Remote storage not configured (${this.localFallbackReason()}) and local file missing`;
      this.logger.error(
        `${reason} for ${storagePath}: ${localErr?.message ?? localErr}. ` +
          `On Vercel, /tmp is ephemeral; configure SUPABASE_SERVICE_ROLE_KEY for persistent storage.`,
      );
      throw new Error(
        `Document file not found: ${storagePath}. ${reason}. ` +
          `Ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set in Vercel environment variables.`,
      );
    }
  }

  async testConnection(): Promise<{
    ok: boolean;
    message: string;
    buckets?: string[];
  }> {
    if (!this.remoteEnabled || !this.supabase) {
      return {
        ok: false,
        message: `Remote storage disabled: ${this.localFallbackReason()}`,
      };
    }
    try {
      const { data, error } = await this.supabase.storage.listBuckets();
      if (error) {
        return {
          ok: false,
          message: `Failed to list buckets: ${error.message}`,
        };
      }
      const exists = (data ?? []).some((b) => b.name === this.bucket);
      if (!exists) {
        return {
          ok: false,
          message: `Bucket "${this.bucket}" does not exist. Available: ${data.map((b) => b.name).join(', ')}`,
        };
      }
      return {
        ok: true,
        message: `Connected successfully. Bucket "${this.bucket}" exists.`,
        buckets: data.map((b) => b.name),
      };
    } catch (err: any) {
      return { ok: false, message: `Unexpected error: ${err?.message ?? err}` };
    }
  }
}
