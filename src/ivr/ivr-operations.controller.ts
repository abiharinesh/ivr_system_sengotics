import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { IvrOperationsService } from './ivr-operations.service';

interface AuthReq {
  user: { id: number; role: string; tenant_id: string; org_unit_id: number | null };
}

/**
 * The read side of Voice & IVR, for the office rather than for Exotel.
 *
 * The rest of `IvrController` is webhook surface — the endpoints the telephony
 * provider posts to mid-call. Nothing served the operations screen, so it
 * rendered rows generated from a loop counter (`IVR-${4200 + index}`) while
 * 220 real calls sat in the database unread.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(
  'super_admin',
  'panchayat_admin',
  'municipal_commissioner',
  'deputy_commissioner',
  'executive_officer',
  'i3c_staff',
)
@Controller('api/ivr-operations')
export class IvrOperationsController {
  constructor(private readonly service: IvrOperationsService) {}

  /** GET /api/ivr-operations/voice-calls — recorded calls and their transcripts. */
  @Get('voice-calls')
  voiceCalls(
    @Req() req: AuthReq,
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('take') take?: string,
  ) {
    return this.service.listVoiceCalls({
      tenantId: req.user.tenant_id,
      search: search?.trim() || undefined,
      status: status?.trim() || undefined,
      take: Math.min(Number(take) || 50, 200),
    });
  }

  /** GET /api/ivr-operations/calls — the IVR interaction log. */
  @Get('calls')
  calls(
    @Req() req: AuthReq,
    @Query('search') search?: string,
    @Query('take') take?: string,
  ) {
    return this.service.listIvrCalls({
      tenantId: req.user.tenant_id,
      search: search?.trim() || undefined,
      take: Math.min(Number(take) || 50, 200),
    });
  }

  /** GET /api/ivr-operations/summary — the counters above both lists. */
  @Get('summary')
  summary(@Req() req: AuthReq) {
    return this.service.summary(req.user.tenant_id);
  }
}
