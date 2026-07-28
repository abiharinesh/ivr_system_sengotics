import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Req,
  Query,
  UseGuards,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import {
  CitizenPortalService,
  CreateCitizenProfileDto,
  CreateAnnouncementDto,
  CreateFeedbackDto,
} from './citizen-portal.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    panchayat_id: number | null;
    tenant_id: string;
    user_type: string;
    employee_id: number | null;
    access_scope: string;
  };
}

@UseGuards(JwtAuthGuard)
@Controller('api/citizen')
export class CitizenPortalController {
  constructor(private readonly service: CitizenPortalService) {}

  // ── Profile Endpoints ───────────────────────────────────────────────────

  @Post('profile')
  createProfile(@Req() req: AuthenticatedRequest, @Body() dto: CreateCitizenProfileDto) {
    return this.service.createProfile(req.user.tenant_id, req.user.id, dto);
  }

  @Get('profile')
  getProfile(@Req() req: AuthenticatedRequest) {
    return this.service.getProfile(req.user.tenant_id, req.user.id);
  }

  @Put('profile')
  updateProfile(@Req() req: AuthenticatedRequest, @Body() dto: Partial<CreateCitizenProfileDto>) {
    return this.service.updateProfile(req.user.tenant_id, req.user.id, dto);
  }

  // ── Announcement Endpoints ──────────────────────────────────────────────

  @UseGuards(RolesGuard)
  @Roles('super_admin', 'panchayat_admin', 'i3c_staff')
  @Post('announcements')
  createAnnouncement(@Req() req: AuthenticatedRequest, @Body() dto: CreateAnnouncementDto) {
    const branchId = dto.branchId ?? req.user.panchayat_id;
    if (!branchId) {
      throw new BadRequestException('Branch ID is required');
    }
    return this.service.createAnnouncement(
      req.user.tenant_id,
      { ...dto, branchId },
      req.user.id,
    );
  }

  @Get('announcements')
  listAnnouncements(@Req() req: AuthenticatedRequest, @Query('branchId') branchId?: string) {
    const bId = branchId ? parseInt(branchId, 10) : req.user.panchayat_id;
    if (!bId) {
      throw new BadRequestException('Branch ID is required');
    }
    return this.service.getAnnouncements(req.user.tenant_id, bId);
  }

  // ── Feedback Endpoints ──────────────────────────────────────────────────

  @Post('feedback')
  createFeedback(@Req() req: AuthenticatedRequest, @Body() dto: CreateFeedbackDto) {
    const branchId = dto.branchId ?? req.user.panchayat_id;
    if (!branchId) {
      throw new BadRequestException('Branch ID is required');
    }
    return this.service.createFeedback(req.user.tenant_id, req.user.id, {
      ...dto,
      branchId,
    });
  }

  @UseGuards(RolesGuard)
  @Roles('super_admin', 'panchayat_admin', 'i3c_staff')
  @Get('feedback')
  listFeedback(@Req() req: AuthenticatedRequest, @Query('branchId') branchId?: string) {
    const bId = branchId ? parseInt(branchId, 10) : req.user.panchayat_id;
    if (!bId) {
      throw new BadRequestException('Branch ID is required');
    }
    return this.service.getFeedbackList(req.user.tenant_id, bId);
  }
}
