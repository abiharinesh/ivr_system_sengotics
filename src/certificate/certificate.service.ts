import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { randomUUID } from 'crypto';

@Injectable()
export class CertificateService {
  private readonly logger = new Logger(CertificateService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── Certificate Application ───────────────────────────────────────────────

  async createRequest(data: {
    org_unit_id: number;
    certificate_type: string;
    applicant_name: string;
    applicant_phone?: string;
    applicant_email?: string;
    application_data?: any;
    fee_amount: number;
  }) {
    return this.prisma.certificateRequest.create({
      data: {
        org_unit_id: data.org_unit_id,
        certificate_type: data.certificate_type,
        applicant_name: data.applicant_name,
        applicant_phone: data.applicant_phone || null,
        applicant_email: data.applicant_email || null,
        application_data: data.application_data || {},
        fee_amount: data.fee_amount,
        payment_status: 'unpaid',
        review_status: 'pending',
      },
    });
  }

  // ─── Payment Record ────────────────────────────────────────────────────────

  async recordPayment(requestId: number, paymentRef: string) {
    const request = await this.prisma.certificateRequest.findUnique({
      where: { id: requestId },
    });
    if (!request) throw new NotFoundException(`Certificate request #${requestId} not found`);

    return this.prisma.certificateRequest.update({
      where: { id: requestId },
      data: {
        payment_status: 'paid',
        payment_ref: paymentRef,
      },
    });
  }

  // ─── Administrative Workflow ──────────────────────────────────────────────

  async getRequestById(id: number) {
    const request = await this.prisma.certificateRequest.findUnique({
      where: { id },
    });
    if (!request) throw new NotFoundException(`Certificate request #${id} not found`);
    return request;
  }

  async listRequestsByPanchayat(orgUnitId: number, type?: string) {
    const where: any = { org_unit_id: orgUnitId };
    if (type) where.certificate_type = type;

    return this.prisma.certificateRequest.findMany({
      where,
      orderBy: { applied_at: 'desc' },
    });
  }

  async approveRequest(id: number, data: { reviewer_notes?: string; certificate_url?: string }) {
    const request = await this.prisma.certificateRequest.findUnique({ where: { id } });
    if (!request) throw new NotFoundException(`Request #${id} not found`);

    const qrToken = randomUUID();

    return this.prisma.certificateRequest.update({
      where: { id },
      data: {
        review_status: 'approved',
        reviewer_notes: data.reviewer_notes || null,
        certificate_url: data.certificate_url || null,
        certificate_qr: qrToken,
        reviewed_at: new Date(),
        issued_at: new Date(),
      },
    });
  }

  async rejectRequest(id: number, notes: string) {
    const request = await this.prisma.certificateRequest.findUnique({ where: { id } });
    if (!request) throw new NotFoundException(`Request #${id} not found`);

    return this.prisma.certificateRequest.update({
      where: { id },
      data: {
        review_status: 'rejected',
        reviewer_notes: notes,
        reviewed_at: new Date(),
      },
    });
  }

  // ─── Verification ─────────────────────────────────────────────────────────

  async verifyCertificate(qrToken: string) {
    const request = await this.prisma.certificateRequest.findUnique({
      where: { certificate_qr: qrToken },
      select: {
        id: true,
        certificate_type: true,
        applicant_name: true,
        fee_amount: true,
        payment_status: true,
        review_status: true,
        issued_at: true,
        org_unit: { select: { name: true } },
      },
    });
    if (!request) throw new NotFoundException('Certificate QR token is invalid or expired');
    return request;
  }
}
