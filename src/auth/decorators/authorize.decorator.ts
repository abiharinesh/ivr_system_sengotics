import { SetMetadata } from '@nestjs/common';

export const AUTHORIZATION_KEY = 'authorization-policy';

/**
 * Explicit server-side authorization.  A policy is deliberately about a
 * capability, never about a display role name.  `platformOnly` is reserved
 * for the small set of operations that can alter tenant boundaries or the
 * authorization model itself.
 */
export interface AuthorizationPolicy {
  permissions?: string[];
  module?: string;
  platformOnly?: boolean;
}

export const Authorize = (policy: AuthorizationPolicy) =>
  SetMetadata(AUTHORIZATION_KEY, policy);
