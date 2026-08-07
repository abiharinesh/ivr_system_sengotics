import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface AuditEntry {
  tenantId?: string;
  orgUnitId?: number;
  actorUserId?: number;
  /** Backward-compatible alias used by existing module services. */
  userId?: number;
  module?: string;
  entityType?: string;
  entityId?: string;
  action: string;
  oldValue?: Record<string, unknown> | null;
  newValue?: Record<string, unknown> | null;
  /** Backward-compatible names used by the workflow modules. */
  beforeValue?: Record<string, unknown> | null;
  afterValue?: Record<string, unknown> | null;
  changedFields?: string[];
  ipAddress?: string;
  deviceInfo?: string;
}

/**
 * Immutable audit trail service.
 * Captures old/new values on administrative and operational actions.
 */
@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private prisma: PrismaService) {}

  /** Log a single audit entry. */
  async log(entry: AuditEntry): Promise<void> {
    try {
      const beforeValue = entry.beforeValue ?? entry.oldValue;
      const afterValue = entry.afterValue ?? entry.newValue;
      await this.prisma.auditLog.create({
        data: {
          // AuditLog is tenant-owned in the schema. Platform actions are
          // recorded under the operating tenant rather than becoming orphaned.
          tenant_id: entry.tenantId ?? 'default',
          org_unit_id: entry.orgUnitId ?? null,
          user_id: entry.userId ?? entry.actorUserId ?? null,
          module: entry.module ?? 'core',
          entity_type:
            entry.entityType ?? entry.action.split('.')[0] ?? 'system',
          entity_id: entry.entityId ?? '',
          action: entry.action,
          before_value: (beforeValue as any) ?? undefined,
          after_value: (afterValue as any) ?? undefined,
          changed_fields:
            entry.changedFields ??
            (beforeValue && afterValue
              ? AuditService.diffFields(beforeValue, afterValue)
              : []),
          ip_address: entry.ipAddress ?? null,
          device_info: entry.deviceInfo ?? null,
        },
      });
    } catch (err) {
      // Audit logging should NEVER break the main operation
      const error = err as Error;
      this.logger.error(
        `Failed to write audit log: ${error.message}`,
        error.stack,
      );
    }
  }

  /** Compute changed fields between before and after objects. */
  static diffFields(
    before: Record<string, unknown>,
    after: Record<string, unknown>,
  ): string[] {
    const changed: string[] = [];
    const allKeys = new Set([...Object.keys(before), ...Object.keys(after)]);
    for (const key of allKeys) {
      if (JSON.stringify(before[key]) !== JSON.stringify(after[key])) {
        changed.push(key);
      }
    }
    return changed;
  }

  /** Query audit trail for a tenant or action. */
  async getAuditLogs(tenantId?: string, take = 100) {
    return this.prisma.auditLog.findMany({
      where: tenantId ? { tenant_id: tenantId } : {},
      include: {
        user: { select: { id: true, email: true, role: true } },
        org_unit: { select: { id: true, name: true } },
      },
      orderBy: { created_at: 'desc' },
      take,
    });
  }

  /** Return an entity's immutable audit history, newest first. */
  async getEntityHistory(
    tenantId: string,
    entityType: string,
    entityId: string,
    take = 100,
  ) {
    return this.prisma.auditLog.findMany({
      where: {
        tenant_id: tenantId,
        entity_type: entityType,
        entity_id: entityId,
      },
      include: {
        user: { select: { id: true, email: true, role: true } },
        org_unit: { select: { id: true, name: true } },
      },
      orderBy: { created_at: 'desc' },
      take,
    });
  }
}
