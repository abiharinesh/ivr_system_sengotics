import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Seeding Phase 2 Generic Assets...');

  const tenantId = 'default';

  // 1. Fetch Thayanur Village Panchayat (seeded in Phase 1)
  const branch = await prisma.orgUnit.findFirst({
    where: { tenant_id: tenantId, name: 'Thayanur Village Panchayat' },
  });

  if (!branch) {
    console.error('❌ Thayanur Village Panchayat not found. Please run Phase 1 seed first.');
    return;
  }

  // 2. Create Street Light Asset with Custom properties
  const streetLight = await prisma.asset.create({
    data: {
      tenant_id: tenantId,
      branch_id: branch.id,
      asset_type_code: 'electric_pole', // References seeded master value
      asset_code: 'AST-SL-001',
      name: 'Thayanur Main Road Light 1',
      latitude: 11.0170,
      longitude: 76.9560,
      installed_at: new Date(),
      condition_rating: 5,
      is_operational: true,
      custom_data: {
        wattage: 120,
        pole_type: 'galvanized_iron',
        lamp_type: 'LED',
      },
      notes: 'Main junction LED street light.',
    },
  });
  console.log(`✅ Created Street Light Asset: ${streetLight.name} (Code: ${streetLight.asset_code})`);

  // 3. Create Water Tank Asset with Custom properties
  const waterTank = await prisma.asset.create({
    data: {
      tenant_id: tenantId,
      branch_id: branch.id,
      asset_type_code: 'water_tank', // References seeded master value
      asset_code: 'AST-WT-002',
      name: 'Colony OHT 60KL',
      latitude: 11.0160,
      longitude: 76.9550,
      installed_at: new Date(),
      condition_rating: 4,
      is_operational: true,
      custom_data: {
        capacity_liters: 60000,
        material: 'RCC',
        inlet_diameter_inches: 4,
      },
      notes: 'Overhead reservoir serving ration shop colony.',
    },
  });
  console.log(`✅ Created Water Tank Asset: ${waterTank.name} (Code: ${waterTank.asset_code})`);

  // 4. Create Mock Image upload verification
  const image = await prisma.assetImage.create({
    data: {
      asset_id: streetLight.id,
      storage_key: 'default/mock-key.jpg',
      image_url: '/uploads/mock-key.jpg',
      image_type: 'installation',
      caption: 'Initial installation verification photo',
      file_size_bytes: 1024 * 350,
      resolution: '4000x3000',
      captured_device: 'Apple iPhone 15 Pro',
      exif_data: {
        Make: 'Apple',
        Model: 'iPhone 15 Pro',
        DateTimeOriginal: new Date().toISOString(),
        latitude: 11.0171,
        longitude: 76.9561,
      },
      gps_lat: 11.0171,
      gps_lng: 76.9561,
      gps_accuracy_m: 12.5,
    },
  });
  console.log(`✅ Created Mock Asset Image with verified EXIF: ${image.image_url}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
