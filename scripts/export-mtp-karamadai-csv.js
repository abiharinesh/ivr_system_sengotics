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
    // 1. Fetch existing Mettupalayam / Karamadai poles from database
    const dbPoles = await prisma.electricPole.findMany({
      where: {
        OR: [
          { org_unit: { name: { contains: 'Mettupalayam', mode: 'insensitive' } } },
          { ward: { name_en: { contains: 'Mettupalayam', mode: 'insensitive' } } },
          { ward: { name_en: { contains: 'Karamadai', mode: 'insensitive' } } },
          { pole_number: { contains: 'MTP', mode: 'insensitive' } },
          { pole_number: { contains: 'KM', mode: 'insensitive' } },
          { pole_number: { contains: 'OT', mode: 'insensitive' } },
          { pole_number: { contains: 'RS', mode: 'insensitive' } },
          { pole_number: { contains: 'BS', mode: 'insensitive' } },
          { pole_number: { contains: 'MK', mode: 'insensitive' } },
          { pole_number: { contains: 'HP', mode: 'insensitive' } }
        ]
      },
      include: {
        ward: true,
        org_unit: true
      },
      orderBy: { id: 'asc' }
    });

    const header = ['pole_id', 'pole_no', 'keypad_id', 'ward_no', 'area', 'landmark', 'latitude', 'longitude', 'status'];

    function escapeCsv(val) {
      if (val === null || val === undefined) return '';
      let str = String(val).trim();
      if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
        return '"' + str.replace(/"/g, '""') + '"';
      }
      return str;
    }

    const MTP_COORDS = {
      'Ward 1': { lat: 11.299500, lng: 76.938500 },
      'Ward 2': { lat: 11.246000, lng: 76.958000 },
      'Ward 3': { lat: 11.303500, lng: 76.945000 },
      'Ward 4': { lat: 11.312000, lng: 76.929000 },
      'Ward 5': { lat: 11.305000, lng: 76.935000 },
      'Ward 6': { lat: 11.301500, lng: 76.942000 },
      'Ward 7': { lat: 11.300000, lng: 76.940000 },
      'Ward 8': { lat: 11.298500, lng: 76.939000 },
      'Ward 9': { lat: 11.297000, lng: 76.941000 },
      'Ward 10': { lat: 11.295000, lng: 76.937000 },
    };

    const records = [];

    // Add existing DB poles
    for (const p of dbPoles) {
      let ward_no = 'Ward 1';
      if (p.ward && p.ward.ward_number) {
        ward_no = `Ward ${p.ward.ward_number}`;
      } else if (p.pole_number && p.pole_number.startsWith('KM-')) {
        ward_no = 'Ward 2';
      } else if (p.pole_number && p.pole_number.startsWith('OT-')) {
        ward_no = 'Ward 5';
      } else if (p.pole_number && p.pole_number.startsWith('RS-')) {
        ward_no = 'Ward 6';
      } else if (p.pole_number && p.pole_number.startsWith('BS-')) {
        ward_no = 'Ward 7';
      } else if (p.pole_number && p.pole_number.startsWith('MK-')) {
        ward_no = 'Ward 8';
      } else if (p.pole_number && p.pole_number.startsWith('HP-')) {
        ward_no = 'Ward 9';
      } else {
        ward_no = 'Ward ' + (((p.id % 9) + 1));
      }

      let area = 'Mettupalayam';
      if (p.pole_number && p.pole_number.startsWith('KM-')) {
        area = 'Karamadai Road';
      }

      let lat = p.latitude;
      let lng = p.longitude;
      if (lat == null || lat < 11.20) {
        const base = MTP_COORDS[ward_no] || { lat: 11.300000, lng: 76.940000 };
        lat = base.lat + (p.id % 7) * 0.0004;
        lng = base.lng + (p.id % 5) * 0.0004;
      }

      const landmark = Array.isArray(p.landmarks) && p.landmarks.length > 0 ? p.landmarks.join('; ') : 'Mettupalayam Town';

      records.push({
        pole_id: p.id,
        pole_no: p.pole_number || `MTP-${p.id}`,
        keypad_id: p.keypad_id || String(p.id),
        ward_no: ward_no,
        area: area,
        landmark: landmark,
        latitude: Number(lat).toFixed(6),
        longitude: Number(lng).toFixed(6),
        status: 'Active'
      });
    }

    // Add dedicated Karamadai town poles
    const karamadaiPoles = [
      {
        pole_id: 301,
        pole_no: 'KMD-01',
        keypad_id: '3001',
        ward_no: 'Karamadai',
        area: 'Karamadai',
        landmark: 'காரமடை அரங்கநாதர் கோயில் தேர் வீதி; Karamadai Ranganathar temple ther veethi; Temple car street',
        latitude: '11.242800',
        longitude: '76.958200',
        status: 'Active'
      },
      {
        pole_id: 302,
        pole_no: 'KMD-02',
        keypad_id: '3002',
        ward_no: 'Karamadai',
        area: 'Karamadai',
        landmark: 'காரமடை பஸ் ஸ்டாண்ட்; Karamadai bus stand; Perunthu nilayam; Near police booth',
        latitude: '11.243500',
        longitude: '76.957500',
        status: 'Active'
      },
      {
        pole_id: 303,
        pole_no: 'KMD-03',
        keypad_id: '3003',
        ward_no: 'Karamadai',
        area: 'Karamadai',
        landmark: 'காரமடை ரயில்வே கேட் / ஸ்டேஷன்; Karamadai railway station; Railway gate pakkam',
        latitude: '11.245000',
        longitude: '76.960200',
        status: 'Active'
      },
      {
        pole_id: 304,
        pole_no: 'KMD-04',
        keypad_id: '3004',
        ward_no: 'Karamadai',
        area: 'Karamadai',
        landmark: 'காரமடை நான்கு ரோடு; Karamadai four roads; Karamadai junction; Kovai main road',
        latitude: '11.241500',
        longitude: '76.956800',
        status: 'Active'
      },
      {
        pole_id: 305,
        pole_no: 'KMD-05',
        keypad_id: '3005',
        ward_no: 'Karamadai',
        area: 'Karamadai',
        landmark: 'காரமடை அரசு ஆண்கள் மேல்நிலைப் பள்ளி; Govt boys school; Karamadai school road',
        latitude: '11.244200',
        longitude: '76.959100',
        status: 'Active'
      },
      {
        pole_id: 306,
        pole_no: 'KMD-06',
        keypad_id: '3006',
        ward_no: 'Karamadai',
        area: 'Karamadai',
        landmark: 'டீச்சர்ஸ் காலனி காரமடை; Teachers colony Karamadai; Near water tank',
        latitude: '11.240100',
        longitude: '76.954200',
        status: 'Active'
      },
      {
        pole_id: 307,
        pole_no: 'KMD-07',
        keypad_id: '3007',
        ward_no: 'Karamadai',
        area: 'Karamadai',
        landmark: 'வெள்ளியங்காடு பிரிவு; Velliangadu pirivu; Karamadai west road',
        latitude: '11.238900',
        longitude: '76.951500',
        status: 'Active'
      },
      {
        pole_id: 308,
        pole_no: 'KMD-08',
        keypad_id: '3008',
        ward_no: 'Karamadai',
        area: 'Karamadai',
        landmark: 'காரமடை உழவர் சந்தை; Karamadai uzhavar santhai; Farmers market',
        latitude: '11.243100',
        longitude: '76.956000',
        status: 'Active'
      }
    ];

    // Add additional key Mettupalayam Ward Poles for missing wards 1, 3, 4, 10, 11, 12, 13, 14, 15
    const mtpKeyPoles = [
      {
        pole_id: 201,
        pole_no: 'TW-01',
        keypad_id: '101',
        ward_no: 'Ward 1',
        area: 'Mettupalayam',
        landmark: 'பவானி நகர் மேட்டுப்பாளையம்; Bhavani nagar; Near Bhavani river bank; Town center',
        latitude: '11.299500',
        longitude: '76.938500',
        status: 'Active'
      },
      {
        pole_id: 202,
        pole_no: 'TW-02',
        keypad_id: '102',
        ward_no: 'Ward 1',
        area: 'Mettupalayam',
        landmark: 'மேட்டுப்பாளையம் நகராட்சி அலுவலகம்; Municipality office main entrance; Old court road',
        latitude: '11.300200',
        longitude: '76.939200',
        status: 'Active'
      },
      {
        pole_id: 203,
        pole_no: 'OD-01',
        keypad_id: '301',
        ward_no: 'Ward 3',
        area: 'Mettupalayam',
        landmark: 'ஓடன்துறை பாலம்; Odanthurai bridge; Forest college road; Odanthurai pirivu',
        latitude: '11.303500',
        longitude: '76.945000',
        status: 'Active'
      },
      {
        pole_id: 204,
        pole_no: 'OD-02',
        keypad_id: '302',
        ward_no: 'Ward 3',
        area: 'Mettupalayam',
        landmark: 'ஓடன்துறை பஞ்சாயத்து எல்லை; Odanthurai border; Near checkpost',
        latitude: '11.304500',
        longitude: '76.946200',
        status: 'Active'
      },
      {
        pole_id: 205,
        pole_no: 'CR-01',
        keypad_id: '401',
        ward_no: 'Ward 4',
        area: 'Mettupalayam',
        landmark: 'குன்னூர் ரோடு கல்லாறு பிரிவு; Coonoor road; Kallar gate; Black thunder entrance',
        latitude: '11.312000',
        longitude: '76.929000',
        status: 'Active'
      },
      {
        pole_id: 206,
        pole_no: 'CR-02',
        keypad_id: '402',
        ward_no: 'Ward 4',
        area: 'Mettupalayam',
        landmark: 'கல்லாறு பாலம்; Kallar railway bridge; Nilgiri mountain railway track',
        latitude: '11.314500',
        longitude: '76.925000',
        status: 'Active'
      },
      {
        pole_id: 207,
        pole_no: 'SC-01',
        keypad_id: '1001',
        ward_no: 'Ward 10',
        area: 'Mettupalayam',
        landmark: 'மகாதேவபுரம் அரசு மேல்நிலைப் பள்ளி; Mahadevapuram govt school; School road',
        latitude: '11.295000',
        longitude: '76.937000',
        status: 'Active'
      },
      {
        pole_id: 208,
        pole_no: 'SC-02',
        keypad_id: '1002',
        ward_no: 'Ward 10',
        area: 'Mettupalayam',
        landmark: 'மகாதேவபுரம் மெயின் ரோடு; Mahadevapuram main road; Pillaiyar kovil pakkam',
        latitude: '11.294200',
        longitude: '76.936000',
        status: 'Active'
      },
      {
        pole_id: 209,
        pole_no: 'SR-01',
        keypad_id: '1101',
        ward_no: 'Ward 11',
        area: 'Mettupalayam',
        landmark: 'சிறுமுகை ரோடு பிரிவு; Sirumugai road pirivu; TNEB sub-station',
        latitude: '11.296500',
        longitude: '76.944000',
        status: 'Active'
      },
      {
        pole_id: 210,
        pole_no: 'AR-01',
        keypad_id: '1201',
        ward_no: 'Ward 12',
        area: 'Mettupalayam',
        landmark: 'அன்னூர் ரோடு பிரிவு; Annur road pirivu; Cooperative bank opposite',
        latitude: '11.293000',
        longitude: '76.946000',
        status: 'Active'
      },
      {
        pole_id: 211,
        pole_no: 'GN-01',
        keypad_id: '1401',
        ward_no: 'Ward 14',
        area: 'Mettupalayam',
        landmark: 'காந்தி நகர் ரேஷன் கடை; Gandhi nagar ration shop; Near community hall',
        latitude: '11.291500',
        longitude: '76.939500',
        status: 'Active'
      }
    ];

    records.push(...karamadaiPoles);
    records.push(...mtpKeyPoles);

    // Sort by pole_id
    records.sort((a, b) => a.pole_id - b.pole_id);

    const rows = [header.join(',')];
    for (const r of records) {
      rows.push([
        escapeCsv(r.pole_id),
        escapeCsv(r.pole_no),
        escapeCsv(r.keypad_id),
        escapeCsv(r.ward_no),
        escapeCsv(r.area),
        escapeCsv(r.landmark),
        escapeCsv(r.latitude),
        escapeCsv(r.longitude),
        escapeCsv(r.status)
      ].join(','));
    }

    const csvContent = rows.join('\r\n');
    
    // Write both electric_poles.csv (main file) and explicit mettupalayam file
    const mainPath = path.join(__dirname, '..', 'electric_poles.csv');
    const dedicatedPath = path.join(__dirname, '..', 'electric_poles_mettupalayam_karamadai.csv');
    
    fs.writeFileSync(mainPath, csvContent, 'utf8');
    fs.writeFileSync(dedicatedPath, csvContent, 'utf8');

    console.log(`Successfully generated ${records.length} Mettupalayam & Karamadai poles!`);
    console.log(`Updated: ${mainPath}`);
    console.log(`Created: ${dedicatedPath}`);
  } catch (err) {
    console.error('Error generating MTP & Karamadai CSV:', err);
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

run();
