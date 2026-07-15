import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Seeding Phase 0 E-Governance Metadata...');

  // 1. Create default Tenant
  const tenantId = 'default';
  await prisma.tenant.upsert({
    where: { id: tenantId },
    update: {},
    create: {
      id: tenantId,
      name: 'Default Tenant',
      subscription: 'enterprise',
      is_active: true,
    },
  });
  console.log('✅ Default Tenant verified.');

  // 2. Seed Master Categories
  const categories = [
    { code: 'complaint_category', name: 'Complaint Category', name_ta: 'புகார் வகை' },
    { code: 'asset_type', name: 'Asset Type', name_ta: 'சொத்து வகை' },
    { code: 'department', name: 'Department', name_ta: 'துறை' },
    { code: 'urgency_level', name: 'Urgency Level', name_ta: 'அவசர நிலை' },
    { code: 'holiday_type', name: 'Holiday Type', name_ta: 'விடுமுறை வகை' },
  ];

  for (const cat of categories) {
    const category = await prisma.masterCategory.upsert({
      where: { tenant_id_code: { tenant_id: tenantId, code: cat.code } },
      update: { name: cat.name, name_ta: cat.name_ta },
      create: {
        tenant_id: tenantId,
        code: cat.code,
        name: cat.name,
        name_ta: cat.name_ta,
        is_system: true,
        is_active: true,
      },
    });

    // Seed values for each category
    if (cat.code === 'complaint_category') {
      const values = [
        { code: 'street_light', value: 'Street Light Issue', value_ta: 'தெரு விளக்கு பழுது', icon: 'lightbulb', color: '#EF4444' },
        { code: 'water_leakage', value: 'Water Leakage', value_ta: 'குடிநீர் கசிவு', icon: 'water', color: '#3B82F6' },
        { code: 'drainage_block', value: 'Drainage Block', value_ta: 'சாக்கடை அடைப்பு', icon: 'waves', color: '#F59E0B' },
        { code: 'road_pothole', value: 'Road Pothole', value_ta: 'சாலை குழி', icon: 'edit_road', color: '#10B981' },
      ];
      for (const val of values) {
        await prisma.masterValue.upsert({
          where: { category_id_code: { category_id: category.id, code: val.code } },
          update: { value: val.value, value_ta: val.value_ta, icon: val.icon, color: val.color },
          create: {
            category_id: category.id,
            code: val.code,
            value: val.value,
            value_ta: val.value_ta,
            icon: val.icon,
            color: val.color,
            is_system: true,
            is_active: true,
          },
        });
      }
    }

    if (cat.code === 'asset_type') {
      const values = [
        { code: 'electric_pole', value: 'Electric Pole', value_ta: 'மின் கம்பம்', icon: 'bolt' },
        { code: 'water_tank', value: 'Overhead Water Tank', value_ta: 'மேல்நிலை நீர் தொட்டி', icon: 'water_damage' },
        { code: 'borewell', value: 'Borewell Pump', value_ta: 'ஆழ்குழாய் கிணறு', icon: 'settings_input_component' },
        { code: 'road', value: 'Road', value_ta: 'சாலை', icon: 'add_road' },
      ];
      for (const val of values) {
        await prisma.masterValue.upsert({
          where: { category_id_code: { category_id: category.id, code: val.code } },
          update: { value: val.value, value_ta: val.value_ta, icon: val.icon },
          create: {
            category_id: category.id,
            code: val.code,
            value: val.value,
            value_ta: val.value_ta,
            icon: val.icon,
            is_system: true,
            is_active: true,
          },
        });
      }
    }

    if (cat.code === 'urgency_level') {
      const values = [
        { code: 'low', value: 'Low', value_ta: 'குறைந்த', color: '#9CA3AF' },
        { code: 'medium', value: 'Medium', value_ta: 'நடுத்தர', color: '#FBBF24' },
        { code: 'high', value: 'High', value_ta: 'உயர்ந்த', color: '#F97316' },
        { code: 'critical', value: 'Critical', value_ta: 'மிக அவசரம்', color: '#EF4444' },
      ];
      for (const val of values) {
        await prisma.masterValue.upsert({
          where: { category_id_code: { category_id: category.id, code: val.code } },
          update: { value: val.value, value_ta: val.value_ta, color: val.color },
          create: {
            category_id: category.id,
            code: val.code,
            value: val.value,
            value_ta: val.value_ta,
            color: val.color,
            is_system: true,
            is_active: true,
          },
        });
      }
    }
  }
  console.log('✅ Seeded Master Categories and Values.');

  // 3. Create Default Working Calendar
  await prisma.workingCalendar.create({
    data: {
      tenant_id: tenantId,
      branch_id: null,
      name: 'Standard Tamil Nadu Government Calendar',
      working_days: [1, 2, 3, 4, 5, 6], // Mon-Sat
      working_hours_start: '09:30',
      working_hours_end: '17:45',
      is_default: true,
    },
  }).catch(() => {
    console.log('Standard Calendar already exists.');
  });

  // 4. Create Standard Permissions
  const permissions = [
    { code: 'complaints.read', module: 'complaints', action: 'read', description: 'Read complaints' },
    { code: 'complaints.write', module: 'complaints', action: 'write', description: 'Create/update complaints' },
    { code: 'complaints.approve', module: 'complaints', action: 'approve', description: 'Approve/resolve complaints' },
    { code: 'assets.read', module: 'assets', action: 'read', description: 'View assets' },
    { code: 'assets.write', module: 'assets', action: 'write', description: 'Manage assets' },
    { code: 'tenders.read', module: 'tenders', action: 'read', description: 'Read tenders' },
    { code: 'tenders.write', module: 'tenders', action: 'write', description: 'Create/manage tenders' },
  ];

  for (const perm of permissions) {
    await prisma.permission.upsert({
      where: { code: perm.code },
      update: { description: perm.description },
      create: perm,
    });
  }
  console.log('✅ Seeded Permissions.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
