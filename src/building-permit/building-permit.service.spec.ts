import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { BuildingPermitService } from './building-permit.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { DocumentService } from '../core/document/document.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { SlaService } from '../core/sla/sla.service';
import { WorkflowService } from '../core/workflow/workflow.service';

const TENANT = 'tenant-a';
const USER = 7;

/** A permit row as Prisma would return it, overridable per test. */
const permitRow = (overrides: Record<string, any> = {}) => ({
  id: 1,
  tenant_id: TENANT,
  org_unit_id: 5,
  permit_number: 'PERMIT-2026-0001',
  applicant_name: 'R. Kumar',
  applicant_phone: '9876543210',
  survey_number: '112/3B',
  construction_type: 'residential',
  work_nature: 'new',
  plot_area_sqm: 300,
  built_up_area_sqm: 200,
  floors_proposed: 2,
  scrutiny_fee: 2000,
  permit_fee: 6000,
  development_fee: 4500,
  total_fee: 12500,
  paid_amount: 0,
  payment_status: 'unpaid',
  payment_ref: null,
  status: 'DRAFT',
  nocs: [],
  inspections: [],
  ...overrides,
});

const grantedNoc = (department: string, id = 1) => ({
  id,
  department,
  is_mandatory: true,
  status: 'GRANTED',
  reference_no: null,
  remarks: null,
});

const pendingNoc = (department: string, id = 2) => ({
  id,
  department,
  is_mandatory: true,
  status: 'PENDING',
  reference_no: null,
  remarks: null,
});

const compliantInspection = () => ({
  id: 1,
  status: 'completed',
  is_compliant: true,
  inspector_user_id: 9,
});

