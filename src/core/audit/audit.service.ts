import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface AuditEntry {
  tenantId: string;
  orgUnitId?: number;
  userId?: number;
  module: string;
  entityType: string;
  entityId: string;
  action: string;
  beforeValue?: Record<string, unknown>;
  afterValue?: Record<string, unknown>;
  changedFields?: string[];
  deviceInfo?: string;
  ipAddress?: string;
  userAgent?: string;
  sessionId?: string;
}

/**
 * Immutable audit trail service.
 * Captures before/after values on every data mutation.
 * Can be used directly or triggered via the EventBus.
 */
@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private prisma: PrismaService) {}

  /** Log a single audit entry. */
  async log(entry: AuditEntry): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: {
          tenant_id: entry.tenantId,
          org_unit_id: entry.orgUnitId ?? null,
          user_id: entry.userId ?? null,
          module: entry.module,
          entity_type: entry.entityType,
          entity_id: entry.entityId,
          action: entry.action,
          before_value: (entry.beforeValue as any) ?? undefined,
          after_value: (entry.afterValue as any) ?? undefined,
          changed_fields: entry.changedFields ?? [],
          device_info: entry.deviceInfo ?? null,
          ip_address: entry.ipAddress ?? null,
          user_agent: entry.userAgent ?? null,
          session_id: entry.sessionId ?? null,
        },
      });
    } catch (err) {
      // Audit logging should NEVER break the main operation
      this.logger.error(`Failed to write audit log: ${err.message}`, err.stack);
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

  /** Query audit trail for an entity. */
  async getEntityHistory(
    tenantId: string,
    entityType: string,
    entityId: string,
    take = 50,
  ) {
    return this.prisma.auditLog.findMany({
      where: {
        tenant_id: tenantId,
        entity_type: entityType,
        entity_id: entityId,
      },
      orderBy: { created_at: 'desc' },
      take,
    });
  }
}
