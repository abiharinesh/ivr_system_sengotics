import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  Post,
  Put,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { validateTemplateId } from '../tender-status';
import { DocumentTemplateSettingsService } from './document-template-settings.service';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    panchayat_id: number | null;
  };
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('panchayat_admin')
@Controller('api/admin/settings/document-templates')
export class PanchayatDocumentTemplateSettingsController {
  constructor(private readonly settings: DocumentTemplateSettingsService) {}

  private getPanchayatId(req: AuthenticatedRequest): number {
    if (!req.user.panchayat_id) {
      throw new ForbiddenException(
        'Account is not associated with a panchayat',
      );
    }
    return req.user.panchayat_id;
  }

  @Get()
  getSettings(@Req() req: AuthenticatedRequest) {
    return this.settings.getPanchayatSettings(this.getPanchayatId(req));
  }

  @Put()
  updateSettings(
    @Req() req: AuthenticatedRequest,
    @Body() body: { templates?: unknown },
  ) {
    return this.settings.updatePanchayatSettings(
      this.getPanchayatId(req),
      body,
    );
  }

  @Delete(':templateId')
  resetTemplate(
    @Req() req: AuthenticatedRequest,
    @Param('templateId') templateId: string,
  ) {
    validateTemplateId(templateId);
    return this.settings.resetPanchayatTemplate(
      this.getPanchayatId(req),
      templateId,
    );
  }

  @Post(':templateId/design')
  saveDesign(
    @Req() req: AuthenticatedRequest,
    @Param('templateId') templateId: string,
    @Body() body: { fabric_scene?: unknown; overlay_svg?: unknown },
  ) {
    validateTemplateId(templateId);
    return this.settings.savePanchayatDesign(
      this.getPanchayatId(req),
      templateId,
      body,
    );
  }

  @Post(':templateId/preview')
  async preview(
    @Req() req: AuthenticatedRequest,
    @Param('templateId') templateId: string,
    @Body() body: { tender_id?: number; vendor_id?: number } = {},
    @Res() res: Response,
  ) {
    validateTemplateId(templateId);
    const html = await this.settings.buildPreviewHtml(
      this.getPanchayatId(req),
      templateId,
      body,
    );
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(html);
  }
}
