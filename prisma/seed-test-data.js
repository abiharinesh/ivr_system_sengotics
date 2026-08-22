require('dotenv').config();
const { makeClient } = require('./db');
const { prisma, close } = makeClient({ max: 2 });

const METTUPALAYAM_WARDS = [
  { ward_number: 1, name_en: 'Ward 1 - Mettupalayam Town', name_ta: 'வார்டு 1 - மேட்டுப்பாளையம் நகரம்', aliases: ['town', 'nagar', 'center', 'town hall'] },
  { ward_number: 2, name_en: 'Ward 2 - Karamadai Road', name_ta: 'வார்டு 2 - கரமடை சாலை', aliases: ['karamadai', 'karamadai road', 'mariamman temple', 'checkpost'] },
  { ward_number: 3, name_en: 'Ward 3 - Odanthurai Road', name_ta: 'வார்டு 3 - ஓடன்துறை சாலை', aliases: ['odanthurai', 'odanthurai road', 'river bank'] },
  { ward_number: 4, name_en: 'Ward 4 - Coonoor Road', name_ta: 'வார்டு 4 - குன்னூர் சாலை', aliases: ['coonoor', 'coonoor road', 'hill view'] },
  { ward_number: 5, name_en: 'Ward 5 - Ooty Road', name_ta: 'வார்டு 5 - ஊட்டி சாலை', aliases: ['ooty', 'ooty road', 'udhagai', 'petrol bunk', 'bridge'] },
  { ward_number: 6, name_en: 'Ward 6 - Railway Station Area', name_ta: 'வார்டு 6 - ரயில் நிலையம் பகுதி', aliases: ['railway station', 'station', 'railway gate', 'auto stand'] },
  { ward_number: 7, name_en: 'Ward 7 - Bus Stand Area', name_ta: 'வார்டு 7 - பேருந்து நிலையம் பகுதி', aliases: ['bus stand', 'bus stop', 'perunthu nilayam', 'clock tower'] },
  { ward_number: 8, name_en: 'Ward 8 - Market Area', name_ta: 'வார்டு 8 - சந்தை பகுதி', aliases: ['market', 'santhai', 'bazaar', 'vegetable market'] },
  { ward_number: 9, name_en: 'Ward 9 - Hospital Road', name_ta: 'வார்டு 9 - மருத்துவமனை சாலை', aliases: ['hospital', 'hospital road', 'aaspatri', 'government hospital'] },
  { ward_number: 10, name_en: 'Ward 10 - School Area', name_ta: 'வார்டு 10 - பள்ளி பகுதி', aliases: ['school', 'palli', 'government school', 'higher secondary school'] },
  { ward_number: 11, name_en: 'Ward 11 - Mahadevapuram', name_ta: 'வார்டு 11 - மகாதேவபுரம்', aliases: ['mahadevapuram', 'mahadeva'] },
  { ward_number: 12, name_en: 'Ward 12 - Annur Road', name_ta: 'வார்டு 12 - அன்னூர் சாலை', aliases: ['annur', 'annur road'] },
  { ward_number: 13, name_en: 'Ward 13 - Sirumugai Road', name_ta: 'வார்டு 13 - சிறுமுகை சாலை', aliases: ['sirumugai', 'sirumugai road'] },
  { ward_number: 14, name_en: 'Ward 14 - Bhavani Nagar', name_ta: 'வார்டு 14 - பவானி நகர்', aliases: ['bhavani nagar', 'bhavani'] },
  { ward_number: 15, name_en: 'Ward 15 - Anna Nagar', name_ta: 'வார்டு 15 - அண்ணா நகர்', aliases: ['anna nagar', 'anna'] },
  { ward_number: 16, name_en: 'Ward 16 - Kamaraj Nagar', name_ta: 'வார்டு 16 - காமராஜ் நகர்', aliases: ['kamaraj nagar', 'kamaraj'] },
  { ward_number: 17, name_en: 'Ward 17 - Gandhi Nagar', name_ta: 'வார்டு 17 - காந்தி நகர்', aliases: ['gandhi nagar', 'gandhi'] },
  { ward_number: 18, name_en: 'Ward 18 - Nehru Nagar', name_ta: 'வார்டு 18 - நேரு நகர்', aliases: ['nehru nagar', 'nehru'] },
  { ward_number: 19, name_en: 'Ward 19 - Teachers Colony', name_ta: 'வார்டு 19 - ஆசிரியர் காலனி', aliases: ['teachers colony', 'colony'] },
  { ward_number: 20, name_en: 'Ward 20 - Housing Unit', name_ta: 'வார்டு 20 - ஹவுசிங் யூனிட்', aliases: ['housing unit', 'housing board'] },
  { ward_number: 21, name_en: 'Ward 21 - Co-op Colony', name_ta: 'வார்டு 21 - கூட்டுறவு காலனி', aliases: ['coop colony', 'cooperative'] },
  { ward_number: 22, name_en: 'Ward 22 - Shanti Nagar', name_ta: 'வார்டு 22 - சாந்தி நகர்', aliases: ['shanti nagar'] },
  { ward_number: 23, name_en: 'Ward 23 - Subash Nagar', name_ta: 'வார்டு 23 - சுபாஷ் நகர்', aliases: ['subash nagar'] },
  { ward_number: 24, name_en: 'Ward 24 - Bharathi Nagar', name_ta: 'வார்டு 24 - பாரதி நகர்', aliases: ['bharathi nagar'] },
  { ward_number: 25, name_en: 'Ward 25 - V.O.C. Nagar', name_ta: 'வார்டு 25 - வ.உ.சி. நகர்', aliases: ['voc nagar', 'v o c'] },
  { ward_number: 26, name_en: 'Ward 26 - Indira Nagar', name_ta: 'வார்டு 26 - இந்திரா நகர்', aliases: ['indira nagar'] },
  { ward_number: 27, name_en: 'Ward 27 - Sivan Kovil Street', name_ta: 'வார்டு 27 - சிவன் கோவில் தெரு', aliases: ['sivan kovil', 'shiva temple'] },
  { ward_number: 28, name_en: 'Ward 28 - Perumal Kovil Street', name_ta: 'வார்டு 28 - பெருமாள் கோவில் தெரு', aliases: ['perumal kovil', 'vishnu temple'] },
  { ward_number: 29, name_en: 'Ward 29 - Mosque Street', name_ta: 'வார்டு 29 - பள்ளிவாசல் தெரு', aliases: ['mosque street', 'pallivasal', 'masjid'] },
  { ward_number: 30, name_en: 'Ward 30 - Church Road', name_ta: 'வார்டு 30 - சர்ச் சாலை', aliases: ['church road', 'church', 'madha kovil'] },
  { ward_number: 31, name_en: 'Ward 31 - Alangombu Road', name_ta: 'வார்டு 31 - ஆலங்கொம்பு சாலை', aliases: ['alangombu'] },
  { ward_number: 32, name_en: 'Ward 32 - Thekkampatti Road', name_ta: 'வார்டு 32 - தேக்கம்பட்டி சாலை', aliases: ['thekkampatti'] },
  { ward_number: 33, name_en: 'Ward 33 - Nellithurai Road', name_ta: 'வார்டு 33 - நெல்லித்துறை சாலை', aliases: ['nellithurai', 'nellithurai road'] },
];

