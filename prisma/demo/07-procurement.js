/**
 * Procurement: the contractor directory, tenders across their lifecycle,
 * quotations, and the work orders that follow an award.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, daysAhead, recentBiased,
  personName, phone, step, heading, bulk, STREETS,
} = require('./lib');

const crypto = require('crypto');

const FIRM_PREFIX = ['Sri', 'Sree', 'Kongu', 'Kovai', 'Amman', 'Vinayaga', 'Bharath', 'Annai', 'Senthil', 'Velan'];
const FIRM_SUFFIX = ['Constructions', 'Engineering Works', 'Contractors', 'Infra', 'Builders', 'Electricals', 'Enterprises', 'Associates'];

const WORKS = [
  ['Street light LED replacement', 'electrical', 240000],
  ['Pipeline replacement — 300m stretch', 'plumbing', 680000],
  ['Road patchwork and premix carpeting', 'civil', 1250000],
  ['Storm drain desilting', 'civil', 380000],
  ['Overhead tank cleaning and chlorination', 'plumbing', 145000],
  ['Park fencing and play equipment', 'civil', 520000],
  ['Bus shelter construction — 4 nos', 'civil', 890000],
  ['High-mast light installation', 'electrical', 760000],
  ['Community hall roof repair', 'civil', 430000],
  ['Borewell drilling and motor fitting', 'plumbing', 295000],
  ['Ward office renovation', 'civil', 610000],
  ['Solar street light pilot — 30 poles', 'electrical', 1450000],
];

async function seedProcurement(ctx) {
  heading('Procurement');
  const { all } = ctx;
  const engineers = await prisma.user.findMany({
    where: { role: { in: ['municipal_engineer', 'assistant_engineer', 'panchayat_admin'] } },
    select: { id: true },
  });
  const anyUser = engineers[0]?.id ?? 1;

  // ── Contractor directory ──────────────────────────────────────────────────
  if ((await prisma.contractor.count()) === 0) {
    const rows = [];
    for (const org of all) {
      for (let i = 0; i < 6; i++) {
        const cats = pickN(['civil', 'electrical', 'plumbing', 'horticulture'], int(1, 3));
        rows.push({
          tenant_id: 'default',
          org_unit_id: org.id,
          name: `${pick(FIRM_PREFIX)} ${pick(FIRM_SUFFIX)}`,
          phone: phone(),
          email: chance(0.6) ? `contact${rows.length}@example.com` : null,
          place: pick(['Coimbatore', 'Tiruppur', 'Mettupalayam', 'Annur', 'Sulur', 'Pollachi']),
          gst_number: `33${pick(['AABCU', 'ABCDE', 'AAECS'])}${int(1000, 9999)}${pick(['A', 'B'])}1Z${int(1, 9)}`,
          pan_number: `${pick(['AABCU', 'ABCDE'])}${int(1000, 9999)}${pick(['A', 'C', 'K'])}`,
          registration_number: `TN/PWD/${pick(['I', 'II', 'III'])}/${int(1000, 9999)}`,
          category: cats,
          // A believable rating spread: mostly competent, a few poor.
          rating: dec(2.4, 5, 1),
          blacklisted: chance(0.05),
          is_active: chance(0.94),
          notes: chance(0.3) ? pick([
            'Class I registered. Good record on road works.',
            'Delays reported on the last two work orders.',
            'Preferred for electrical works in this division.',
          ]) : null,
        });
      }
    }
    step('contractors', await bulk(prisma.contractor, rows));
  } else {
    step('contractors (already present)');
  }

  // ── Tenders ───────────────────────────────────────────────────────────────
  if ((await prisma.tender.count()) === 0) {
    const contractors = await prisma.contractor.findMany({
      where: { is_active: true, blacklisted: false },
      select: { id: true, name: true, org_unit_id: true },
    });
    const STATUSES = [
      'draft', 'published', 'published', 'quotations_closed',
      'awarded', 'awarded', 'work_in_progress', 'closed', 'closed',
      'field_verification',
    ];
    let t = 0;
    for (const org of all) {
      const count = org.branch_type === 'MUNICIPAL_CORPORATION' ? 8 : 4;
      for (let i = 0; i < count; i++) {
        const [title, category, budget] = pick(WORKS);
        const status = pick(STATUSES);
        const created = daysAgo(recentBiased(220));
        const awarded = ['awarded', 'work_in_progress', 'closed', 'field_verification'].includes(status);

        const tender = await prisma.tender.create({
          data: {
            org_unit_id: org.id,
            status,
            title_en: title,
            title_ta: null,
            narrative_en: `${title} within ${org.name} limits. Materials, labour and disposal to be borne by the contractor. Work to be completed within the stipulated period from the date of the work order.`,
            anchor_date: daysAhead(int(-60, 40)),
            quotation_access_mode: pick(['invited_only', 'invited_only', 'open']),
            auto_resolve_linked_complaints: chance(0.4),
            officer_self_inspection: chance(0.3),
            public_token: crypto.randomBytes(16).toString('hex'),
            work_order_date: awarded ? new Date(created.getTime() + int(20, 45) * 86400000) : null,
            work_completed_at: ['closed'].includes(status)
              ? new Date(created.getTime() + int(60, 130) * 86400000) : null,
            inspection_done_at: ['closed'].includes(status)
              ? new Date(created.getTime() + int(65, 140) * 86400000) : null,
            inspection_notes: ['closed'].includes(status)
              ? 'Work measured and found in order. Quality satisfactory.' : null,
            created_by_user_id: anyUser,
            created_at: created,
          },
        });

        // Line items give the tender a bill of quantities.
        const itemCount = int(2, 5);
        await bulk(prisma.tenderLineItem, Array.from({ length: itemCount }, (_, k) => ({
          tender_id: tender.id,
          seq: k + 1,
          description_en: pick([
            'Supply and fixing of 60W LED fitting',
            'Excavation and refilling for pipeline',
            'Premix carpeting including rolling',
            'Desilting of storm water drain',
            'Supply of MS fabricated grill',
            'Painting with two coats of enamel',
          ]),
          quantity: String(int(10, 400)),
          unit: pick(['nos', 'sqm', 'rmt', 'cum', 'kg']),
        })));

        // Quotations from a few invited contractors.
        const orgContractors = contractors.filter((c) => c.org_unit_id === org.id);
        const bidders = pickN(orgContractors.length ? orgContractors : contractors, int(2, 4));
        let bestId = null, bestAmount = Infinity;
        for (const b of bidders) {
          const amount = Math.round(budget * dec(0.86, 1.14));
          const q = await prisma.tenderQuotation.create({
            data: {
              tender_id: tender.id,
              contractor_id: b.id,
              submitter_name: b.name,
              submitter_phone_e164: phone(),
              amount: String(amount),
              remarks: chance(0.4) ? 'Rates inclusive of GST and transport.' : null,
              source: pick(['officer_entry', 'public_link', 'invite_link']),
              screening_outcome: pick(['accepted', 'accepted', 'pending']),
              submitted_at: new Date(created.getTime() + int(5, 25) * 86400000),
            },
          }).catch(() => null);
          if (q && amount < bestAmount) { bestAmount = amount; bestId = q.id; }
        }
        if (awarded && bestId) {
          await prisma.tender.update({
            where: { id: tender.id },
            data: { awarded_quotation_id: bestId },
          }).catch(() => {});
        }
        t++;
      }
    }
    step('tenders', t);
    step('  line items', await prisma.tenderLineItem.count());
    step('  quotations', await prisma.tenderQuotation.count());
  } else {
    step('tenders (already present)');
  }

  // ── Work orders ───────────────────────────────────────────────────────────
  if ((await prisma.workOrder.count()) === 0) {
    const tenders = await prisma.tender.findMany({
      where: { status: { in: ['awarded', 'work_in_progress', 'closed', 'field_verification'] } },
      select: { id: true, org_unit_id: true, title_en: true, created_at: true },
    });
    const contractors = await prisma.contractor.findMany({ select: { id: true, org_unit_id: true } });
    let w = 0;
    for (const tender of tenders) {
      const est = int(150000, 1500000);
      const status = pick(['issued', 'in_progress', 'in_progress', 'completed', 'completed', 'verified', 'paid']);
      const done = ['completed', 'verified', 'paid'].includes(status);
      const orgContractors = contractors.filter((c) => c.org_unit_id === tender.org_unit_id);
      const issued = new Date(tender.created_at.getTime() + int(25, 50) * 86400000);
      await prisma.workOrder.create({
        data: {
          tenant_id: 'default',
          org_unit_id: tender.org_unit_id,
          work_order_number: `WO-2026-27-${String(++w).padStart(4, '0')}`,
          contractor_id: orgContractors.length ? pick(orgContractors).id : (contractors.length ? pick(contractors).id : null),
          tender_id: tender.id,
          title: tender.title_en ?? 'Municipal work',
          description: `Execution of ${tender.title_en ?? 'the sanctioned work'} as per the approved estimate and specifications.`,
          estimated_cost: est,
          actual_cost: done ? Math.round(est * dec(0.92, 1.06)) : null,
          status,
          issued_at: issued,
          start_date: new Date(issued.getTime() + 3 * 86400000),
          expected_completion: new Date(issued.getTime() + int(30, 90) * 86400000),
          actual_completion: done ? new Date(issued.getTime() + int(35, 110) * 86400000) : null,
          measurement_book: done ? [
            { desc: 'Excavation', qty: int(20, 200), unit: 'cum', rate: int(180, 420), amount: int(8000, 60000) },
            { desc: 'Supply of material', qty: int(10, 120), unit: 'nos', rate: int(400, 3200), amount: int(20000, 180000) },
            { desc: 'Labour charges', qty: 1, unit: 'LS', rate: int(20000, 120000), amount: int(20000, 120000) },
          ] : null,
          financial_year_code: '2026-27',
          created_by: anyUser,
        },
      });
    }
    step('work orders', w);
  } else {
    step('work orders (already present)');
  }

  await linkContractorLogin();
}

/**
 * Give the seeded contractor account a business to be.
 *
 * `contractors` and `users` were unrelated tables, so the one seeded
 * contractor login belonged to none of the 48 registered firms. Signing in as
 * them, the platform had no way to answer "which of these tenders are mine",
 * which is why the portal could only ever have been a mockup.
 *
 * Links the login to whichever firm has the most invitations, so the demo
 * account lands on a portal with something in it rather than an empty one.
 * Idempotent: does nothing once any contractor has a login.
 */
async function linkContractorLogin() {
  const already = await prisma.contractor.count({ where: { user_id: { not: null } } });
  if (already > 0) {
    step('contractor login (already linked)');
    return;
  }

  const login = await prisma.user.findFirst({
    where: { user_type: 'contractor' },
    select: { id: true, email: true },
  });
  if (!login) {
    step('contractor login (no contractor account seeded)');
    return;
  }

  const busiest = await prisma.tenderInvite.groupBy({
    by: ['contractor_id'],
    _count: { _all: true },
    orderBy: { _count: { contractor_id: 'desc' } },
    take: 1,
  });
  const contractorId = busiest[0]?.contractor_id
    ?? (await prisma.contractor.findFirst({ select: { id: true } }))?.id;
  if (!contractorId) {
    step('contractor login (no contractor records)');
    return;
  }

  const firm = await prisma.contractor.update({
    where: { id: contractorId },
    data: { user_id: login.id, email: login.email },
  });
  step(`contractor login → ${firm.name}`, busiest[0]?._count?._all ?? 0);
}

module.exports = { seedProcurement };
