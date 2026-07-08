import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import { PenaltyService } from './penalty.service';

@Controller('penalties')
export class PenaltyController {
  constructor(private readonly penaltyService: PenaltyService) {}

  // ─── Penalty Rules ──────────────────────────────────────────────────────────

  /** GET /penalties/rules?panchayat_id=1 */
  @Get('rules')
  async listRules(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    return this.penaltyService.listRules(panchayatId);
  }

  /** POST /penalties/rules */
  @Post('rules')
  async upsertRule(@Body() body: {
    panchayat_id: number;
    role: string;
    urgency_level: string;
    deadline_hours: number;
    penalty_amount: number;
  }) {
    return this.penaltyService.upsertRule(body);
  }

  // ─── Penalty Records ────────────────────────────────────────────────────────

  /** GET /penalties?panchayat_id=1 */
  @Get()
  async listPenalties(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    return this.penaltyService.listPenaltiesByPanchayat(panchayatId);
  }

  /** GET /penalties/user/:userId */
  @Get('user/:userId')
  async listUserPenalties(@Param('userId', ParseIntPipe) userId: number) {
    return this.penaltyService.listPenaltiesByUser(userId);
  }

  /** GET /penalties/summary?panchayat_id=1 */
  @Get('summary')
  async getSummary(@Query('panchayat_id', ParseIntPipe) panchayatId: number) {
    return this.penaltyService.getPenaltySummary(panchayatId);
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
