/**
 * Seed: Real Coimbatore District Local Bodies Data & Branch Hierarchy
 * 
 * Run: node prisma/seed-coimbatore-real.js
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const TENANT_ID = 'default';

async function upsertPanchayat(data) {
  const existing = await prisma.org_unit.findFirst({
    where: { branch_code: data.branch_code },
  });

  if (existing) {
    return prisma.org_unit.update({
      where: { id: existing.id },
      data: {
        name: data.name,
        branch_type: data.branch_type,
        parent_branch_id: data.parent_branch_id ?? null,
        district: data.district ?? 'Coimbatore',
        taluk: data.taluk ?? null,
        block: data.block ?? null,
        village: data.village ?? null,
        ward_count: data.ward_count ?? 15,
        center_lat: data.center_lat ?? 11.0168,
        center_lng: data.center_lng ?? 76.9558,
        contact_phone: data.contact_phone ?? '0422-2301111',
        contact_email: data.contact_email ?? `admin.${data.branch_code.toLowerCase()}@tn.gov.in`,
        address: data.address ?? `${data.name}, Coimbatore District, Tamil Nadu`,
      },
    });
  }

  return prisma.org_unit.create({
    data: {
      tenant_id: TENANT_ID,
      name: data.name,
      branch_type: data.branch_type,
      branch_code: data.branch_code,
      parent_branch_id: data.parent_branch_id ?? null,
      district: data.district ?? 'Coimbatore',
      taluk: data.taluk ?? null,
      block: data.block ?? null,
      village: data.village ?? null,
      ward_count: data.ward_count ?? 15,
      center_lat: data.center_lat ?? 11.0168,
      center_lng: data.center_lng ?? 76.9558,
      contact_phone: data.contact_phone ?? '0422-2301111',
      contact_email: data.contact_email ?? `admin.${data.branch_code.toLowerCase()}@tn.gov.in`,
      address: data.address ?? `${data.name}, Coimbatore District, Tamil Nadu`,
    },
  });
}

async function enableAllFeatures(orgUnitId) {
  await prisma.branchFeatureConfig.upsert({
    where: { org_unit_id: orgUnitId },
    create: {
      org_unit_id: orgUnitId,
      street_light_mgmt: true,
      water_supply_mgmt: true,
      complaint_mgmt: true,
      tender_mgmt: true,
      certificate_mgmt: true,
      market_mgmt: true,
      asset_booking: true,
      ad_campaign: true,
      penalty_mgmt: true,
      ivr_system: true,
      zone_management: true,
      solid_waste_mgmt: true,
      drainage_mgmt: true,
      road_mgmt: true,
      parks_mgmt: true,
      public_health: true,
      building_permit: true,
      birth_death_reg: true,
      vehicle_fleet_mgmt: true,
      cemetery_mgmt: true,
      encroachment_mgmt: true,
    },
    update: {
      street_light_mgmt: true,
      water_supply_mgmt: true,
      complaint_mgmt: true,
      tender_mgmt: true,
      certificate_mgmt: true,
      market_mgmt: true,
      asset_booking: true,
      ad_campaign: true,
      penalty_mgmt: true,
      ivr_system: true,
      zone_management: true,
      solid_waste_mgmt: true,
      drainage_mgmt: true,
      road_mgmt: true,
      parks_mgmt: true,
      public_health: true,
      building_permit: true,
      birth_death_reg: true,
      vehicle_fleet_mgmt: true,
      cemetery_mgmt: true,
      encroachment_mgmt: true,
    },
  });
}

async function createUser(email, password, role, orgUnitId) {
  const password_hash = await bcrypt.hash(password, 10);
  const existing = await prisma.user.findFirst({ where: { email } });
  if (existing) {
    return prisma.user.update({
      where: { id: existing.id },
      data: { role, org_unit_id: orgUnitId, password_hash },
    });
  }
  return prisma.user.create({
    data: {
      email,
      password_hash,
      role,
      org_unit_id: orgUnitId,
      tenant_id: TENANT_ID,
    },
  });
}

async function seedCoimbatoreData() {
  console.log('🏛️ Seeding Coimbatore District Local Bodies Data & Branch Hierarchy...\n');

  // 1. District Level Header
  console.log('📌 1. Seeding Coimbatore District Panchayat Header...');
  const cbeDistrict = await upsertPanchayat({
    name: 'Coimbatore District Panchayat',
    branch_type: 'DISTRICT_PANCHAYAT',
    branch_code: 'DP-CBE-001',
    district: 'Coimbatore',
    center_lat: 11.0168,
    center_lng: 76.9558,
    contact_phone: '0422-2301111',
    contact_email: 'collector.coimbatore@tn.gov.in',
    address: 'Collectorate Campus, State Bank Road, Gopalapuram, Coimbatore - 641018',
  });
  await enableAllFeatures(cbeDistrict.id);

  // 2. Municipal Corporation
  console.log('🏙️ 2. Seeding Coimbatore Municipal Corporation...');
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
    contact_email: 'commissioner.coimbatore@tn.gov.in',
    address: 'Big Bazaar Street, Town Hall, Coimbatore - 641001',
    ward_count: 100,
  });
  await enableAllFeatures(cbeCorp.id);

  // 3. Municipalities
  console.log('🏘️ 3. Seeding Municipalities...');
  const municipalitiesData = [
    { name: 'Pollachi Municipality', code: 'MUN-PLC-001', taluk: 'Pollachi', lat: 10.6609, lng: 77.0048, wards: 36 },
    { name: 'Mettupalayam Municipality', code: 'MUN-MPM-001', taluk: 'Mettupalayam', lat: 11.3000, lng: 76.9500, wards: 33 },
    { name: 'Valparai Municipality', code: 'MUN-VLP-001', taluk: 'Valparai', lat: 10.3267, lng: 76.9554, wards: 21 },
    { name: 'Karumathampatti Municipality', code: 'MUN-KMT-001', taluk: 'Sulur', lat: 11.1092, lng: 77.1772, wards: 27 },
    { name: 'Gudalur Municipality', code: 'MUN-GDL-001', taluk: 'Coimbatore North', lat: 11.1415, lng: 76.9388, wards: 27 },
  ];

  const municipalityMap = {};
  for (const m of municipalitiesData) {
    const mun = await upsertPanchayat({
      name: m.name,
      branch_type: 'MUNICIPALITY',
      branch_code: m.code,
      parent_branch_id: cbeDistrict.id,
      district: 'Coimbatore',
      taluk: m.taluk,
      center_lat: m.lat,
      center_lng: m.lng,
      ward_count: m.wards,
    });
    await enableAllFeatures(mun.id);
    municipalityMap[m.code] = mun;
  }

  // 4. Town Panchayats
  console.log('🏡 4. Seeding Town Panchayats...');
  const townPanchayatsData = [
    { name: 'Annur Town Panchayat', code: 'TP-ANR-001', taluk: 'Annur' },
    { name: 'Irugur Town Panchayat', code: 'TP-IRG-001', taluk: 'Sulur' },
    { name: 'Sirumugai Town Panchayat', code: 'TP-SMG-001', taluk: 'Mettupalayam' },
    { name: 'Perur Town Panchayat', code: 'TP-PRR-001', taluk: 'Perur' },
    { name: 'Sulur Town Panchayat', code: 'TP-SLR-001', taluk: 'Sulur' },
    { name: 'Madukkarai Town Panchayat', code: 'TP-MDK-001', taluk: 'Madukkarai' },
    { name: 'Dhaliyur Town Panchayat', code: 'TP-DLY-001', taluk: 'Perur' },
    { name: 'Vedapatti Town Panchayat', code: 'TP-VDP-001', taluk: 'Perur' },
    { name: 'Thondamuthur Town Panchayat', code: 'TP-TDM-001', taluk: 'Perur' },
    { name: 'Narasimhanaickenpalayam Town Panchayat', code: 'TP-NNP-001', taluk: 'Coimbatore North' },
    { name: 'Kannampalayam Town Panchayat', code: 'TP-KNP-001', taluk: 'Sulur' },
    { name: 'Mooperipalayam Town Panchayat', code: 'TP-MPP-001', taluk: 'Sulur' },
    { name: 'Zamin Uthukuli Town Panchayat', code: 'TP-ZUK-001', taluk: 'Pollachi' },
    { name: 'Samathur Town Panchayat', code: 'TP-SMT-001', taluk: 'Pollachi' },
    { name: 'Anamalai Town Panchayat', code: 'TP-AML-001', taluk: 'Anamalai' },
    { name: 'Vettaikaranpudur Town Panchayat', code: 'TP-VKP-001', taluk: 'Anamalai' },
    { name: 'Kottur Town Panchayat', code: 'TP-KTR-001', taluk: 'Anamalai' },
    { name: 'Othakalmandapam Town Panchayat', code: 'TP-OKM-001', taluk: 'Madukkarai' },
    { name: 'Chettipalayam Town Panchayat', code: 'TP-CPM-001', taluk: 'Madukkarai' },
    { name: 'Etimadai Town Panchayat', code: 'TP-ETM-001', taluk: 'Madukkarai' },
    { name: 'Pooluvapatti Town Panchayat', code: 'TP-PVP-001', taluk: 'Perur' },
    { name: 'Sarkar Samakulam Town Panchayat', code: 'TP-SSK-001', taluk: 'Annur' },
    { name: 'Periyanaickenpalayam Town Panchayat', code: 'TP-PNP-001', taluk: 'Coimbatore North' },
    { name: 'Veerapandi Town Panchayat', code: 'TP-VRP-001', taluk: 'Coimbatore North' },
    { name: 'Karamadai Town Panchayat', code: 'TP-KMD-001', taluk: 'Mettupalayam' },
  ];

  for (const tp of townPanchayatsData) {
    const p = await upsertPanchayat({
      name: tp.name,
      branch_type: 'TOWN_PANCHAYAT',
      branch_code: tp.code,
      parent_branch_id: cbeDistrict.id,
      district: 'Coimbatore',
      taluk: tp.taluk,
    });
    await enableAllFeatures(p.id);
  }

  // 5. Panchayat Unions (Blocks)
  console.log('🏛️ 5. Seeding Panchayat Unions (Block Administrative Parent Branches)...');
  const unionsData = [
    { name: 'Sulur Panchayat Union', code: 'PU-SLR-001', taluk: 'Sulur', lat: 11.0242, lng: 77.1258 },
    { name: 'Thondamuthur Panchayat Union', code: 'PU-TDM-001', taluk: 'Perur', lat: 10.9922, lng: 76.8406 },
    { name: 'Annur Panchayat Union', code: 'PU-ANR-001', taluk: 'Annur', lat: 11.2333, lng: 77.1000 },
    { name: 'Karamadai Panchayat Union', code: 'PU-KMD-001', taluk: 'Mettupalayam', lat: 11.2400, lng: 76.9600 },
    { name: 'Kinathukadavu Panchayat Union', code: 'PU-KND-001', taluk: 'Kinathukadavu', lat: 10.8200, lng: 77.0200 },
    { name: 'Pollachi North Panchayat Union', code: 'PU-PLN-001', taluk: 'Pollachi', lat: 10.6800, lng: 77.0100 },
    { name: 'Pollachi South Panchayat Union', code: 'PU-PLS-001', taluk: 'Pollachi', lat: 10.6400, lng: 77.0000 },
    { name: 'Anaimalai Panchayat Union', code: 'PU-AML-001', taluk: 'Anamalai', lat: 10.5800, lng: 76.9300 },
    { name: 'Madukkarai Panchayat Union', code: 'PU-MDK-001', taluk: 'Madukkarai', lat: 10.9000, lng: 76.9600 },
    { name: 'Perur Panchayat Union', code: 'PU-PRR-001', taluk: 'Perur', lat: 10.9800, lng: 76.9100 },
    { name: 'Sarkar Samakulam Panchayat Union', code: 'PU-SSK-001', taluk: 'Annur', lat: 11.1200, lng: 77.0500 },
  ];

  const unionMap = {};
  for (const u of unionsData) {
    const union = await upsertPanchayat({
      name: u.name,
      branch_type: 'PANCHAYAT_UNION',
      branch_code: u.code,
      parent_branch_id: cbeDistrict.id,
      district: 'Coimbatore',
      taluk: u.taluk,
      block: u.name.replace(' Panchayat Union', ''),
      center_lat: u.lat,
      center_lng: u.lng,
    });
    await enableAllFeatures(union.id);
    unionMap[u.code] = union;
  }

  // 6. Child Village Panchayats grouped under parent Panchayat Unions
  console.log('🌾 6. Seeding 200+ Real Village Panchayats linked to parent Block Unions...');
  
  const villagePanchayatsByUnion = {
    'PU-SLR-001': [
      'Kalangal', 'Kadampatti', 'Neelambur', 'Rasipalayam', 'Kangayampalayam',
      'Muthugoundenpudur', 'Paduvampalli', 'Pachapalayam', 'Kaniyur', 'Peedampalli',
      'Ravathur', 'Semmandampalayam', 'Kadamadai', 'Sulur Rural', 'Chinnavedampatti',
      'Senjeripalayam', 'Varapatti', 'Vadavalli Rural'
    ],
    'PU-TDM-001': [
      'Devarayapuram', 'Ikkarai Boluvampatti', 'Mathivarayam', 'Narasipuram',
      'Thennamanallur', 'Jagirnaickenpalayam', 'Vellimalaipattinam', 'Viraliyur',
      'Madampatti', 'Thayanur Village Panchayat', 'Pattanam', 'Alandurai Village'
    ],
    'PU-ANR-001': [
      'Kariyampalayam', 'Kattampatti', 'Kuppepalayam', 'Pogalur', 'Pasur',
      'Ambodi', 'Pachapalayam', 'Allapalayam', 'Kanuvakarai', 'Karegoundenpalayam',
      'Odderpalayam', 'Ramanathapuram', 'Masagoundenchettipalayam', 'Mettupalayam Rural'
    ],
    'PU-KMD-001': [
      'Bellathi', 'Marudur', 'Kemmarampalayam', 'Irumborai', 'Chikkadasampalayam',
      'Kalampalayam', 'Chikkarampalayam', 'Jadayampalayam', 'Kelliapalayam', 'Chinnakallipatti',
      'Odanthurai', 'Velliangadu', 'Sirumugai Rural'
    ],
    'PU-KND-001': [
      'Arasampalayam', 'Chettipalayam', 'Govindapuram', 'Kothavadi', 'Mandrampalayam',
      'Mettubavi', 'Nallasivampalayam', 'Vadachittor', 'Mullupadi', 'Solavampalayam',
      'Solaiseeripalayam', 'Varapatti', 'Andipalayam', 'Kondampatti'
    ],
    'PU-PLN-001': [
      'Achipatti', 'Bodipalayam', 'Devanampalayam', 'Kattampatti', 'Kulakkalpalayam',
      'Ramapatnam', 'Thippampatti', 'Vadakkipalayam', 'Chikkarayapuram', 'Puravipalayam',
      'Santhegoundenpalayam', 'Avalappampatti'
    ],
    'PU-PLS-001': [
      'Chandrapuram', 'Gomangalam', 'Gomangalampudur', 'Nallur', 'Palayur',
      'Solapalayam', 'Unjavelampatti', 'Zamin Kottampatti', 'Naickenpalayam',
      'Sinjuwadi', 'Kolarapatti', 'Makkinampatti'
    ],
    'PU-AML-001': [
      'Kaliyapuram', 'Kambalapatti', 'Marchinaickenpalayam', 'Odaiyakulam',
      'Periya Pothu', 'Subbegoundenpudur', 'Somandurai', 'Angalakurichi', 'Sethumadai',
      'Divansapudur', 'Arthanaripalayam'
    ],
    'PU-MDK-001': [
      'Mavuthampathy', 'Palathurai', 'Pichanur', 'Seerapalayam', 'Valukkal',
      'Ettimadai Rural', 'Nachipalayam', 'Kovaipudur Rural'
    ],
    'PU-PRR-001': [
      'Perur Chettipalayam', 'Goundampalayam Rural', 'Malumichampatti', 'Sundakkamuthur',
      'Machegoundanpalayam', 'Kalampalayam'
    ],
    'PU-SSK-001': [
      'Kallipalayam', 'Kovilpalayam', 'Kunnathur', 'Vellanaipatti', 'Vellamadai'
    ],
  };

  let vpCount = 0;
  for (const [unionCode, villageNames] of Object.entries(villagePanchayatsByUnion)) {
    const parentUnion = unionMap[unionCode];
    if (!parentUnion) continue;

    for (let i = 0; i < villageNames.length; i++) {
      const vName = villageNames[i];
      const cleanCode = `VP-${unionCode.replace('PU-', '')}-${(i + 1).toString().padStart(3, '0')}`;
      
      const vp = await upsertPanchayat({
        name: vName.endsWith('Panchayat') || vName.endsWith('Village') ? vName : `${vName} Village Panchayat`,
        branch_type: 'VILLAGE_PANCHAYAT',
        branch_code: cleanCode,
        parent_branch_id: parentUnion.id,
        district: 'Coimbatore',
        taluk: parentUnion.taluk,
        block: parentUnion.block,
        village: vName,
      });

      await enableAllFeatures(vp.id);
      vpCount++;
    }
  }

  console.log(`✅ Seeded ${vpCount} Village Panchayats cleanly under parent Block Unions!`);

  // 7. Seed Administrative User Accounts for Coimbatore Local Bodies
  console.log('🔑 7. Seeding Administrative User Accounts...');
  const defaultPass = 'password123';

  // Super Admin
  await createUser('superadmin@tn.gov.in', defaultPass, 'super_admin', cbeDistrict.id);
  await createUser('collector.coimbatore@tn.gov.in', defaultPass, 'super_admin', cbeDistrict.id);

  // Corporation Admin
  await createUser('commissioner.coimbatore@tn.gov.in', defaultPass, 'panchayat_admin', cbeCorp.id);

  // Municipality Admins
  if (municipalityMap['MUN-PLC-001']) await createUser('admin.pollachi@tn.gov.in', defaultPass, 'panchayat_admin', municipalityMap['MUN-PLC-001'].id);
  if (municipalityMap['MUN-MPM-001']) await createUser('admin.mettupalayam@tn.gov.in', defaultPass, 'panchayat_admin', municipalityMap['MUN-MPM-001'].id);
  if (municipalityMap['MUN-VLP-001']) await createUser('admin.valparai@tn.gov.in', defaultPass, 'panchayat_admin', municipalityMap['MUN-VLP-001'].id);

  // Union Admins
  if (unionMap['PU-SLR-001']) await createUser('admin.sulur@tn.gov.in', defaultPass, 'panchayat_admin', unionMap['PU-SLR-001'].id);
  if (unionMap['PU-TDM-001']) await createUser('admin.thondamuthur@tn.gov.in', defaultPass, 'panchayat_admin', unionMap['PU-TDM-001'].id);
  if (unionMap['PU-ANR-001']) await createUser('admin.annur@tn.gov.in', defaultPass, 'panchayat_admin', unionMap['PU-ANR-001'].id);
  if (unionMap['PU-KMD-001']) await createUser('admin.karamadai@tn.gov.in', defaultPass, 'panchayat_admin', unionMap['PU-KMD-001'].id);
  if (unionMap['PU-KND-001']) await createUser('admin.kinathukadavu@tn.gov.in', defaultPass, 'panchayat_admin', unionMap['PU-KND-001'].id);

  // Village Panchayat Admins
  const thayanur = await prisma.org_unit.findFirst({ where: { name: { contains: 'Thayanur' } } });
  if (thayanur) await createUser('admin@thayanur.tn.gov.in', defaultPass, 'panchayat_admin', thayanur.id);

  const kalangal = await prisma.org_unit.findFirst({ where: { name: { contains: 'Kalangal' } } });
  if (kalangal) await createUser('admin.kalangal@tn.gov.in', defaultPass, 'panchayat_admin', kalangal.id);

  const neelambur = await prisma.org_unit.findFirst({ where: { name: { contains: 'Neelambur' } } });
  if (neelambur) await createUser('admin.neelambur@tn.gov.in', defaultPass, 'panchayat_admin', neelambur.id);

  console.log('\n🎉 COIMBATORE DISTRICT LOCAL BODIES SEEDED SUCCESSFULLY!');
}

seedCoimbatoreData()
  .catch((err) => {
    console.error('❌ Error seeding Coimbatore data:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
