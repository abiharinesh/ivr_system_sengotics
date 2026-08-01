import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { Observable } from 'rxjs';
import { TenantContext } from './tenant-context';

/**
 * Populates `TenantContext` for the duration of a request from the already-
 * authenticated `req.user` (set by JwtAuthGuard, which runs before this
 * interceptor). Unauthenticated routes simply get no context — callers must
 * treat an absent context as "no tenant scoping available", never as
 * "assume default tenant".
 */
@Injectable()
export class TenantContextInterceptor implements NestInterceptor {
  constructor(private readonly tenantContext: TenantContext) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const user = req?.user;

    if (!user?.tenant_id) {
      return next.handle();
    }

    let result!: Observable<any>;
    this.tenantContext.run(
      { tenantId: user.tenant_id, isSuperAdmin: !!user.is_super_admin },
      () => {
        result = next.handle();
      },
    );
    return result;
  }
}
