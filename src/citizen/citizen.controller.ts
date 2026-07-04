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
    panchayat_id: number | null;
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
      panchayat_id: number;
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
    const panchayatId = req.user.panchayat_id;
    if (!panchayatId) {
      throw new ForbiddenException('User is not associated with any panchayat');
    }
    return this.service.listPoles(panchayatId);
  }

  @Get('complaints')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('citizen')
  listComplaints(@Req() req: AuthenticatedRequest) {
    const panchayatId = req.user.panchayat_id;
    if (!panchayatId) {
      throw new ForbiddenException('User is not associated with any panchayat');
    }
    return this.service.listComplaints(panchayatId);
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
    const panchayatId = req.user.panchayat_id;
    if (!panchayatId) {
      throw new ForbiddenException('User is not associated with any panchayat');
    }
    return this.service.createComplaint(panchayatId, body);
  }
}
