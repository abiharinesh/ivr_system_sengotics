import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { SidebarBuilderService } from './sidebar-builder.service';

@UseGuards(JwtAuthGuard)
@Controller('api/sidebar')
export class SidebarController {
  constructor(private readonly sidebarBuilder: SidebarBuilderService) {}

  @Get()
  async getSidebar(@Req() req: any) {
    const userId = req.user?.id;
    const tenantId = req.user?.tenant_id || req.headers['x-tenant-id'];
    return this.sidebarBuilder.buildSidebar(userId, tenantId);
  }
}
