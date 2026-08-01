import { AsyncLocalStorage } from 'async_hooks';
import { Injectable } from '@nestjs/common';

export interface TenantContextData {
  tenantId: string;
  isSuperAdmin: boolean;
}

/**
 * Request-scoped tenant context, propagated via AsyncLocalStorage so it's
 * readable from anywhere in the async call chain (services, Prisma
 * extensions) without threading tenantId through every function signature.
 *
 * Replaces the old `TenantMiddleware`, which set `req['tenantId']` from
 * `req['user']` — except Express middleware runs *before* guards, so
 * `req['user']` was never populated yet when that middleware executed. It
 * silently fell back to `'default'` on every single request. This class is
 * populated instead by `TenantContextInterceptor`, which runs after
 * `JwtAuthGuard` has resolved the user.
 */
@Injectable()
export class TenantContext {
  private static storage = new AsyncLocalStorage<TenantContextData>();

  run<T>(data: TenantContextData, callback: () => T): T {
    return TenantContext.storage.run(data, callback);
  }

  get current(): TenantContextData | undefined {
    return TenantContext.storage.getStore();
  }
}
