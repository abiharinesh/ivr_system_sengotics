import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  Req,
  ForbiddenException,
} from '@nestjs/common';
import { CitizenService } from './citizen.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    org_unit_id: number | null;
  };
}

@Controller('api/citizen')
export class CitizenController {
  constructor(private readonly service: CitizenService) {}

  // ── Public endpoints ───────────────────────────────────────────────────

  @Get('panchayats')
  listPanchayats() {
    return this.service.listPanchayats();
  }

  @Post('register')
  registerCitizen(
    @Body()
    body: {
      email: string;
      password_hash: string;
      org_unit_id: number;
      phone_e164?: string;
    },
  ) {
    return this.service.registerCitizen(body);
  }

  // ── Guarded endpoints ──────────────────────────────────────────────────

  @Get('poles')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('citizen', 'panchayat_admin', 'super_admin')
  listPoles(@Req() req: AuthenticatedRequest) {
    const orgUnitId = req.user.org_unit_id;
    if (!orgUnitId) {
      throw new ForbiddenException('User is not associated with any panchayat');
    }
    return this.service.listPoles(orgUnitId);
  }

  @Get('complaints')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('citizen')
  listComplaints(@Req() req: AuthenticatedRequest) {
    const orgUnitId = req.user.org_unit_id;
    if (!orgUnitId) {
      throw new ForbiddenException('User is not associated with any panchayat');
    }
    return this.service.listComplaints(orgUnitId);
  }

  @Post('complaints')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('citizen')
  createComplaint(
    @Req() req: AuthenticatedRequest,
    @Body()
    body: {
      pole_id: number;
      complaint_type?: string;
      description?: string;
      urgency_level?: string;
    },
  ) {
    const orgUnitId = req.user.org_unit_id;
    if (!orgUnitId) {
      throw new ForbiddenException('User is not associated with any panchayat');
    }
    return this.service.createComplaint(orgUnitId, body);
  }
}