// Test poles with landmarks across key wards
const SAMPLE_POLES = [
  // ── Ward 2 (Karamadai Road) ──
  { ward_num: 2, pole_number: 'KM-01', keypad_id: '201', landmarks: ['near Mariamman temple', 'Mariamman kovil pakkam', 'Karamadai road'] },
  { ward_num: 2, pole_number: 'KM-02', keypad_id: '202', landmarks: ['opposite Government school', 'Arasu palli ethirla', 'Karamadai checkpost'] },
  { ward_num: 2, pole_number: 'KM-03', keypad_id: '203', landmarks: ['near big banyan tree', 'Aalamaram pakkathula', 'Karamadai junction'] },

  // ── Ward 5 (Ooty Road) ──
  { ward_num: 5, pole_number: 'OT-01', keypad_id: '501', landmarks: ['near Petrol pump', 'Petrol bunk pakkam', 'Ooty road'] },
  { ward_num: 5, pole_number: 'OT-02', keypad_id: '502', landmarks: ['near Bridge', 'Paalam pakkathula', 'Bhavani river bridge'] },
  { ward_num: 5, pole_number: 'OT-03', keypad_id: '503', landmarks: ['near Toll gate', 'Toll gate ethirla'] },

  // ── Ward 6 (Railway Station Area) ──
  { ward_num: 6, pole_number: 'RS-01', keypad_id: '601', landmarks: ['near Railway station entrance', 'Station vasal', 'Railway gate'] },
  { ward_num: 6, pole_number: 'RS-02', keypad_id: '602', landmarks: ['near Auto stand', 'Auto stand pakkam', 'Station parking'] },

  // ── Ward 7 (Bus Stand Area) ──
  { ward_num: 7, pole_number: 'BS-01', keypad_id: '701', landmarks: ['near Bus stand clock tower', 'Bus stand mani koondu', 'Perunthu nilayam'] },
  { ward_num: 7, pole_number: 'BS-02', keypad_id: '702', landmarks: ['near Murugan bakery', 'Bakery pakkathula', 'Bus stand entrance'] },

  // ── Ward 8 (Market Area) ──
  { ward_num: 8, pole_number: 'MK-01', keypad_id: '801', landmarks: ['near Vegetable market', 'Kaikari santhai pakkam', 'Market center'] },
  { ward_num: 8, pole_number: 'MK-02', keypad_id: '802', landmarks: ['near Fish market', 'Meen market pakkam'] },

  // ── Ward 9 (Hospital Road) ──
  { ward_num: 9, pole_number: 'HP-01', keypad_id: '901', landmarks: ['near Government hospital', 'Aaspatri pakkam', 'Hospital main gate'] },
  { ward_num: 9, pole_number: 'HP-02', keypad_id: '902', landmarks: ['near Pharmacy', 'Medical shop pakkathula'] },
];

