import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/** Entity key used on the shared audit trail for tender events. */
const ENTITY_TYPE = 'tender';

/**
 * Tender audit trail.
 *
 * Backed by the platform-wide `audit_logs` table rather than a tender-specific
 * one. The old `tender_audit_logs` held exactly the same shape — an actor, an
 * event name, a JSON payload and a timestamp against one entity — so the
 * product carried two audit trails and a dispute meant looking in two places.
 * `AuditLog` expresses this natively via `entity_type`/`entity_id`, and unlike
 * the old table it is tenant-scoped.
 *
 * The public method signatures and the row shape returned by [list] are
 * unchanged, so no caller had to move.
 */
@Injectable()
export class TenderAuditService {
  constructor(private readonly prisma: PrismaService) {}

  /** Resolve the tenant and branch a tender belongs to. */
  private async scopeFor(tenderId: number): Promise<{
    tenantId: string;
    orgUnitId: number | null;
  }> {
    const tender = await this.prisma.tender.findUnique({
      where: { id: tenderId },
      select: { org_unit_id: true, org_unit: { select: { tenant_id: true } } },
    });
    return {
      tenantId: tender?.org_unit?.tenant_id ?? 'default',
      orgUnitId: tender?.org_unit_id ?? null,
    };
  }

  /** Append a single audit entry; non-throwing (best-effort). */
  async record(args: {
    tenderId: number;
    actorUserId?: number | null;
    event: string;
    payload?: Record<string, unknown> | null;
  }): Promise<void> {
    try {
      const { tenantId, orgUnitId } = await this.scopeFor(args.tenderId);
      await this.prisma.auditLog.create({
        data: {
          tenant_id: tenantId,
          org_unit_id: orgUnitId,
          user_id: args.actorUserId ?? null,
          module: 'tenders',
          entity_type: ENTITY_TYPE,
          entity_id: args.tenderId.toString(),
          action: args.event,
          after_value: (args.payload ?? undefined) as any,
        },
      });
    } catch (_err) {
      // Audit failures must not break the operation.
    }
  }

  /**
   * Tender history, shaped like the old `tender_audit_logs` rows — `event`,
   * `payload`, `actor` — so the existing UI keeps rendering unchanged.
   */
  async list(tenderId: number) {
    const rows = await this.prisma.auditLog.findMany({
      where: { entity_type: ENTITY_TYPE, entity_id: tenderId.toString() },
      orderBy: { created_at: 'desc' },
      take: 200,
    });

    // `AuditLog.user_id` is a plain column, not a relation, so the actor is
    // resolved in one extra query rather than per row.
    const actorIds = [
      ...new Set(
        rows.map((r) => r.user_id).filter((id): id is number => id != null),
      ),
    ];
    const actors = actorIds.length
      ? await this.prisma.user.findMany({
          where: { id: { in: actorIds } },
          select: { id: true, email: true },
        })
      : [];
    const byId = new Map(actors.map((a) => [a.id, a]));

    return rows.map((r) => ({
      id: Number(r.id),
      tender_id: tenderId,
      actor_user_id: r.user_id,
      event: r.action,
      payload: r.after_value,
      created_at: r.created_at,
      actor: r.user_id != null ? (byId.get(r.user_id) ?? null) : null,
    }));
  }
}
