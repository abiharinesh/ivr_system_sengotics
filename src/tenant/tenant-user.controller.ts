import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  Req,
  ParseIntPipe,
  UseGuards,
  ForbiddenException,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TenantUserService } from './tenant-user.service';
import type { CreateStaffDto, UpdateStaffDto } from './tenant-user.service';
import { FeatureGateService } from '../core/rbac/feature-gate.service';

@UseGuards(JwtAuthGuard)
@Controller('api/tenant/users')
export class TenantUserController {
  constructor(
    private readonly tenantUserService: TenantUserService,
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
    const tenantId = this.extractTenantId(req);
    await this.gate.checkOrThrow({
      userId: req.user.id,
      tenantId,
      orgUnitId: req.user.org_unit_id,
      moduleKey: 'core',
      permissionCode,
    });
  }

  @Post()
  createStaff(@Req() req: any, @Body() dto: CreateStaffDto) {
    const tenantId = this.extractTenantId(req);
    return this.authorize(req, 'users.write').then(() =>
      this.tenantUserService.createStaff(tenantId, req.user?.id, dto),
    );
  }

  @Get()
  listStaff(
    @Req() req: any,
    @Query('org_unit_id') orgUnitId?: string,
    @Query('department_id') departmentId?: string,
    @Query('search') search?: string,
  ) {
    const tenantId = this.extractTenantId(req);
    return this.authorize(req, 'users.read').then(() =>
      this.tenantUserService.listStaff(tenantId, {
        org_unit_id: orgUnitId ? parseInt(orgUnitId, 10) : undefined,
        department_id: departmentId ? parseInt(departmentId, 10) : undefined,
        search,
      }),
    );
  }

  @Get(':id')
  getStaff(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    const tenantId = this.extractTenantId(req);
    return this.authorize(req, 'users.read').then(() =>
      this.tenantUserService.getStaff(tenantId, id),
    );
  }

  @Patch(':id')
  updateStaff(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateStaffDto,
  ) {
    const tenantId = this.extractTenantId(req);
    return this.authorize(req, 'users.write').then(() =>
      this.tenantUserService.updateStaff(tenantId, id, req.user?.id, dto),
    );
  }

  @Patch(':id/deactivate')
  deactivateStaff(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    const tenantId = this.extractTenantId(req);
    return this.authorize(req, 'users.write').then(() =>
      this.tenantUserService.deactivateStaff(tenantId, id, req.user?.id),
    );
  }

  @Delete(':id')
  deleteStaff(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    const tenantId = this.extractTenantId(req);
    return this.authorize(req, 'users.delete').then(() =>
      this.tenantUserService.softDeleteStaff(tenantId, id, req.user?.id),
    );
  }
}
