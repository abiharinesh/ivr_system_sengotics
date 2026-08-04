import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Service-performance analytics for the Insights hub.
 *
 * Both of its tabs were hardcoded: one showed a fixed "94% SLA Compliance",
 * the other a fixed resolution time, while real complaints and SLA trackers
 * sat in the database. These are the same figures computed from them.
 *
 * Everything is scoped to the caller's branch, and to a rolling window rather
 * than all time — "average resolution" over three years of history tells a
 * commissioner nothing about this month.
 */
@Injectable()
export class ServiceAnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  private static readonly OPEN = ['pending', 'assigned', 'in_progress'];

  async overview(orgUnitId: number | null, days = 30) {
    const since = new Date(Date.now() - days * 86400000);
    const where = orgUnitId == null ? {} : { org_unit_id: orgUnitId };
    const windowed = { ...where, created_at: { gte: since } };

    const [
      total,
      inWindow,
      open,
      resolved,
      byCategory,
      byUrgency,
      resolvedRows,
      feedback,
      slaRows,
    ] = await Promise.all([
      this.prisma.complaint.count({ where }),
      this.prisma.complaint.count({ where: windowed }),
      this.prisma.complaint.count({
        where: { ...where, status: { in: ServiceAnalyticsService.OPEN } },
      }),
      this.prisma.complaint.count({
        where: { ...where, status: { in: ['resolved', 'closed'] } },
      }),
      this.prisma.complaint.groupBy({
        by: ['category'],
        where,
        _count: { _all: true },
      }),
      this.prisma.complaint.groupBy({
        by: ['urgency_level'],
        where,
        _count: { _all: true },
      }),
      this.prisma.complaint.findMany({
        where: { ...where, resolved_at: { not: null } },
        select: { created_at: true, resolved_at: true, category: true },
        orderBy: { resolved_at: 'desc' },
        take: 500,
      }),
      this.prisma.citizenFeedback.aggregate({
        where,
        _avg: { rating: true },
        _count: { _all: true },
      }),
      this.prisma.slaTracker.groupBy({
        by: ['status'],
        where: { entity_type: 'complaint' },
        _count: { _all: true },
      }),
    ]);

    // ── Resolution time ──────────────────────────────────────────────────
    const hours = resolvedRows
      .map((r) => (r.resolved_at!.getTime() - r.created_at.getTime()) / 3600000)
      .filter((h) => h >= 0)
      .sort((a, b) => a - b);

    const avg = hours.length
      ? hours.reduce((a, b) => a + b, 0) / hours.length
      : 0;
    // The median is the honest headline: one complaint left open for a year
    // drags a mean far past what anybody actually experiences.
    const median = hours.length ? hours[Math.floor(hours.length / 2)] : 0;
    const p90 = hours.length
      ? hours[Math.min(hours.length - 1, Math.floor(hours.length * 0.9))]
      : 0;

    // ── SLA ──────────────────────────────────────────────────────────────
    const slaByStatus = new Map(slaRows.map((r) => [r.status, r._count._all]));
    const tracked = slaRows.reduce((n, r) => n + r._count._all, 0);
    const breached = slaByStatus.get('breached') ?? 0;
    const compliance = tracked === 0 ? 100 : Math.round(((tracked - breached) / tracked) * 100);

    // ── Resolution time per category ─────────────────────────────────────
    const perCategory = new Map<string, number[]>();
    for (const r of resolvedRows) {
      const key = r.category ?? 'uncategorised';
      const h = (r.resolved_at!.getTime() - r.created_at.getTime()) / 3600000;
      if (h < 0) continue;
      if (!perCategory.has(key)) perCategory.set(key, []);
      perCategory.get(key)!.push(h);
    }

    // ── Daily volume ─────────────────────────────────────────────────────
    const buckets = new Map<string, number>();
    for (let d = days - 1; d >= 0; d--) {
      buckets.set(
        new Date(Date.now() - d * 86400000).toISOString().slice(0, 10),
        0,
      );
    }
    const recent = await this.prisma.complaint.findMany({
      where: windowed,
      select: { created_at: true },
    });
    for (const c of recent) {
      const k = c.created_at.toISOString().slice(0, 10);
      if (buckets.has(k)) buckets.set(k, buckets.get(k)! + 1);
    }

    return {
      window_days: days,
      totals: {
        all_time: total,
        in_window: inWindow,
        open,
        resolved,
        resolution_rate_pct:
          total === 0 ? 0 : Math.round((resolved / total) * 100),
      },
      resolution_hours: {
        average: Math.round(avg),
        median: Math.round(median),
        p90: Math.round(p90),
        sample: hours.length,
      },
      sla: {
        tracked,
        breached,
        compliance_pct: compliance,
        by_status: [...slaByStatus.entries()].map(([status, count]) => ({
          status,
          count,
        })),
      },
      satisfaction: {
        average: feedback._avg.rating
          ? Number(feedback._avg.rating.toFixed(2))
          : null,
        responses: feedback._count._all,
      },
      by_category: byCategory
        .map((c) => ({
          category: c.category ?? 'uncategorised',
          count: c._count._all,
        }))
        .sort((a, b) => b.count - a.count),
      by_urgency: byUrgency
        .map((u) => ({
          urgency: u.urgency_level ?? 'unset',
          count: u._count._all,
        }))
        .sort((a, b) => b.count - a.count),
      resolution_by_category: [...perCategory.entries()]
        .map(([category, list]) => ({
          category,
          median_hours: Math.round(
            [...list].sort((a, b) => a - b)[Math.floor(list.length / 2)],
          ),
          resolved: list.length,
        }))
        .sort((a, b) => b.median_hours - a.median_hours),
      daily_volume: [...buckets.entries()].map(([date, count]) => ({
        date,
        count,
      })),
    };
  }
}
