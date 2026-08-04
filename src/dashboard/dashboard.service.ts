import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * The per-role dashboard.
 *
 * `dashboard_widgets` and `role_dashboards` shipped with the schema and were
 * never read, so every role landed on one of two hardcoded screens — a
 * Municipal Commissioner and a Sanitary Inspector saw the same panels. This
 * service resolves the caller's role to its configured widget list and then
 * computes each widget from live data, scoped to the branch they work at.
 *
 * Adding a panel to somebody's dashboard is now a row in `role_dashboards`,
 * editable from the super admin console, rather than a redeploy.
 */

/** What a computed widget hands back to the client. */
export interface WidgetPayload {
  code: string;
  title: string;
  widget_type: string;
  data_source: string;
  size: string;
  /** Headline figure for counter/kpi widgets. */
  value?: number | string;
  /** Qualifier under the figure — "of 412 due", "last 30 days". */
  caption?: string;
  /** Direction of travel, where a comparison is meaningful. */
  delta?: number;
  /** How to read the figure: a rising complaint count is not good news. */
  tone?: 'good' | 'warn' | 'bad' | 'neutral';
  /** Series for bar/pie widgets. */
  series?: Array<{ label: string; value: number; color?: string }>;
  /** Rows for table widgets. */
  rows?: Array<Record<string, string | number | null>>;
  columns?: string[];
  /** Points for map widgets. */
  points?: Array<{
    lat: number;
    lng: number;
    label: string;
    value?: string;
    tone?: string;
  }>;
  /** Where tapping the widget should go. */
  route?: string;
  error?: string;
}

const DAY = 86400000;