describe('BuildingPermitService', () => {
  let service: BuildingPermitService;

  const prisma = {
    buildingPermit: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
      count: jest.fn(),
      groupBy: jest.fn(),
      aggregate: jest.fn(),
    },
    buildingPermitNoc: { create: jest.fn(), update: jest.fn() },
    buildingPermitInspection: { create: jest.fn(), update: jest.fn() },
    orgUnit: { findFirst: jest.fn() },
    slaTracker: { findFirst: jest.fn(), updateMany: jest.fn(), count: jest.fn() },
  };

  const numbers = { next: jest.fn() };
  const workflow = { startWorkflow: jest.fn(), getTimeline: jest.fn() };
  const sla = { startTracker: jest.fn() };
  const audit = { log: jest.fn(), getEntityHistory: jest.fn() };
  const documents = { getForEntity: jest.fn() };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BuildingPermitService,
        { provide: PrismaService, useValue: prisma },
        { provide: NumberGenService, useValue: numbers },
        { provide: WorkflowService, useValue: workflow },
        { provide: SlaService, useValue: sla },
        { provide: AuditService, useValue: audit },
        { provide: DocumentService, useValue: documents },
      ],
    }).compile();

    service = module.get(BuildingPermitService);
    jest.clearAllMocks();

    // Sensible defaults; individual tests override what they care about.
    prisma.orgUnit.findFirst.mockResolvedValue({ id: 5 });
    numbers.next.mockResolvedValue('PERMIT-2026-0001');
    prisma.buildingPermit.update.mockImplementation(({ data }) =>
      Promise.resolve(permitRow(data)),
    );
    audit.log.mockResolvedValue(undefined);
    audit.getEntityHistory.mockResolvedValue([]);
    documents.getForEntity.mockResolvedValue([]);
    workflow.getTimeline.mockResolvedValue(null);
    prisma.slaTracker.findFirst.mockResolvedValue(null);
    prisma.slaTracker.updateMany.mockResolvedValue({ count: 1 });
  });

  describe('create', () => {
    it('generates a permit number, computes fees and seeds the NOC checklist', async () => {
      prisma.buildingPermit.create.mockResolvedValue(permitRow());

      await service.create(TENANT, USER, {
        org_unit_id: 5,
        applicant_name: 'R. Kumar',
        survey_number: '112/3B',
        plot_area_sqm: 300,
        construction_type: 'residential',
        built_up_area_sqm: 200,
        floors_proposed: 2,
      } as any);

      expect(numbers.next).toHaveBeenCalledWith(TENANT, 'permit', 5);

      const data = prisma.buildingPermit.create.mock.calls[0][0].data;
      expect(data.permit_number).toBe('PERMIT-2026-0001');
      expect(data.total_fee).toBe(12500);
      expect(data.status).toBe('DRAFT');
      // Residential defaults: water + electricity.
      expect(data.nocs.create.map((n: any) => n.department)).toEqual([
        'water',
        'electricity',
      ]);
    });

    it('honours an explicit NOC department list', async () => {
      prisma.buildingPermit.create.mockResolvedValue(permitRow());

      await service.create(TENANT, USER, {
        org_unit_id: 5,
        applicant_name: 'R. Kumar',
        survey_number: '112/3B',
        plot_area_sqm: 300,
        construction_type: 'residential',
        built_up_area_sqm: 200,
        noc_departments: ['fire'],
      } as any);

      const data = prisma.buildingPermit.create.mock.calls[0][0].data;
      expect(data.nocs.create).toEqual([{ department: 'fire', is_mandatory: true }]);
    });

    it('stores only the last four digits of an Aadhaar number', async () => {
      prisma.buildingPermit.create.mockResolvedValue(permitRow());

      await service.create(TENANT, USER, {
        org_unit_id: 5,
        applicant_name: 'R. Kumar',
        survey_number: '112/3B',
        plot_area_sqm: 300,
        construction_type: 'residential',
        built_up_area_sqm: 200,
        applicant_aadhaar: '123456789012',
      } as any);

      const data = prisma.buildingPermit.create.mock.calls[0][0].data;
      expect(data.applicant_aadhaar).toBe('XXXXXXXX9012');
      expect(data.applicant_aadhaar).not.toContain('12345678');
    });

    it('refuses an org unit belonging to another tenant', async () => {
      prisma.orgUnit.findFirst.mockResolvedValue(null);

      await expect(
        service.create(TENANT, USER, {
          org_unit_id: 99,
          applicant_name: 'R. Kumar',
          survey_number: '112/3B',
          plot_area_sqm: 300,
          construction_type: 'residential',
          built_up_area_sqm: 200,
        } as any),
      ).rejects.toThrow(ForbiddenException);

      expect(prisma.buildingPermit.create).not.toHaveBeenCalled();
    });

    it('rejects a proposal whose built-up area cannot fit the plot', async () => {
      await expect(
        service.create(TENANT, USER, {
          org_unit_id: 5,
          applicant_name: 'R. Kumar',
          survey_number: '112/3B',
          plot_area_sqm: 100,
          construction_type: 'residential',
          built_up_area_sqm: 500,
          floors_proposed: 2,
        } as any),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('update', () => {
    it('recomputes fees when the proposal size changes', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(permitRow());

      await service.update(TENANT, 1, USER, { built_up_area_sqm: 400 } as any);

      const data = prisma.buildingPermit.update.mock.calls[0][0].data;
      // 400 × 30 permit + 400 × 10 scrutiny + 300 × 15 development
      expect(data.permit_fee).toBe(12000);
      expect(data.scrutiny_fee).toBe(4000);
      expect(data.total_fee).toBe(20500);
    });

    it('leaves fees alone when only contact details change', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(permitRow());

      await service.update(TENANT, 1, USER, { applicant_phone: '9000000001' } as any);

      const data = prisma.buildingPermit.update.mock.calls[0][0].data;
      expect(data.total_fee).toBeUndefined();
    });

    it('refuses to edit a permit that has left the applicant', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ status: 'NOC_PENDING' }),
      );

      await expect(
        service.update(TENANT, 1, USER, { applicant_name: 'Someone Else' } as any),
      ).rejects.toThrow(BadRequestException);
    });

    it('does not leak a permit belonging to another tenant', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(null);

      await expect(
        service.update(TENANT, 1, USER, { applicant_name: 'X' } as any),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('submit', () => {
    it('starts the approval chain and the SLA clock', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ nocs: [pendingNoc('water')] }),
      );
      workflow.startWorkflow.mockResolvedValue({ id: 42 });
      sla.startTracker.mockResolvedValue({ id: 11 });

      await service.submit(TENANT, 1, USER);

      expect(workflow.startWorkflow).toHaveBeenCalledWith(
        TENANT,
        5,
        'building_permit_approval',
        'building_permit',
        1,
      );
      expect(sla.startTracker).toHaveBeenCalledWith(
        TENANT,
        5,
        'building_permit',
        1,
        'residential',
        'medium',
      );
      expect(prisma.buildingPermit.update.mock.calls[0][0].data.status).toBe(
        'SUBMITTED',
      );
    });

    it('treats a high-rise proposal as higher urgency', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ floors_proposed: 6, nocs: [pendingNoc('fire')] }),
      );
      workflow.startWorkflow.mockResolvedValue({ id: 42 });

      await service.submit(TENANT, 1, USER);

      expect(sla.startTracker).toHaveBeenCalledWith(
        TENANT,
        5,
        'building_permit',
        1,
        'residential',
        'high',
      );
    });

    it('still accepts the application when no workflow template is configured', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ nocs: [pendingNoc('water')] }),
      );
      workflow.startWorkflow.mockResolvedValue(null);

      await expect(service.submit(TENANT, 1, USER)).resolves.toBeDefined();
      expect(prisma.buildingPermit.update).toHaveBeenCalled();
    });

    it('refuses to submit a permit with no clearances listed', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(permitRow({ nocs: [] }));

      await expect(service.submit(TENANT, 1, USER)).rejects.toThrow(
        BadRequestException,
      );
      expect(workflow.startWorkflow).not.toHaveBeenCalled();
    });

    it('refuses to submit twice', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ status: 'SUBMITTED', nocs: [pendingNoc('water')] }),
      );

      await expect(service.submit(TENANT, 1, USER)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('changeStatus', () => {
    it('blocks the move to INSPECTION while a mandatory clearance is pending', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({
          status: 'NOC_PENDING',
          nocs: [grantedNoc('water', 1), pendingNoc('fire', 2)],
        }),
      );

      await expect(
        service.changeStatus(TENANT, 1, USER, 'INSPECTION' as any),
      ).rejects.toThrow(/fire/);
    });

    it('allows INSPECTION once every mandatory clearance is settled', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({
          status: 'NOC_PENDING',
          nocs: [
            grantedNoc('water', 1),
            { ...pendingNoc('fire', 2), status: 'NOT_APPLICABLE' },
          ],
        }),
      );

      await expect(
        service.changeStatus(TENANT, 1, USER, 'INSPECTION' as any),
      ).resolves.toBeDefined();
    });

    it('rejects an illegal jump straight from SUBMITTED to INSPECTION', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ status: 'SUBMITTED' }),
      );

      await expect(
        service.changeStatus(TENANT, 1, USER, 'INSPECTION' as any),
      ).rejects.toThrow(BadRequestException);
    });

    it('sends approval and rejection through their own endpoints', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ status: 'INSPECTION' }),
      );

      await expect(
        service.changeStatus(TENANT, 1, USER, 'APPROVED' as any),
      ).rejects.toThrow(/approve or reject endpoint/);
    });
  });

  describe('updateNoc', () => {
    it('advances to INSPECTION when the last mandatory clearance lands', async () => {
      const beforeClearing = permitRow({
        status: 'NOC_PENDING',
        nocs: [grantedNoc('water', 1), pendingNoc('fire', 2)],
      });
      const afterClearing = permitRow({
        status: 'NOC_PENDING',
        nocs: [grantedNoc('water', 1), grantedNoc('fire', 2)],
      });

      prisma.buildingPermit.findFirst
        .mockResolvedValueOnce(beforeClearing) // updateNoc's own load
        .mockResolvedValueOnce(afterClearing) // re-read after the write
        .mockResolvedValueOnce(afterClearing) // changeStatus load
        .mockResolvedValueOnce(afterClearing); // getById at the end
      prisma.buildingPermitNoc.update.mockResolvedValue(grantedNoc('fire', 2));
      prisma.buildingPermit.groupBy.mockResolvedValue([]);

      await service.updateNoc(TENANT, 1, 2, USER, { status: 'GRANTED' } as any);

      const statuses = prisma.buildingPermit.update.mock.calls.map(
        (c) => c[0].data.status,
      );
      expect(statuses).toContain('INSPECTION');
    });

    it('stays put while another mandatory clearance is outstanding', async () => {
      const row = permitRow({
        status: 'NOC_PENDING',
        nocs: [grantedNoc('water', 1), pendingNoc('fire', 2)],
      });
      prisma.buildingPermit.findFirst.mockResolvedValue(row);
      prisma.buildingPermitNoc.update.mockResolvedValue(grantedNoc('water', 1));

      await service.updateNoc(TENANT, 1, 1, USER, { status: 'GRANTED' } as any);

      expect(prisma.buildingPermit.update).not.toHaveBeenCalled();
    });

    it('clears the actor and timestamp when a clearance is reset to PENDING', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ status: 'NOC_PENDING', nocs: [grantedNoc('water', 1)] }),
      );
      prisma.buildingPermitNoc.update.mockResolvedValue(pendingNoc('water', 1));

      await service.updateNoc(TENANT, 1, 1, USER, { status: 'PENDING' } as any);

      const data = prisma.buildingPermitNoc.update.mock.calls[0][0].data;
      expect(data.cleared_by).toBeNull();
      expect(data.cleared_at).toBeNull();
    });

    it('404s for a clearance that is not on this permit', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(permitRow());

      await expect(
        service.updateNoc(TENANT, 1, 999, USER, { status: 'GRANTED' } as any),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('recordPayment', () => {
    it('marks the permit paid once the full fee is in', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(permitRow());

      await service.recordPayment(TENANT, 1, USER, {
        amount: 12500,
        payment_ref: 'RCPT-9',
      } as any);

      const data = prisma.buildingPermit.update.mock.calls[0][0].data;
      expect(data.payment_status).toBe('paid');
      expect(data.paid_amount).toBe(12500);
      expect(data.paid_at).toBeInstanceOf(Date);
    });

    it('accumulates part payments', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ paid_amount: 5000, payment_status: 'partial' }),
      );

      await service.recordPayment(TENANT, 1, USER, { amount: 2500 } as any);

      const data = prisma.buildingPermit.update.mock.calls[0][0].data;
      expect(data.paid_amount).toBe(7500);
      expect(data.payment_status).toBe('partial');
      expect(data.paid_at).toBeUndefined();
    });

    it('refuses an overpayment', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ paid_amount: 12000 }),
      );

      await expect(
        service.recordPayment(TENANT, 1, USER, { amount: 1000 } as any),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('approve', () => {
    const readyPermit = () =>
      permitRow({
        status: 'INSPECTION',
        paid_amount: 12500,
        payment_status: 'paid',
        nocs: [grantedNoc('water', 1), grantedNoc('electricity', 2)],
        inspections: [compliantInspection()],
      });

    it('sanctions the permit and sets a default 36-month validity', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(readyPermit());

      await service.approve(TENANT, 1, USER, {} as any);

      const data = prisma.buildingPermit.update.mock.calls[0][0].data;
      expect(data.status).toBe('APPROVED');
      expect(data.approved_by).toBe(USER);

      const months =
        (data.valid_until.getFullYear() - new Date().getFullYear()) * 12 +
        (data.valid_until.getMonth() - new Date().getMonth());
      expect(months).toBe(36);
    });

    it('honours a shorter sanctioned validity', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(readyPermit());

      await service.approve(TENANT, 1, USER, { validity_months: 12 } as any);

      const data = prisma.buildingPermit.update.mock.calls[0][0].data;
      const months =
        (data.valid_until.getFullYear() - new Date().getFullYear()) * 12 +
        (data.valid_until.getMonth() - new Date().getMonth());
      expect(months).toBe(12);
    });

    it('stops the SLA clock', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(readyPermit());

      await service.approve(TENANT, 1, USER, {} as any);

      expect(prisma.slaTracker.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'resolved' }),
        }),
      );
    });

    it('refuses while a mandatory clearance is pending', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({
          status: 'INSPECTION',
          payment_status: 'paid',
          paid_amount: 12500,
          nocs: [grantedNoc('water', 1), pendingNoc('fire', 2)],
          inspections: [compliantInspection()],
        }),
      );

      await expect(service.approve(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /clearance pending from fire/,
      );
      expect(prisma.buildingPermit.update).not.toHaveBeenCalled();
    });

    it('refuses when a department has refused clearance', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({
          status: 'INSPECTION',
          payment_status: 'paid',
          paid_amount: 12500,
          nocs: [{ ...pendingNoc('fire', 2), status: 'REJECTED' }],
          inspections: [compliantInspection()],
        }),
      );

      await expect(service.approve(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /refused by fire/,
      );
    });

    it('refuses while fees are outstanding, naming the balance', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({
          status: 'INSPECTION',
          paid_amount: 2500,
          payment_status: 'partial',
          nocs: [grantedNoc('water', 1)],
          inspections: [compliantInspection()],
        }),
      );

      await expect(service.approve(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /10000 of fees unpaid/,
      );
    });

    it('refuses without a compliant site inspection', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({
          status: 'INSPECTION',
          paid_amount: 12500,
          payment_status: 'paid',
          nocs: [grantedNoc('water', 1)],
          inspections: [{ ...compliantInspection(), is_compliant: false }],
        }),
      );

      await expect(service.approve(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /no compliant site inspection/,
      );
    });

    it('refuses from a status that is not INSPECTION', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ status: 'SCRUTINY' }),
      );

      await expect(service.approve(TENANT, 1, USER, {} as any)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('reject', () => {
    it('records the reason and stops the SLA clock', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ status: 'SCRUTINY' }),
      );

      await service.reject(TENANT, 1, USER, {
        reason: 'Setback on the north side falls short of the required 1.5 m',
      } as any);

      const data = prisma.buildingPermit.update.mock.calls[0][0].data;
      expect(data.status).toBe('REJECTED');
      expect(data.rejection_reason).toContain('Setback');
      expect(prisma.slaTracker.updateMany).toHaveBeenCalled();
    });

    it('cannot reject an already-approved permit', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ status: 'APPROVED' }),
      );

      await expect(
        service.reject(TENANT, 1, USER, { reason: 'Changed our mind entirely' } as any),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('recordInspection', () => {
    it('will not overwrite a finding that is already on record', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({ status: 'INSPECTION', inspections: [compliantInspection()] }),
      );

      await expect(
        service.recordInspection(TENANT, 1, 1, USER, { is_compliant: false } as any),
      ).rejects.toThrow(/already recorded/);
    });

    it('attributes the visit to the recording user when none was assigned', async () => {
      prisma.buildingPermit.findFirst.mockResolvedValue(
        permitRow({
          status: 'INSPECTION',
          inspections: [
            { id: 1, status: 'scheduled', is_compliant: null, inspector_user_id: null },
          ],
        }),
      );
      prisma.buildingPermitInspection.update.mockResolvedValue({ id: 1 });

      await service.recordInspection(TENANT, 1, 1, USER, {
        is_compliant: true,
      } as any);

      const data = prisma.buildingPermitInspection.update.mock.calls[0][0].data;
      expect(data.inspector_user_id).toBe(USER);
      expect(data.status).toBe('completed');
    });
  });

  describe('expireLapsedPermits', () => {
    it('expires approved permits past their validity and audits each one', async () => {
      prisma.buildingPermit.findMany.mockResolvedValue([
        { id: 1, tenant_id: TENANT, org_unit_id: 5, permit_number: 'PERMIT-2026-0001' },
        { id: 2, tenant_id: TENANT, org_unit_id: 5, permit_number: 'PERMIT-2026-0002' },
      ]);
      prisma.buildingPermit.updateMany.mockResolvedValue({ count: 2 });

      const result = await service.expireLapsedPermits();

      expect(result).toEqual({ expired: 2 });
      expect(prisma.buildingPermit.updateMany).toHaveBeenCalledWith({
        where: { id: { in: [1, 2] } },
        data: { status: 'EXPIRED' },
      });
      expect(audit.log).toHaveBeenCalledTimes(2);
    });

    it('does nothing when no permit has lapsed', async () => {
      prisma.buildingPermit.findMany.mockResolvedValue([]);

      const result = await service.expireLapsedPermits();

      expect(result).toEqual({ expired: 0 });
      expect(prisma.buildingPermit.updateMany).not.toHaveBeenCalled();
    });
  });
});
