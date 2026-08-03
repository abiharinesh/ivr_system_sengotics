import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { TradeLicenceService } from './trade-licence.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { DocumentService } from '../core/document/document.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { SlaService } from '../core/sla/sla.service';
import { WorkflowService } from '../core/workflow/workflow.service';

const TENANT = 'tenant-a';
const USER = 31;
const ORG = 5;

const utc = (iso: string) => new Date(`${iso}T00:00:00.000Z`);

const licenceRow = (overrides: Record<string, any> = {}) => ({
  id: 1,
  tenant_id: TENANT,
  org_unit_id: ORG,
  licence_number: 'TL/2026-27/000001',
  status: 'DRAFT',
  trade_name: 'Sri Krishna Mess',
  trade_category: 'eatery',
  motive_power_hp: 3,
  area_sqft: 500,
  owner_name: 'R. Kumar',
  door_number: '12A',
  street_name: 'Anna Nagar',
  ward_number: '7',
  licence_year: '2026-27',
  valid_from: null,
  valid_until: null,
  base_fee: 2000,
  area_fee: 2000,
  power_fee: 300,
  penalty_fee: 0,
  total_fee: 4300,
  paid_amount: 0,
  payment_status: 'unpaid',
  payment_ref: null,
  fssai_expiry: null,
  fire_noc_expiry: null,
  pollution_consent_expiry: null,
  renewals: [],
  inspections: [],
  certificates: [],
  org_unit: { id: ORG, name: 'Coimbatore Corporation' },
  ...overrides,
});

const compliantInspection = () => ({
  id: 1,
  status: 'completed',
  is_compliant: true,
  inspector_user_id: 9,
});

/**
 * Turn a Prisma write payload into the row Prisma would return.
 *
 * The service uses nested relation writes (`renewals: { create: {...} }`).
 * Spreading that raw over a row would replace the `renewals` array with a
 * `{ create: ... }` object, which the real client never does — it returns the
 * included relation as an array. Emulating that here keeps the assertions
 * about the write payload while letting the service's serializer run.
 */
const asReturnedRow = (data: Record<string, any>) => {
  const { renewals, inspections, certificates, ...scalars } = data;
  const unwrap = (rel: any) => {
    if (!rel) return undefined;
    if (Array.isArray(rel)) return rel;
    if (rel.create) {
      return Array.isArray(rel.create)
        ? rel.create.map((r: any, i: number) => ({ id: i + 1, ...r }))
        : [{ id: 1, ...rel.create }];
    }
    return undefined;
  };

  return {
    ...scalars,
    ...(unwrap(renewals) && { renewals: unwrap(renewals) }),
    ...(unwrap(inspections) && { inspections: unwrap(inspections) }),
    ...(unwrap(certificates) && { certificates: unwrap(certificates) }),
  };
};

