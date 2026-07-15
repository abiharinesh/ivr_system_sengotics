import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SearchService {
  constructor(private prisma: PrismaService) {}

  /**
   * Search across Complaints, Assets, Tenders, WorkOrders, and Contractors.
   */
  async universalSearch(tenantId: string, query: string, branchId?: number) {
    if (!query || query.trim() === '') {
      return {
        complaints: [],
        assets: [],
        tenders: [],
        workOrders: [],
        contractors: [],
      };
    }

    const isNum = !isNaN(Number(query));

    // Parallel execution for optimal performance
    const [complaints, assets, tenders, workOrders, contractors] = await Promise.all([
      this.prisma.complaint.findMany({
        where: {
          ...(branchId && { panchayat_id: branchId }),
          OR: [
            { category: { contains: query, mode: 'insensitive' } },
            { description: { contains: query, mode: 'insensitive' } },
            { complaint_type: { contains: query, mode: 'insensitive' } },
            ...(isNum ? [{ id: Number(query) }] : []),
          ],
        },
        take: 10,
      }),
      this.prisma.asset.findMany({
        where: {
          tenant_id: tenantId,
          ...(branchId && { branch_id: branchId }),
          OR: [
            { asset_code: { contains: query, mode: 'insensitive' } },
            { name: { contains: query, mode: 'insensitive' } },
            { notes: { contains: query, mode: 'insensitive' } },
          ],
        },
        take: 10,
      }),
      this.prisma.tender.findMany({
        where: {
          ...(branchId && { panchayat_id: branchId }),
          OR: [
            { title_en: { contains: query, mode: 'insensitive' } },
            { title_ta: { contains: query, mode: 'insensitive' } },
            { narrative_en: { contains: query, mode: 'insensitive' } },
            { narrative_ta: { contains: query, mode: 'insensitive' } },
          ],
        },
        take: 10,
      }),
      this.prisma.workOrder.findMany({
        where: {
          tenant_id: tenantId,
          ...(branchId && { branch_id: branchId }),
          OR: [
            { work_order_number: { contains: query, mode: 'insensitive' } },
            { title: { contains: query, mode: 'insensitive' } },
            { description: { contains: query, mode: 'insensitive' } },
          ],
        },
        take: 10,
      }),
      this.prisma.contractor.findMany({
        where: {
          tenant_id: tenantId,
          is_deleted: false,
          OR: [
            { name: { contains: query, mode: 'insensitive' } },
            { phone: { contains: query, mode: 'insensitive' } },
            { gst_number: { contains: query, mode: 'insensitive' } },
            { pan_number: { contains: query, mode: 'insensitive' } },
          ],
        },
        take: 10,
      }),
    ]);

    return {
      complaints,
      assets,
      tenders,
      workOrders,
      contractors,
    };
  }
}
