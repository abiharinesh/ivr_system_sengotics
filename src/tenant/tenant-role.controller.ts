import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Req,
  ParseIntPipe,
  UseGuards,
  ForbiddenException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { PermissionCacheService } from '../core/rbac/permission-cache.service';
import { FeatureGateService } from '../core/rbac/feature-gate.service';

export interface CreateRoleDto {
  name: string;
  display_name: string;
  display_name_ta?: string;
  template_id?: number;
  department?: string;
  hierarchy_level?: number;
  permission_ids?: number[];
  screen_ids?: number[];
}

export interface UpdateRoleDto {
  display_name?: string;
  display_name_ta?: string;
  department?: string;
  hierarchy_level?: number;
  permission_ids?: number[];
  screen_ids?: number[];
  is_active?: boolean;
}

@UseGuards(JwtAuthGuard)
@Controller('api/tenant/roles')
export class TenantRoleController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly cache: PermissionCacheService,
    private readonly gate: FeatureGateService,
  ) {}

  private extractTenantId(req: any): string {
    const tenantId = req.user?.tenant_id;
    if (!tenantId) {
      throw new ForbiddenException('Tenant context missing from request');
    }
    return tenantId;
  }

  private async authorize(req: any, permissionCode: string): Promise<void> {
    await this.gate.checkOrThrow({
      userId: req.user.id,
      tenantId: this.extractTenantId(req),
      orgUnitId: req.user.org_unit_id,
      moduleKey: 'core',
      permissionCode,
    });
  }

  @Get()
  async listTenantRoles(@Req() req: any) {
    await this.authorize(req, 'roles.read');
    const tenantId = this.extractTenantId(req);
    return this.prisma.role.findMany({
      where: {
        OR: [{ tenant_id: tenantId }, { tenant_id: '__system__' }],
        is_active: true,
      },
      include: {
        permissions: { select: { permission: true } },
        screen_access: { select: { screen: true, can_view: true } },
      },
      orderBy: { hierarchy_level: 'asc' },
    });
  }

  @Get('templates')
  async listAvailableRoleTemplates(@Req() req: any) {
    await this.authorize(req, 'roles.read');
    const tenantId = this.extractTenantId(req);

    // Filter role templates enabled for this tenant
    const enabledTemplates = await this.prisma.tenantRoleTemplate.findMany({
      where: { tenant_id: tenantId, enabled: true },
      select: { role_template_id: true },
    });

    const enabledIds = new Set(enabledTemplates.map((t) => t.role_template_id));

    const systemTemplates = await this.prisma.role.findMany({
      where: { tenant_id: '__system__', org_unit_id: null },
      orderBy: { hierarchy_level: 'asc' },
    });

    // If tenant has explicit entries, filter them; otherwise return all published system templates
    if (enabledIds.size > 0) {
      return systemTemplates.filter((t) => enabledIds.has(t.id));
    }

    return systemTemplates;
  }

  @Get(':id')
  async getRole(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    await this.authorize(req, 'roles.read');
    const tenantId = this.extractTenantId(req);
    const role = await this.prisma.role.findFirst({
      where: { id, OR: [{ tenant_id: tenantId }, { tenant_id: '__system__' }] },
      include: {
        permissions: { select: { permission: true } },
        screen_access: { select: { screen: true, can_view: true } },
      },
    });

    if (!role) {
      throw new NotFoundException(`Role with ID ${id} not found`);
    }

    return role;
  }

  @Post()
  async createCustomRole(@Req() req: any, @Body() dto: CreateRoleDto) {
    await this.authorize(req, 'roles.write');
    const tenantId = this.extractTenantId(req);
    const actorUserId = req.user?.id;

    if (!dto.name || !dto.display_name) {
      throw new BadRequestException('Role name and display_name are required');
    }

    const slugifiedName = dto.name.toLowerCase().replace(/[^a-z0-9_]+/g, '_');

    const existing = await this.prisma.role.findFirst({
      where: { tenant_id: tenantId, name: slugifiedName, org_unit_id: null },
    });

    if (existing) {
      throw new BadRequestException(
        `Role with name "${slugifiedName}" already exists for tenant`,
      );
    }

    const newRole = await this.prisma.$transaction(async (tx) => {
      const role = await tx.role.create({
        data: {
          tenant_id: tenantId,
          name: slugifiedName,
          display_name: dto.display_name,
          display_name_ta: dto.display_name_ta ?? null,
          department: dto.department ?? null,
          hierarchy_level: dto.hierarchy_level ?? 5,
          template_id: dto.template_id ?? null,
          customised_at: new Date(),
        },
      });

      if (dto.permission_ids && dto.permission_ids.length > 0) {
        await tx.rolePermission.createMany({
          data: dto.permission_ids.map((pid) => ({
            role_id: role.id,
            permission_id: pid,
            granted_by: actorUserId,
          })),
        });
      }

      if (dto.screen_ids && dto.screen_ids.length > 0) {
        await tx.roleScreenAccess.createMany({
          data: dto.screen_ids.map((sid) => ({
            role_id: role.id,
            screen_id: sid,
            can_view: true,
            granted_by: actorUserId,
          })),
        });
      }

      return role;
    });

    this.cache.invalidateTenant(tenantId);

    await this.audit.log({
      tenantId,
      actorUserId,
      action: 'role.create',
      newValue: {
        roleId: newRole.id,
        name: newRole.name,
        display_name: newRole.display_name,
      },
    });

    return this.getRole(req, newRole.id);
  }

  @Patch(':id')
  async updateCustomRole(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateRoleDto,
  ) {
    await this.authorize(req, 'roles.write');
    const tenantId = this.extractTenantId(req);
    const actorUserId = req.user?.id;

    const role = await this.prisma.role.findFirst({
      where: { id, tenant_id: tenantId },
    });

    if (!role) {
      throw new NotFoundException(`Custom role #${id} not found for tenant`);
    }

    if (role.is_system) {
      throw new ForbiddenException(
        'System default roles cannot be modified directly',
      );
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.role.update({
        where: { id },
        data: {
          display_name: dto.display_name ?? undefined,
          display_name_ta: dto.display_name_ta ?? undefined,
          department: dto.department ?? undefined,
          hierarchy_level: dto.hierarchy_level ?? undefined,
          is_active: dto.is_active ?? undefined,
          customised_at: new Date(),
        },
      });

      if (dto.permission_ids !== undefined) {
        await tx.rolePermission.deleteMany({ where: { role_id: id } });
        if (dto.permission_ids.length > 0) {
          await tx.rolePermission.createMany({
            data: dto.permission_ids.map((pid) => ({
              role_id: id,
              permission_id: pid,
              granted_by: actorUserId,
            })),
          });
        }
      }

      if (dto.screen_ids !== undefined) {
        await tx.roleScreenAccess.deleteMany({ where: { role_id: id } });
        if (dto.screen_ids.length > 0) {
          await tx.roleScreenAccess.createMany({
            data: dto.screen_ids.map((sid) => ({
              role_id: id,
              screen_id: sid,
              can_view: true,
              granted_by: actorUserId,
            })),
          });
        }
      }
    });

    this.cache.invalidateTenant(tenantId);

    await this.audit.log({
      tenantId,
      actorUserId,
      action: 'role.update',
      newValue: { roleId: id, display_name: dto.display_name },
    });

    return this.getRole(req, id);
  }

  @Delete(':id')
  async deleteRole(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    await this.authorize(req, 'roles.delete');
    const tenantId = this.extractTenantId(req);
    const actorUserId = req.user?.id;

    const role = await this.prisma.role.findFirst({
      where: { id, tenant_id: tenantId },
    });

    if (!role) {
      throw new NotFoundException(`Custom role #${id} not found for tenant`);
    }

    if (role.is_system) {
      throw new ForbiddenException('System default roles cannot be deleted');
    }

    const assignedCount = await this.prisma.userRole.count({
      where: { role_id: id },
    });
    if (assignedCount > 0) {
      throw new BadRequestException(
        `Cannot delete role #${id}: assigned to ${assignedCount} active user(s)`,
      );
    }

    await this.prisma.role.delete({ where: { id } });

    this.cache.invalidateTenant(tenantId);

    await this.audit.log({
      tenantId,
      actorUserId,
      action: 'role.delete',
      newValue: { roleId: id, name: role.name },
    });

    return { success: true, id };
  }
}
