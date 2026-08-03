/**
 * Revenue: property tax demand and collection, market stall fees, advertising
 * campaigns, technician penalties, certificate requests, and bookable
 * community facilities.
 *
 * Collection rates are deliberately imperfect — a demand register where
 * everything is paid tells a revenue officer nothing, and the defaulter list,
 * which is the screen they actually live in, would be empty.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, dayAgo, daysAhead,
  recentBiased, personName, phone, address, doorNo, scatter, step, heading,
  bulk, STREETS,
} = require('./lib');

const CURRENT_FY = '2026-27';
const PREV_FY = '2025-26';

const BUSINESS_TYPES = [
  'Vegetables', 'Fruits', 'Flowers', 'Fish', 'Meat', 'Provisions',
  'Textiles', 'Footwear', 'Plastic goods', 'Pottery', 'Snacks', 'Tea stall',
];

async function seedRevenue(ctx) {
  heading('Revenue');
  const { all } = ctx;

  // ── Property tax register ─────────────────────────────────────────────────
  if ((await prisma.taxProperty.count()) === 0) {
    const TYPES = ['residential', 'residential', 'residential', 'commercial', 'vacant_land', 'industrial'];
    const propRows = [];
    for (const org of all) {
      const count = org.branch_type === 'MUNICIPAL_CORPORATION' ? 70 : 35;
      for (let i = 0; i < count; i++) {
        const type = pick(TYPES);
        const area = type === 'industrial' ? int(2000, 20000)
          : type === 'commercial' ? int(400, 5000)
          : type === 'vacant_land' ? int(600, 8000)
          : int(450, 3000);
        // Rough TN slab: commercial and industrial carry a much higher rate.
        const rate = type === 'commercial' ? 6.5 : type === 'industrial' ? 8
          : type === 'vacant_land' ? 1.2 : 2.4;
        const loc = scatter(0.08);
        propRows.push({
          org_unit_id: org.id,
          owner_name: personName(),
          owner_phone: phone(),
          // Unique per branch: the table carries a (org_unit_id, door_number)
          // constraint, so a random door number collides within a few dozen
          // rows. A ward-qualified number is also what a real register uses.
          door_number: `${int(1, 60)}/${String(i + 1).padStart(3, '0')}`,
          address: `${pick(STREETS)}, Ward ${int(1, 60)}, ${org.district ?? 'Coimbatore'}`,
          property_type: type,
          area_sqft: area,
          latitude: loc.latitude,
          longitude: loc.longitude,
          annual_tax: Math.round(area * rate),
          status: chance(0.96) ? 'active' : pick(['demolished', 'exempted']),
        });
      }
    }
    step('tax properties', await bulk(prisma.taxProperty, propRows));

    // Two years of demand, so year-on-year collection is comparable.
    const props = await prisma.taxProperty.findMany({
      where: { status: 'active' },
      select: { id: true, annual_tax: true },
    });
    const demandRows = [];
    for (const prop of props) {
      for (const [fy, dueDays, paidChance] of [
        [PREV_FY, 400, 0.9],
        [CURRENT_FY, -60, 0.62],
      ]) {
        const demand = Number(prop.annual_tax);
        const paid = chance(paidChance);
        const partial = !paid && chance(0.25);
        const paidAmount = paid ? demand : partial ? Math.round(demand * dec(0.2, 0.7)) : 0;
        const overdue = !paid && dueDays > 0;
        demandRows.push({
          property_id: prop.id,
          financial_year: fy,
          demand_amount: demand,
          penalty_amount: overdue ? Math.round(demand * 0.02 * int(1, 6)) : 0,
          paid_amount: paidAmount,
          payment_method: paidAmount > 0 ? pick(['upi', 'upi', 'razorpay', 'cash', 'bank_transfer']) : null,
          transaction_ref: paidAmount > 0 ? `TXN${int(100000000, 999999999)}` : null,
          paid_at: paidAmount > 0 ? daysAgo(int(5, dueDays > 0 ? 380 : 55)) : null,
          status: paid ? 'paid' : partial ? 'partial' : overdue ? 'overdue' : 'unpaid',
          due_date: dueDays > 0 ? daysAgo(dueDays) : daysAhead(-dueDays),
        });
      }
    }
    step('tax demands', await bulk(prisma.taxPayment, demandRows));
  } else {
    step('property tax (already present)');
  }

  // ── Market stall fees ─────────────────────────────────────────────────────
  if ((await prisma.marketDay.count()) === 0) {
    const MARKETS = [
      ['Uzhavar Sandhai', 'Gandhipuram', 2], ['Weekly Shandy', 'Ukkadam', 5],
      ['Daily Vegetable Market', 'Town Hall', 1], ['Flower Market', 'RS Puram', 6],
      ['Fish Market', 'Singanallur', 0],
    ];
    let m = 0;
    for (const org of all.slice(0, 5)) {
      for (const [name, loc, dow] of pickN(MARKETS, 3)) {
        await prisma.marketDay.create({
          data: {
            org_unit_id: org.id, name, location: loc,
            day_of_week: dow, daily_fee: pick([20, 30, 40, 50, 75]),
            is_active: true,
          },
        });
        m++;
      }
    }
    step('market days', m);

    let v = 0;
    for (const org of all.slice(0, 5)) {
      for (let i = 0; i < 24; i++) {
        await prisma.marketVendor.create({
          data: {
            org_unit_id: org.id,
            vendor_name: personName(),
            vendor_phone: phone(),
            business_type: pick(BUSINESS_TYPES),
            is_active: chance(0.92),
            registered_at: daysAgo(int(30, 900)),
          },
        });
        v++;
      }
    }
    step('market vendors', v);

    const days = await prisma.marketDay.findMany();
    const vendors = await prisma.marketVendor.findMany({ where: { is_active: true } });
    const collectors = await prisma.user.findMany({
      where: { role: { in: ['revenue_inspector', 'bill_collector'] } },
    });
    const payRows = [];
    for (const vendor of vendors) {
      const market = pick(days.filter((d) => d.org_unit_id === vendor.org_unit_id)) ?? pick(days);
      // Roughly weekly attendance over the last four months.
      for (let w = 0; w < int(6, 18); w++) {
        payRows.push({
          vendor_id: vendor.id,
          market_day_id: market.id,
          amount_paid: market.daily_fee,
          payment_method: pick(['cash', 'cash', 'cash', 'upi']),
          collected_by: collectors.length ? pick(collectors).email : 'Counter',
          paid_at: daysAgo(w * 7 + int(0, 3)),
        });
      }
    }
    step('market fee collections', await bulk(prisma.marketVendorPayment, payRows));
  } else {
    step('market fees (already present)');
  }

  // ── Advertising campaigns ─────────────────────────────────────────────────
  if ((await prisma.adCampaign.count()) === 0) {
    const ADVERTISERS = [
      ['Sri Krishna Sweets', 'Festival season offer'],
      ['Kumaran Silks', 'Wedding collection launch'],
      ['PSG Hospitals', 'Free diabetes screening camp'],
      ['Annapoorna Restaurant', 'New branch opening'],
      ['Coimbatore Cotton Mills', 'Recruitment drive'],
      ['Sakthi Finance', 'Gold loan at 0.99%'],
      ['GRD Driving School', 'Learn to drive in 15 days'],
      ['Nilgiris Supermarket', 'Weekend grocery offers'],
      ['KMCH', 'Cardiology consultation camp'],
      ['Tamil Nadu Electricity Board', 'Save energy public notice'],
    ];
    const poles = await prisma.electricPole.findMany({ take: 60, select: { id: true } });
    const zones = await prisma.zone.findMany({ select: { id: true } });
    let a = 0;
    for (const org of all.slice(0, 4)) {
      for (const [advertiser, title] of pickN(ADVERTISERS, 6)) {
        const type = pick(['basic', 'standard', 'standard', 'premium']);
        const startDays = int(-30, 120);
        const durationDays = pick([30, 60, 90]);
        const impressions = type === 'premium' ? int(4000, 22000)
          : type === 'standard' ? int(1200, 7000) : int(200, 1800);
        await prisma.adCampaign.create({
          data: {
            org_unit_id: org.id,
            advertiser_name: advertiser,
            advertiser_phone: phone(),
            title,
            description: `${title} — displayed on QR panels across ${org.name}.`,
            image_url: `/uploads/ads/${advertiser.toLowerCase().replace(/\s+/g, '-')}.jpg`,
            link_url: 'https://example.tn.gov.in/ad',
            campaign_type: type,
            target_zone_ids: zones.length ? pickN(zones, int(1, 3)).map((z) => z.id) : [],
            target_pole_ids: poles.length ? pickN(poles, int(3, 12)).map((p) => p.id) : [],
            amount_paid: type === 'premium' ? int(40000, 120000)
              : type === 'standard' ? int(12000, 38000) : int(3000, 10000),
            starts_at: daysAgo(startDays),
            ends_at: daysAgo(startDays - durationDays),
            is_active: startDays > 0 && startDays < durationDays,
            total_impressions: impressions,
            total_clicks: Math.round(impressions * dec(0.01, 0.08, 3)),
          },
        });
        a++;
      }
    }
    step('ad campaigns', a);

    const campaigns = await prisma.adCampaign.findMany({ take: 12, select: { id: true } });
    const impRows = [];
    for (const c of campaigns) {
      for (let i = 0; i < 40; i++) {
        impRows.push({
          campaign_id: c.id,
          pole_id: poles.length ? pick(poles).id : null,
          device_ip: `10.${int(0, 255)}.${int(0, 255)}.${int(1, 254)}`,
          scanned_at: daysAgo(recentBiased(90)),
          clicked: chance(0.06),
        });
      }
    }
    step('ad impressions', await bulk(prisma.adImpression, impRows));
  } else {
    step('ad campaigns (already present)');
  }

  // ── Technician penalties ──────────────────────────────────────────────────
  if ((await prisma.penaltyRule.count()) === 0) {
    let r = 0;
    for (const org of all) {
      for (const role of ['electrician', 'plumber']) {
        for (const [urgency, hours, amount] of [
          ['critical', 4, 1000], ['high', 12, 500],
          ['medium', 24, 250], ['low', 72, 100],
        ]) {
          await prisma.penaltyRule.create({
            data: {
              org_unit_id: org.id, role, urgency_level: urgency,
              deadline_hours: hours, penalty_amount: amount, is_active: true,
            },
          });
          r++;
        }
      }
    }
    step('penalty rules', r);

    // Penalties only against complaints that were genuinely resolved late.
    const late = await prisma.complaint.findMany({
      where: {
        status: { in: ['resolved', 'closed'] },
        urgency_level: { in: ['high', 'critical'] },
        assigned_at: { not: null }, resolved_at: { not: null },
      },
      take: 120,
    });
    let p = 0;
    for (const c of late) {
      const hours = (c.resolved_at - c.assigned_at) / 3600000;
      const deadline = c.urgency_level === 'critical' ? 4 : 12;
      if (hours <= deadline) continue;
      const uid = c.assigned_electrician_id ?? c.assigned_plumber_id;
      if (!uid) continue;
      const delay = Number((hours - deadline).toFixed(1));
      await prisma.userPenalty.create({
        data: {
          user_id: uid, complaint_id: c.id,
          amount: c.urgency_level === 'critical' ? 1000 : 500,
          reason: `Resolved ${delay}h past the ${deadline}h deadline for a ${c.urgency_level} complaint.`,
          hours_delayed: delay,
          status: pick(['pending', 'pending', 'deducted', 'waived']),
          waived_reason: chance(0.15) ? 'Vehicle breakdown; supervisor verified.' : null,
          created_at: c.resolved_at,
        },
      });
      p++;
    }
    step('technician penalties', p);
  } else {
    step('penalties (already present)');
  }

  // ── Certificate requests ──────────────────────────────────────────────────
  if ((await prisma.certificateRequest.count()) === 0) {
    const TYPES = [
      ['birth', 50], ['death', 50], ['income', 100],
      ['residence', 100], ['trade_license', 500], ['building_permit', 1000],
    ];
    const crypto = require('crypto');
    let c = 0;
    for (const org of all.slice(0, 5)) {
      for (let i = 0; i < 30; i++) {
        const [type, fee] = pick(TYPES);
        const applied = daysAgo(recentBiased(150));
        const status = pick(['approved', 'approved', 'approved', 'pending', 'pending', 'rejected']);
        const approved = status === 'approved';
        await prisma.certificateRequest.create({
          data: {
            org_unit_id: org.id,
            certificate_type: type,
            applicant_name: personName(),
            applicant_phone: phone(),
            applicant_email: chance(0.4) ? `applicant${c}@example.com` : null,
            application_data: { purpose: pick(['Bank loan', 'School admission', 'Passport', 'Scholarship', 'Court']), ward: int(1, 60) },
            fee_amount: fee,
            payment_status: approved || chance(0.7) ? 'paid' : 'unpaid',
            payment_ref: approved ? `RCPT${int(100000, 999999)}` : null,
            review_status: status,
            reviewer_notes: status === 'rejected'
              ? pick(['Supporting documents incomplete.', 'Applicant details do not match the register.', 'Duplicate application.'])
              : null,
            certificate_url: approved ? `/uploads/certificates/cert-${c}.pdf` : null,
            certificate_qr: approved ? crypto.randomBytes(16).toString('hex') : null,
            applied_at: applied,
            reviewed_at: status !== 'pending' ? new Date(applied.getTime() + int(1, 12) * 86400000) : null,
            issued_at: approved ? new Date(applied.getTime() + int(2, 14) * 86400000) : null,
          },
        });
        c++;
      }
    }
    step('certificate requests', c);
  } else {
    step('certificate requests (already present)');
  }

  // ── Community facilities and bookings ─────────────────────────────────────
  if ((await prisma.bookableFacility.count()) === 0) {
    const FACILITIES = [
      ['Corporation Kalyana Mandapam', 'hall', 12000, 1500, 600],
      ['Ward Community Hall', 'hall', 4000, 500, 200],
      ['Municipal Playground', 'ground', 3000, 400, 500],
      ['Open Air Auditorium', 'ground', 8000, 1000, 1200],
      ['Water Tanker (6000L)', 'vehicle', 2500, 400, null],
      ['Public Address System', 'equipment', 1500, 250, null],
      ['Shamiana & Chairs (200)', 'equipment', 6000, 900, null],
    ];
    let f = 0;
    for (const org of all.slice(0, 5)) {
      for (const [name, type, daily, hourly, cap] of pickN(FACILITIES, 4)) {
        await prisma.bookableFacility.create({
          data: {
            org_unit_id: org.id, name, facility_type: type,
            description: `${name} available for public booking through the ${org.name} office.`,
            daily_rate: daily, hourly_rate: hourly,
            deposit_amount: Math.round(daily * 0.25),
            max_capacity: cap, is_available: chance(0.9),
          },
        });
        f++;
      }
    }
    step('bookable facilities', f);

    const facilities = await prisma.bookableFacility.findMany();
    let b = 0;
    for (const fac of facilities) {
      for (let i = 0; i < int(3, 9); i++) {
        const startOffset = int(-90, 45);
        const days = int(1, 3);
        const total = Number(fac.daily_rate) * days;
        const past = startOffset > 0;
        const status = past
          ? pick(['completed', 'completed', 'completed', 'cancelled'])
          : pick(['confirmed', 'confirmed', 'pending']);
        const cancelled = status === 'cancelled';
        await prisma.facilityBooking.create({
          data: {
            facility_id: fac.id,
            booked_by_name: personName(),
            booked_by_phone: phone(),
            event_type: pick(['Wedding', 'Reception', 'Birthday', 'Public meeting', 'Religious function', 'Sports event', 'Training']),
            start_date: daysAgo(startOffset),
            end_date: daysAgo(startOffset - days),
            total_amount: total,
            deposit_paid: Number(fac.deposit_amount),
            balance_amount: cancelled ? 0 : status === 'pending' ? total - Number(fac.deposit_amount) : 0,
            payment_ref: `BKG${int(100000, 999999)}`,
            booking_status: status,
            cancelled_at: cancelled ? daysAgo(startOffset + int(1, 10)) : null,
            cancellation_fee: cancelled ? Math.round(total * 0.1) : null,
          },
        });
        b++;
      }
    }
    step('facility bookings', b);
  } else {
    step('facilities (already present)');
  }
}

module.exports = { seedRevenue, CURRENT_FY, PREV_FY };
