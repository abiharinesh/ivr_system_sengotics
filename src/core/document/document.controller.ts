import { Controller, Get, Param, ParseIntPipe, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { DocumentBrowserService } from './document-browser.service';

interface AuthReq {
  user: { id: number; role: string; tenant_id: string; org_unit_id: number | null };
}

/**
 * The document register.
 *
 * `DocumentService` could upload and sign but had no HTTP surface at all, so
 * the explorer screen listed hardcoded filenames — `Gazette_Notification_2026.pdf`
 * and two others — while 200 real documents in 136 folders sat unread.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(
  'super_admin',
  'panchayat_admin',
  'municipal_commissioner',
  'deputy_commissioner',
  'executive_officer',
  'municipal_engineer',
  'town_planning_officer',
  'registrar',
  'licensing_clerk',
  'accounts_officer',
  'clerk',
)
@Controller('api/documents')
export class DocumentController {
  constructor(private readonly browser: DocumentBrowserService) {}

  /** GET /api/documents/folders — the folder tree for this branch. */
  @Get('folders')
  folders(@Req() req: AuthReq) {
    return this.browser.folderTree(req.user.tenant_id, req.user.org_unit_id);
  }

  /** GET /api/documents?folder_id=&search=&module= */
  @Get()
  list(
    @Req() req: AuthReq,
    @Query('folder_id') folderId?: string,
    @Query('search') search?: string,
    @Query('module') module?: string,
    @Query('take') take?: string,
  ) {
    return this.browser.list({
      tenantId: req.user.tenant_id,
      orgUnitId: req.user.org_unit_id,
      folderId: folderId ? Number(folderId) : undefined,
      search: search?.trim() || undefined,
      module: module?.trim() || undefined,
      take: Math.min(Number(take) || 100, 300),
    });
  }

  /** GET /api/documents/summary — counters above the explorer. */
  @Get('summary')
  summary(@Req() req: AuthReq) {
    return this.browser.summary(req.user.tenant_id, req.user.org_unit_id);
  }

  /** GET /api/documents/:id */
  @Get(':id')
  one(@Req() req: AuthReq, @Param('id', ParseIntPipe) id: number) {
    return this.browser.one(req.user.tenant_id, req.user.org_unit_id, id);
  }
}
