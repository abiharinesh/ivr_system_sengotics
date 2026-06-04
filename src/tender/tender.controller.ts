import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { TenderService } from './tender.service';
import type { TenderCreateBody, TenderLineItemBody } from './tender.service';
import { VendorService } from './vendor.service';
import { MilestoneService } from './milestone.service';
import { TenderAuditService } from './audit.service';

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
@Controller('api/admin')
export class TenderController {
  constructor(
    private readonly tenders: TenderService,
    private readonly vendors: VendorService,
    private readonly milestones: MilestoneService,
    private readonly audit: TenderAuditService,
  ) {}

  private getPanchayatId(req: AuthenticatedRequest): number {
    if (!req.user.panchayat_id)
      throw new ForbiddenException(
        'Account is not associated with a panchayat',
      );
    return req.user.panchayat_id;
  }

  // ── Vendors ──────────────────────────────────────────────────────────
  @Get('vendors')
  listVendors(
    @Req() req: AuthenticatedRequest,
    @Query('active') active?: string,
  ) {
    return this.vendors.list(this.getPanchayatId(req), {
      active: active == null ? undefined : active === 'true',
    });
  }

  @Post('vendors')
  createVendor(@Req() req: AuthenticatedRequest, @Body() body: any) {
    return this.vendors.create(this.getPanchayatId(req), body);
  }

  @Get('vendors/:id')
  getVendor(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.vendors.get(this.getPanchayatId(req), id);
  }

  @Patch('vendors/:id')
  updateVendor(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    return this.vendors.update(this.getPanchayatId(req), id, body);
  }

  @Delete('vendors/:id')
  deactivateVendor(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.vendors.deactivate(this.getPanchayatId(req), id);
  }

  // ── Tenders ──────────────────────────────────────────────────────────
  @Get('tenders')
  listTenders(
    @Req() req: AuthenticatedRequest,
    @Query('status') status?: string,
  ) {
    return this.tenders.list(this.getPanchayatId(req), { status });
  }

  @Post('tenders')
  createTender(
    @Req() req: AuthenticatedRequest,
    @Body() body: TenderCreateBody,
  ) {
    return this.tenders.create(this.getPanchayatId(req), req.user.id, body);
  }

  @Get('tenders/:id')
  getTender(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.tenders.getDetail(this.getPanchayatId(req), id);
  }

  @Patch('tenders/:id/quotation-access-mode')
  setQuotationAccessMode(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { quotation_access_mode?: string },
  ) {
    if (!body?.quotation_access_mode)
      throw new BadRequestException('quotation_access_mode required');
    return this.tenders.setQuotationAccessMode(
      this.getPanchayatId(req),
      id,
      req.user.id,
      body.quotation_access_mode,
    );
  }

  @Patch('tenders/:id')
  patchTender(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: any,
  ) {
    return this.tenders.patch(this.getPanchayatId(req), id, req.user.id, body);
  }

  @Get('tenders/:id/timeline')
  timeline(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    const _pid = this.getPanchayatId(req);
    return this.tenders
      .getDetail(_pid, id)
      .then(() => this.milestones.resolveForTender(id));
  }

  @Get('tenders/:id/audit')
  listAudit(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    const pid = this.getPanchayatId(req);
    return this.tenders.getDetail(pid, id).then(() => this.audit.list(id));
  }

  // ── Line items ───────────────────────────────────────────────────────
  @Post('tenders/:id/line-items')
  addLine(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: TenderLineItemBody,
  ) {
    return this.tenders.addLineItem(
      this.getPanchayatId(req),
      id,
      req.user.id,
      body,
    );
  }

  @Patch('tenders/:id/line-items/:itemId')
  updateLine(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Param('itemId', ParseIntPipe) itemId: number,
    @Body() body: TenderLineItemBody,
  ) {
    return this.tenders.updateLineItem(
      this.getPanchayatId(req),
      id,
      itemId,
      req.user.id,
      body,
    );
  }

  @Delete('tenders/:id/line-items/:itemId')
  deleteLine(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Param('itemId', ParseIntPipe) itemId: number,
  ) {
    return this.tenders.deleteLineItem(
      this.getPanchayatId(req),
      id,
      itemId,
      req.user.id,
    );
  }

  // ── Invites ──────────────────────────────────────────────────────────
  @Post('tenders/:id/invites')
  setInvites(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { vendor_ids: number[] },
  ) {
    if (!Array.isArray(body?.vendor_ids))
      throw new BadRequestException('vendor_ids array required');
    return this.tenders.setInvites(
      this.getPanchayatId(req),
      id,
      req.user.id,
      body.vendor_ids,
    );
  }

  // ── Lifecycle transitions ────────────────────────────────────────────
  @Post('tenders/:id/publish')
  publish(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.tenders.publish(this.getPanchayatId(req), id, req.user.id);
  }

  @Post('tenders/:id/close-quotations')
  closeQuotations(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.tenders.closeQuotations(
      this.getPanchayatId(req),
      id,
      req.user.id,
    );
  }

  @Post('tenders/:id/award')
  award(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { quotation_id: number },
  ) {
    if (!body?.quotation_id)
      throw new BadRequestException('quotation_id required');
    return this.tenders.award(
      this.getPanchayatId(req),
      id,
      req.user.id,
      body.quotation_id,
    );
  }

  @Post('tenders/:id/work-completion')
  workCompletion(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { work_completed_at?: string; inspection_notes?: string },
  ) {
    return this.tenders.recordWorkCompletion(
      this.getPanchayatId(req),
      id,
      req.user.id,
      body ?? {},
    );
  }

  @Post('tenders/:id/payment')
  payment(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { payment_meta: Record<string, unknown>; close?: boolean },
  ) {
    return this.tenders.recordPayment(
      this.getPanchayatId(req),
      id,
      req.user.id,
      body,
    );
  }

  // ── Quotations (officer offline entry) ───────────────────────────────
  @Post('tenders/:id/quotations')
  addOfficerQuotation(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
    @Body()
    body: {
      vendor_id?: number;
      submitter_name?: string;
      phone?: string;
      amount: number | string;
      remarks?: string;
      screening_outcome?: string;
    },
  ) {
    return this.tenders.addOfficerQuotation(
      this.getPanchayatId(req),
      id,
      req.user.id,
      body,
    );
  }
}
