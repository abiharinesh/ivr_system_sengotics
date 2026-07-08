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
import { CertificateService } from './certificate.service';

@Controller('certificates')
export class CertificateController {
  constructor(private readonly certificateService: CertificateService) {}

  // ─── Citizen Applications ──────────────────────────────────────────────────

  /** POST /certificates/apply */
  @Post('apply')
  async apply(@Body() body: {
    panchayat_id: number;
    certificate_type: string;
    applicant_name: string;
    applicant_phone?: string;
    applicant_email?: string;
    application_data?: any;
    fee_amount: number;
  }) {
    return this.certificateService.createRequest(body);
  }

  /** POST /certificates/:id/pay */
  @Post(':id/pay')
  async recordPayment(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { payment_ref: string },
  ) {
    return this.certificateService.recordPayment(id, body.payment_ref);
  }

  // ─── Verification ─────────────────────────────────────────────────────────

  /** GET /certificates/verify/:qrToken */
  @Get('verify/:qrToken')
  async verify(@Param('qrToken') qrToken: string) {
    return this.certificateService.verifyCertificate(qrToken);
  }

  // ─── Administrative Workflow ──────────────────────────────────────────────

  /** GET /certificates?panchayat_id=1&type=birth */
  @Get()
  async listRequests(
    @Query('panchayat_id', ParseIntPipe) panchayatId: number,
    @Query('type') type?: string,
  ) {
    return this.certificateService.listRequestsByPanchayat(panchayatId, type);
  }

  /** GET /certificates/:id */
  @Get(':id')
  async getRequest(@Param('id', ParseIntPipe) id: number) {
    return this.certificateService.getRequestById(id);
  }

  /** PUT /certificates/:id/approve */
  @Put(':id/approve')
  async approve(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { reviewer_notes?: string; certificate_url?: string },
  ) {
    return this.certificateService.approveRequest(id, body);
  }

  /** PUT /certificates/:id/reject */
  @Put(':id/reject')
  async reject(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { reviewer_notes: string },
  ) {
    return this.certificateService.rejectRequest(id, body.reviewer_notes);
  }
}
