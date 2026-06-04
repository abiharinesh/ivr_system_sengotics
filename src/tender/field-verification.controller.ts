import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { FieldVerificationService } from './field-verification.service';

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
@Controller('api/admin/tenders')
export class FieldVerificationController {
  constructor(private readonly service: FieldVerificationService) {}

  private getPanchayatId(req: AuthenticatedRequest): number {
    if (!req.user.panchayat_id)
      throw new ForbiddenException(
        'Account is not associated with a panchayat',
      );
    return req.user.panchayat_id;
  }

  @Post(':id/verification-sessions')
  createSession(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      label?: string | null;
      pole_subset_ids?: number[];
      expires_in_days?: number;
    },
  ) {
    return this.service.createSession(
      this.getPanchayatId(req),
      id,
      req.user.id,
      body ?? {},
    );
  }

  @Get(':id/verification-sessions')
  listSessions(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.service.listSessions(this.getPanchayatId(req), id);
  }

  @Get(':id/checklist')
  getChecklist(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.service.getChecklist(this.getPanchayatId(req), id);
  }

  @Patch(':id/checklist/:itemId')
  patchChecklist(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Param('itemId', ParseIntPipe) itemId: number,
    @Body()
    body: {
      is_done?: boolean;
      verified_upload_id?: number | null;
      notes?: string | null;
    },
  ) {
    return this.service.patchChecklistItem(
      this.getPanchayatId(req),
      id,
      itemId,
      req.user.id,
      body ?? {},
    );
  }

  @Post(':id/verification-uploads/:uploadId/assign')
  assignUpload(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Param('uploadId', ParseIntPipe) uploadId: number,
    @Body() body: { pole_id: number; approve?: boolean },
  ) {
    return this.service.assignUpload(
      this.getPanchayatId(req),
      id,
      uploadId,
      req.user.id,
      body ?? { pole_id: 0 },
    );
  }

  @Post(':id/confirm-verification')
  confirm(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.service.confirmVerification(
      this.getPanchayatId(req),
      id,
      req.user.id,
    );
  }
}
