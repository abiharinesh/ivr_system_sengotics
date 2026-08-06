import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { BranchType } from '@prisma/client';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { RbacAdminService } from './rbac-admin.service';
import { RbacAnalyticsService } from './rbac-analytics.service';
import { RoleTemplateService } from './role-template.service';
import { RbacService } from './rbac.service';

interface AuthReq {
  user: {
    id: number;
    role: string;
    tenant_id: string;
    org_unit_id: number | null;
    is_super_admin?: boolean;
  };
}

/**
 * The API behind the role management console.
 *
 * Narrowed to the roles that administer other roles. Note this is deliberately
 * *not* gated on a permission code: a permission that controls who may edit
 * permissions can be granted to yourself, so the check stays on role identity.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin')
@Controller('api/rbac')
export class RbacController {
  constructor(
    private readonly admin: RbacAdminService,
    private readonly rbac: RbacService,
    private readonly analytics: RbacAnalyticsService,
    private readonly templates: RoleTemplateService,
  ) {}

  // ── Templates ─────────────────────────────────────────────────────────────

  /**
   * GET /api/rbac/templates?branch_type=MUNICIPALITY
   *
   * The shipped catalogue, and how many tenants each entry is in use by.
   */
  @Get('templates')
  listTemplates(@Query('branch_type') branchType?: string) {
    return this.templates.listTemplates(branchType as BranchType | undefined);
  }

  /**
   * GET /api/rbac/templates/pending
   *
   * What a sync would change, without changing it. The console shows this
   * before asking anyone to confirm, because "update my roles" is not a button
   * whose effect should be a surprise.
   */
  @Get('templates/pending')
  pendingSync(@Req() req: AuthReq) {
    return this.templates.preview(req.user.tenant_id);
  }

  /**
   * POST /api/rbac/templates/sync
   *
   * Bring this tenant's untouched roles back in line with the catalogue.
   * Roles the tenant has edited are reported and left alone.
   */
  @Post('templates/sync')
  sync(@Req() req: AuthReq, @Body() body: { role_ids?: number[]; dry_run?: boolean }) {
    return this.templates.syncTenant(req.user.tenant_id, req.user.id, {
      dryRun: body?.dry_run ?? false,
      roleIds: body?.role_ids,
    });
  }

  /**
   * GET /api/rbac/roles/:id/template-diff
   *
   * How one role differs from the template it was provisioned from.
   */
  @Get('roles/:id/template-diff')
  templateDiff(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.templates.diff(req.user.tenant_id, id);
  }

  // ── Catalogue ─────────────────────────────────────────────────────────────

  /** GET /api/rbac/summary */
  @Get('summary')
  summary(@Req() req: AuthReq) {
    return this.admin.summary(req.user.tenant_id);
  }

  /**
   * GET /api/rbac/analytics
   *
   * Everything the console's insight views draw: the role × screen-group
   * coverage matrix, per-screen reach, permission distribution, the hierarchy,
   * geographic deployment across branches, near-duplicate roles, findings that
   * need action, and the 30-day change history.
   */
  @Get('analytics')
  analyticsOverview(@Req() req: AuthReq) {
    return this.analytics.overview(req.user.tenant_id);
  }

  /** GET /api/rbac/screens — the tickable screen catalogue, grouped. */
  @Get('screens')
  screens() {
    return this.admin.listScreens();
  }

  /** GET /api/rbac/permissions — the permission catalogue, by module. */
  @Get('permissions')
  permissions() {
    return this.admin.listPermissions();
  }

  // ── Roles ─────────────────────────────────────────────────────────────────

  /** GET /api/rbac/roles?branch_type=MUNICIPALITY */
  @Get('roles')
  listRoles(@Req() req: AuthReq, @Query('branch_type') branchType?: string) {
    let type: BranchType | undefined;
    if (branchType) {
      if (!Object.values(BranchType).includes(branchType as BranchType)) {
        throw new BadRequestException(`Unknown branch type "${branchType}"`);
      }
      type = branchType as BranchType;
    }
    return this.admin.listRoles(req.user.tenant_id, type);
  }

  /** GET /api/rbac/roles/:id */
  @Get('roles/:id')
  getRole(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.admin.getRole(req.user.tenant_id, id);
  }

  /**
   * POST /api/rbac/roles — define a new designation inside your own tenant.
   *
   * The role is created with no grants; screens and permissions are set
   * afterwards through the endpoints below. A council needs this because the
   * shipped roster only covers the six Tamil Nadu body types, and every client
   * has a job title it does not contain.
   */
  @Post('roles')
  createRole(
    @Req() req: AuthReq,
    @Body()
    body: {
      name: string;
      display_name: string;
      display_name_ta?: string;
      department?: string;
      hierarchy_level?: number;
      can_approve?: boolean;
      applicable_branch_types?: string[];
    },
  ) {
    const types = body?.applicable_branch_types ?? [];
    const unknown = types.filter(
      (t) => !Object.values(BranchType).includes(t as BranchType),
    );
    if (unknown.length) {
      throw new BadRequestException(
        `Unknown branch type(s): ${unknown.join(', ')}`,
      );
    }

    return this.admin.createRole(req.user.tenant_id, req.user.id, {
      ...body,
      applicable_branch_types: types as BranchType[],
    });
  }

  /** POST /api/rbac/roles/:id/clone — copy a system template into the tenant. */
  @Post('roles/:id/clone')
  cloneRole(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body('name') name?: string,
  ) {
    return this.admin.cloneRole(req.user.tenant_id, id, req.user.id, name);
  }

  /**
   * PUT /api/rbac/roles/:id/screens — set the whole visible-screen list.
   *
   * This is the endpoint the sidebar toggles write to: switching a screen on
   * here makes it appear for everyone holding the role at their next login.
   */
  @Put('roles/:id/screens')
  setScreens(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body('screen_keys') screenKeys: string[],
  ) {
    if (!Array.isArray(screenKeys)) {
      throw new BadRequestException('screen_keys must be an array');
    }
    return this.admin.setRoleScreens(req.user.tenant_id, id, req.user.id, screenKeys);
  }

  /** PUT /api/rbac/roles/:id/permissions */
  @Put('roles/:id/permissions')
  setPermissions(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body('permission_codes') codes: string[],
  ) {
    if (!Array.isArray(codes)) {
      throw new BadRequestException('permission_codes must be an array');
    }
    return this.admin.setRolePermissions(req.user.tenant_id, id, req.user.id, codes);
  }

  /** PUT /api/rbac/roles/:id/active */
  @Put('roles/:id/active')
  setActive(
    @Req() req: AuthReq,
    @Param('id', ParseIntPipe) id: number,
    @Body('is_active') isActive: boolean,
  ) {
    if (typeof isActive !== 'boolean') {
      throw new BadRequestException('is_active must be true or false');
    }
    return this.admin.setRoleActive(req.user.tenant_id, id, req.user.id, isActive);
  }

  // ── People ────────────────────────────────────────────────────────────────

  /** GET /api/rbac/roles/:id/members */
  @Get('roles/:id/members')
  members(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.admin.listRoleMembers(req.user.tenant_id, id);
  }

  /** POST /api/rbac/assignments */
  @Post('assignments')
  assign(
    @Req() req: AuthReq,
    @Body()
    body: {
      user_id: number;
      role_id: number;
      org_unit_id: number;
      is_primary?: boolean;
    },
  ) {
    const { user_id, role_id, org_unit_id, is_primary } = body ?? ({} as any);
    if (!user_id || !role_id || !org_unit_id) {
      throw new BadRequestException(
        'user_id, role_id and org_unit_id are all required',
      );
    }
    return this.admin.assignRole(
      req.user.tenant_id,
      user_id,
      req.user.id,
      role_id,
      org_unit_id,
      is_primary ?? false,
    );
  }

  /** DELETE /api/rbac/assignments/:id */
  @Delete('assignments/:id')
  revoke(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.admin.revokeRole(req.user.tenant_id, id, req.user.id);
  }

  // ── Self ──────────────────────────────────────────────────────────────────

  /**
   * GET /api/rbac/me/entitlements
   *
   * What the caller may see and do, resolved fresh. The same data rides on the
   * JWT, but a client that has just had its access changed can refresh here
   * without forcing a re-login.
   */
  @Get('me/entitlements')
  // Deliberately an empty `@Roles`, which overrides the class-level list:
  // `RolesGuard` treats an empty requirement as "any authenticated user", and
  // `JwtAuthGuard` still runs.
  //
  // This route answers "what may I, the caller, see and do" about the caller
  // alone. It was gated on a hardcoded list of the eighteen shipped role
  // names, which meant a role a tenant invented through `createRole` — the
  // whole point of tenant self-service — got a 403 asking about itself, and
  // its holder could never refresh their access without signing in again.
  //
  // A list of role names is the wrong gate for this in any case: it has to be
  // edited every time a role ships, and forgetting is silent.
  @Roles()
  async myEntitlements(@Req() req: AuthReq) {
    const ent = await this.rbac.entitlementsFor(req.user.id);
    if (!ent.isSuperAdmin) return ent;

    // A platform operator's menu follows the catalogue rather than grants, so
    // a newly shipped module is reachable without anyone ticking a box.
    const nav = await this.rbac.platformNav();
    return { ...ent, nav, screens: nav.map((s) => s.key) };
  }
}