@Injectable()
export class DashboardService {
  private readonly logger = new Logger(DashboardService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * The caller's dashboard: their role's widget list, each one computed.
   *
   * `orgUnitId` narrows every figure to the branch the user works at. A null
   * org unit means platform scope — the super admin sees the whole tenant.
   */
  async forUser(params: {
    tenantId: string;
    role: string;
    orgUnitId: number | null;
    isSuperAdmin: boolean;
  }) {
    const { tenantId, role, orgUnitId, isSuperAdmin } = params;

    const layout = await this.prisma.roleDashboard.findFirst({
      where: { tenant_id: tenantId, role_name: role },
    });

    // An unconfigured role still gets a usable dashboard rather than a blank
    // page: the generic set works for anyone.
    const FALLBACK = [
      'complaints_open',
      'complaints_overdue',
      'complaints_trend',
      'complaints_by_category',
      'recent_activity',
    ];

    let widgets = layout?.widget_ids?.length
      ? await this.prisma.dashboardWidget.findMany({
          where: { id: { in: layout.widget_ids }, is_active: true },
        })
      : await this.prisma.dashboardWidget.findMany({
          where: { tenant_id: tenantId, code: { in: FALLBACK }, is_active: true },
        });

    // `findMany` does not preserve the configured order, and the order is the
    // layout — it is what the super admin arranged.
    if (layout?.widget_ids?.length) {
      const rank = new Map(layout.widget_ids.map((id, i) => [id, i]));
      widgets = widgets.sort(
        (a, b) => (rank.get(a.id) ?? 0) - (rank.get(b.id) ?? 0),
      );
    }

    const scope = isSuperAdmin ? null : orgUnitId;

    const computed = await Promise.all(
      widgets.map((w) =>
        this.compute(w.code, w.title, w.widget_type, w.data_source, w.default_size, scope)
          .catch((e): WidgetPayload => {
            // One failing panel must not blank the whole dashboard.
            this.logger.warn(`Widget "${w.code}" failed: ${e.message}`);
            return {
              code: w.code,
              title: w.title,
              widget_type: w.widget_type,
              data_source: w.data_source,
              size: w.default_size,
              error: 'Could not load',
            };
          }),
      ),
    );

    return {
      role,
      org_unit_id: scope,
      generated_at: new Date().toISOString(),
      configured: layout != null,
      widgets: computed,
    };
  }

  // ── Widget computation ────────────────────────────────────────────────────

  private async compute(
    code: string,
    title: string,
    widgetType: string,
    dataSource: string,
    size: string,
    org: number | null,
  ): Promise<WidgetPayload> {
    const base: WidgetPayload = {
      code,
      title,
      widget_type: widgetType,
      data_source: dataSource,
      size,
    };
    const where = org == null ? {} : { org_unit_id: org };

    switch (code) {
      // ── Complaints ────────────────────────────────────────────────────────
      case 'complaints_open': {
        const value = await this.prisma.complaint.count({
          where: { ...where, status: { in: ['pending', 'assigned', 'in_progress'] } },
        });
        const total = await this.prisma.complaint.count({ where });
        return {
          ...base,
          value,
          caption: `of ${total} logged`,
          tone: value === 0 ? 'good' : value > 40 ? 'bad' : 'warn',
          route: '/complaints',
        };
      }

      case 'complaints_overdue': {
        // Overdue is what the SLA engine says, not an age guess.
        const value = await this.prisma.slaTracker.count({
          where: { entity_type: 'complaint', status: 'breached' },
        });
        const warning = await this.prisma.slaTracker.count({
          where: { entity_type: 'complaint', status: { in: ['warning', 'escalated'] } },
        });
        return {
          ...base,
          value,
          caption: `${warning} more approaching the deadline`,
          tone: value === 0 ? 'good' : 'bad',
          route: '/complaints',
        };
      }

      case 'complaints_trend': {
        const since = new Date(Date.now() - 29 * DAY);
        const rows = await this.prisma.complaint.findMany({
          where: { ...where, created_at: { gte: since } },
          select: { created_at: true, status: true },
        });
        const buckets = new Map<string, number>();
        for (let d = 29; d >= 0; d--) {
          buckets.set(new Date(Date.now() - d * DAY).toISOString().slice(0, 10), 0);
        }
        for (const r of rows) {
          const k = r.created_at.toISOString().slice(0, 10);
          if (buckets.has(k)) buckets.set(k, buckets.get(k)! + 1);
        }
        const series = [...buckets.entries()].map(([label, value]) => ({
          label,
          value,
        }));
        const half = Math.floor(series.length / 2);
        const first = series.slice(0, half).reduce((n, s) => n + s.value, 0);
        const second = series.slice(half).reduce((n, s) => n + s.value, 0);
        return {
          ...base,
          series,
          value: rows.length,
          caption: 'complaints in the last 30 days',
          delta: first === 0 ? 0 : Math.round(((second - first) / first) * 100),
          tone: second <= first ? 'good' : 'warn',
          route: '/complaints',
        };
      }

      case 'complaints_by_category': {
        const grouped = await this.prisma.complaint.groupBy({
          by: ['category'],
          where,
          _count: { _all: true },
        });
        return {
          ...base,
          series: grouped
            .map((g) => ({
              label: this.pretty(g.category ?? 'Uncategorised'),
              value: g._count._all,
            }))
            .sort((a, b) => b.value - a.value),
          route: '/complaints',
        };
      }

      case 'sla_compliance': {
        const [onTime, breached] = await Promise.all([
          this.prisma.slaTracker.count({
            where: { status: { in: ['on_track', 'resolved', 'warning'] } },
          }),
          this.prisma.slaTracker.count({ where: { status: 'breached' } }),
        ]);
        const total = onTime + breached;
        const pct = total === 0 ? 100 : Math.round((onTime / total) * 100);
        return {
          ...base,
          value: pct,
          caption: `${breached} breach(es) of ${total} tracked`,
          tone: pct >= 90 ? 'good' : pct >= 75 ? 'warn' : 'bad',
        };
      }

      case 'resolution_time': {
        const resolved = await this.prisma.complaint.findMany({
          where: { ...where, resolved_at: { not: null } },
          select: { created_at: true, resolved_at: true },
          take: 400,
          orderBy: { resolved_at: 'desc' },
        });
        const spans = resolved
          .map((r) => (r.resolved_at!.getTime() - r.created_at.getTime()) / 3600000)
          .filter((h) => h >= 0);
        const avg = spans.length
          ? Math.round(spans.reduce((a, b) => a + b, 0) / spans.length)
          : 0;
        return {
          ...base,
          value: avg,
          caption: `hours, across ${spans.length} resolved`,
          tone: avg === 0 ? 'neutral' : avg <= 24 ? 'good' : avg <= 72 ? 'warn' : 'bad',
        };
      }

      // ── Property tax ──────────────────────────────────────────────────────
      case 'tax_collected': {
        const agg = await this.prisma.taxPayment.aggregate({
          where: org == null ? {} : { property: { org_unit_id: org } },
          _sum: { paid_amount: true, demand_amount: true },
        });
        const paid = Number(agg._sum.paid_amount ?? 0);
        const demand = Number(agg._sum.demand_amount ?? 0);
        return {
          ...base,
          value: Math.round(paid),
          caption: demand
            ? `${Math.round((paid / demand) * 100)}% of ₹${this.short(demand)} demanded`
            : 'no demand raised',
          tone: demand === 0 ? 'neutral' : paid / demand >= 0.7 ? 'good' : 'warn',
          route: '/revenue/property-tax',
        };
      }

      case 'tax_defaulters': {
        const value = await this.prisma.taxPayment.count({
          where: {
            ...(org == null ? {} : { property: { org_unit_id: org } }),
            status: { in: ['unpaid', 'overdue', 'partial'] },
            due_date: { lt: new Date() },
          },
        });
        return {
          ...base,
          value,
          caption: 'demands past their due date',
          tone: value === 0 ? 'good' : 'bad',
          route: '/revenue/property-tax',
        };
      }

      case 'tax_collection_trend': {
        const since = new Date(Date.now() - 179 * DAY);
        const rows = await this.prisma.taxPayment.findMany({
          where: {
            ...(org == null ? {} : { property: { org_unit_id: org } }),
            paid_at: { gte: since },
          },
          select: { paid_at: true, paid_amount: true },
        });
        const buckets = new Map<string, number>();
        for (let m = 5; m >= 0; m--) {
          const d = new Date();
          d.setMonth(d.getMonth() - m, 1);
          buckets.set(d.toISOString().slice(0, 7), 0);
        }
        for (const r of rows) {
          if (!r.paid_at) continue;
          const k = r.paid_at.toISOString().slice(0, 7);
          if (buckets.has(k)) {
            buckets.set(k, buckets.get(k)! + Number(r.paid_amount));
          }
        }
        return {
          ...base,
          series: [...buckets.entries()].map(([label, value]) => ({
            label: this.monthLabel(label),
            value: Math.round(value),
          })),
          route: '/revenue/property-tax',
        };
      }

      case 'revenue_mix': {
        const [tax, licences, market, ads, bookings] = await Promise.all([
          this.prisma.taxPayment.aggregate({
            where: org == null ? {} : { property: { org_unit_id: org } },
            _sum: { paid_amount: true },
          }),
          this.prisma.tradeLicence.aggregate({ where, _sum: { paid_amount: true } }),
          this.prisma.marketVendorPayment.aggregate({
            where: org == null ? {} : { vendor: { org_unit_id: org } },
            _sum: { amount_paid: true },
          }),
          this.prisma.adCampaign.aggregate({ where, _sum: { amount_paid: true } }),
          this.prisma.facilityBooking.aggregate({
            where: org == null ? {} : { facility: { org_unit_id: org } },
            _sum: { total_amount: true },
          }),
        ]);
        return {
          ...base,
          series: [
            { label: 'Property tax', value: Math.round(Number(tax._sum.paid_amount ?? 0)) },
            { label: 'Trade licences', value: Math.round(Number(licences._sum.paid_amount ?? 0)) },
            { label: 'Market fees', value: Math.round(Number(market._sum.amount_paid ?? 0)) },
            { label: 'Advertising', value: Math.round(Number(ads._sum.amount_paid ?? 0)) },
            { label: 'Facility rental', value: Math.round(Number(bookings._sum.total_amount ?? 0)) },
          ].filter((s) => s.value > 0),
        };
      }

      // ── Trade licences ────────────────────────────────────────────────────
      case 'licences_active': {
        const value = await this.prisma.tradeLicence.count({
          where: { ...where, status: 'APPROVED' },
        });
        const total = await this.prisma.tradeLicence.count({ where });
        return {
          ...base,
          value,
          caption: `of ${total} on the register`,
          tone: 'neutral',
          route: '/municipality/trade-licences',
        };
      }

      case 'licences_expiring': {
        const value = await this.prisma.tradeLicence.count({
          where: {
            ...where,
            status: 'APPROVED',
            valid_until: { gte: new Date(), lte: new Date(Date.now() + 30 * DAY) },
          },
        });
        const lapsed = await this.prisma.tradeLicence.count({
          where: { ...where, valid_until: { lt: new Date() } },
        });
        return {
          ...base,
          value,
          caption: `${lapsed} already lapsed`,
          tone: value === 0 ? 'good' : 'warn',
          route: '/municipality/trade-licences/renewals',
        };
      }

      // ── Building permits ──────────────────────────────────────────────────
      case 'permits_pending': {
        const value = await this.prisma.buildingPermit.count({
          where: {
            ...where,
            status: { in: ['SUBMITTED', 'SCRUTINY', 'NOC_PENDING', 'INSPECTION'] },
          },
        });
        const old = await this.prisma.buildingPermit.count({
          where: {
            ...where,
            status: { in: ['SUBMITTED', 'SCRUTINY', 'NOC_PENDING', 'INSPECTION'] },
            submitted_at: { lt: new Date(Date.now() - 30 * DAY) },
          },
        });
        return {
          ...base,
          value,
          caption: `${old} pending beyond 30 days`,
          tone: old === 0 ? 'good' : 'bad',
          route: '/municipality/building-permits',
        };
      }

      case 'permits_by_stage': {
        const grouped = await this.prisma.buildingPermit.groupBy({
          by: ['status'],
          where,
          _count: { _all: true },
        });
        return {
          ...base,
          series: grouped
            .map((g) => ({ label: this.pretty(g.status), value: g._count._all }))
            .sort((a, b) => b.value - a.value),
          route: '/municipality/building-permits',
        };
      }

      // ── Vital events ──────────────────────────────────────────────────────
      case 'births_registered':
      case 'deaths_registered': {
        const type = code === 'births_registered' ? 'BIRTH' : 'DEATH';
        const since = new Date(Date.now() - 365 * DAY);
        const value = await this.prisma.vitalEvent.count({
          where: { ...where, event_type: type as never, event_date: { gte: since } },
        });
        const pending = await this.prisma.vitalEvent.count({
          where: { ...where, event_type: type as never, status: { in: ['REPORTED', 'VERIFIED'] } },
        });
        return {
          ...base,
          value,
          caption: `in the last year · ${pending} awaiting registration`,
          tone: 'neutral',
          route: '/municipality/vital-events',
        };
      }

      case 'vital_late_registrations': {
        const value = await this.prisma.vitalEvent.count({
          where: { ...where, is_late_registration: true },
        });
        const magistrate = await this.prisma.vitalEvent.count({
          where: { ...where, delay_days: { gt: 365 } },
        });
        return {
          ...base,
          value,
          caption: `${magistrate} need a magistrate's order`,
          tone: value === 0 ? 'good' : 'warn',
          route: '/municipality/vital-events',
        };
      }

      // ── Solid waste ───────────────────────────────────────────────────────
      case 'bins_red': {
        const value = await this.prisma.wasteBin.count({
          where: { ...where, status: 'ACTIVE', fill_level: { in: ['HIGH', 'OVERFLOWING'] } },
        });
        const total = await this.prisma.wasteBin.count({
          where: { ...where, status: 'ACTIVE' },
        });
        return {
          ...base,
          value,
          caption: `of ${total} active bins`,
          tone: value === 0 ? 'good' : value > total * 0.25 ? 'bad' : 'warn',
          route: '/municipality/solid-waste',
        };
      }

      case 'bin_fill_map': {
        const bins = await this.prisma.wasteBin.findMany({
          where: { ...where, status: 'ACTIVE' },
          select: {
            bin_code: true, latitude: true, longitude: true,
            fill_pct: true, fill_level: true, landmark: true,
          },
          take: 400,
        });
        return {
          ...base,
          points: bins.map((b) => ({
            lat: b.latitude,
            lng: b.longitude,
            label: b.landmark ?? b.bin_code,
            value: `${b.fill_pct}%`,
            tone:
              b.fill_level === 'OVERFLOWING' || b.fill_level === 'HIGH'
                ? 'bad'
                : b.fill_level === 'MEDIUM'
                  ? 'warn'
                  : 'good',
          })),
          value: bins.length,
          caption: 'bins mapped',
          route: '/municipality/solid-waste',
        };
      }

      case 'collection_progress': {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);
        const trips = await this.prisma.collectionTrip.findMany({
          where: { ...where, trip_date: { gte: today } },
          select: { stops_total: true, stops_completed: true, status: true },
        });
        const total = trips.reduce((n, t) => n + t.stops_total, 0);
        const done = trips.reduce((n, t) => n + t.stops_completed, 0);
        const pct = total === 0 ? 0 : Math.round((done / total) * 100);
        return {
          ...base,
          value: pct,
          caption: `${done} of ${total} stops · ${trips.length} round(s) today`,
          tone: total === 0 ? 'neutral' : pct >= 90 ? 'good' : pct >= 60 ? 'warn' : 'bad',
          route: '/municipality/solid-waste',
        };
      }

      case 'workers_on_duty': {
        const today = new Date();
        today.setUTCHours(0, 0, 0, 0);
        const [present, roster] = await Promise.all([
          this.prisma.sanitationAttendance.count({
            where: { ...where, attendance_date: { gte: today }, status: { in: ['PRESENT', 'HALF_DAY'] } },
          }),
          this.prisma.sanitationAttendance.count({
            where: { ...where, attendance_date: { gte: today } },
          }),
        ]);
        return {
          ...base,
          value: present,
          caption: roster ? `of ${roster} on the roster` : 'attendance not yet marked',
          tone: roster === 0 ? 'neutral' : present / roster >= 0.85 ? 'good' : 'warn',
        };
      }

      // ── Water supply ──────────────────────────────────────────────────────
      case 'water_tank_levels': {
        const tanks = await this.prisma.waterTankBorewell.findMany({
          where,
          select: { name: true, current_level_pct: true, status: true },
          orderBy: { current_level_pct: 'asc' },
          take: 12,
        });
        return {
          ...base,
          series: tanks.map((t) => ({
            label: t.name,
            value: Math.round(t.current_level_pct),
          })),
          route: '/water',
        };
      }

      case 'pipeline_alerts': {
        const value = await this.prisma.waterPipeline.count({
          where: { ...where, status: 'leak_alert' },
        });
        const maintenance = await this.prisma.waterPipeline.count({
          where: { ...where, status: 'maintenance' },
        });
        return {
          ...base,
          value,
          caption: `${maintenance} more under maintenance`,
          tone: value === 0 ? 'good' : 'bad',
          route: '/water',
        };
      }

      // ── Street lighting ───────────────────────────────────────────────────
      case 'poles_faulty': {
        // A pole is "faulty" when it has an unresolved complaint against it —
        // there is no fault column, and an open ticket is the real signal.
        const rows = await this.prisma.complaint.groupBy({
          by: ['pole_id'],
          where: {
            ...where,
            pole_id: { not: null },
            status: { in: ['pending', 'assigned', 'in_progress'] },
          },
          _count: { _all: true },
        });
        const total = await this.prisma.electricPole.count({ where });
        return {
          ...base,
          value: rows.length,
          caption: `of ${total} poles`,
          tone: rows.length === 0 ? 'good' : 'warn',
          route: '/poles',
        };
      }

      case 'pole_map': {
        const poles = await this.prisma.electricPole.findMany({
          where: { ...where, latitude: { not: null }, longitude: { not: null } },
          select: { id: true, pole_number: true, latitude: true, longitude: true },
          take: 400,
        });
        const faulty = new Set(
          (
            await this.prisma.complaint.findMany({
              where: {
                ...where,
                pole_id: { not: null },
                status: { in: ['pending', 'assigned', 'in_progress'] },
              },
              select: { pole_id: true },
            })
          ).map((c) => c.pole_id),
        );
        return {
          ...base,
          points: poles.map((p) => ({
            lat: p.latitude!,
            lng: p.longitude!,
            label: p.pole_number ?? `Pole ${p.id}`,
            value: faulty.has(p.id) ? 'Fault reported' : 'OK',
            tone: faulty.has(p.id) ? 'bad' : 'good',
          })),
          value: poles.length,
          caption: `${faulty.size} with an open fault`,
          route: '/poles',
        };
      }

      // ── Procurement ───────────────────────────────────────────────────────
      case 'tenders_open': {
        const value = await this.prisma.tender.count({
          where: { ...where, status: { in: ['published', 'quotations_closed'] } },
        });
        const awaiting = await this.prisma.tender.count({
          where: { ...where, status: 'quotations_closed' },
        });
        return {
          ...base,
          value,
          caption: `${awaiting} awaiting an award decision`,
          tone: 'neutral',
          route: '/tenders',
        };
      }

      case 'work_orders_progress': {
        const grouped = await this.prisma.workOrder.groupBy({
          by: ['status'],
          where,
          _count: { _all: true },
        });
        const inProgress =
          grouped.find((g) => g.status === 'in_progress')?._count._all ?? 0;
        return {
          ...base,
          value: inProgress,
          caption: grouped.map((g) => `${g._count._all} ${this.pretty(g.status)}`).join(' · '),
          series: grouped.map((g) => ({
            label: this.pretty(g.status),
            value: g._count._all,
          })),
          tone: 'neutral',
          route: '/tenders',
        };
      }

      case 'contractor_ratings': {
        const rows = await this.prisma.contractor.findMany({
          where: { ...(org == null ? {} : { org_unit_id: org }), is_active: true },
          select: {
            name: true, rating: true, blacklisted: true,
            _count: { select: { work_orders: true } },
          },
          orderBy: { rating: 'desc' },
          take: 8,
        });
        return {
          ...base,
          columns: ['Contractor', 'Rating', 'Work orders'],
          rows: rows.map((r) => ({
            Contractor: r.blacklisted ? `${r.name} (blacklisted)` : r.name,
            Rating: r.rating == null ? '—' : r.rating.toFixed(1),
            'Work orders': r._count.work_orders,
          })),
          route: '/contractors',
        };
      }

      // ── Inspections ───────────────────────────────────────────────────────
      case 'inspections_due': {
        const [field, licence, permit] = await Promise.all([
          this.prisma.fieldInspection.count({ where: { ...where, status: 'scheduled' } }),
          this.prisma.tradeLicenceInspection.count({ where: { status: 'scheduled' } }),
          this.prisma.buildingPermitInspection.count({ where: { status: 'scheduled' } }),
        ]);
        const value = field + licence + permit;
        return {
          ...base,
          value,
          caption: `${field} field · ${licence} licence · ${permit} permit`,
          tone: value === 0 ? 'good' : 'warn',
          route: '/inspections',
        };
      }

      // ── Cross-cutting ─────────────────────────────────────────────────────
      case 'recent_activity': {
        const rows = await this.prisma.auditLog.findMany({
          where: org == null ? {} : { org_unit_id: org },
          orderBy: { created_at: 'desc' },
          take: 10,
          select: {
            action: true, module: true, entity_type: true,
            entity_id: true, created_at: true,
          },
        });
        return {
          ...base,
          columns: ['Action', 'Module', 'Record', 'When'],
          rows: rows.map((r) => ({
            Action: this.pretty(r.action),
            Module: this.pretty(r.module),
            Record: `${this.pretty(r.entity_type)} #${r.entity_id}`,
            When: r.created_at.toISOString(),
          })),
        };
      }

      case 'citizen_satisfaction': {
        const agg = await this.prisma.citizenFeedback.aggregate({
          where,
          _avg: { rating: true },
          _count: { _all: true },
        });
        const avg = agg._avg.rating ?? 0;
        return {
          ...base,
          value: Number(avg.toFixed(1)),
          caption: `out of 5, from ${agg._count._all} response(s)`,
          tone: avg === 0 ? 'neutral' : avg >= 4 ? 'good' : avg >= 3 ? 'warn' : 'bad',
        };
      }

      case 'ward_heatmap': {
        const complaints = await this.prisma.complaint.findMany({
          where: {
            ...where,
            status: { in: ['pending', 'assigned', 'in_progress'] },
            latitude: { not: null },
            longitude: { not: null },
          },
          select: {
            latitude: true, longitude: true, ward_number: true,
            category: true, urgency_level: true,
          },
          take: 500,
        });
        const wards = new Set(
          complaints.map((c) => c.ward_number).filter((w) => w != null),
        );
        return {
          ...base,
          points: complaints.map((c) => ({
            lat: c.latitude!,
            lng: c.longitude!,
            label: c.ward_number == null
              ? this.pretty(c.category ?? 'Complaint')
              : `Ward ${c.ward_number} — ${this.pretty(c.category ?? 'Complaint')}`,
            value: this.pretty(c.urgency_level ?? 'medium'),
            tone:
              c.urgency_level === 'critical' || c.urgency_level === 'high'
                ? 'bad'
                : c.urgency_level === 'medium'
                  ? 'warn'
                  : 'good',
          })),
          value: complaints.length,
          caption: `open complaints across ${wards.size} ward(s)`,
          route: '/complaints',
        };
      }

      default:
        return { ...base, error: `No handler for "${code}"` };
    }
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  /** `noc_pending` / `NOC_PENDING` → `Noc pending`. */
  private pretty(raw: string): string {
    if (!raw) return raw;
    const s = raw.replace(/_/g, ' ').toLowerCase();
    return s[0].toUpperCase() + s.slice(1);
  }

  /** `1234567` → `12.3L`, matching how the figure is spoken about locally. */
  private short(n: number): string {
    if (n >= 10000000) return `${(n / 10000000).toFixed(1)}Cr`;
    if (n >= 100000) return `${(n / 100000).toFixed(1)}L`;
    if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
    return `${Math.round(n)}`;
  }

  /** `2026-08` → `Aug`. */
  private monthLabel(ym: string): string {
    const [y, m] = ym.split('-').map(Number);
    return new Date(y, m - 1, 1).toLocaleString('en-IN', { month: 'short' });
  }
}
