require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function testRbacAndFeatures() {
  console.log('🔍 Verifying Coimbatore District DB Seeding Breakdown...\n');

  const totalBranches = await prisma.panchayat.count();
  console.log(`✅ Total Branches in DB: ${totalBranches}`);

  const byType = await prisma.panchayat.groupBy({
    by: ['branch_type'],
    _count: { _all: true },
  });
  console.log('\n📊 Breakdown by Branch Type:');
  byType.forEach(t => {
    console.log(`   - ${t.branch_type}: ${t._count._all}`);
  });

  const featureConfigs = await prisma.branchFeatureConfig.count();
  console.log(`\n✅ Total BranchFeatureConfig records in DB: ${featureConfigs}`);

  const sampleChildVPs = await prisma.panchayat.findMany({
    where: { branch_type: 'VILLAGE_PANCHAYAT' },
    include: { parent_branch: true },
    take: 5,
  });

  console.log('\n🌾 Sample Child Village Panchayats linked to Parent Block Unions:');
  sampleChildVPs.forEach(vp => {
    console.log(`   - ${vp.name} (Code: ${vp.branch_code}) -> Parent Block: ${vp.parent_branch?.name}`);
  });

  console.log('\n🎉 COIMBATORE SEEDING VERIFICATION COMPLETE!');
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
