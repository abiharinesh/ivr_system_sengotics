/**
 * Seed script for Mettupalayam municipality wards (33 wards).
 *
 * Usage:
 *   node prisma/seed-mettupalayam-wards.js
 *
 * This creates the 33 wards for a Mettupalayam OrgUnit. If the OrgUnit
 * doesn't exist yet, it creates one. Wards are upserted so the script is
 * idempotent.
 */

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// ── Mettupalayam Ward Data ────────────────────────────────────────────────────
// Ward names are placeholders — replace with actual ward names when available.
// Aliases include common spoken variants that callers might use.

const METTUPALAYAM_WARDS = [
  { ward_number: 1, name_en: 'Ward 1 - Mettupalayam Town', name_ta: 'வார்டு 1 - மேட்டுப்பாளையம் நகரம்', aliases: ['town', 'nagar', 'center'] },
  { ward_number: 2, name_en: 'Ward 2 - Karamadai Road', name_ta: 'வார்டு 2 - கரமடை சாலை', aliases: ['karamadai', 'karamadai road'] },
  { ward_number: 3, name_en: 'Ward 3 - Odanthurai Road', name_ta: 'வார்டு 3 - ஓடன்துறை சாலை', aliases: ['odanthurai', 'odanthurai road'] },
  { ward_number: 4, name_en: 'Ward 4 - Coonoor Road', name_ta: 'வார்டு 4 - குன்னூர் சாலை', aliases: ['coonoor', 'coonoor road'] },
  { ward_number: 5, name_en: 'Ward 5 - Ooty Road', name_ta: 'வார்டு 5 - ஊட்டி சாலை', aliases: ['ooty', 'ooty road', 'udhagai'] },
  { ward_number: 6, name_en: 'Ward 6 - Railway Station Area', name_ta: 'வார்டு 6 - ரயில் நிலையம் பகுதி', aliases: ['railway station', 'station', 'rail'] },
  { ward_number: 7, name_en: 'Ward 7 - Bus Stand Area', name_ta: 'வார்டு 7 - பேருந்து நிலையம் பகுதி', aliases: ['bus stand', 'bus stop', 'perunthunilayam'] },
  { ward_number: 8, name_en: 'Ward 8 - Market Area', name_ta: 'வார்டு 8 - சந்தை பகுதி', aliases: ['market', 'santhai', 'bazaar'] },
  { ward_number: 9, name_en: 'Ward 9 - Hospital Road', name_ta: 'வார்டு 9 - மருத்துவமனை சாலை', aliases: ['hospital', 'hospital road', 'aaspatri'] },
  { ward_number: 10, name_en: 'Ward 10 - School Area', name_ta: 'வார்டு 10 - பள்ளி பகுதி', aliases: ['school', 'palli', 'school area'] },
  { ward_number: 11, name_en: 'Ward 11', name_ta: 'வார்டு 11', aliases: [] },
  { ward_number: 12, name_en: 'Ward 12', name_ta: 'வார்டு 12', aliases: [] },
  { ward_number: 13, name_en: 'Ward 13', name_ta: 'வார்டு 13', aliases: [] },
  { ward_number: 14, name_en: 'Ward 14', name_ta: 'வார்டு 14', aliases: [] },
  { ward_number: 15, name_en: 'Ward 15', name_ta: 'வார்டு 15', aliases: [] },
  { ward_number: 16, name_en: 'Ward 16', name_ta: 'வார்டு 16', aliases: [] },
  { ward_number: 17, name_en: 'Ward 17', name_ta: 'வார்டு 17', aliases: [] },
  { ward_number: 18, name_en: 'Ward 18', name_ta: 'வார்டு 18', aliases: [] },
  { ward_number: 19, name_en: 'Ward 19', name_ta: 'வார்டு 19', aliases: [] },
  { ward_number: 20, name_en: 'Ward 20', name_ta: 'வார்டு 20', aliases: [] },
  { ward_number: 21, name_en: 'Ward 21', name_ta: 'வார்டு 21', aliases: [] },
  { ward_number: 22, name_en: 'Ward 22', name_ta: 'வார்டு 22', aliases: [] },
  { ward_number: 23, name_en: 'Ward 23', name_ta: 'வார்டு 23', aliases: [] },
  { ward_number: 24, name_en: 'Ward 24', name_ta: 'வார்டு 24', aliases: [] },
  { ward_number: 25, name_en: 'Ward 25', name_ta: 'வார்டு 25', aliases: [] },
  { ward_number: 26, name_en: 'Ward 26', name_ta: 'வார்டு 26', aliases: [] },
  { ward_number: 27, name_en: 'Ward 27', name_ta: 'வார்டு 27', aliases: [] },
  { ward_number: 28, name_en: 'Ward 28', name_ta: 'வார்டு 28', aliases: [] },
  { ward_number: 29, name_en: 'Ward 29', name_ta: 'வார்டு 29', aliases: [] },
  { ward_number: 30, name_en: 'Ward 30', name_ta: 'வார்டு 30', aliases: [] },
  { ward_number: 31, name_en: 'Ward 31', name_ta: 'வார்டு 31', aliases: [] },
  { ward_number: 32, name_en: 'Ward 32', name_ta: 'வார்டு 32', aliases: [] },
  { ward_number: 33, name_en: 'Ward 33', name_ta: 'வார்டு 33', aliases: [] },
];

async function main() {
  console.log('🏘️  Seeding Mettupalayam wards...');

  // Find or create the Mettupalayam OrgUnit
  let orgUnit = await prisma.orgUnit.findFirst({
    where: {
      name: { contains: 'Mettupalayam', mode: 'insensitive' },
    },
  });

  if (!orgUnit) {
    // Check if any org unit exists; use the first one as fallback
    orgUnit = await prisma.orgUnit.findFirst();
  }

  if (!orgUnit) {
    console.log('  No OrgUnit found. Creating Mettupalayam municipality...');
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
    console.log(`  ✅ Created OrgUnit #${orgUnit.id}: ${orgUnit.name}`);
  } else {
    console.log(`  📍 Using existing OrgUnit #${orgUnit.id}: ${orgUnit.name}`);
  }

  // Upsert all 33 wards
  let created = 0;
  let updated = 0;

  for (const ward of METTUPALAYAM_WARDS) {
    const result = await prisma.ward.upsert({
      where: {
        org_unit_id_ward_number: {
          org_unit_id: orgUnit.id,
          ward_number: ward.ward_number,
        },
      },
      create: {
        org_unit_id: orgUnit.id,
        ward_number: ward.ward_number,
        name_en: ward.name_en,
        name_ta: ward.name_ta,
        aliases: ward.aliases,
      },
      update: {
        name_en: ward.name_en,
        name_ta: ward.name_ta,
        aliases: ward.aliases,
      },
    });

    if (result.created_at.getTime() === result.updated_at.getTime()) {
      created++;
    } else {
      updated++;
    }
  }

  console.log(`  ✅ Wards seeded: ${created} created, ${updated} updated`);
  console.log('🏘️  Done!');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
