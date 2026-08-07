import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class PermissionCacheService {
  private readonly logger = new Logger(PermissionCacheService.name);
  private readonly cache = new Map<string, { data: any; expiresAt: number }>();
  private readonly defaultTtlMs = 5 * 60 * 1000; // 5 minutes default TTL

  get<T>(key: string): T | null {
    const entry = this.cache.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return null;
    }
    return entry.data as T;
  }

  set(key: string, data: any, ttlMs: number = this.defaultTtlMs): void {
    this.cache.set(key, {
      data,
      expiresAt: Date.now() + ttlMs,
    });
  }

  invalidateUser(userId: number): void {
    for (const key of this.cache.keys()) {
      if (
        key.includes(`:user:${userId}:`) ||
        key.startsWith(`user:${userId}:`)
      ) {
        this.cache.delete(key);
      }
    }
    this.logger.debug(`Invalidated cache for userId: ${userId}`);
  }

  invalidateTenant(tenantId: string): void {
    const prefix = `tenant:${tenantId}:`;
    for (const key of this.cache.keys()) {
      if (key.includes(prefix)) {
        this.cache.delete(key);
      }
    }
    this.logger.debug(`Invalidated cache for tenantId: ${tenantId}`);
  }

  clearAll(): void {
    this.cache.clear();
    this.logger.log('Cleared all permission caches');
  }
}
