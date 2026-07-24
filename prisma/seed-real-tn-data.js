/**
 * Seed: Real Tamil Nadu Local Bodies Hierarchy & Real Data
 * 
 * Run: node prisma/seed-real-tn-data.js
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const TENANT_ID = 'default';

async function seedRealData() {
  console.log('🏛️ Seeding Real Tamil Nadu Local Bodies Branch Hierarchy & Real Data...\n');

  // 1. District Panchayats (Top Level Hierarchy)
  console.log('📌 Seeding District Panchayats...');
  const cbeDistrict = await upsertPanchayat({
    name: 'Coimbatore District Panchayat',
    branch_type: 'DISTRICT_PANCHAYAT',
    branch_code: 'DP-CBE-001',
    district: 'Coimbatore',
    center_lat: 11.0168,
    center_lng: 76.9558,
    contact_phone: '0422-2301111',
    contact_email: 'collector.cbe@tn.gov.in',
    address: 'Collectorate Campus, Coimbatore - 641018',
  });

  const chnDistrict = await upsertPanchayat({
    name: 'Chennai District',
    branch_type: 'DISTRICT_PANCHAYAT',
    branch_code: 'DP-CHN-001',
    district: 'Chennai',
    center_lat: 13.0827,
    center_lng: 80.2707,
    contact_phone: '044-25268000',
    contact_email: 'collector.chn@tn.gov.in',
    address: 'Singaravelar Maaligai, Rajaji Salai, Chennai - 600001',
  });

  // 2. Municipal Corporations
  console.log('🏛️ Seeding Municipal Corporations...');
  const chennaiCorp = await upsertPanchayat({
    name: 'Greater Chennai Corporation',
    branch_type: 'MUNICIPAL_CORPORATION',
    branch_code: 'MC-GCC-001',
    parent_branch_id: chnDistrict.id,
    district: 'Chennai',
    taluk: 'Fort Tondiarpet',
    center_lat: 13.0839,
    center_lng: 80.2740,
    contact_phone: '044-25384520',
    contact_email: 'commissioner@chennaicorporation.gov.in',
    address: 'Ripon Building, EVR Periyar Salai, Chennai - 600003',
    ward_count: 200,
    area_sq_km: 426.0,
  });

  const cbeCorp = await upsertPanchayat({
    name: 'Coimbatore Municipal Corporation',
    branch_type: 'MUNICIPAL_CORPORATION',
    branch_code: 'MC-CMC-001',
    parent_branch_id: cbeDistrict.id,
    district: 'Coimbatore',
    taluk: 'Coimbatore South',
    center_lat: 11.0018,
    center_lng: 76.9629,
    contact_phone: '0422-2390261',
    contact_email: 'commr.coimbatore@tn.gov.in',
    address: 'Big Bazaar Street, Town Hall, Coimbatore - 641001',
    ward_count: 100,
    area_sq_km: 257.0,
  });

  const maduraiCorp = await upsertPanchayat({
    name: 'Madurai Municipal Corporation',
    branch_type: 'MUNICIPAL_CORPORATION',
    branch_code: 'MC-MMC-001',
    district: 'Madurai',
    center_lat: 9.9252,
    center_lng: 78.1198,
    contact_phone: '0452-2530521',
    contact_email: 'commr.madurai@tn.gov.in',
    address: 'Arignar Anna Maaligai, Tallakulam, Madurai - 625002',
    ward_count: 100,
  });

  // 3. Municipalities
  console.log('🏙️ Seeding Municipalities...');
  const pollachiMun = await upsertPanchayat({
    name: 'Pollachi Municipality',
    branch_type: 'MUNICIPALITY',
    branch_code: 'MUN-PLC-001',
    parent_branch_id: cbeDistrict.id,
    district: 'Coimbatore',
    taluk: 'Pollachi',
    center_lat: 10.6609,
    center_lng: 77.0048,
    contact_phone: '04259-223344',
    address: 'Palakkad Road, Pollachi - 642001',
    ward_count: 36,
  });

  const metupalayamMun = await upsertPanchayat({
    name: 'Mettupalayam Municipality',
    branch_type: 'MUNICIPALITY',
    branch_code: 'MUN-MTP-001',
    parent_branch_id: cbeDistrict.id,
    district: 'Coimbatore',
    taluk: 'Mettupalayam',
    center_lat: 11.3002,
    center_lng: 76.9442,
    contact_phone: '04254-222211',
    address: 'Ooty Main Road, Mettupalayam - 641301',
    ward_count: 33,
  });

  // 4. Panchayat Unions
  console.log('🌾 Seeding Panchayat Unions...');
  const annurUnion = await upsertPanchayat({
    name: 'Annur Panchayat Union',
    branch_type: 'PANCHAYAT_UNION',
    branch_code: 'PU-ANR-001',
    parent_branch_id: cbeDistrict.id,
    district: 'Coimbatore',
    block: 'Annur',
    center_lat: 11.2333,
    center_lng: 77.1000,
    contact_phone: '04254-262234',
    address: 'BDO Office Road, Annur - 641653',
  });

  const sulurUnion = await upsertPanchayat({
    name: 'Sulur Panchayat Union',
    branch_type: 'PANCHAYAT_UNION',
    branch_code: 'PU-SLR-001',
    parent_branch_id: cbeDistrict.id,
    district: 'Coimbatore',
    block: 'Sulur',
    center_lat: 11.0242,
    center_lng: 77.1264,
    contact_phone: '0422-2687222',
    address: 'Trichy Main Road, Sulur - 641402',
  });

  // 5. Town Panchayats
  console.log('🏘️ Seeding Town Panchayats...');
  const perurTown = await upsertPanchayat({
    name: 'Perur Town Panchayat',
    branch_type: 'TOWN_PANCHAYAT',
    branch_code: 'TP-PRR-001',
    parent_branch_id: cbeDistrict.id,
    district: 'Coimbatore',
    center_lat: 10.9705,
    center_lng: 76.9142,
    contact_phone: '0422-2607100',
    address: 'Perur Temple Street, Perur, Coimbatore - 641010',
    ward_count: 15,
  });

  const sirumugaiTown = await upsertPanchayat({
    name: 'Sirumugai Town Panchayat',
    branch_type: 'TOWN_PANCHAYAT',
    branch_code: 'TP-SMG-001',
    parent_branch_id: cbeDistrict.id,
    district: 'Coimbatore',
    center_lat: 11.3284,
    center_lng: 76.9933,
    contact_phone: '04254-251200',
    address: 'Sirumugai Main Road - 641302',
    ward_count: 18,
  });

  // 6. Village Panchayats & Sub-Offices (Under Unions / Corporations)
  console.log('🏡 Seeding Village Panchayats & Sub-Offices...');
  const thayanurVillage = await upsertPanchayat({
    name: 'Thayanur Village Panchayat',
    branch_type: 'VILLAGE_PANCHAYAT',
    branch_code: 'VP-TYN-001',
    parent_branch_id: annurUnion.id,
    district: 'Coimbatore',
    block: 'Annur',
    village: 'Thayanur',
    center_lat: 11.0168,
    center_lng: 76.9558,
    ivr_number: '04442123456',
    address: 'Panchayat Office, Thayanur - 641653',
  });

  const vadavalliVillage = await upsertPanchayat({
    name: 'Vadavalli Ward Office',
    branch_type: 'VILLAGE_PANCHAYAT',
    branch_code: 'VP-VDV-001',
    parent_branch_id: cbeCorp.id,
    district: 'Coimbatore',
    village: 'Vadavalli',
    center_lat: 11.0234,
    center_lng: 76.9012,
    ivr_number: '04442123457',
    address: 'Marudhamalai Road, Vadavalli - 641041',
  });

  const kurichiVillage = await upsertPanchayat({
    name: 'Kurichi Zonal Office',
    branch_type: 'VILLAGE_PANCHAYAT',
    branch_code: 'VP-KRC-001',
    parent_branch_id: cbeCorp.id,
    district: 'Coimbatore',
    village: 'Kurichi',
    center_lat: 11.0089,
    center_lng: 76.9345,
    ivr_number: '04442123458',
    address: 'Sundarapuram, Kurichi, Coimbatore - 641024',
  });

  // Feature Config auto-generation for all created branches
  const allBranches = [
    cbeDistrict, chnDistrict, chennaiCorp, cbeCorp, maduraiCorp,
    pollachiMun, metupalayamMun, annurUnion, sulurUnion, perurTown,
    sirumugaiTown, thayanurVillage, vadavalliVillage, kurichiVillage
  ];

  console.log('\n⚙️ Configuring feature matrix for all Tamil Nadu local body branches...');
  for (const b of allBranches) {
    const isCorp = b.branch_type === 'MUNICIPAL_CORPORATION' || b.branch_type === 'MUNICIPALITY';
    await prisma.branchFeatureConfig.upsert({
      where: { panchayat_id: b.id },
      create: {
        panchayat_id: b.id,
        street_light_mgmt: true,
        water_supply_mgmt: true,
        complaint_mgmt: true,
        zone_management: true,
        tender_mgmt: isCorp,
        certificate_mgmt: true,
        market_mgmt: true,
        asset_booking: true,
        ad_campaign: isCorp,
        penalty_mgmt: true,
        ivr_system: true,
        solid_waste_mgmt: isCorp,
        drainage_mgmt: isCorp,
        road_mgmt: isCorp,
        parks_mgmt: isCorp,
        public_health: isCorp,
        building_permit: isCorp,
        birth_death_reg: isCorp,
        vehicle_fleet_mgmt: isCorp,
      },
      update: {
        street_light_mgmt: true,
        water_supply_mgmt: true,
        complaint_mgmt: true,
        zone_management: true,
        solid_waste_mgmt: isCorp,
        building_permit: isCorp,
      },
    });
  }

  console.log('\n🎉 Real Tamil Nadu Local Bodies hierarchy & dummy data seeded successfully!');
}

async function upsertPanchayat(data) {
  let existing = null;
  if (data.branch_code) {
    existing = await prisma.panchayat.findFirst({ where: { branch_code: data.branch_code } });
  }
  if (!existing && data.ivr_number) {
    existing = await prisma.panchayat.findFirst({ where: { ivr_number: data.ivr_number } });
  }
  if (!existing && data.name) {
    existing = await prisma.panchayat.findFirst({ where: { name: data.name } });
  }

  if (existing) {
    return prisma.panchayat.update({
      where: { id: existing.id },
      data: { ...data, tenant_id: TENANT_ID },
    });
  } else {
    return prisma.panchayat.create({
      data: { ...data, tenant_id: TENANT_ID },
    });
  }
}

seedRealData()
  .catch(err => {
    console.error('❌ Error seeding real TN data:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
