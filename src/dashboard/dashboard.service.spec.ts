import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { DashboardService } from './dashboard.service';

/**
 * The layout resolution and the tone/scoping rules are what matter here: which
 * panels a role gets, in what order, and whether a figure is reported as good
 * news or bad. The individual counts are Prisma calls; the judgement around
 * them is this service's.
 */

const widget = (
  id: number,
  code: string,
  over: Record<string, any> = {},
) => ({
  id,
  tenant_id: 'default',
  code,
  title: code,
  widget_type: 'counter',
  data_source: 'complaints',
  query_config: {},
  default_size: 'small',
  is_active: true,
  ...over,
});

describe('DashboardService', () => {
  let service: DashboardService;

  const prisma = {
    roleDashboard: { findFirst: jest.fn() },
    dashboardWidget: { findMany: jest.fn() },
    complaint: { count: jest.fn(), findMany: jest.fn(), groupBy: jest.fn() },
    slaTracker: { count: jest.fn() },
    wasteBin: { count: jest.fn(), findMany: jest.fn() },
    taxPayment: { count: jest.fn(), aggregate: jest.fn(), findMany: jest.fn() },
    tradeLicence: { count: jest.fn(), aggregate: jest.fn() },
    marketVendorPayment: { aggregate: jest.fn() },
    adCampaign: { aggregate: jest.fn() },
    facilityBooking: { aggregate: jest.fn() },
    auditLog: { findMany: jest.fn() },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [DashboardService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get(DashboardService);
    jest.clearAllMocks();

    prisma.roleDashboard.findFirst.mockResolvedValue(null);
    prisma.dashboardWidget.findMany.mockResolvedValue([]);
    prisma.complaint.count.mockResolvedValue(0);
    prisma.complaint.findMany.mockResolvedValue([]);
    prisma.complaint.groupBy.mockResolvedValue([]);
    prisma.slaTracker.count.mockResolvedValue(0);
    prisma.wasteBin.count.mockResolvedValue(0);
    prisma.auditLog.findMany.mockResolvedValue([]);
  });

  const call = (over: Record<string, any> = {}) =>
    service.forUser({
      tenantId: 'default',
      role: 'health_officer',
      orgUnitId: 7,
      isSuperAdmin: false,
      ...over,
    });

  describe('layout resolution', () => {
    it('returns the panels the role is configured with, in the configured order', async () => {
      prisma.roleDashboard.findFirst.mockResolvedValue({
        id: 1,
        widget_ids: [30, 10, 20],
      });
      // Prisma does not preserve the `in` order, and the order is the layout.
      prisma.dashboardWidget.findMany.mockResolvedValue([
        widget(10, 'complaints_open'),
        widget(20, 'bins_red'),
        widget(30, 'complaints_overdue'),
      ]);

      const r = await call();

      expect(r.configured).toBe(true);
      expect(r.widgets.map((w) => w.code)).toEqual([
        'complaints_overdue',
        'complaints_open',
        'bins_red',
      ]);
    });

    it('falls back to a generic set when the role has no layout', async () => {
      prisma.dashboardWidget.findMany.mockResolvedValue([
        widget(1, 'complaints_open'),
      ]);

      const r = await call();

      expect(r.configured).toBe(false);
      expect(r.widgets).toHaveLength(1);
      // The fallback is fetched by code, not by the (absent) id list.
      expect(prisma.dashboardWidget.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            code: { in: expect.arrayContaining(['complaints_open']) },
          }),
        }),
      );
    });

    it('reports an unknown widget code instead of dropping the panel', async () => {
      prisma.roleDashboard.findFirst.mockResolvedValue({ id: 1, widget_ids: [1] });
      prisma.dashboardWidget.findMany.mockResolvedValue([
        widget(1, 'not_a_real_widget'),
      ]);

      const r = await call();

      expect(r.widgets).toHaveLength(1);
      expect(r.widgets[0].error).toContain('not_a_real_widget');
    });

    it('keeps the rest of the dashboard when one panel throws', async () => {
      prisma.roleDashboard.findFirst.mockResolvedValue({ id: 1, widget_ids: [1, 2] });
      prisma.dashboardWidget.findMany.mockResolvedValue([
        widget(1, 'complaints_open'),
        widget(2, 'bins_red'),
      ]);
      prisma.complaint.count.mockRejectedValue(new Error('connection lost'));
      prisma.wasteBin.count.mockResolvedValue(4);

      const r = await call();

      expect(r.widgets[0].error).toBe('Could not load');
      expect(r.widgets[1].value).toBe(4);
    });
  });

  describe('scoping', () => {
    it("narrows every figure to the caller's branch", async () => {
      prisma.roleDashboard.findFirst.mockResolvedValue({ id: 1, widget_ids: [1] });
      prisma.dashboardWidget.findMany.mockResolvedValue([
        widget(1, 'complaints_open'),
      ]);

      const r = await call({ orgUnitId: 7 });

      expect(r.org_unit_id).toBe(7);
      expect(prisma.complaint.count).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ org_unit_id: 7 }),
        }),
      );
    });

    it('gives a super admin tenant-wide figures rather than one branch', async () => {
      prisma.roleDashboard.findFirst.mockResolvedValue({ id: 1, widget_ids: [1] });
      prisma.dashboardWidget.findMany.mockResolvedValue([
        widget(1, 'complaints_open'),
      ]);

      const r = await call({ role: 'super_admin', isSuperAdmin: true, orgUnitId: 7 });

      expect(r.org_unit_id).toBeNull();
      expect(prisma.complaint.count).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.not.objectContaining({ org_unit_id: expect.anything() }),
        }),
      );
    });
  });

  describe('tone', () => {
    const single = async (code: string) => {
      prisma.roleDashboard.findFirst.mockResolvedValue({ id: 1, widget_ids: [1] });
      prisma.dashboardWidget.findMany.mockResolvedValue([widget(1, code)]);
      const r = await call();
      return r.widgets[0];
    };

    it('calls zero open complaints good and a large backlog bad', async () => {
      prisma.complaint.count.mockResolvedValue(0);
      expect((await single('complaints_open')).tone).toBe('good');

      prisma.complaint.count.mockResolvedValue(120);
      expect((await single('complaints_open')).tone).toBe('bad');
    });

    it('treats any SLA breach as bad regardless of how few', async () => {
      prisma.slaTracker.count.mockResolvedValue(1);
      expect((await single('complaints_overdue')).tone).toBe('bad');
    });

    it('reports SLA compliance as a percentage of tracked items', async () => {
      prisma.slaTracker.count
        .mockResolvedValueOnce(90) // on time
        .mockResolvedValueOnce(10); // breached

      const w = await single('sla_compliance');

      expect(w.value).toBe(90);
      expect(w.tone).toBe('good');
    });

    it('reports full compliance when nothing is tracked, not a divide by zero', async () => {
      prisma.slaTracker.count.mockResolvedValue(0);

      const w = await single('sla_compliance');

      expect(w.value).toBe(100);
      expect(Number.isNaN(w.value as number)).toBe(false);
    });

    it('marks tax collection short of target as needing attention', async () => {
      prisma.taxPayment.aggregate.mockResolvedValue({
        _sum: { paid_amount: 200, demand_amount: 1000 },
      });

      const w = await single('tax_collected');

      expect(w.value).toBe(200);
      expect(w.caption).toContain('20%');
      expect(w.tone).toBe('warn');
    });

    it('does not divide by zero when no tax demand has been raised', async () => {
      prisma.taxPayment.aggregate.mockResolvedValue({
        _sum: { paid_amount: null, demand_amount: null },
      });

      const w = await single('tax_collected');

      expect(w.value).toBe(0);
      expect(w.tone).toBe('neutral');
      expect(w.caption).toBe('no demand raised');
    });
  });

  describe('trend', () => {
    it('buckets 30 days and reports the direction of travel', async () => {
      prisma.roleDashboard.findFirst.mockResolvedValue({ id: 1, widget_ids: [1] });
      prisma.dashboardWidget.findMany.mockResolvedValue([
        widget(1, 'complaints_trend', { widget_type: 'bar_chart' }),
      ]);
      // Everything logged today, so the second half of the window is busier.
      prisma.complaint.findMany.mockResolvedValue(
        Array.from({ length: 6 }, () => ({ created_at: new Date(), status: 'pending' })),
      );

      const w = await call().then((r) => r.widgets[0]);

      expect(w.series).toHaveLength(30);
      expect(w.value).toBe(6);
      expect(w.tone).toBe('warn');
    });
  });
});