describe('TradeLicenceService', () => {
  let service: TradeLicenceService;

  const prisma = {
    tradeLicence: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
      count: jest.fn(),
      groupBy: jest.fn(),
    },
    tradeLicenceRenewal: { updateMany: jest.fn(), aggregate: jest.fn() },
    tradeLicenceInspection: { create: jest.fn(), update: jest.fn() },
    tradeLicenceCertificate: {
      create: jest.fn(),
      updateMany: jest.fn(),
      findUnique: jest.fn(),
    },
    orgUnit: { findFirst: jest.fn() },
    slaTracker: { updateMany: jest.fn() },
  };

  const numbers = { next: jest.fn() };
  const workflow = { startWorkflow: jest.fn(), getTimeline: jest.fn() };
  const sla = { startTracker: jest.fn() };
  const audit = { log: jest.fn(), getEntityHistory: jest.fn() };
  const documents = { getForEntity: jest.fn() };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TradeLicenceService,
        { provide: PrismaService, useValue: prisma },
        { provide: NumberGenService, useValue: numbers },
        { provide: WorkflowService, useValue: workflow },
        { provide: SlaService, useValue: sla },
        { provide: AuditService, useValue: audit },
        { provide: DocumentService, useValue: documents },
      ],
    }).compile();

    service = module.get(TradeLicenceService);
    jest.clearAllMocks();

    prisma.orgUnit.findFirst.mockResolvedValue({ id: ORG });
    numbers.next.mockResolvedValue('TL/2026-27/000001');
    prisma.tradeLicence.create.mockImplementation(({ data }) =>
      Promise.resolve(licenceRow(asReturnedRow(data))),
    );
    prisma.tradeLicence.update.mockImplementation(({ data }) =>
      Promise.resolve(licenceRow(asReturnedRow(data))),
    );
    prisma.tradeLicenceRenewal.updateMany.mockResolvedValue({ count: 1 });
    prisma.slaTracker.updateMany.mockResolvedValue({ count: 1 });
    audit.log.mockResolvedValue(undefined);
    audit.getEntityHistory.mockResolvedValue([]);
    documents.getForEntity.mockResolvedValue([]);
    workflow.getTimeline.mockResolvedValue(null);
    sla.startTracker.mockResolvedValue({ id: 1 });
  });

  describe('create', () => {
    it('allots a licence number and pro-rates the first year', async () => {
      await service.create(TENANT, ORG, USER, {
        trade_name: 'Sri Krishna Mess',
        trade_category: 'eatery',
        owner_name: 'R. Kumar',
        area_sqft: 500,
        motive_power_hp: 3,
      } as any);

      expect(numbers.next).toHaveBeenCalledWith(TENANT, 'trade_licence', ORG);
      const data = prisma.tradeLicence.create.mock.calls[0][0].data;
      expect(data.status).toBe('DRAFT');
      expect(data.licence_year).toMatch(/^\d{4}-\d{2}$/);
      // Whatever quarter we are in, the charge is at most the annual figure.
      expect(data.total_fee).toBeLessThanOrEqual(4300);
      expect(data.total_fee).toBeGreaterThan(0);
    });

    it('masks the owner Aadhaar', async () => {
      await service.create(TENANT, ORG, USER, {
        trade_name: 'X',
        trade_category: 'eatery',
        owner_name: 'R. Kumar',
        area_sqft: 100,
        owner_aadhaar: '123456789012',
      } as any);

      const data = prisma.tradeLicence.create.mock.calls[0][0].data;
      expect(data.owner_aadhaar).toBe('XXXXXXXX9012');
      expect(JSON.stringify(data)).not.toContain('123456789012');
    });

    it('refuses an org unit from another tenant', async () => {
      prisma.orgUnit.findFirst.mockResolvedValue(null);

      await expect(
        service.create(TENANT, 999, USER, {
          trade_name: 'X',
          trade_category: 'eatery',
          owner_name: 'R. Kumar',
          area_sqft: 100,
        } as any),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('submit', () => {
    it('starts the approval chain and the decision SLA', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(licenceRow());
      workflow.startWorkflow.mockResolvedValue({ id: 42 });

      await service.submit(TENANT, 1, USER);

      expect(workflow.startWorkflow).toHaveBeenCalledWith(
        TENANT,
        ORG,
        'trade_licence_approval',
        'trade_licence',
        1,
      );
      expect(sla.startTracker).toHaveBeenCalled();
      expect(prisma.tradeLicence.update.mock.calls[0][0].data.status).toBe(
        'SUBMITTED',
      );
    });

    it('refuses to submit an already-granted licence', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({ status: 'APPROVED' }),
      );

      await expect(service.submit(TENANT, 1, USER)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('approve', () => {
    const ready = (overrides: Record<string, any> = {}) =>
      licenceRow({
        status: 'INSPECTION',
        paid_amount: 4300,
        payment_status: 'paid',
        inspections: [compliantInspection()],
        ...overrides,
      });

    it('grants for the financial year and opens the renewal chain', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(ready());

      await service.approve(TENANT, 1, USER, {} as any);

      const data = prisma.tradeLicence.update.mock.calls[0][0].data;
      expect(data.status).toBe('APPROVED');
      // 31 March closes the licence year whatever the grant date.
      expect(data.valid_until.toISOString().slice(5, 10)).toBe('03-31');
      expect(data.renewals.create.is_initial_grant).toBe(true);
      expect(data.renewals.create.penalty_band).toBe('ontime');
    });

    it('refuses while fees are outstanding', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        ready({ paid_amount: 1000, payment_status: 'partial' }),
      );

      await expect(service.approve(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /fees unpaid/,
      );
      expect(prisma.tradeLicence.update).not.toHaveBeenCalled();
    });

    it('refuses a food trade with no compliant inspection', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        ready({ inspections: [] }),
      );

      await expect(service.approve(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /compliant premises inspection/,
      );
    });

    it('does not demand an inspection for a low-risk category', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        ready({ trade_category: 'provision_store', inspections: [] }),
      );

      await expect(
        service.approve(TENANT, 1, USER, {} as any),
      ).resolves.toBeDefined();
    });

    it('refuses when a statutory reference has already lapsed', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        ready({ fire_noc_expiry: utc('2020-01-01') }),
      );

      await expect(service.approve(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /Fire NOC/,
      );
    });

    it('closes the decision SLA', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(ready());

      await service.approve(TENANT, 1, USER, {} as any);

      expect(prisma.slaTracker.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'resolved' }),
        }),
      );
    });
  });

  describe('renew', () => {
    const granted = (overrides: Record<string, any> = {}) =>
      licenceRow({
        status: 'APPROVED',
        licence_year: '2026-27',
        valid_until: utc('2027-03-31'),
        paid_amount: 4300,
        payment_status: 'paid',
        ...overrides,
      });

    it('rolls into the next year at the full annual fee', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(granted());
      jest.useFakeTimers().setSystemTime(utc('2027-03-20'));

      await service.renew(TENANT, 1, USER, {} as any);

      const data = prisma.tradeLicence.update.mock.calls[0][0].data;
      expect(data.licence_year).toBe('2027-28');
      expect(data.renewals.create.penalty_band).toBe('ontime');
      expect(data.renewals.create.penalty_fee).toBe(0);
      // A full year, not a pro-rated remainder.
      expect(data.total_fee).toBe(4300);

      jest.useRealTimers();
    });

    it('resets the payment state — a new year is a new demand', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(granted());
      jest.useFakeTimers().setSystemTime(utc('2027-03-20'));

      await service.renew(TENANT, 1, USER, {} as any);

      const data = prisma.tradeLicence.update.mock.calls[0][0].data;
      expect(data.paid_amount).toBe(0);
      expect(data.payment_status).toBe('unpaid');
      expect(data.payment_ref).toBeNull();

      jest.useRealTimers();
    });

    it('charges a penalty on a late renewal', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(granted());
      jest.useFakeTimers().setSystemTime(utc('2027-04-20')); // 20 days late

      await service.renew(TENANT, 1, USER, {} as any);

      const data = prisma.tradeLicence.update.mock.calls[0][0].data;
      expect(data.renewals.create.penalty_band).toBe('late_30');
      expect(data.renewals.create.days_late).toBe(20);
      expect(data.penalty_fee).toBeGreaterThan(0);

      jest.useRealTimers();
    });

    it('escalates the penalty band past the grace window', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(granted());
      jest.useFakeTimers().setSystemTime(utc('2027-06-01')); // ~62 days late

      await service.renew(TENANT, 1, USER, {} as any);

      expect(
        prisma.tradeLicence.update.mock.calls[0][0].data.renewals.create
          .penalty_band,
      ).toBe('late_90');

      jest.useRealTimers();
    });

    it('refuses a renewal once the licence has lapsed beyond recovery', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(granted());
      jest.useFakeTimers().setSystemTime(utc('2027-09-01')); // >90 days

      await expect(service.renew(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /fresh application/i,
      );
      expect(prisma.tradeLicence.update).not.toHaveBeenCalled();

      jest.useRealTimers();
    });

    it('renews an expired licence that is still inside the window', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        granted({ status: 'EXPIRED' }),
      );
      jest.useFakeTimers().setSystemTime(utc('2027-04-10'));

      await expect(
        service.renew(TENANT, 1, USER, {} as any),
      ).resolves.toBeDefined();

      jest.useRealTimers();
    });

    it('refuses a second renewal into the same year', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        granted({
          renewals: [{ id: 2, licence_year: '2027-28' }],
        }),
      );
      jest.useFakeTimers().setSystemTime(utc('2027-03-20'));

      await expect(service.renew(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /already renewed for 2027-28/,
      );

      jest.useRealTimers();
    });

    it('refuses to renew a cancelled licence', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        granted({ status: 'CANCELLED' }),
      );

      await expect(service.renew(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /Only a granted licence can be renewed/,
      );
    });
  });

  describe('recordPayment', () => {
    it('marks paid and keeps the renewal row in step', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(licenceRow());

      await service.recordPayment(TENANT, 1, USER, {
        amount: 4300,
        payment_ref: 'RCPT-1',
      } as any);

      const data = prisma.tradeLicence.update.mock.calls[0][0].data;
      expect(data.payment_status).toBe('paid');
      expect(prisma.tradeLicenceRenewal.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { licence_id: 1, licence_year: '2026-27' },
        }),
      );
    });

    it('refuses an overpayment', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({ paid_amount: 4000 }),
      );

      await expect(
        service.recordPayment(TENANT, 1, USER, { amount: 500 } as any),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('suspend / restore / cancel', () => {
    it('suspends a live licence', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({ status: 'APPROVED' }),
      );

      await service.suspend(TENANT, 1, USER, {
        reason: 'Repeated hygiene violations at inspection',
      } as any);

      expect(prisma.tradeLicence.update.mock.calls[0][0].data.status).toBe(
        'SUSPENDED',
      );
    });

    it('restores a suspension into service when the year is still current', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({
          status: 'SUSPENDED',
          valid_until: new Date(Date.now() + 30 * 86_400_000),
        }),
      );

      await service.restore(TENANT, 1, USER);

      expect(prisma.tradeLicence.update.mock.calls[0][0].data.status).toBe(
        'APPROVED',
      );
    });

    it('restores to EXPIRED when the licence year has already run out', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({ status: 'SUSPENDED', valid_until: utc('2020-03-31') }),
      );

      await service.restore(TENANT, 1, USER);

      // Lifting a suspension does not extend the licence year.
      expect(prisma.tradeLicence.update.mock.calls[0][0].data.status).toBe(
        'EXPIRED',
      );
    });

    it('cancels outstanding certificates so none stays valid in a shop window', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({
          status: 'APPROVED',
          certificates: [
            { id: 1, is_cancelled: false },
            { id: 2, is_cancelled: true },
          ],
        }),
      );
      prisma.tradeLicenceCertificate.updateMany.mockResolvedValue({ count: 1 });

      const result = await service.cancel(TENANT, 1, USER, {
        reason: 'Premises permanently closed by the owner',
      } as any);

      expect(result.cancelled_certificates).toBe(1);
      expect(prisma.tradeLicenceCertificate.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: { in: [1] } } }),
      );
    });
  });

  describe('issueCertificate', () => {
    it('issues with a random token and a seal hash', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({ status: 'APPROVED' }),
      );
      numbers.next.mockResolvedValue('TLC-2026-27-000001');
      prisma.tradeLicenceCertificate.create.mockImplementation(({ data }) =>
        Promise.resolve({ id: 1, ...data }),
      );

      await service.issueCertificate(TENANT, 1, USER, {} as any);

      const data = prisma.tradeLicenceCertificate.create.mock.calls[0][0].data;
      expect(data.copy_number).toBe(1);
      expect(data.verification_token).toHaveLength(32);
      expect(data.seal_hash).toMatch(/^[a-f0-9]{64}$/);
    });

    it('numbers copies within the licence year, not across years', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({
          status: 'APPROVED',
          licence_year: '2027-28',
          certificates: [
            { id: 1, licence_year: '2026-27', copy_number: 1 },
            { id: 2, licence_year: '2026-27', copy_number: 2 },
          ],
        }),
      );
      prisma.tradeLicenceCertificate.create.mockImplementation(({ data }) =>
        Promise.resolve({ id: 3, ...data }),
      );

      await service.issueCertificate(TENANT, 1, USER, {} as any);

      // A fresh year starts its copy numbering again.
      expect(
        prisma.tradeLicenceCertificate.create.mock.calls[0][0].data.copy_number,
      ).toBe(1);
    });

    it('refuses to issue against a licence that is not granted', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({ status: 'SUBMITTED' }),
      );

      await expect(
        service.issueCertificate(TENANT, 1, USER, {} as any),
      ).rejects.toThrow(/only be issued against a granted licence/);
    });
  });

  describe('verifyByToken', () => {
    const certRow = (overrides: Record<string, any> = {}) => ({
      certificate_number: 'TLC-2026-27-000001',
      licence_year: '2026-27',
      copy_number: 1,
      issued_at: utc('2026-05-01'),
      seal_hash: 'abc',
      is_cancelled: false,
      cancelled_reason: null,
      licence: {
        licence_number: 'TL/2026-27/000001',
        status: 'APPROVED',
        trade_name: 'Sri Krishna Mess',
        trade_category: 'eatery',
        owner_name: 'R. Kumar',
        owner_phone: '9876543210',
        owner_aadhaar: 'XXXXXXXX9012',
        total_fee: 4300,
        door_number: '12A',
        street_name: 'Anna Nagar',
        ward_number: '7',
        valid_from: utc('2026-04-01'),
        valid_until: new Date(Date.now() + 30 * 86_400_000),
        org_unit: { name: 'Coimbatore Corporation' },
      },
      ...overrides,
    });

    it('confirms a current licence', async () => {
      prisma.tradeLicenceCertificate.findUnique.mockResolvedValue(certRow());

      const result = await service.verifyByToken('tok');

      expect(result.valid).toBe(true);
      expect(result.lapsed).toBe(false);
      expect(result.trade_name).toBe('Sri Krishna Mess');
    });

    it('withholds the owner contact details, Aadhaar and fee history', async () => {
      prisma.tradeLicenceCertificate.findUnique.mockResolvedValue(certRow());

      const serialized = JSON.stringify(await service.verifyByToken('tok'));

      expect(serialized).not.toContain('9876543210');
      expect(serialized).not.toContain('XXXXXXXX9012');
      expect(serialized).not.toContain('4300');
    });

    it('separates a lapsed licence from a forged document', async () => {
      const row = certRow();
      row.licence.valid_until = utc('2020-03-31');
      row.licence.status = 'EXPIRED';
      prisma.tradeLicenceCertificate.findUnique.mockResolvedValue(row);

      const result = await service.verifyByToken('tok');

      expect(result.valid).toBe(false);
      expect(result.lapsed).toBe(true);
      expect(result.status).toBe('EXPIRED');
    });

    it('reports a cancelled certificate as invalid', async () => {
      prisma.tradeLicenceCertificate.findUnique.mockResolvedValue(
        certRow({ is_cancelled: true, cancelled_reason: 'Licence cancelled' }),
      );

      const result = await service.verifyByToken('tok');

      expect(result.valid).toBe(false);
      expect(result.cancelled_reason).toBe('Licence cancelled');
    });

    it('404s on an unknown token', async () => {
      prisma.tradeLicenceCertificate.findUnique.mockResolvedValue(null);

      await expect(service.verifyByToken('nope')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('expireLapsedLicences', () => {
    it('expires licences past their year and audits each one', async () => {
      prisma.tradeLicence.findMany.mockResolvedValue([
        {
          id: 1,
          tenant_id: TENANT,
          org_unit_id: ORG,
          licence_number: 'TL/2026-27/000001',
          licence_year: '2026-27',
        },
        {
          id: 2,
          tenant_id: TENANT,
          org_unit_id: ORG,
          licence_number: 'TL/2026-27/000002',
          licence_year: '2026-27',
        },
      ]);
      prisma.tradeLicence.updateMany.mockResolvedValue({ count: 2 });

      const result = await service.expireLapsedLicences();

      expect(result).toEqual({ expired: 2 });
      expect(prisma.tradeLicence.updateMany).toHaveBeenCalledWith({
        where: { id: { in: [1, 2] } },
        data: { status: 'EXPIRED' },
      });
      expect(audit.log).toHaveBeenCalledTimes(2);
    });

    it('does nothing when nothing has lapsed', async () => {
      prisma.tradeLicence.findMany.mockResolvedValue([]);

      expect(await service.expireLapsedLicences()).toEqual({ expired: 0 });
      expect(prisma.tradeLicence.updateMany).not.toHaveBeenCalled();
    });
  });

  describe('update', () => {
    it('refuses to edit a granted licence', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(
        licenceRow({ status: 'APPROVED' }),
      );

      await expect(
        service.update(TENANT, 1, USER, { trade_name: 'New name' } as any),
      ).rejects.toThrow(/cannot be edited/);
    });

    it('does not leak a licence from another tenant', async () => {
      prisma.tradeLicence.findFirst.mockResolvedValue(null);

      await expect(
        service.update(TENANT, 1, USER, { trade_name: 'X' } as any),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
