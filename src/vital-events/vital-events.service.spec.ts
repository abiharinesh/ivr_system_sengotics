import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { VitalEventsService } from './vital-events.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../core/audit/audit.service';
import { DocumentService } from '../core/document/document.service';
import { NumberGenService } from '../core/number-gen/number-gen.service';
import { SlaService } from '../core/sla/sla.service';
import { WorkflowService } from '../core/workflow/workflow.service';

const TENANT = 'tenant-a';
const USER = 11;
const ORG = 5;

const daysAgo = (n: number) =>
  new Date(Date.now() - n * 24 * 60 * 60 * 1000);

const birthDto = (overrides: Record<string, any> = {}) => ({
  event_type: 'BIRTH' as const,
  event_date: daysAgo(3).toISOString(),
  place_type: 'hospital',
  place_name: 'GH Coimbatore',
  informant_name: 'R. Kumar',
  informant_relation: 'father',
  birth: { sex: 'male', mother_name: 'S. Lakshmi' },
  ...overrides,
});

const eventRow = (overrides: Record<string, any> = {}) => ({
  id: 1,
  tenant_id: TENANT,
  org_unit_id: ORG,
  event_type: 'BIRTH',
  status: 'REPORTED',
  registration_number: null,
  event_date: daysAgo(5),
  reported_at: daysAgo(3),
  place_type: 'hospital',
  place_name: 'GH Coimbatore',
  informant_name: 'R. Kumar',
  informant_relation: 'father',
  is_late_registration: false,
  delay_days: 2,
  delay_approval_ref: null,
  birth: { id: 1, sex: 'male', mother_name: 'S. Lakshmi', child_name: 'Arun' },
  death: null,
  certificates: [],
  org_unit: { id: ORG, name: 'Coimbatore Corporation' },
  ...overrides,
});

