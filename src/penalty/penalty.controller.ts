import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Query,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { PenaltyService } from './penalty.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin', 'revenue_officer')
@Controller('penalties')
export class PenaltyController {
  constructor(private readonly penaltyService: PenaltyService) {}

  // ─── Penalty Rules ──────────────────────────────────────────────────────────

  /** GET /penalties/rules?org_unit_id=1 */
  @Get('rules')
  async listRules(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.penaltyService.listRules(orgUnitId);
  }

  /** POST /penalties/rules */
  @Post('rules')
  async upsertRule(@Body() body: {
    org_unit_id: number;
    role: string;
    urgency_level: string;
    deadline_hours: number;
    penalty_amount: number;
  }) {
    return this.penaltyService.upsertRule(body);
  }

  // ─── Penalty Records ────────────────────────────────────────────────────────

  /** GET /penalties?org_unit_id=1 */
  @Get()
  async listPenalties(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.penaltyService.listPenaltiesByPanchayat(orgUnitId);
  }

  /** GET /penalties/user/:userId */
  @Get('user/:userId')
  async listUserPenalties(@Param('userId', ParseIntPipe) userId: number) {
    return this.penaltyService.listPenaltiesByUser(userId);
  }

  /** GET /penalties/summary?org_unit_id=1 */
  @Get('summary')
  async getSummary(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.penaltyService.getPenaltySummary(orgUnitId);
  }

  /** PUT /penalties/:id/waive */
  @Put(':id/waive')
  async waivePenalty(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { reason: string },
  ) {
    return this.penaltyService.waivePenalty(id, body.reason);
  }

  /** PUT /penalties/:id/deduct */
  @Put(':id/deduct')
  async markDeducted(@Param('id', ParseIntPipe) id: number) {
    return this.penaltyService.markDeducted(id);
  }
}
