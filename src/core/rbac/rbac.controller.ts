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
  ) {}

  // ── Catalogue ─────────────────────────────────────────────────────────────

  /** GET /api/rbac/summary */
  @Get('summary')
  summary(@Req() req: AuthReq) {
    return this.admin.summary(req.user.tenant_id);
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
  @Roles(
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'municipal_engineer',
    'assistant_engineer',
    'junior_engineer',
    'revenue_officer',
    'revenue_inspector',
    'health_officer',
    'sanitary_inspector',
    'town_planning_officer',
    'registrar',
    'licensing_clerk',
    'i3c_staff',
    'contractor',
    'agent',
    'electrician',
    'plumber',
  )
  async myEntitlements(@Req() req: AuthReq) {
    const ent = await this.rbac.entitlementsFor(req.user.id);
    const screens = ent.isSuperAdmin
      ? await this.rbac.platformScreens()
      : ent.screens;
    return { ...ent, screens };
  }
}
