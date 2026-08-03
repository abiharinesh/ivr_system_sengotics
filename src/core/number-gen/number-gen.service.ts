import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Central sequence generator for all numbered entities.
 * Generates IDs like: CMP-2026-000001, WO-2026-0045, AST-000231
 *
 * Thread-safe using database-level atomic increment.
 * Resets based on financial year or calendar year.
 */
@Injectable()
export class NumberGenService {
  private readonly logger = new Logger(NumberGenService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Generate the next number for a given entity type.
   * @param tenantId - Tenant scope
   * @param entityType - "complaint", "work_order", "asset", "tender", etc.
   * @param orgUnitId - Optional branch-level scoping
   * @returns Formatted number string, e.g., "CMP-2026-000042"
   */
  async next(
    tenantId: string,
    entityType: string,
    orgUnitId?: number,
  ): Promise<string> {
    // Find or create sequence config
    let config = await this.prisma.sequenceConfig.findFirst({
      where: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId ?? null,
        entity_type: entityType,
      },
    });

    if (!config) {
      // Fall back to tenant-wide config
      config = await this.prisma.sequenceConfig.findFirst({
        where: {
          tenant_id: tenantId,
          org_unit_id: null,
          entity_type: entityType,
        },
      });
    }

    if (!config) {
      // Create a default config
      const defaults = this.getDefaults(entityType);
      config = await this.prisma.sequenceConfig.create({
        data: {
          tenant_id: tenantId,
          org_unit_id: orgUnitId ?? null,
          entity_type: entityType,
          prefix: defaults.prefix,
          format: defaults.format,
          current_seq: 0,
          reset_cycle: defaults.resetCycle,
          // Stamped at creation because `needsReset` compares against this
          // date. Left null, the very first cycle rollover would never fire
          // and the sequence would run on across years.
          last_reset_at: new Date(),
        },
      });
    }

    // Check if reset is needed
    if (this.needsReset(config)) {
      await this.prisma.sequenceConfig.update({
        where: { id: config.id },
        data: { current_seq: 0, last_reset_at: new Date() },
      });
      config.current_seq = 0;
    }

    // Atomic increment
    const updated = await this.prisma.sequenceConfig.update({
      where: { id: config.id },
      data: { current_seq: { increment: 1 } },
    });

    return this.formatNumber(config.format, config.prefix, updated.current_seq);
  }

  private formatNumber(
    format: string,
    prefix: string,
    seq: number,
  ): string {
    const now = new Date();
    const fy = this.getCurrentFY();

    // Parse format: "{prefix}-{fy}-{seq:6}"
    return format
      .replace('{prefix}', prefix)
      .replace('{fy}', fy)
      .replace('{year}', now.getFullYear().toString())
      .replace(/\{seq:(\d+)\}/, (_, width) =>
        seq.toString().padStart(parseInt(width, 10), '0'),
      )
      .replace('{seq}', seq.toString());
  }

  private getCurrentFY(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1; // 1-indexed
    // Indian FY: April to March
    if (month >= 4) {
      return `${year}-${(year + 1).toString().slice(-2)}`;
    }
    return `${year - 1}-${year.toString().slice(-2)}`;
  }

  private needsReset(config: {
    reset_cycle: string | null;
    last_reset_at: Date | null;
  }): boolean {
    if (!config.reset_cycle || config.reset_cycle === 'never') return false;
    if (!config.last_reset_at) return false;

    const now = new Date();
    const lastReset = new Date(config.last_reset_at);

    if (config.reset_cycle === 'financial_year') {
      // Reset if we've crossed April 1st since last reset
      const currentFYStart = new Date(
        now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1,
        3, // April (0-indexed)
        1,
      );
      return lastReset < currentFYStart;
    }

    if (config.reset_cycle === 'calendar_year') {
      return lastReset.getFullYear() < now.getFullYear();
    }

    return false;
  }

  private getDefaults(entityType: string): {
    prefix: string;
    format: string;
    resetCycle: string;
  } {
    const map: Record<
      string,
      { prefix: string; format: string; resetCycle?: string }
    > = {
      complaint: { prefix: 'CMP', format: '{prefix}-{fy}-{seq:6}' },
      work_order: { prefix: 'WO', format: '{prefix}-{fy}-{seq:4}' },
      tender: { prefix: 'TEN', format: '{prefix}-{fy}-{seq:4}' },
      asset: { prefix: 'AST', format: '{prefix}-{seq:6}', resetCycle: 'never' },
      permit: { prefix: 'PERMIT', format: '{prefix}-{fy}-{seq:4}' },
      employee: { prefix: 'EMP', format: '{prefix}-{seq:5}', resetCycle: 'never' },
      inspection: { prefix: 'INS', format: '{prefix}-{fy}-{seq:5}' },
      // Vital registration serials run against the calendar year, not the
      // financial year — the register is closed and totalled on 31 December.
      birth_registration: {
        prefix: 'B',
        format: '{prefix}/{year}/{seq:6}',
        resetCycle: 'calendar_year',
      },
      death_registration: {
        prefix: 'D',
        format: '{prefix}/{year}/{seq:6}',
        resetCycle: 'calendar_year',
      },
      vital_certificate: {
        prefix: 'VC',
        format: '{prefix}-{year}-{seq:6}',
        resetCycle: 'calendar_year',
      },
      // Bins and routes are long-lived infrastructure — their codes must not
      // be reused when the year turns.
      waste_bin: { prefix: 'BIN', format: '{prefix}-{seq:6}', resetCycle: 'never' },
      collection_route: {
        prefix: 'RTE',
        format: '{prefix}-{seq:4}',
        resetCycle: 'never',
      },
      collection_trip: { prefix: 'TRIP', format: '{prefix}-{fy}-{seq:6}' },
      // Licence numbers carry their financial year — the licence year runs
      // 1 April to 31 March, and the number is quoted on the displayed licence.
      trade_licence: { prefix: 'TL', format: '{prefix}/{fy}/{seq:6}' },
      trade_licence_certificate: {
        prefix: 'TLC',
        format: '{prefix}-{fy}-{seq:6}',
      },
    };
    const entry = map[entityType] ?? {
      prefix: entityType.toUpperCase().slice(0, 3),
      format: '{prefix}-{seq:6}',
    };
    return {
      prefix: entry.prefix,
      format: entry.format,
      resetCycle: entry.resetCycle ?? 'financial_year',
    };
  }
}
