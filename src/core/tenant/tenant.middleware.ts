import { Injectable, NestMiddleware, UnauthorizedException } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

/**
 * Extracts tenant_id from the JWT payload and attaches it to the request.
 * All downstream services access req['tenantId'] for scoping queries.
 */
@Injectable()
export class TenantMiddleware implements NestMiddleware {
  use(req: Request, _res: Response, next: NextFunction) {
    // tenant_id comes from the decoded JWT (set by auth guard)
    const user = req['user'] as any;
    if (user?.tenant_id) {
      req['tenantId'] = user.tenant_id;
    } else {
      // For unauthenticated routes (public report, citizen portal), default tenant
      req['tenantId'] = 'default';
    }
    next();
  }
}
