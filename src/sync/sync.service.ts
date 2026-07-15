import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { InspectionService } from '../inspection/inspection.service';

export class SyncOperationDto {
  id: string; // Client-side UUID
  table: 'complaints' | 'inspections' | 'assets';
  action: 'create' | 'update';
  clientTimestamp: string;
  data: any;
}

export class SyncPayloadDto {
  lastSyncTime: string;
  operations: SyncOperationDto[];
}

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(
    private prisma: PrismaService,
    private inspections: InspectionService,
  ) {}

  /**
   * Process a batch of offline client operations (crude transactions & server-wins conflict resolution).
   */
  async processSyncUpload(tenantId: string, branchId: number, userId: number, dto: SyncPayloadDto) {
    const results: any[] = [];
    const clientSyncTime = new Date(dto.lastSyncTime);

    for (const op of dto.operations) {
      try {
        if (op.table === 'complaints') {
          if (op.action === 'create') {
            const complaint = await this.prisma.complaint.create({
              data: {
                panchayat_id: branchId,
                complaint_type: op.data.complaint_type ?? 'offline_reported',
                description: op.data.description ?? null,
                urgency_level: op.data.urgency_level ?? 'medium',
                status: op.data.status ?? 'pending',
                guest_phone: op.data.guest_phone ?? null,
              },
            });
            results.push({ id: op.id, success: true, serverId: complaint.id, action: 'create' });
          } else if (op.action === 'update') {
            const serverRecord = await this.prisma.complaint.findUnique({
              where: { id: op.data.id },
            });

            if (!serverRecord) {
              results.push({ id: op.id, success: false, error: 'Record not found on server' });
              continue;
            }

            // Conflict check: if server was updated after client last synced
            if (serverRecord.created_at > clientSyncTime) {
              results.push({
                id: op.id,
                success: true,
                conflict: 'server-wins',
                serverId: serverRecord.id,
                data: serverRecord,
              });
              continue;
            }

            const updated = await this.prisma.complaint.update({
              where: { id: op.data.id },
              data: {
                status: op.data.status,
                description: op.data.description,
              },
            });
            results.push({ id: op.id, success: true, serverId: updated.id, action: 'update' });
          }
        } else if (op.table === 'inspections') {
          if (op.action === 'create') {
            const inspection = await this.inspections.createInspection(tenantId, {
              templateId: op.data.template_id,
              branchId: branchId,
              inspectorUserId: userId,
              assetId: op.data.asset_id,
              locationLat: op.data.location_lat,
              locationLng: op.data.location_lng,
              checklistResults: op.data.checklist_results,
              overallScore: op.data.overall_score,
              photos: op.data.photos,
              remarks: op.data.remarks,
            });
            results.push({ id: op.id, success: true, serverId: inspection.id, action: 'create' });
          }
        } else {
          results.push({ id: op.id, success: false, error: `Unsupported table: ${op.table}` });
        }
      } catch (err: any) {
        this.logger.error(`Error syncing operation ${op.id}: ${err.message}`);
        results.push({ id: op.id, success: false, error: err.message });
      }
    }

    return {
      syncTimestamp: new Date(),
      results,
    };
  }

  /**
   * Fetch updates (delta changes) across key tables since lastSyncTime.
   */
  async getSyncDelta(tenantId: string, branchId: number, lastSyncTime: string) {
    const syncDate = new Date(lastSyncTime);

    // Fetch newly created or updated assets & complaints since last sync time
    const complaints = await this.prisma.complaint.findMany({
      where: {
        panchayat_id: branchId,
        created_at: { gte: syncDate },
      },
    });

    const assets = await this.prisma.asset.findMany({
      where: {
        tenant_id: tenantId,
        branch_id: branchId,
        created_at: { gte: syncDate },
      },
    });

    return {
      serverTime: new Date(),
      delta: {
        complaints,
        assets,
      },
    };
  }
}
