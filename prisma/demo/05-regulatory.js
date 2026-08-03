/**
 * Regulatory services: building permits, the birth & death register, and trade
 * licences — the three modules built in this branch.
 *
 * Each carries records at every lifecycle stage, because the screens are built
 * around the blockers. A register where everything is already approved would
 * hide the NOC checklist, the readiness panel and the renewal board, which are
 * the parts worth demonstrating.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, dayAgo, daysAhead,
  recentBiased, personName, maleName, femaleName, phone, doorNo, scatter,
  step, heading, bulk, STREETS,
} = require('./lib');

const crypto = require('crypto');
const token = () => crypto.randomBytes(24).toString('base64url');
const seal = () => crypto.randomBytes(32).toString('hex');

const HOSPITALS = [
  'Government Hospital, Coimbatore', 'PSG Hospitals', 'KMCH Coimbatore',
  'Kovai Medical Centre', 'Ganga Hospital', 'Sri Ramakrishna Hospital',
  'Primary Health Centre, Annur', 'ESI Hospital, Peelamedu',
];

async function seedRegulatory(ctx) {
  heading('Regulatory services');
  const { all } = ctx;
  const urban = all.filter((o) =>
    ['MUNICIPAL_CORPORATION', 'MUNICIPALITY', 'TOWN_PANCHAYAT'].includes(o.branch_type));
  const staff = await prisma.user.findMany({
    where: { role: { in: ['town_planning_officer', 'registrar', 'licensing_clerk', 'health_officer'] } },
  });
  const anyUser = staff[0]?.id ?? 1;

  // ── Building permits ──────────────────────────────────────────────────────
  if ((await prisma.buildingPermit.count()) === 0) {
    const STATUSES = [
      'DRAFT', 'SUBMITTED', 'SUBMITTED', 'SCRUTINY', 'NOC_PENDING',
      'NOC_PENDING', 'INSPECTION', 'APPROVED', 'APPROVED', 'APPROVED',
      'REJECTED', 'RETURNED',
    ];
    const CONSTRUCTION = ['residential', 'residential', 'residential', 'commercial', 'industrial', 'institutional', 'mixed'];
    const RATE = { residential: 30, commercial: 90, industrial: 75, institutional: 45, mixed: 60 };

    let n = 0;
    for (const org of urban) {
      const count = org.branch_type === 'MUNICIPAL_CORPORATION' ? 30 : 18;
      for (let i = 0; i < count; i++) {
        const status = pick(STATUSES);
        const type = pick(CONSTRUCTION);
        const plot = int(600, 6000);
        const floors = int(1, type === 'residential' ? 3 : 6);
        const builtUp = Math.round(plot * dec(0.4, 0.75) * floors);
        const scrutiny = Math.max(500, Math.round(builtUp * 10));
        const permitFee = Math.round(builtUp * RATE[type] * (floors > 3 ? 1.2 : 1));
        const devFee = Math.round(plot * 15);
        const total = scrutiny + permitFee + devFee;
        const age = recentBiased(240);
        const created = daysAgo(age);
        const approved = status === 'APPROVED';
        const paid = approved || chance(0.55);
        const loc = scatter(0.07);

        const permit = await prisma.buildingPermit.create({
          data: {
            tenant_id: 'default',
            org_unit_id: org.id,
            permit_number: `PERMIT-2026-27-${String(n + 1).padStart(4, '0')}`,
            applicant_name: personName(),
            applicant_phone: phone(),
            applicant_email: chance(0.5) ? `applicant${n}@example.com` : null,
            applicant_address: `${doorNo()}, ${pick(STREETS)}, ${org.district}`,
            applicant_aadhaar: `XXXXXXXX${int(1000, 9999)}`,
            is_owner: chance(0.85),
            survey_number: `${int(10, 480)}/${int(1, 9)}${pick(['A', 'B', 'C', ''])}`,
            ward_number: String(int(1, 60)),
            street_name: pick(STREETS),
            door_number: doorNo(),
            plot_area_sqm: plot,
            latitude: loc.latitude,
            longitude: loc.longitude,
            construction_type: type,
            work_nature: pick(['new', 'new', 'new', 'extension', 'alteration']),
            built_up_area_sqm: builtUp,
            floors_proposed: floors,
            height_m: dec(3.5, floors * 3.4, 1),
            setback_front_m: dec(1.5, 4.5, 1),
            setback_rear_m: dec(1, 3, 1),
            setback_left_m: dec(1, 2.5, 1),
            setback_right_m: dec(1, 2.5, 1),
            estimated_cost: builtUp * int(1200, 2600),
            architect_name: personName(),
            architect_licence: `TN/LS/${int(1000, 9999)}`,
            scrutiny_fee: scrutiny,
            permit_fee: permitFee,
            development_fee: devFee,
            total_fee: total,
            paid_amount: paid ? total : chance(0.3) ? Math.round(total * 0.4) : 0,
            payment_status: paid ? 'paid' : chance(0.3) ? 'partial' : 'unpaid',
            payment_ref: paid ? `RCPT${int(100000, 999999)}` : null,
            paid_at: paid ? new Date(created.getTime() + int(1, 20) * 86400000) : null,
            status,
            rejection_reason: status === 'REJECTED'
              ? pick([
                  'Setback on the northern side falls short of the required 1.5 m.',
                  'Proposed floor area exceeds the permissible FSI for this zone.',
                  'Site falls within the water-body buffer; no construction permitted.',
                ]) : null,
            approved_by: approved ? anyUser : null,
            approved_at: approved ? new Date(created.getTime() + int(20, 70) * 86400000) : null,
            valid_until: approved ? daysAhead(int(200, 1000)) : null,
            submitted_at: status === 'DRAFT' ? null : new Date(created.getTime() + 86400000),
            created_by: anyUser,
            created_at: created,
          },
        });

        // NOC checklist — the gate the approval screen is built around.
        const depts = type === 'residential'
          ? ['water', 'electricity']
          : type === 'industrial'
            ? ['fire', 'pollution', 'electricity', 'water', 'highways']
            : ['fire', 'traffic', 'electricity', 'water', 'health'];
        const allCleared = ['APPROVED', 'INSPECTION'].includes(status);
        await bulk(prisma.buildingPermitNoc, depts.map((d) => ({
          permit_id: permit.id,
          department: d,
          is_mandatory: true,
          status: allCleared ? 'GRANTED'
            : status === 'NOC_PENDING' ? pick(['GRANTED', 'PENDING', 'PENDING'])
            : status === 'REJECTED' ? pick(['REJECTED', 'PENDING'])
            : 'PENDING',
          reference_no: allCleared ? `${d.toUpperCase()}/${int(1000, 9999)}/2026` : null,
          cleared_by: allCleared ? anyUser : null,
          cleared_at: allCleared ? new Date(created.getTime() + int(10, 40) * 86400000) : null,
          requested_at: new Date(created.getTime() + 2 * 86400000),
        })));

        if (['INSPECTION', 'APPROVED'].includes(status)) {
          await prisma.buildingPermitInspection.create({
            data: {
              permit_id: permit.id,
              inspection_type: 'site_verification',
              scheduled_for: new Date(created.getTime() + int(25, 50) * 86400000),
              inspector_user_id: anyUser,
              status: 'completed',
              is_compliant: status === 'APPROVED' ? true : chance(0.7),
              findings: 'Site measurements verified against the submitted plan. Setbacks conform.',
              location_lat: loc.latitude, location_lng: loc.longitude,
              inspected_at: new Date(created.getTime() + int(26, 52) * 86400000),
            },
          });
        }
        n++;
      }
    }
    step('building permits', n);
    step('  permit NOCs', await prisma.buildingPermitNoc.count());
    step('  permit inspections', await prisma.buildingPermitInspection.count());
  } else {
    step('building permits (already present)');
  }

  // ── Birth & death register ────────────────────────────────────────────────
  if ((await prisma.vitalEvent.count()) === 0) {
    let births = 0, deaths = 0;
    for (const org of all.slice(0, 5)) {
      const count = org.branch_type === 'MUNICIPAL_CORPORATION' ? 45 : 22;
      for (let i = 0; i < count; i++) {
        const isBirth = chance(0.58);
        const age = recentBiased(300);
        const eventDate = dayAgo(age + int(0, 25));
        const reportedAt = daysAgo(age);
        const delayDays = Math.max(0, Math.floor((reportedAt - eventDate) / 86400000));
        const isLate = delayDays > 21;
        // Older reports are almost all registered by now.
        const status = age > 60
          ? pick(['REGISTERED', 'REGISTERED', 'REGISTERED', 'REGISTERED', 'CORRECTED'])
          : pick(['REGISTERED', 'REGISTERED', 'VERIFIED', 'REPORTED', 'REPORTED']);
        const registered = ['REGISTERED', 'CORRECTED'].includes(status);
        const source = pick(['HOSPITAL', 'HOSPITAL', 'HOSPITAL', 'DOMICILIARY', 'INSTITUTION']);
        const hospital = source === 'HOSPITAL' ? pick(HOSPITALS) : null;

        const event = await prisma.vitalEvent.create({
          data: {
            tenant_id: 'default',
            org_unit_id: org.id,
            event_type: isBirth ? 'BIRTH' : 'DEATH',
            registration_number: registered
              ? `${isBirth ? 'B' : 'D'}/2026/${String((isBirth ? births : deaths) + 1).padStart(6, '0')}`
              : null,
            status,
            event_date: eventDate,
            event_time: `${String(int(0, 23)).padStart(2, '0')}:${String(int(0, 59)).padStart(2, '0')}`,
            place_type: source === 'HOSPITAL' ? 'hospital' : pick(['home', 'institution']),
            place_name: hospital ?? `${pick(STREETS)} residence`,
            place_address: `${pick(STREETS)}, ${org.district}`,
            reporting_source: source,
            hospital_name: hospital,
            hospital_reg_no: hospital ? `TN/HOSP/${int(1000, 9999)}` : null,
            reported_at: reportedAt,
            informant_name: personName(),
            informant_relation: isBirth
              ? pick(['father', 'mother', 'hospital_official'])
              : pick(['son', 'daughter', 'husband', 'wife', 'brother', 'hospital_official']),
            informant_phone: phone(),
            informant_address: `${doorNo()}, ${pick(STREETS)}`,
            informant_aadhaar: `XXXXXXXX${int(1000, 9999)}`,
            is_late_registration: isLate,
            delay_days: delayDays,
            delay_approval_ref: isLate && delayDays > 30 ? `DR/CBE/2026/${int(100, 999)}` : null,
            registered_at: registered ? new Date(reportedAt.getTime() + int(1, 10) * 86400000) : null,
            registered_by: registered ? anyUser : null,
            correction_note: status === 'CORRECTED'
              ? 'Name spelling corrected per affidavit produced by the informant.' : null,
            created_by: anyUser,
            created_at: reportedAt,
          },
        });

        if (isBirth) {
          const male = chance(0.52);
          await prisma.birthDetail.create({
            data: {
              vital_event_id: event.id,
              child_name: chance(0.75) ? (male ? maleName() : femaleName()) : null,
              sex: male ? 'male' : 'female',
              weight_kg: dec(2.1, 4.2, 2),
              delivery_type: pick(['normal', 'normal', 'caesarean', 'caesarean', 'forceps']),
              father_name: maleName(),
              father_aadhaar: `XXXXXXXX${int(1000, 9999)}`,
              father_occupation: pick(['Farmer', 'Driver', 'Weaver', 'Teacher', 'Shopkeeper', 'Engineer', 'Labourer']),
              mother_name: femaleName(),
              mother_aadhaar: `XXXXXXXX${int(1000, 9999)}`,
              mother_occupation: pick(['Homemaker', 'Teacher', 'Nurse', 'Tailor', 'Labourer', 'Clerk']),
              mother_age_at_birth: int(20, 38),
              birth_order: int(1, 3),
              address_at_birth: `${doorNo()}, ${pick(STREETS)}`,
              permanent_address: `${doorNo()}, ${pick(STREETS)}, ${org.district}`,
              is_multiple_birth: chance(0.02),
            },
          });
          births++;
        } else {
          const male = chance(0.55);
          const years = pick([int(0, 1), int(45, 95), int(60, 92), int(70, 96), int(25, 60)]);
          await prisma.deathDetail.create({
            data: {
              vital_event_id: event.id,
              deceased_name: male ? maleName() : femaleName(),
              sex: male ? 'male' : 'female',
              age_years: years,
              age_months: years === 0 ? int(0, 11) : null,
              age_days: years === 0 ? int(1, 29) : null,
              father_name: maleName(),
              mother_name: femaleName(),
              spouse_name: years > 25 ? (male ? femaleName() : maleName()) : null,
              occupation: years > 18 ? pick(['Farmer', 'Retired', 'Weaver', 'Teacher', 'Homemaker', 'Driver']) : null,
              address: `${doorNo()}, ${pick(STREETS)}, ${org.district}`,
              cause_of_death: pick([
                'Cardiac arrest', 'Chronic renal failure', 'Road traffic accident',
                'Respiratory failure', 'Cerebrovascular accident', 'Old age',
                'Carcinoma', 'Septicaemia', 'Diabetes with complications',
              ]),
              cause_category: pick(['natural', 'natural', 'natural', 'natural', 'accident']),
              medically_certified: chance(0.7),
              certifying_doctor: chance(0.7) ? `Dr. ${personName()}` : null,
              doctor_reg_no: chance(0.7) ? `TNMC/${int(10000, 99999)}` : null,
              disposal_method: pick(['burial', 'cremation', 'cremation']),
              disposal_place: pick(['Municipal Crematorium', 'Village Burial Ground', 'Electric Crematorium, Ukkadam']),
              disposal_date: dayAgo(age - 1),
            },
          });
          deaths++;
        }

        // Certificates against registered entries.
        if (registered && chance(0.7)) {
          const copies = chance(0.2) ? 2 : 1;
          for (let c = 1; c <= copies; c++) {
            await prisma.vitalCertificate.create({
              data: {
                vital_event_id: event.id,
                certificate_number: `VC-2026-${String(int(1, 999999)).padStart(6, '0')}-${event.id}-${c}`,
                verification_token: token(),
                copy_number: c,
                issued_to: personName(),
                issued_to_relation: pick(['Father', 'Mother', 'Son', 'Daughter', 'Spouse', 'Self']),
                purpose: pick(['School admission', 'Passport', 'Bank account', 'Insurance claim', 'Pension', 'Property transfer']),
                fee_amount: c === 1 ? 0 : 50,
                seal_hash: seal(),
                issued_by: anyUser,
                issued_at: new Date(reportedAt.getTime() + int(5, 40) * 86400000),
              },
            });
          }
        }
      }
    }
    step('vital events', births + deaths);
    step('  births / deaths', `${births} / ${deaths}`);
    step('  certificates', await prisma.vitalCertificate.count());
  } else {
    step('vital events (already present)');
  }

  // ── Trade licences ────────────────────────────────────────────────────────
  if ((await prisma.tradeLicence.count()) === 0) {
    const CATS = {
      eatery: { base: 2000, sqft: 4, hp: 100, names: ['Mess', 'Hotel', 'Tiffin Centre', 'Bakery & Sweets', 'Juice Shop'] },
      provision_store: { base: 1000, sqft: 2, hp: 50, names: ['Provision Store', 'Super Market', 'Kirana Store'] },
      workshop: { base: 2500, sqft: 3, hp: 200, names: ['Auto Works', 'Lathe Works', 'Welding Shop', 'Service Centre'] },
      godown: { base: 1500, sqft: 2, hp: 50, names: ['Cotton Godown', 'Rice Godown', 'Warehouse'] },
      clinic: { base: 3000, sqft: 4, hp: 100, names: ['Clinic', 'Dental Care', 'Diagnostic Centre'] },
      salon: { base: 1200, sqft: 3, hp: 80, names: ['Salon', 'Beauty Parlour', 'Hair Studio'] },
      bakery: { base: 2200, sqft: 4, hp: 150, names: ['Bakery', 'Cake Shop'] },
      laundry: { base: 1200, sqft: 3, hp: 120, names: ['Laundry', 'Dry Cleaners'] },
      timber_depot: { base: 3000, sqft: 2, hp: 200, names: ['Timber Depot', 'Saw Mill'] },
    };
    const PREFIX = ['Sri', 'New', 'Sree', 'Amman', 'Annapoorna', 'Lakshmi', 'Kongu', 'Kovai', 'Vinayaga', 'Murugan'];
    const STATUSES = [
      'APPROVED', 'APPROVED', 'APPROVED', 'APPROVED', 'APPROVED',
      'SUBMITTED', 'INSPECTION', 'EXPIRED', 'EXPIRED', 'DRAFT', 'SUSPENDED', 'REJECTED',
    ];

    let n = 0;
    for (const org of urban) {
      const count = org.branch_type === 'MUNICIPAL_CORPORATION' ? 35 : 20;
      for (let i = 0; i < count; i++) {
        const catKey = pick(Object.keys(CATS));
        const cat = CATS[catKey];
        const status = pick(STATUSES);
        const area = int(120, 2400);
        const hp = chance(0.5) ? dec(0, 25, 1) : 0;
        const base = cat.base, areaFee = Math.round(area * cat.sqft), powerFee = Math.round(hp * cat.hp);
        const isLate = status === 'EXPIRED';
        const penalty = isLate ? Math.round((base + areaFee + powerFee) * 0.25) : 0;
        const total = base + areaFee + powerFee + penalty;
        const granted = ['APPROVED', 'EXPIRED', 'SUSPENDED'].includes(status);
        const paid = granted || chance(0.5);
        const created = daysAgo(recentBiased(400));
        const loc = scatter(0.07);

        const licence = await prisma.tradeLicence.create({
          data: {
            tenant_id: 'default',
            org_unit_id: org.id,
            licence_number: `TL/2026-27/${String(n + 1).padStart(6, '0')}`,
            status,
            trade_name: `${pick(PREFIX)} ${pick(cat.names)}`,
            trade_category: catKey,
            description: `${catKey.replace(/_/g, ' ')} operating at ${pick(STREETS)}.`,
            motive_power_hp: hp || null,
            worker_count: int(1, 24),
            operating_hours: pick(['06:00-22:00', '09:00-21:00', '07:00-23:00', '10:00-20:00']),
            owner_name: personName(),
            ownership_type: pick(['PROPRIETOR', 'PROPRIETOR', 'PROPRIETOR', 'PARTNERSHIP', 'PRIVATE_LIMITED']),
            owner_phone: phone(),
            owner_email: chance(0.4) ? `owner${n}@example.com` : null,
            owner_address: `${doorNo()}, ${pick(STREETS)}, ${org.district}`,
            owner_aadhaar: `XXXXXXXX${int(1000, 9999)}`,
            door_number: doorNo(),
            street_name: pick(STREETS),
            ward_number: String(int(1, 60)),
            survey_number: `${int(10, 400)}/${int(1, 9)}`,
            area_sqft: area,
            is_rented: chance(0.6),
            landlord_name: chance(0.6) ? personName() : null,
            latitude: loc.latitude,
            longitude: loc.longitude,
            fssai_number: ['eatery', 'bakery', 'provision_store'].includes(catKey)
              ? String(int(10000000000000, 99999999999999)) : null,
            fssai_expiry: ['eatery', 'bakery', 'provision_store'].includes(catKey)
              ? dayAgo(-int(-120, 400)) : null,
            gst_number: chance(0.5) ? `33${pick(['AABCU', 'ABCDE', 'AAECS'])}${int(1000, 9999)}${pick(['A', 'B'])}1Z${int(1, 9)}` : null,
            fire_noc_ref: ['eatery', 'timber_depot', 'workshop'].includes(catKey) ? `TNFS/CBE/2026/${int(100, 999)}` : null,
            fire_noc_expiry: ['eatery', 'timber_depot', 'workshop'].includes(catKey) ? dayAgo(-int(-90, 500)) : null,
            licence_year: '2026-27',
            valid_from: granted ? dayAgo(int(60, 300)) : null,
            valid_until: status === 'EXPIRED' ? dayAgo(int(5, 80)) : granted ? dayAgo(-int(30, 260)) : null,
            base_fee: base, area_fee: areaFee, power_fee: powerFee,
            penalty_fee: penalty, total_fee: total,
            paid_amount: paid ? total : 0,
            payment_status: paid ? 'paid' : 'unpaid',
            payment_ref: paid ? `RCPT${int(100000, 999999)}` : null,
            paid_at: paid ? created : null,
            approved_by: granted ? anyUser : null,
            approved_at: granted ? new Date(created.getTime() + int(5, 30) * 86400000) : null,
            rejection_reason: status === 'REJECTED'
              ? pick(['Premises do not meet the minimum hygiene standard.', 'Fire NOC not produced.', 'Objection received from neighbouring residents.']) : null,
            suspension_reason: status === 'SUSPENDED'
              ? 'Repeated hygiene violations recorded at the last two inspections.' : null,
            suspended_at: status === 'SUSPENDED' ? daysAgo(int(5, 60)) : null,
            submitted_at: status === 'DRAFT' ? null : created,
            created_by: anyUser,
            created_at: created,
          },
        });

        if (granted) {
          await prisma.tradeLicenceRenewal.create({
            data: {
              licence_id: licence.id,
              licence_year: '2026-27',
              valid_from: dayAgo(int(60, 300)),
              valid_until: dayAgo(-int(30, 260)),
              days_late: isLate ? int(1, 25) : 0,
              penalty_band: isLate ? 'late_30' : 'ontime',
              base_fee: base, area_fee: areaFee, power_fee: powerFee,
              penalty_fee: penalty, total_fee: total,
              paid_amount: paid ? total : 0,
              is_initial_grant: true,
              renewed_by: anyUser,
              renewed_at: created,
            },
          });

          if (chance(0.75)) {
            await prisma.tradeLicenceCertificate.create({
              data: {
                licence_id: licence.id,
                licence_year: '2026-27',
                certificate_number: `TLC-2026-27-${String(n + 1).padStart(6, '0')}`,
                verification_token: token(),
                copy_number: 1,
                seal_hash: seal(),
                issued_by: anyUser,
                issued_at: new Date(created.getTime() + int(6, 32) * 86400000),
              },
            });
          }
        }

        if (['INSPECTION', 'APPROVED', 'SUSPENDED'].includes(status)) {
          const compliant = status !== 'SUSPENDED';
          await prisma.tradeLicenceInspection.create({
            data: {
              licence_id: licence.id,
              inspection_type: pick(['pre_licence', 'annual']),
              scheduled_for: new Date(created.getTime() + int(4, 20) * 86400000),
              inspector_user_id: anyUser,
              status: 'completed',
              is_compliant: compliant,
              findings: compliant
                ? 'Premises inspected. Hygiene and safety norms met.'
                : 'Waste storage inadequate; no hand-wash facility for staff.',
              violations: compliant ? [] : ['No hand wash', 'Uncovered waste bins'],
              latitude: loc.latitude, longitude: loc.longitude,
              inspected_at: new Date(created.getTime() + int(5, 22) * 86400000),
            },
          });
        }
        n++;
      }
    }
    step('trade licences', n);
    step('  renewals', await prisma.tradeLicenceRenewal.count());
    step('  licence certificates', await prisma.tradeLicenceCertificate.count());
    step('  licence inspections', await prisma.tradeLicenceInspection.count());
  } else {
    step('trade licences (already present)');
  }
}

module.exports = { seedRegulatory };
