require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function testRbacAndFeatures() {
  console.log('🔍 Testing RBAC and Feature Toggle database queries...\n');

  // 1. Test Permissions
  const permissionsCount = await prisma.permission.count();
  console.log(`✅ Permissions count: ${permissionsCount}`);

  // 2. Test Permission Groups
  const groups = await prisma.permissionGroup.findMany({ select: { name: true, permissions: true } });
  console.log(`✅ Permission groups count: ${groups.length}`);
  groups.forEach(g => {
    const perms = Array.isArray(g.permissions) ? g.permissions.length : 0;
    console.log(`   - ${g.name}: ${perms} permissions`);
  });

  // 3. Test System Roles
  const roles = await prisma.role.findMany({ select: { name: true, display_name: true, hierarchy_level: true } });
  console.log(`\n✅ System roles count: ${roles.length}`);
  roles.slice(0, 5).forEach(r => {
    console.log(`   - ${r.display_name} (${r.name}) - Level ${r.hierarchy_level}`);
  });

  // 4. Test Branch Feature Config for Panchayat #1
  const firstPanchayat = await prisma.panchayat.findFirst();
  if (firstPanchayat) {
    const featureConfig = await prisma.branchFeatureConfig.upsert({
      where: { panchayat_id: firstPanchayat.id },
      create: { panchayat_id: firstPanchayat.id, street_light_mgmt: true, ivr_system: true },
      update: { street_light_mgmt: true },
    });
    console.log(`\n✅ Branch Feature Config for "${firstPanchayat.name}" (ID: ${firstPanchayat.id}):`);
    console.log(`   - street_light_mgmt: ${featureConfig.street_light_mgmt}`);
    console.log(`   - water_supply_mgmt: ${featureConfig.water_supply_mgmt}`);
    console.log(`   - ivr_system: ${featureConfig.ivr_system}`);
    console.log(`   - tender_mgmt: ${featureConfig.tender_mgmt}`);
  }

  console.log('\n🎉 ALL DATABASE QUERIES WORKING PERFECTLY!');
}

testRbacAndFeatures()
  .catch(err => {
    console.error('❌ Error testing RBAC and features:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
