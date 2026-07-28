import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RoleDashboardService } from './role-dashboard.service';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    panchayat_id: number | null;
  };
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('api')
export class RoleDashboardController {
  constructor(private readonly service: RoleDashboardService) {}

  /** Executive summary for Commissioner */
  @Get('commissioner/executive-summary')
  @Roles('municipal_commissioner', 'super_admin', 'panchayat_admin')
  getCommissionerSummary(@Req() req: AuthenticatedRequest) {
    return this.service.getCommissionerExecutiveSummary(req.user.panchayat_id ?? undefined);
  }

  /** Capital projects overview for Municipal Engineer */
  @Get('engineering/capital-projects')
  @Roles('municipal_engineer', 'super_admin', 'panchayat_admin')
  getEngineeringProjects(@Req() req: AuthenticatedRequest) {
    return this.service.getEngineeringCapitalProjects(req.user.panchayat_id ?? undefined);
  }

  /** Consolidated revenue overview for Revenue Officer */
  @Get('revenue/summary')
  @Roles('revenue_officer', 'super_admin', 'panchayat_admin')
  getRevenueSummary(@Req() req: AuthenticatedRequest) {
    return this.service.getRevenueSummary(req.user.panchayat_id ?? undefined);
  }

  /** Sub-division field dispatches for Assistant & Junior Engineers */
  @Get('field-ops/dispatches')
  @Roles('assistant_engineer', 'junior_engineer', 'super_admin', 'panchayat_admin')
  getFieldDispatches(@Req() req: AuthenticatedRequest) {
    return this.service.getFieldOpsDispatches(req.user.panchayat_id ?? undefined);
  }

  /** Stall fee collection logging for Revenue Inspectors */
  @Post('market/collect-stall-fee')
  @Roles('revenue_inspector', 'revenue_officer', 'super_admin', 'panchayat_admin')
  recordStallFee(@Body() dto: { stall_id?: number; vendor_name: string; amount: number; payment_mode: string; remarks?: string }) {
    return this.service.recordStallFeeCollection(dto);
  }

  /** Ticket routing for I3C Command Center operators */
  @Post('i3c/tickets/:id/route')
  @Roles('i3c_staff', 'super_admin', 'panchayat_admin')
  routeTicket(@Param('id') ticketId: string, @Body() body: { department: string; assigned_to?: string }) {
    return this.service.routeI3cTicket(ticketId, body.department, body.assigned_to);
  }

  /** Vendor portal self-service bids & work orders for Contractors */
  @Get('contractor/my-bids')
  @Roles('contractor', 'super_admin', 'panchayat_admin')
  getContractorBids(@Req() req: AuthenticatedRequest) {
    return this.service.getContractorBidsAndWorkOrders(req.user.id);
  }
}
