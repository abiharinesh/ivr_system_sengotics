import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { AuditService } from '../core/audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { DashboardService } from './dashboard.service';

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
 * The dashboard every signed-in user lands on, and the super admin endpoints
 * that decide what it contains.
 *
 * Deliberately open to every role: a dashboard is the landing page, and a role
 * with no dashboard has nowhere to land. What each role *sees* is decided by
 * its `role_dashboards` row, not by this guard.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('api/dashboard')
export class DashboardController {
  constructor(
    private readonly service: DashboardService,
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  /** GET /api/dashboard — the caller's own dashboard, computed. */
  @Get()
  mine(@Req() req: AuthReq) {
    return this.service.forUser({
      tenantId: req.user.tenant_id,
      role: req.user.role,
      orgUnitId: req.user.org_unit_id,
      isSuperAdmin: req.user.is_super_admin ?? false,
    });
  }

  /**
   * GET /api/dashboard/widgets — the widget palette a layout is composed from.
   */
  @Get('widgets')
  @Roles('super_admin', 'panchayat_admin')
  async widgets(@Req() req: AuthReq) {
    const widgets = await this.prisma.dashboardWidget.findMany({
      where: { tenant_id: req.user.tenant_id, is_active: true },
      orderBy: [{ data_source: 'asc' }, { title: 'asc' }],
    });

    const bySource = new Map<string, typeof widgets>();
    for (const w of widgets) {
      if (!bySource.has(w.data_source)) bySource.set(w.data_source, []);
      bySource.get(w.data_source)!.push(w);
    }

    return {
      total: widgets.length,
      groups: [...bySource.entries()].map(([data_source, items]) => ({
        data_source,
        items,
      })),
    };
  }

  /** GET /api/dashboard/layouts — every role's configured layout. */
  @Get('layouts')
  @Roles('super_admin', 'panchayat_admin')
  async layouts(@Req() req: AuthReq) {
    const [rows, roles, widgets] = await Promise.all([
      this.prisma.roleDashboard.findMany({
        where: { tenant_id: req.user.tenant_id },
      }),
      this.prisma.role.findMany({
        where: { tenant_id: { in: [req.user.tenant_id, '__system__'] }, is_active: true },
        select: { name: true, display_name: true, hierarchy_level: true },
        orderBy: [{ hierarchy_level: 'asc' }, { display_name: 'asc' }],
      }),
      this.prisma.dashboardWidget.findMany({
        where: { tenant_id: req.user.tenant_id },
        select: { id: true, code: true, title: true },
      }),
    ]);

    const byRole = new Map(rows.map((r) => [r.role_name, r]));
    const byId = new Map(widgets.map((w) => [w.id, w]));

    // Every role is listed, configured or not — an unconfigured role falling
    // back to a generic dashboard is exactly what the operator needs to see.
    return roles.map((role) => {
      const layout = byRole.get(role.name);
      return {
        role_name: role.name,
        display_name: role.display_name,
        hierarchy_level: role.hierarchy_level,
        configured: layout != null,
        widget_ids: layout?.widget_ids ?? [],
        widgets: (layout?.widget_ids ?? [])
          .map((id) => byId.get(id))
          .filter((w): w is NonNullable<typeof w> => w != null),
      };
    });
  }

  /** GET /api/dashboard/preview/:role — see a role's dashboard as they do. */
  @Get('preview/:role')
  @Roles('super_admin', 'panchayat_admin')
  preview(@Req() req: AuthReq, @Param('role') role: string) {
    return this.service.forUser({
      tenantId: req.user.tenant_id,
      role,
      orgUnitId: req.user.org_unit_id,
      // Preview from the operator's own branch, not with platform scope, so
      // the figures match what that role would actually see.
      isSuperAdmin: false,
    });
  }

  /**
   * PUT /api/dashboard/layouts/:role — set which widgets a role lands on.
   *
   * The array order is the layout: it is what the operator arranged, and the
   * service reads the panels back in exactly this sequence.
   */
  @Put('layouts/:role')
  @Roles('super_admin', 'panchayat_admin')
  async setLayout(
    @Req() req: AuthReq,
    @Param('role') role: string,
    @Body('widget_ids') widgetIds: number[],
  ) {
    if (!Array.isArray(widgetIds) || widgetIds.some((n) => !Number.isInteger(n))) {
      throw new BadRequestException('widget_ids must be an array of integers');
    }

    const known = await this.prisma.dashboardWidget.findMany({
      where: { id: { in: widgetIds }, tenant_id: req.user.tenant_id },
      select: { id: true, code: true },
    });
    const unknown = widgetIds.filter((id) => !known.some((w) => w.id === id));
    if (unknown.length) {
      throw new BadRequestException(`Unknown widget id(s): ${unknown.join(', ')}`);
    }

    const before = await this.prisma.roleDashboard.findFirst({
      where: { tenant_id: req.user.tenant_id, role_name: role },
    });

    const saved = await this.prisma.roleDashboard.upsert({
      where: {
        tenant_id_role_name: { tenant_id: req.user.tenant_id, role_name: role },
      },
      update: { widget_ids: widgetIds, layout: { columns: 4 } },
      create: {
        tenant_id: req.user.tenant_id,
        role_name: role,
        widget_ids: widgetIds,
        layout: { columns: 4 },
      },
    });

    await this.audit.log({
      tenantId: req.user.tenant_id,
      userId: req.user.id,
      module: 'rbac',
      entityType: 'role_dashboard',
      entityId: saved.id.toString(),
      action: 'dashboard_layout_updated',
      beforeValue: { role, widget_ids: before?.widget_ids ?? [] },
      afterValue: { role, widget_ids: widgetIds },
      changedFields: ['widget_ids'],
    });

    return saved;
  }
}
