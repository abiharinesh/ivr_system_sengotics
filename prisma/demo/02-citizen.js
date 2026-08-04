/**
 * Citizen-facing records: complaints and their resolution history, the IVR
 * call log those complaints arrive through, announcements, citizen accounts
 * and service feedback.
 *
 * Complaints carry most of the weight — they feed the complaint board, the SLA
 * analytics, several dashboards and the field-staff job lists. They are spread
 * across six months and biased toward recent weeks so the trend charts have a
 * believable shape instead of a flat line.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, recentBiased,
  personName, phone, address, scatter, step, heading, bulk, LANDMARKS, STREETS,
} = require('./lib');

const CATEGORIES = [
  { key: 'street_light', label: 'Street light not working', dept: 'Engineering' },
  { key: 'water_supply', label: 'No water supply', dept: 'Engineering' },
  { key: 'garbage', label: 'Garbage not collected', dept: 'Public Health' },
  { key: 'drainage', label: 'Drainage overflow', dept: 'Public Health' },
  { key: 'road', label: 'Pothole on the road', dept: 'Engineering' },
  { key: 'water_leak', label: 'Pipeline leak', dept: 'Engineering' },
  { key: 'mosquito', label: 'Mosquito menace', dept: 'Public Health' },
  { key: 'stray_animals', label: 'Stray cattle on the road', dept: 'Public Health' },
  { key: 'encroachment', label: 'Roadside encroachment', dept: 'Town Planning' },
  { key: 'property_tax', label: 'Property tax assessment query', dept: 'Revenue' },
];

const COMPLAINT_TEXT = {
  street_light: [
    'The street light has not been working for the past week, {landmark}. The whole stretch is dark after 7pm.',
    'Two poles {landmark} are out. Women returning from the evening shift are afraid to use this road.',
    'Light flickers all night and goes off completely by midnight, {landmark}.',
  ],
  water_supply: [
    'No water supply for three days in our street. We are buying cans daily.',
    'Water comes only for ten minutes in the morning, {landmark}. Pressure is very low.',
    'The overhead tank has not been filled since Monday. About forty houses affected.',
  ],
  garbage: [
    'Garbage has not been collected for four days, {landmark}. It is starting to smell.',
    'The bin is overflowing and dogs are scattering the waste across the road.',
    'Door-to-door collection vehicle has not come to our street this week.',
  ],
  drainage: [
    'Drainage is overflowing onto the road {landmark}. Water is entering the compound.',
    'The storm drain is blocked with silt and plastic. Any rain floods the junction.',
    'Sewage is stagnating {landmark} for over a week now.',
  ],
  road: [
    'Large pothole {landmark}. Two-wheelers have fallen here twice this month.',
    'The road was dug for a pipeline and never restored properly.',
    'Road surface has completely worn out near the school entrance.',
  ],
  water_leak: [
    'Pipeline is leaking continuously {landmark}. Drinking water is going waste.',
    'A burst pipe has flooded the street corner since yesterday morning.',
    'Valve is leaking at the junction; the road stays wet all day.',
  ],
  mosquito: [
    'Severe mosquito problem {landmark}. Request fogging in our area.',
    'Stagnant water in the vacant plot is breeding mosquitoes.',
    'No fogging has been done in this ward for over a month.',
  ],
  stray_animals: [
    'Stray cattle are blocking the main road {landmark} every evening.',
    'Stray dogs near the school gate are frightening the children.',
  ],
  encroachment: [
    'Shops have encroached onto the footpath {landmark}. Pedestrians walk on the road.',
    'A temporary shed has come up on panchayat land without permission.',
  ],
  property_tax: [
    'My property tax demand seems to have doubled without any reassessment notice.',
    'Paid the tax last month but the receipt is not reflecting in the portal.',
  ],
};

const RESOLUTIONS = [
  'Replaced the faulty LED fitting and tested. Working normally now.',
  'Line cleared and supply restored. Informed the complainant by phone.',
  'Waste cleared by the morning shift. Bin emptied and area disinfected.',
  'Drain desilted by the sanitary team. Flow restored.',
  'Pothole patched with premix. Road usable.',
  'Leak arrested by the plumbing crew and the joint replaced.',
  'Fogging carried out in the ward on schedule.',
  'Cattle impounded and owner fined as per bye-laws.',
  'Encroachment removed after notice. Footpath cleared.',
  'Assessment re-verified and corrected. Revised demand issued.',
];

async function seedCitizen(ctx) {
  heading('Citizen services');
  const { all } = ctx;
  const orgIds = all.map((o) => o.id);

  // ── Citizen accounts ──────────────────────────────────────────────────────
  if ((await prisma.citizenProfile.count()) === 0) {
    const bcrypt = require('bcrypt');
    const hash = await bcrypt.hash('Citizen@123', 10);
    let c = 0;
    for (let i = 1; i <= 40; i++) {
      const name = personName();
      const org = pick(all);
      const email = `citizen${i}@ooraatchi.local`;
      if (await prisma.user.findFirst({ where: { email } })) continue;
      const u = await prisma.user.create({
        data: {
          tenant_id: 'default', email, password_hash: hash,
          role: 'citizen', user_type: 'citizen',
          phone_e164: phone(), primary_org_unit_id: org.id,
          is_active: true, is_verified: chance(0.8),
        },
      });
      await prisma.citizenProfile.create({
        data: {
          tenant_id: 'default', user_id: u.id, full_name: name,
          phone: u.phone_e164, email,
          address: address(), ward: `Ward ${int(1, 60)}`,
          org_unit_id: org.id,
        },
      });
      c++;
    }
    step('citizen accounts', c);
  } else {
    step('citizen accounts (already present)');
  }

  const citizens = await prisma.citizenProfile.findMany();
  const electricians = await prisma.user.findMany({ where: { role: 'electrician' } });
  const plumbers = await prisma.user.findMany({ where: { role: 'plumber' } });
  const poles = await prisma.electricPole.findMany({ take: 40 });

  // ── IVR call log ──────────────────────────────────────────────────────────
  //
  // Complaints reference the call they arrived on, so calls are created first.
  const callSids = [];
  if ((await prisma.ivrCall.count()) === 0) {
    for (let i = 0; i < 220; i++) {
      const sid = `CA${String(Date.now()).slice(-8)}${String(i).padStart(4, '0')}`;
      const start = daysAgo(recentBiased(180));
      const secs = int(25, 240);
      await prisma.ivrCall.create({
        data: {
          call_sid: sid,
          caller_number: phone(),
          call_to: `+91422${int(2000000, 2999999)}`,
          flow_id: pick(['complaint_v2', 'complaint_v2', 'enquiry_v1', 'poll_v1']),
          tenant_id: 'default',
          call_start_time: start,
          call_end_time: new Date(start.getTime() + secs * 1000),
          service_selected: chance(0.86),
          poll_entered: chance(0.18),
          final_call_status: pick([
            'completed', 'completed', 'completed', 'completed',
            'no-answer', 'busy', 'failed',
          ]),
        },
      });
      callSids.push(sid);
    }
    step('IVR calls', callSids.length);

    let sel = 0;
    for (const sid of callSids) {
      if (!chance(0.86)) continue;
      await prisma.ivrServiceSelection.create({
        data: {
          call_sid: sid, caller_number: phone(),
          service_option: pick(['1', '2', '3', '4', '5']),
          raw_payload: { digits: pick(['1', '2', '3']), source: 'exotel' },
        },
      });
      sel++;
    }
    step('IVR service selections', sel);
  } else {
    step('IVR calls (already present)');
  }

  // ── Voice calls with transcripts ──────────────────────────────────────────
  //
  // A voice call is the recording of an IVR call, so it reuses that call's
  // sid. Minting a fresh one left the operations screen unable to join back to
  // the caller's number, which then rendered as a blank column.
  const ivrSids = (
    await prisma.ivrCall.findMany({ select: { call_sid: true }, take: 200 })
  ).map((c) => c.call_sid);

  const voiceIds = [];
  if ((await prisma.voiceCall.count()) === 0) {
    for (let i = 0; i < 140; i++) {
      const cat = pick(CATEGORIES);
      const text = pick(COMPLAINT_TEXT[cat.key]).replace('{landmark}', pick(LANDMARKS));
      const v = await prisma.voiceCall.create({
        data: {
          call_sid:
            ivrSids[i] ??
            `CA${String(Date.now()).slice(-8)}V${String(i).padStart(4, '0')}`,
          audio_url: `/uploads/voice/demo-${i}.mp3`,
          transcript: text,
          transcript_english: text,
          ai_extracted_json: {
            category: cat.key,
            urgency: pick(['low', 'medium', 'high']),
            sentiment: pick(['neutral', 'frustrated', 'angry', 'calm']),
          },
          processing_status: pick(['completed', 'completed', 'completed', 'manual_review']),
          confidence_score: dec(0.62, 0.99, 2),
          attempt_number: 1,
          created_at: daysAgo(recentBiased(180)),
        },
      });
      voiceIds.push(v.id);
    }
    step('voice calls', voiceIds.length);
  } else {
    step('voice calls (already present)');
  }

  // ── Complaints ────────────────────────────────────────────────────────────
  if ((await prisma.complaint.count()) === 0) {
    const voice = await prisma.voiceCall.findMany({ select: { id: true } });
    let n = 0;
    for (let i = 0; i < 260; i++) {
      const cat = pick(CATEGORIES);
      const age = recentBiased(180);
      const created = daysAgo(age);
      const org = pick(all);

      // Older complaints are far more likely to be closed; a register where
      // last week and last quarter have the same closure rate looks fake.
      const closedChance = age > 60 ? 0.93 : age > 21 ? 0.74 : age > 7 ? 0.45 : 0.18;
      const isResolved = chance(closedChance);
      const inProgress = !isResolved && chance(0.45);
      const status = isResolved
        ? pick(['resolved', 'resolved', 'closed'])
        : inProgress
          ? pick(['assigned', 'in_progress'])
          : 'pending';

      const isElectrical = ['street_light'].includes(cat.key);
      const isPlumbing = ['water_supply', 'water_leak'].includes(cat.key);
      const assignee = isElectrical
        ? pick(electricians)
        : isPlumbing
          ? pick(plumbers)
          : null;

      const assignedAt = status !== 'pending'
        ? new Date(created.getTime() + int(1, 36) * 3600000)
        : null;
      const resolvedAt = isResolved && assignedAt
        ? new Date(assignedAt.getTime() + int(2, 120) * 3600000)
        : null;

      const loc = scatter(0.08);
      await prisma.complaint.create({
        data: {
          voice_call_id: voice.length ? pick(voice).id : null,
          pole_id: isElectrical && poles.length ? pick(poles).id : null,
          org_unit_id: org.id,
          complaint_type: cat.key,
          category: cat.key,
          description: pick(COMPLAINT_TEXT[cat.key]).replace('{landmark}', pick(LANDMARKS)),
          caller_language: pick(['ta', 'ta', 'ta', 'en']),
          caller_emotion: pick(['neutral', 'frustrated', 'angry', 'calm', 'worried']),
          urgency_level: pick(['low', 'medium', 'medium', 'high', 'critical']),
          status,
          created_at: created,
          guest_phone: phone(),
          assigned_electrician_id: isElectrical ? assignee?.id ?? null : null,
          assigned_plumber_id: isPlumbing ? assignee?.id ?? null : null,
          assigned_at: assignedAt,
          resolved_at: resolvedAt,
          resolution_note: isResolved ? pick(RESOLUTIONS) : null,
          resolution_image_url: isResolved ? `/uploads/resolutions/demo-${i}.jpg` : null,
          resolution_image_latitude: isResolved ? loc.latitude : null,
          resolution_image_longitude: isResolved ? loc.longitude : null,
          resolution_image_captured_at: resolvedAt,
          resolution_distance_meters: isResolved ? dec(2, 85, 1) : null,
        },
      });
      n++;
    }
    step('complaints', n);
  } else {
    step('complaints (already present)');
  }

  // ── Announcements ─────────────────────────────────────────────────────────
  if ((await prisma.announcement.count()) === 0) {
    const admin = await prisma.user.findFirst({ where: { role: 'super_admin' } });
    const items = [
      ['Water supply interruption on Thursday',
       'Supply will be interrupted from 6am to 4pm on Thursday for pipeline maintenance near the head works. Please store water in advance.',
       'water', true],
      ['Property tax rebate — pay before 31 March',
       'A 5% rebate applies on the full-year property tax if paid in a single instalment before 31 March. Pay at the ward office or through the citizen portal.',
       'general', true],
      ['Fogging schedule for this week',
       'Vector control fogging will cover Wards 12, 18 and 24 on Monday and Wednesday between 6am and 9am.',
       'general', false],
      ['Road relaying — Avinashi Road stretch',
       'Relaying work between the flyover and the signal junction will run for ten days. Please use the service road.',
       'road', false],
      ['Free medical camp at the community hall',
       'A general health screening camp will be conducted on Sunday from 9am to 1pm. Diabetes and blood pressure checks are free of charge.',
       'event', false],
      ['Door-to-door waste collection timing change',
       'From next Monday collection in Ward 31 shifts to 6am–9am. Please hand over segregated waste to the crew.',
       'general', false],
      ['Trade licence renewal deadline',
       'All trade licences expire on 31 March. Renewals filed after that date attract a penalty.',
       'general', true],
      ['Birth and death certificate counter timings',
       'The registration counter now works 9am to 5pm on all working days, including the second Saturday.',
       'general', false],
    ];
    let a = 0;
    for (const o of all.slice(0, 4)) {
      for (const [title, body, category, pinned] of items) {
        await prisma.announcement.create({
          data: {
            tenant_id: 'default', org_unit_id: o.id,
            title, body, category, is_pinned: pinned,
            published_at: daysAgo(recentBiased(60)),
            expires_at: chance(0.4) ? daysAgo(-int(10, 90)) : null,
            created_by: admin?.id ?? 1,
          },
        });
        a++;
      }
    }
    step('announcements', a);
  } else {
    step('announcements (already present)');
  }

  // ── Service feedback ──────────────────────────────────────────────────────
  if ((await prisma.citizenFeedback.count()) === 0) {
    const resolved = await prisma.complaint.findMany({
      where: { status: { in: ['resolved', 'closed'] } },
      select: { id: true, org_unit_id: true },
      take: 160,
    });
    const COMMENTS = {
      5: ['Very quick response, thank you.', 'The crew came the same evening. Excellent.', 'Problem solved properly.'],
      4: ['Resolved, took a couple of days.', 'Good work overall.', 'Satisfied with the repair.'],
      3: ['Took longer than expected but done.', 'Average. Follow-up was needed.', 'Partially fixed.'],
      2: ['Had to call three times before anyone came.', 'Work was done poorly.', 'Very slow response.'],
      1: ['No one turned up for a week.', 'Complaint was closed without any work being done.', 'Very disappointing.'],
    };
    let f = 0;
    for (const c of resolved) {
      if (!chance(0.55)) continue;
      const rating = pick([5, 5, 4, 4, 4, 3, 3, 2, 1]);
      await prisma.citizenFeedback.create({
        data: {
          tenant_id: 'default',
          org_unit_id: c.org_unit_id ?? pick(orgIds),
          citizen_user_id: citizens.length ? pick(citizens).user_id : null,
          entity_type: 'complaint', entity_id: c.id,
          rating, comment: pick(COMMENTS[rating]),
          created_at: daysAgo(recentBiased(120)),
        },
      });
      f++;
    }
    step('citizen feedback', f);
  } else {
    step('citizen feedback (already present)');
  }
}

module.exports = { seedCitizen, CATEGORIES };
