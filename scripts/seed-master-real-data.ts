import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as dotenv from 'dotenv';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';

dotenv.config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🚀 Starting Master Realistic Dummy Data Seeding...');

  const tenantId = 'default';

  // 1. Tenant
  await prisma.tenant.upsert({
    where: { id: tenantId },
    update: { is_active: true },
    create: {
      id: tenantId,
      name: 'Tamil Nadu Municipal Governance Portal',
      subscription: 'enterprise',
      is_active: true,
    },
  });
  console.log('✅ Tenant initialized.');

  // 2. Panchayats / Branches
  const panchayatsData = [
    { name: 'Thayanur Village Panchayat', ivr_number: '04440115043', center_lat: 11.0168, center_lng: 76.9558, branch_code: 'THAY-001', branch_type: 'VILLAGE_PANCHAYAT' as const },
    { name: 'Tholampalay Town Panchayat', ivr_number: '04440115434', center_lat: 11.2420, center_lng: 76.9520, branch_code: 'THOL-002', branch_type: 'TOWN_PANCHAYAT' as const },
    { name: 'Vadavalli Municipality', ivr_number: '04442123457', center_lat: 11.0234, center_lng: 76.9012, branch_code: 'VDVL-003', branch_type: 'MUNICIPALITY' as const },
    { name: 'Kovilpatti Municipal Corporation', ivr_number: '04443123458', center_lat: 9.1700, center_lng: 77.8700, branch_code: 'KVPT-004', branch_type: 'MUNICIPAL_CORPORATION' as const },
  ];

  const createdPanchayats: any[] = [];
  for (const p of panchayatsData) {
    let panchayat = await prisma.orgUnit.findFirst({
      where: {
        OR: [
          { ivr_number: p.ivr_number },
          { branch_code: p.branch_code },
          { name: { contains: p.name.split(' ')[0] } }
        ]
      },
    });
    if (!panchayat) {
      panchayat = await prisma.orgUnit.create({
        data: {
          tenant_id: tenantId,
          name: p.name,
          ivr_number: p.ivr_number,
          center_lat: p.center_lat,
          center_lng: p.center_lng,
          branch_code: p.branch_code,
          branch_type: p.branch_type,
          branch_status: 'ACTIVE',
        },
      });
    }
    createdPanchayats.push(panchayat);
  }
  console.log(`✅ ${createdPanchayats.length} Panchayats/Branches initialized.`);

  const mainBranch = createdPanchayats[0];
  const covilBranch = createdPanchayats[3];

  // 3. System Users & Employees
  const passwordHash = await bcrypt.hash('Admin@1234', 10);
  const usersData = [
    { email: 'superadmin@sengotics.gov.in', role: 'super_admin', phone: '+919999999999', panchayat_id: null },
    { email: 'admin@thayanur.gov.in', role: 'panchayat_admin', phone: '+919876543001', panchayat_id: mainBranch.id },
    { email: 'electrician.suresh@sengotics.gov.in', role: 'electrician', phone: '+919876543210', panchayat_id: mainBranch.id },
    { email: 'plumber.kannan@sengotics.gov.in', role: 'plumber', phone: '+919876543211', panchayat_id: mainBranch.id },
    { email: 'admin@kovilpatti.gov.in', role: 'panchayat_admin', phone: '+919876543004', panchayat_id: covilBranch.id },
  ];

  const createdUsers: Record<string, any> = {};
  for (const u of usersData) {
    let user = await prisma.user.findFirst({
      where: {
        OR: [
          { email: u.email },
          { phone_e164: u.phone },
        ],
      },
    });
    if (!user) {
      user = await prisma.user.create({
        data: {
          tenant_id: tenantId,
          email: u.email,
          password_hash: passwordHash,
          role: u.role,
          phone_e164: u.phone,
          panchayat_id: u.panchayat_id,
        },
      });
    }
    createdUsers[u.role] = user;
  }
  console.log('✅ Users initialized.');

  // 4. Electric Pole & Complaint
  let pole = await prisma.electricPole.findFirst({ where: { panchayat_id: mainBranch.id } });
  if (!pole) {
    pole = await prisma.electricPole.create({
      data: {
        panchayat_id: mainBranch.id,
        pole_number: 'TY-PL-001',
        keypad_id: 'TY-KEY-01',
        latitude: 11.0170,
        longitude: 76.9560,
        public_report_token: randomUUID(),
        landmarks: ['near Mariamman Temple', 'மாரியம்மன் கோவில் அருகில்'],
      },
    });
  }

  const complaint = await prisma.complaint.create({
    data: {
      pole_id: pole.id,
      panchayat_id: mainBranch.id,
      complaint_type: 'street_light_failure',
      description: 'Street light lamp flickering heavily on main junction',
      status: 'assigned',
      assigned_electrician_id: createdUsers['electrician'].id,
      assigned_at: new Date(),
      created_at: new Date(Date.now() - 36 * 60 * 60 * 1000),
    },
  });
  console.log('✅ Electric Pole & Complaint created.');

  // 5. Community Asset Rental Data
  const assetsData = [
    {
      name: 'Thayanur Panchayat Community Hall',
      asset_type: 'hall',
      description: 'Air-conditioned community hall with 600 seating capacity, stage, and dining hall.',
      daily_rate: 7500.00,
      deposit_amount: 2500.00,
      max_capacity: 600,
      is_available: true,
    },
    {
      name: 'Vadavalli Mini Auditorium',
      asset_type: 'auditorium',
      description: 'Indoor auditorium with projector, sound system, and central AC.',
      daily_rate: 12000.00,
      deposit_amount: 5000.00,
      max_capacity: 350,
      is_available: true,
    },
  ];

  for (const a of assetsData) {
    const asset = await prisma.panchayatAsset.create({
      data: {
        panchayat_id: mainBranch.id,
        name: a.name,
        asset_type: a.asset_type,
        description: a.description,
        daily_rate: a.daily_rate,
        deposit_amount: a.deposit_amount,
        max_capacity: a.max_capacity,
        is_available: a.is_available,
      },
    });

    await prisma.assetBooking.create({
      data: {
        asset_id: asset.id,
        booked_by_name: 'M. Senthilkumar',
        booked_by_phone: '9443322110',
        event_type: 'Marriage Ceremony',
        start_date: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
        end_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        total_amount: a.daily_rate * 2,
        deposit_paid: a.deposit_amount,
        balance_amount: a.daily_rate * 2 - a.deposit_amount,
        booking_status: 'confirmed',
        payment_ref: `TXN-BOOK-${randomUUID().substring(0, 8)}`,
      },
    });
  }
  console.log('✅ Community Asset Rental data seeded.');

  // 6. Certificate Reviews Data
  const certTypes = ['birth', 'death', 'trade_license', 'income', 'property_ownership'];
  for (let i = 0; i < certTypes.length; i++) {
    const certType = certTypes[i];
    await prisma.certificateRequest.create({
      data: {
        panchayat_id: mainBranch.id,
        certificate_type: certType,
        applicant_name: `Applicant ${i + 1} - ${certType.toUpperCase()}`,
        applicant_phone: `987650000${i}`,
        applicant_email: `applicant${i + 1}@example.com`,
        fee_amount: 100.00,
        payment_status: 'paid',
        payment_ref: `PAY-CERT-${randomUUID().substring(0, 8)}`,
        review_status: i % 2 === 0 ? 'pending' : 'approved',
        reviewer_notes: i % 2 !== 0 ? 'Verified with revenue inspector records. Approved.' : null,
        application_data: {
          address: 'Ward 4, Main Road, Thayanur',
          purpose: 'Official verification and banking records',
          submitted_at: new Date().toISOString(),
        },
      },
    });
  }
  console.log('✅ Certificate Reviews data seeded.');

  // 7. Ad Campaigns Data
  const adCampaign = await prisma.adCampaign.create({
    data: {
      panchayat_id: mainBranch.id,
      advertiser_name: 'Annamalai Real Estate & Builders',
      advertiser_phone: '9845012345',
      title: 'Green Meadows Luxury Gated Community Plots',
      description: 'DTCP Approved plots in Thayanur Main Road. 100% bank loan available.',
      image_url: 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=600',
      link_url: 'https://www.annamalai-builders.com',
      campaign_type: 'premium',
      amount_paid: 10000.00,
      starts_at: new Date(),
      ends_at: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000),
      is_active: true,
    },
  });

  await prisma.adImpression.create({
    data: {
      campaign_id: adCampaign.id,
      pole_id: pole.id,
      device_ip: '10.0.0.12',
      clicked: true,
    },
  });
  console.log('✅ Ad Campaigns data seeded.');

  // 8. Technician Penalties Data
  await prisma.penaltyRule.upsert({
    where: {
      panchayat_id_role_urgency_level: {
        panchayat_id: mainBranch.id,
        role: 'electrician',
        urgency_level: 'high',
      },
    },
    update: {},
    create: {
      panchayat_id: mainBranch.id,
      role: 'electrician',
      urgency_level: 'high',
      deadline_hours: 12,
      penalty_amount: 250.00,
    },
  });

  await prisma.userPenalty.create({
    data: {
      user_id: createdUsers['electrician'].id,
      complaint_id: complaint.id,
      amount: 250.00,
      hours_delayed: 24.0,
      reason: '12-hour high-urgency street light breakdown SLA exceeded by 24 hours.',
      status: 'pending',
    },
  });
  console.log('✅ Technician Penalties data seeded.');

  // 9. Property Tax & Shandy Market Data
  const property = await prisma.property.create({
    data: {
      panchayat_id: mainBranch.id,
      owner_name: 'K. Balasubramanian',
      owner_phone: '9443101010',
      door_number: '45/B, Temple Street',
      address: 'Ward 1, Thayanur',
      property_type: 'commercial',
      area_sqft: 2200,
      latitude: 11.0169,
      longitude: 76.9559,
      annual_tax: 2400.00,
    },
  });

  await prisma.taxPayment.create({
    data: {
      property_id: property.id,
      financial_year: '2025-26',
      demand_amount: 2400.00,
      penalty_amount: 240.00,
      paid_amount: 2640.00,
      status: 'paid',
      due_date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
      paid_at: new Date(),
    },
  });

  const marketDay = await prisma.marketDay.create({
    data: {
      panchayat_id: mainBranch.id,
      name: 'Thayanur Weekly Farmer Shandy',
      location: 'Bus Stand Ground',
      day_of_week: 0,
      daily_fee: 50.00,
    },
  });

  const marketVendor = await prisma.marketVendor.create({
    data: {
      panchayat_id: mainBranch.id,
      vendor_name: 'P. Velusamy (Vegetables)',
      vendor_phone: '9876512345',
      business_type: 'Vegetables',
      vendor_token: randomUUID(),
      is_active: true,
    },
  });

  await prisma.marketVendorPayment.create({
    data: {
      market_day_id: marketDay.id,
      vendor_id: marketVendor.id,
      amount_paid: 50.00,
      payment_method: 'cash',
      collected_by: 'Inspector Sundaram',
    },
  });
  console.log('✅ Property Tax & Shandy Market data seeded.');

  // 10. Water Infrastructure Data
  await prisma.waterPipeline.create({
    data: {
      panchayat_id: mainBranch.id,
      name: 'Thayanur North Feeder Line',
      diameter_mm: 200,
      material: 'HDPE',
      status: 'active',
      path_geojson: { type: 'LineString', coordinates: [[76.9550, 11.0160], [76.9560, 11.0170], [76.9570, 11.0180]] },
    },
  });
  console.log('✅ Water Infrastructure data seeded.');

  console.log('🎉 Master Realistic Dummy Data Seeding Complete Successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding Error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
