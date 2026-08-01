import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Seeding Phase 1 Branch Tree Hierarchy...');

  const tenantId = 'default';

  // 1. Create District Panchayat (Root)
  const district = await prisma.orgUnit.create({
    data: {
      tenant_id: tenantId,
      name: 'Coimbatore District Panchayat',
      branch_type: 'DISTRICT_PANCHAYAT',
      branch_status: 'ACTIVE',
      branch_code: 'DP-CBE-001',
      district: 'Coimbatore',
      is_active: true,
    },
  });
  console.log(`✅ Created Root District Branch: ${district.name} (ID: ${district.id})`);

  // 2. Create Panchayat Unions under District (Children)
  const unionSulur = await prisma.orgUnit.create({
    data: {
      tenant_id: tenantId,
      name: 'Sulur Panchayat Union',
      branch_type: 'PANCHAYAT_UNION',
      branch_status: 'ACTIVE',
      branch_code: 'PU-CBE-SULUR-002',
      parent_branch_id: district.id,
      district: 'Coimbatore',
      block: 'Sulur',
      is_active: true,
    },
  });
  console.log(`✅ Created Union Branch: ${unionSulur.name} (ID: ${unionSulur.id}, Parent: ${district.name})`);

  const unionAnnur = await prisma.orgUnit.create({
    data: {
      tenant_id: tenantId,
      name: 'Annur Panchayat Union',
      branch_type: 'PANCHAYAT_UNION',
      branch_status: 'ACTIVE',
      branch_code: 'PU-CBE-ANNUR-003',
      parent_branch_id: district.id,
      district: 'Coimbatore',
      block: 'Annur',
      is_active: true,
    },
  });
  console.log(`✅ Created Union Branch: ${unionAnnur.name} (ID: ${unionAnnur.id}, Parent: ${district.name})`);

  // 3. Create Village Panchayats under Unions (Grandchildren)
  const villageThayanur = await prisma.orgUnit.create({
    data: {
      tenant_id: tenantId,
      name: 'Thayanur Village Panchayat',
      branch_type: 'VILLAGE_PANCHAYAT',
      branch_status: 'ACTIVE',
      branch_code: 'VP-CBE-SULUR-004',
      parent_branch_id: unionSulur.id,
      district: 'Coimbatore',
      block: 'Sulur',
      village: 'Thayanur',
      is_active: true,
    },
  });
  console.log(`✅ Created Village Branch: ${villageThayanur.name} (ID: ${villageThayanur.id}, Parent: ${unionSulur.name})`);

  const villageTholampalay = await prisma.orgUnit.create({
    data: {
      tenant_id: tenantId,
      name: 'Tholampalay Village Panchayat',
      branch_type: 'VILLAGE_PANCHAYAT',
      branch_status: 'ACTIVE',
      branch_code: 'VP-CBE-ANNUR-005',
      parent_branch_id: unionAnnur.id,
      district: 'Coimbatore',
      block: 'Annur',
      village: 'Tholampalay',
      is_active: true,
    },
  });
  console.log(`✅ Created Village Branch: ${villageTholampalay.name} (ID: ${villageTholampalay.id}, Parent: ${unionAnnur.name})`);

  // Create default feature configs for all new branches
  const newBranchIds = [district.id, unionSulur.id, unionAnnur.id, villageThayanur.id, villageTholampalay.id];
  for (const id of newBranchIds) {
    await prisma.branchFeatureConfig.upsert({
      where: { panchayat_id: id },
      update: {},
      create: { panchayat_id: id },
    });
  }
  console.log('✅ Created branch feature configurations.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