describe('VitalEventsService', () => {
  let service: VitalEventsService;

  const prisma = {
    vitalEvent: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
      groupBy: jest.fn(),
    },
    vitalCertificate: {
      create: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
      findUnique: jest.fn(),
      count: jest.fn(),
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
        VitalEventsService,
        { provide: PrismaService, useValue: prisma },
        { provide: NumberGenService, useValue: numbers },
        { provide: WorkflowService, useValue: workflow },
        { provide: SlaService, useValue: sla },
        { provide: AuditService, useValue: audit },
        { provide: DocumentService, useValue: documents },
      ],
    }).compile();

    service = module.get(VitalEventsService);
    jest.clearAllMocks();

    prisma.orgUnit.findFirst.mockResolvedValue({ id: ORG });
    prisma.vitalEvent.create.mockImplementation(({ data }) =>
      Promise.resolve(eventRow({ ...data, id: 1 })),
    );
    prisma.vitalEvent.update.mockImplementation(({ data }) =>
      Promise.resolve(eventRow(data)),
    );
    prisma.slaTracker.updateMany.mockResolvedValue({ count: 1 });
    sla.startTracker.mockResolvedValue({ id: 1 });
    audit.log.mockResolvedValue(undefined);
    audit.getEntityHistory.mockResolvedValue([]);
    documents.getForEntity.mockResolvedValue([]);
    workflow.getTimeline.mockResolvedValue(null);
  });

  describe('reportEvent', () => {
    it('records a prompt report as not late and starts the SLA clock', async () => {
      await service.reportEvent(TENANT, ORG, USER, birthDto() as any);

      const data = prisma.vitalEvent.create.mock.calls[0][0].data;
      expect(data.status).toBe('REPORTED');
      expect(data.is_late_registration).toBe(false);
      expect(data.delay_days).toBe(3);
      expect(sla.startTracker).toHaveBeenCalledWith(
        TENANT,
        ORG,
        'vital_event',
        1,
        'birth',
        'medium',
      );
    });

    it('flags a report past the 21-day window and raises its urgency', async () => {
      await service.reportEvent(
        TENANT,
        ORG,
        USER,
        birthDto({ event_date: daysAgo(40).toISOString() }) as any,
      );

      const data = prisma.vitalEvent.create.mock.calls[0][0].data;
      expect(data.is_late_registration).toBe(true);
      expect(data.delay_days).toBe(40);
      expect(sla.startTracker).toHaveBeenCalledWith(
        TENANT,
        ORG,
        'vital_event',
        1,
        'birth',
        'high',
      );
    });

    it('refuses an event dated in the future', async () => {
      const tomorrow = new Date(Date.now() + 86_400_000).toISOString();
      await expect(
        service.reportEvent(
          TENANT,
          ORG,
          USER,
          birthDto({ event_date: tomorrow }) as any,
        ),
      ).rejects.toThrow(/future/);
      expect(prisma.vitalEvent.create).not.toHaveBeenCalled();
    });

    it('masks the informant and parents\' Aadhaar numbers', async () => {
      await service.reportEvent(
        TENANT,
        ORG,
        USER,
        birthDto({
          informant_aadhaar: '123456789012',
          birth: {
            sex: 'male',
            mother_name: 'S. Lakshmi',
            mother_aadhaar: '210987654321',
          },
        }) as any,
      );

      const data = prisma.vitalEvent.create.mock.calls[0][0].data;
      expect(data.informant_aadhaar).toBe('XXXXXXXX9012');
      expect(data.birth.create.mother_aadhaar).toBe('XXXXXXXX4321');
      expect(JSON.stringify(data)).not.toContain('123456789012');
      expect(JSON.stringify(data)).not.toContain('210987654321');
    });

    it('requires Form 1 particulars for a birth', async () => {
      const dto = birthDto();
      delete (dto as any).birth;
      await expect(
        service.reportEvent(TENANT, ORG, USER, dto as any),
      ).rejects.toThrow(/Form 1/);
    });

    it('requires Form 2 particulars for a death', async () => {
      await expect(
        service.reportEvent(TENANT, ORG, USER, {
          ...birthDto(),
          event_type: 'DEATH',
          birth: undefined,
        } as any),
      ).rejects.toThrow(/Form 2/);
    });

    it('refuses an org unit belonging to another tenant', async () => {
      prisma.orgUnit.findFirst.mockResolvedValue(null);
      await expect(
        service.reportEvent(TENANT, 999, USER, birthDto() as any),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('hospitalFeed', () => {
    it('accepts the good records and reports the bad ones without losing the batch', async () => {
      const result = await service.hospitalFeed(TENANT, ORG, USER, {
        hospital_name: 'GH Coimbatore',
        events: [
          birthDto(),
          birthDto({ event_date: new Date(Date.now() + 86_400_000).toISOString() }),
          birthDto(),
        ],
      } as any);

      expect(result.submitted).toBe(3);
      expect(result.accepted).toBe(2);
      expect(result.rejected).toBe(1);
      expect(result.failures[0].index).toBe(1);
      expect(result.failures[0].reason).toMatch(/future/);
    });

    it('stamps every accepted record as hospital-sourced', async () => {
      await service.hospitalFeed(TENANT, ORG, USER, {
        hospital_name: 'GH Coimbatore',
        hospital_reg_no: 'TN/CBE/0091',
        events: [birthDto()],
      } as any);

      const data = prisma.vitalEvent.create.mock.calls[0][0].data;
      expect(data.reporting_source).toBe('HOSPITAL');
      expect(data.hospital_name).toBe('GH Coimbatore');
      expect(data.hospital_reg_no).toBe('TN/CBE/0091');
    });
  });

  describe('verifyEntry', () => {
    it('starts an approval chain only for a late entry', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(eventRow());
      await service.verifyEntry(TENANT, 1, USER);
      expect(workflow.startWorkflow).not.toHaveBeenCalled();

      jest.clearAllMocks();
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({ is_late_registration: true, delay_days: 45 }),
      );
      prisma.vitalEvent.update.mockResolvedValue(eventRow({ status: 'VERIFIED' }));
      workflow.startWorkflow.mockResolvedValue({ id: 9 });

      await service.verifyEntry(TENANT, 1, USER);
      expect(workflow.startWorkflow).toHaveBeenCalledWith(
        TENANT,
        ORG,
        'vital_event_registration',
        'vital_event',
        1,
      );
    });

    it('refuses to verify an already-registered entry', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({ status: 'REGISTERED' }),
      );
      await expect(service.verifyEntry(TENANT, 1, USER)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('register', () => {
    it('allots a serial from the birth register sequence and closes the SLA', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({ status: 'VERIFIED' }),
      );
      numbers.next.mockResolvedValue('B/2026/000042');

      await service.register(TENANT, 1, USER, {} as any);

      expect(numbers.next).toHaveBeenCalledWith(TENANT, 'birth_registration', ORG);
      const data = prisma.vitalEvent.update.mock.calls[0][0].data;
      expect(data.status).toBe('REGISTERED');
      expect(data.registration_number).toBe('B/2026/000042');
      expect(data.registered_by).toBe(USER);
      expect(prisma.slaTracker.updateMany).toHaveBeenCalled();
    });

    it('uses the death register sequence for a death', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({
          status: 'VERIFIED',
          event_type: 'DEATH',
          birth: null,
          death: { id: 1, deceased_name: 'M. Raja', sex: 'male' },
        }),
      );
      numbers.next.mockResolvedValue('D/2026/000007');

      await service.register(TENANT, 1, USER, {} as any);

      expect(numbers.next).toHaveBeenCalledWith(TENANT, 'death_registration', ORG);
    });

    it('blocks registration past thirty days without an authorising reference', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({
          status: 'VERIFIED',
          event_date: daysAgo(90),
          reported_at: new Date(),
          is_late_registration: true,
        }),
      );

      await expect(service.register(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /written permission/i,
      );
      expect(prisma.vitalEvent.update).not.toHaveBeenCalled();
    });

    it('demands a magistrate\'s order beyond a year', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({
          status: 'VERIFIED',
          event_date: daysAgo(400),
          reported_at: new Date(),
          is_late_registration: true,
        }),
      );

      await expect(service.register(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /magistrate/i,
      );
    });

    it('proceeds once the authorising reference is supplied', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({
          status: 'VERIFIED',
          event_date: daysAgo(90),
          reported_at: new Date(),
          is_late_registration: true,
        }),
      );
      numbers.next.mockResolvedValue('B/2026/000043');

      await service.register(TENANT, 1, USER, {
        delay_approval_ref: 'DR/CBE/2026/118',
      } as any);

      const data = prisma.vitalEvent.update.mock.calls[0][0].data;
      expect(data.status).toBe('REGISTERED');
      expect(data.delay_approval_ref).toBe('DR/CBE/2026/118');
    });

    it('refuses when the particulars are missing', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({ status: 'VERIFIED', birth: null }),
      );
      await expect(service.register(TENANT, 1, USER, {} as any)).rejects.toThrow(
        /Form 1/,
      );
    });

    it('cannot register straight from REPORTED', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(eventRow());
      await expect(service.register(TENANT, 1, USER, {} as any)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('does not leak an entry from another tenant', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(null);
      await expect(service.register(TENANT, 1, USER, {} as any)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('correct', () => {
    it('cancels certificates issued against the superseded particulars', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({
          status: 'REGISTERED',
          registration_number: 'B/2026/000042',
          certificates: [
            { id: 1, is_cancelled: false, copy_number: 1, certificate_number: 'VC-1' },
            { id: 2, is_cancelled: true, copy_number: 2, certificate_number: 'VC-2' },
          ],
        }),
      );
      prisma.vitalCertificate.updateMany.mockResolvedValue({ count: 1 });

      const result = await service.correct(TENANT, 1, USER, {
        correction_note: 'Child name spelling corrected per affidavit',
        birth: { sex: 'male', mother_name: 'S. Lakshmi', child_name: 'Arjun' },
      } as any);

      expect(result.cancelled_certificates).toBe(1);
      // Only the live certificate is touched.
      expect(prisma.vitalCertificate.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: { in: [1] } } }),
      );
    });

    it('keeps the pre-correction values in the audit trail', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({ status: 'REGISTERED', certificates: [] }),
      );

      await service.correct(TENANT, 1, USER, {
        correction_note: 'Child name spelling corrected per affidavit',
        birth: { sex: 'male', mother_name: 'S. Lakshmi', child_name: 'Arjun' },
      } as any);

      const entry = audit.log.mock.calls.find((c) => c[0].action === 'correct')[0];
      expect(entry.beforeValue.birth.child_name).toBe('Arun');
      expect(entry.changedFields).toBeDefined();
    });

    it('refuses particulars for the wrong event type', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({ status: 'REGISTERED' }),
      );
      await expect(
        service.correct(TENANT, 1, USER, {
          correction_note: 'Wrong form submitted entirely',
          death: { deceased_name: 'X', sex: 'male' },
        } as any),
      ).rejects.toThrow(/Death particulars sent for a birth/);
    });

    it('refuses a correction that changes nothing', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({ status: 'REGISTERED' }),
      );
      await expect(
        service.correct(TENANT, 1, USER, {
          correction_note: 'No particulars supplied here',
        } as any),
      ).rejects.toThrow(/must change some particular/);
    });

    it('cannot correct an entry that was never registered', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(eventRow());
      await expect(
        service.correct(TENANT, 1, USER, {
          correction_note: 'Attempting a premature correction',
          birth: { sex: 'male', mother_name: 'S. Lakshmi' },
        } as any),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('issueCertificate', () => {
    const registered = (certificates: any[] = []) =>
      eventRow({
        status: 'REGISTERED',
        registration_number: 'B/2026/000042',
        certificates,
      });

    it('issues copy 1 with a random verification token and a seal hash', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(registered());
      numbers.next.mockResolvedValue('VC-2026-000001');
      prisma.vitalCertificate.create.mockImplementation(({ data }) =>
        Promise.resolve({ id: 1, ...data }),
      );

      const cert = await service.issueCertificate(TENANT, 1, USER, {
        issued_to: 'R. Kumar',
      } as any);

      const data = prisma.vitalCertificate.create.mock.calls[0][0].data;
      expect(data.copy_number).toBe(1);
      expect(data.certificate_number).toBe('VC-2026-000001');
      expect(data.verification_token).toHaveLength(32);
      expect(data.verification_token).not.toContain('VC-2026');
      expect(data.seal_hash).toMatch(/^[a-f0-9]{64}$/);
      expect(cert.id).toBe(1);
    });

    it('numbers each reissue as the next copy', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        registered([
          { id: 1, copy_number: 1, is_cancelled: false },
          { id: 2, copy_number: 2, is_cancelled: true },
        ]),
      );
      numbers.next.mockResolvedValue('VC-2026-000003');
      prisma.vitalCertificate.create.mockImplementation(({ data }) =>
        Promise.resolve({ id: 3, ...data }),
      );

      await service.issueCertificate(TENANT, 1, USER, {
        issued_to: 'S. Lakshmi',
      } as any);

      // Cancelled copies still consume a copy number — the register has to
      // show that three documents were produced.
      expect(prisma.vitalCertificate.create.mock.calls[0][0].data.copy_number).toBe(3);
    });

    it('gives two certificates different tokens', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(registered());
      numbers.next.mockResolvedValue('VC-2026-000001');
      prisma.vitalCertificate.create.mockImplementation(({ data }) =>
        Promise.resolve({ id: 1, ...data }),
      );

      await service.issueCertificate(TENANT, 1, USER, { issued_to: 'A' } as any);
      await service.issueCertificate(TENANT, 1, USER, { issued_to: 'B' } as any);

      const [first, second] = prisma.vitalCertificate.create.mock.calls;
      expect(first[0].data.verification_token).not.toBe(
        second[0].data.verification_token,
      );
    });

    it('refuses to issue against an unregistered entry', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(eventRow());
      await expect(
        service.issueCertificate(TENANT, 1, USER, { issued_to: 'X' } as any),
      ).rejects.toThrow(/only be issued against a registered entry/);
    });

    it('issues against a corrected entry', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({
          status: 'CORRECTED',
          registration_number: 'B/2026/000042',
        }),
      );
      numbers.next.mockResolvedValue('VC-2026-000004');
      prisma.vitalCertificate.create.mockImplementation(({ data }) =>
        Promise.resolve({ id: 4, ...data }),
      );

      await expect(
        service.issueCertificate(TENANT, 1, USER, { issued_to: 'X' } as any),
      ).resolves.toBeDefined();
    });
  });

  describe('cancelCertificate', () => {
    it('will not cancel the same certificate twice', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({
          certificates: [{ id: 1, is_cancelled: true, certificate_number: 'VC-1' }],
        }),
      );
      await expect(
        service.cancelCertificate(TENANT, 1, 1, USER, {
          reason: 'Duplicate cancellation attempt',
        } as any),
      ).rejects.toThrow(/already cancelled/);
    });

    it('404s for a certificate on another entry', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(eventRow());
      await expect(
        service.cancelCertificate(TENANT, 1, 99, USER, {
          reason: 'Certificate not on this entry',
        } as any),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('verifyByToken', () => {
    const certRow = (overrides: Record<string, any> = {}) => ({
      certificate_number: 'VC-2026-000001',
      copy_number: 1,
      issued_at: new Date('2026-05-01'),
      seal_hash: 'abc123',
      is_cancelled: false,
      cancelled_reason: null,
      event: {
        event_type: 'BIRTH',
        registration_number: 'B/2026/000042',
        registered_at: new Date('2026-04-01'),
        event_date: new Date('2026-03-20'),
        place_name: 'GH Coimbatore',
        informant_name: 'R. Kumar',
        informant_phone: '9876543210',
        informant_aadhaar: 'XXXXXXXX9012',
        org_unit: { name: 'Coimbatore Corporation' },
        birth: {
          child_name: 'Arun',
          sex: 'male',
          mother_name: 'S. Lakshmi',
          father_name: 'R. Kumar',
        },
        death: null,
      },
      ...overrides,
    });

    it('confirms a genuine certificate', async () => {
      prisma.vitalCertificate.findUnique.mockResolvedValue(certRow());

      const result = await service.verifyByToken('tok');

      expect(result.valid).toBe(true);
      expect(result.registration_number).toBe('B/2026/000042');
      expect(result.subject_name).toBe('Arun');
      expect(result.issuing_authority).toBe('Coimbatore Corporation');
    });

    it('withholds the informant\'s contact details and Aadhaar', async () => {
      prisma.vitalCertificate.findUnique.mockResolvedValue(certRow());

      const result = await service.verifyByToken('tok');
      const serialized = JSON.stringify(result);

      expect(serialized).not.toContain('9876543210');
      expect(serialized).not.toContain('XXXXXXXX9012');
      expect(result).not.toHaveProperty('informant_name');
    });

    it('reports a cancelled certificate as invalid, with the reason', async () => {
      prisma.vitalCertificate.findUnique.mockResolvedValue(
        certRow({ is_cancelled: true, cancelled_reason: 'Superseded by a correction' }),
      );

      const result = await service.verifyByToken('tok');

      expect(result.valid).toBe(false);
      expect(result.cancelled_reason).toMatch(/Superseded/);
    });

    it('404s on an unknown token without hinting at what would work', async () => {
      prisma.vitalCertificate.findUnique.mockResolvedValue(null);
      await expect(service.verifyByToken('nope')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('handles a death certificate with no birth record attached', async () => {
      prisma.vitalCertificate.findUnique.mockResolvedValue(
        certRow({
          event: {
            ...certRow().event,
            event_type: 'DEATH',
            birth: null,
            death: { deceased_name: 'M. Raja', sex: 'male' },
          },
        }),
      );

      const result = await service.verifyByToken('tok');

      expect(result.subject_name).toBe('M. Raja');
      expect(result).not.toHaveProperty('mother_name');
    });
  });

  describe('updateParticulars', () => {
    it('refuses to edit a registered entry outside the correction route', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(
        eventRow({ status: 'REGISTERED' }),
      );
      await expect(
        service.updateParticulars(TENANT, 1, USER, {
          informant_phone: '9000000001',
        } as any),
      ).rejects.toThrow(/correction under s.15/);
    });

    it('allows edits while the entry is still only reported', async () => {
      prisma.vitalEvent.findFirst.mockResolvedValue(eventRow());
      await expect(
        service.updateParticulars(TENANT, 1, USER, {
          informant_phone: '9000000001',
        } as any),
      ).resolves.toBeDefined();
    });
  });
});
