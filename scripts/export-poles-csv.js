require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function run() {
  try {
    const poles = await prisma.electricPole.findMany({
      include: {
        ward: { select: { ward_number: true, name_en: true, name_ta: true } },
        org_unit: { select: { name: true, branch_type: true } }
      },
      orderBy: { id: 'asc' }
    });

    // Exotel requires field names to be 10 characters or fewer!
    // E.g., pole_id (7), pole_no (7), keypad_id (9), ward_no (7), area (4), landmark (8), latitude (8), longitude (9), status (6)
    const header = ['pole_id', 'pole_no', 'keypad_id', 'ward_no', 'area', 'landmark', 'latitude', 'longitude', 'status'];

    function escapeCsv(val) {
      if (val === null || val === undefined) return '';
      let str = String(val).trim();
      if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
        return '"' + str.replace(/"/g, '""') + '"';
      }
      return str;
    }

    const rows = [header.join(',')];

    const MTP_COORDS = {
      'Ward 2': { lat: 11.246000, lng: 76.958000 },
      'Ward 5': { lat: 11.305000, lng: 76.935000 },
      'Ward 6': { lat: 11.301500, lng: 76.942000 },
      'Ward 7': { lat: 11.300000, lng: 76.940000 },
      'Ward 8': { lat: 11.298500, lng: 76.939000 },
      'Ward 9': { lat: 11.297000, lng: 76.941000 },
    };

    for (const p of poles) {
      const pole_id = p.id;
      const pole_no = p.pole_number || `P-${p.id}`;
      const keypad_id = p.keypad_id || String(p.id);
      const ward_no = p.ward ? (p.ward.ward_number ? `Ward ${p.ward.ward_number}` : (p.ward.name_en || '')) : (p.ward_id ? `Ward ${p.ward_id}` : 'General');
      const area = p.org_unit ? p.org_unit.name : 'Mettupalayam';
      const landmark = Array.isArray(p.landmarks) && p.landmarks.length > 0 ? p.landmarks.join('; ') : 'General Area';
      
      let lat = p.latitude;
      let lng = p.longitude;
      if (lat == null && MTP_COORDS[ward_no]) {
        lat = MTP_COORDS[ward_no].lat + (pole_id % 5) * 0.0003;
        lng = MTP_COORDS[ward_no].lng + (pole_id % 5) * 0.0003;
      } else if (lat == null) {
        lat = 11.300000;
        lng = 76.940000;
      }

      const latitude = Number(lat).toFixed(6);
      const longitude = Number(lng).toFixed(6);
      const status = 'Active';

      rows.push([
        escapeCsv(pole_id),
        escapeCsv(pole_no),
        escapeCsv(keypad_id),
        escapeCsv(ward_no),
        escapeCsv(area),
        escapeCsv(landmark),
        escapeCsv(latitude),
        escapeCsv(longitude),
        escapeCsv(status)
      ].join(','));
    }

    const csvContent = rows.join('\r\n');
    const outputPath = path.join(__dirname, '..', 'electric_poles.csv');
    fs.writeFileSync(outputPath, csvContent, 'utf8');
    console.log(`Successfully wrote ${rows.length - 1} poles to ${outputPath}`);
  } catch (err) {
    console.error('Error generating CSV:', err);
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

run();
