import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Seeding Phase 3 SLA Policies & Trackers...');

  const tenantId = 'default';

  // 1. Create a default working calendar if not exists
  const calendar = await prisma.workingCalendar.upsert({
    where: { id: 1 },
    update: {},
    create: {
      tenant_id: tenantId,
      branch_id: null,
      name: 'TN Standard Office Calendar',
      working_days: [1, 2, 3, 4, 5, 6], // Mon-Sat
      working_hours_start: '09:30',
      working_hours_end: '17:45',
      is_default: true,
    },
  });
  console.log(`✅ Verified working calendar: ${calendar.name}`);

  // 2. Create SLA Policy for Critical Complaints
  let policy = await prisma.slaPolicy.findFirst({
    where: {
      tenant_id: tenantId,
      branch_id: null,
      entity_type: 'complaint',
      category: 'electric_pole',
      urgency_level: 'critical',
    },
  });

  if (!policy) {
    policy = await prisma.slaPolicy.create({
      data: {
        tenant_id: tenantId,
        branch_id: null,
        entity_type: 'complaint',
        category: 'electric_pole',
        urgency_level: 'critical',
        target_hours: 4,
        warning_hours: 2,
        escalation_hours: 3,
        breach_hours: 4,
        escalation_role: 'panchayat_admin',
        is_24x7: false,
      },
    });
  }
  console.log(`✅ Verified SLA Policy for critical electric_pole complaints. Target: ${policy.target_hours} business hours.`);

  // 3. Create a mock complaint and associate an SlaTracker
  const branch = await prisma.panchayat.findFirst({
    where: { tenant_id: tenantId, name: 'Thayanur Village Panchayat' },
  });

  if (!branch) {
    console.error('❌ Thayanur Village Panchayat not found.');
    return;
  }

  let pole = await prisma.electricPole.findFirst({
    where: { panchayat_id: branch.id },
  });

  if (!pole) {
    pole = await prisma.electricPole.create({
      data: {
        panchayat_id: branch.id,
        pole_number: 'TYR-PL-042',
        keypad_id: '123456',
        landmarks: ['Thayanur Corner Shop'],
      },
    });
    console.log(`✅ Created dynamic Electric Pole ${pole.pole_number} for Thayanur Village.`);
  }

  const complaint = await prisma.complaint.create({
    data: {
      panchayat_id: branch.id,
      pole_id: pole.id,
      complaint_type: 'electric_pole',
      description: 'Streetlight short circuit sparking.',
      urgency_level: 'critical',
      status: 'pending',
    },
  });
  console.log(`✅ Created Mock Complaint #${complaint.id} to track.`);

  // 4. Create SlaTracker manually since we aren't calling service directly in script
  const start = new Date();
  // Simulate SLA calculation (just add flat hours for seed reference, or compute)
  const target = new Date(start.getTime() + 4 * 60 * 60 * 1000);
  const warning = new Date(start.getTime() + 2 * 60 * 60 * 1000);
  const escalation = new Date(start.getTime() + 3 * 60 * 60 * 1000);
  const breach = new Date(start.getTime() + 4 * 60 * 60 * 1000);

  const tracker = await prisma.slaTracker.create({
    data: {
      tenant_id: tenantId,
      entity_type: 'complaint',
      entity_id: complaint.id,
      sla_policy_id: policy.id,
      started_at: start,
      target_at: target,
      warning_at: warning,
      escalation_at: escalation,
      breach_at: breach,
      status: 'on_track',
    },
  });

  console.log(`✅ Seeded SLA Tracker for Complaint #${complaint.id}. Warning at: ${tracker.warning_at.toISOString()}, Target at: ${tracker.target_at.toISOString()}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