async function main() {
  console.log('🚀 Seeding comprehensive test data for IVR calls...');

  // 1. Get or create OrgUnit
  let orgUnits = await prisma.orgUnit.findMany();
  let orgUnit = orgUnits.find(o => o.name.toLowerCase().includes('mettupalayam')) || orgUnits[0];

  if (!orgUnit) {
    orgUnit = await prisma.orgUnit.create({
      data: {
        name: 'Mettupalayam Municipality',
        branch_type: 'MUNICIPALITY',
        branch_status: 'ACTIVE',
        district: 'Coimbatore',
        taluk: 'Mettupalayam',
        ward_count: 33,
        tenant_id: 'default',
      },
    });
    console.log(`✅ Created OrgUnit #${orgUnit.id}: ${orgUnit.name}`);
  } else {
    console.log(`📍 Using OrgUnit #${orgUnit.id}: ${orgUnit.name}`);
  }

  // 2. Seed all 33 Wards
  const wardMap = new Map();
  for (const w of METTUPALAYAM_WARDS) {
    const ward = await prisma.ward.upsert({
      where: {
        org_unit_id_ward_number: {
          org_unit_id: orgUnit.id,
          ward_number: w.ward_number,
        },
      },
      create: {
        org_unit_id: orgUnit.id,
        ward_number: w.ward_number,
        name_en: w.name_en,
        name_ta: w.name_ta,
        aliases: w.aliases,
      },
      update: {
        name_en: w.name_en,
        name_ta: w.name_ta,
        aliases: w.aliases,
      },
    });
    wardMap.set(w.ward_number, ward.id);
  }
  console.log(`✅ Seeded 33 Wards for OrgUnit #${orgUnit.id}`);

  // 3. Seed Sample Poles in Test Wards
  let poleCount = 0;
  for (const p of SAMPLE_POLES) {
    const wardId = wardMap.get(p.ward_num);
    const existing = await prisma.electricPole.findFirst({
      where: {
        org_unit_id: orgUnit.id,
        keypad_id: p.keypad_id,
      },
    });

    if (existing) {
      await prisma.electricPole.update({
        where: { id: existing.id },
        data: {
          ward_id: wardId,
          pole_number: p.pole_number,
          landmarks: p.landmarks,
        },
      });
    } else {
      await prisma.electricPole.create({
        data: {
          org_unit_id: orgUnit.id,
          ward_id: wardId,
          pole_number: p.pole_number,
          keypad_id: p.keypad_id,
          landmarks: p.landmarks,
        },
      });
    }
    poleCount++;
  }
  console.log(`✅ Seeded ${poleCount} sample poles linked to wards.`);

  console.log('🎉 Done seeding test data!');
}

main()
  .catch((e) => {
    console.error('❌ Test seed error:', e);
    process.exit(1);
  })
  .finally(() => close());
