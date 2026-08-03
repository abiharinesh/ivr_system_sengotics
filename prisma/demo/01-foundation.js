/**
 * Foundation: the local bodies themselves, their departments, zones, staff,
 * and the role assignments that let the seeded accounts actually log in.
 *
 * Everything downstream hangs off org units, so this runs first. The RBAC seed
 * creates accounts but cannot assign them to a branch — no branch exists yet
 * at that point — which is why every seeded user is stranded until this runs.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, dayAgo, personName,
  maleName, phone, scatter, step, heading, BASE_LAT, BASE_LNG,
} = require('./lib');

/**
 * A representative slice of the Tamil Nadu local-body hierarchy — one of each
 * type, so every role in the roster has somewhere real to sit and the branch
 * switcher has something to switch between.
 */
const BODIES = [
  {
    name: 'Coimbatore Municipal Corporation',
    branch_type: 'MUNICIPAL_CORPORATION',
    branch_code: 'CBE-MC',
    district: 'Coimbatore', taluk: 'Coimbatore North',
    ward_count: 100, area_sq_km: 257.0,
    lat: 11.0168, lng: 76.9558,
  },
  {
    name: 'Tiruppur City Municipal Corporation',
    branch_type: 'MUNICIPAL_CORPORATION',
    branch_code: 'TUP-MC',
    district: 'Tiruppur', taluk: 'Tiruppur North',
    ward_count: 60, area_sq_km: 159.6,
    lat: 11.1085, lng: 77.3411,
  },
  {
    name: 'Mettupalayam Municipality',
    branch_type: 'MUNICIPALITY',
    branch_code: 'MTP-MU',
    district: 'Coimbatore', taluk: 'Mettupalayam',
    ward_count: 33, area_sq_km: 12.4,
    lat: 11.2996, lng: 76.9366,
  },
  {
    name: 'Annur Town Panchayat',
    branch_type: 'TOWN_PANCHAYAT',
    branch_code: 'ANR-TP',
    district: 'Coimbatore', taluk: 'Annur',
    ward_count: 18, area_sq_km: 6.8,
    lat: 11.2333, lng: 77.1000,
  },
  {
    name: 'Annur Panchayat Union',
    branch_type: 'PANCHAYAT_UNION',
    branch_code: 'ANR-PU',
    district: 'Coimbatore', taluk: 'Annur',
    ward_count: 42, area_sq_km: 214.0,
    lat: 11.2400, lng: 77.1100,
  },
  {
    name: 'Coimbatore District Panchayat',
    branch_type: 'DISTRICT_PANCHAYAT',
    branch_code: 'CBE-DP',
    district: 'Coimbatore', taluk: null,
    ward_count: 32, area_sq_km: 4723.0,
    lat: 11.0100, lng: 76.9600,
  },
];

const DEPARTMENTS = [
  { name: 'Engineering', code: 'ENG' },
  { name: 'Public Health', code: 'PH' },
  { name: 'Revenue', code: 'REV' },
  { name: 'Town Planning', code: 'TP' },
  { name: 'Administration', code: 'ADM' },
  { name: 'Accounts', code: 'ACC' },
];

/** Ward names that actually exist around Coimbatore. */
const ZONE_NAMES = [
  'Ward 12 — Gandhipuram', 'Ward 18 — RS Puram', 'Ward 24 — Peelamedu',
  'Ward 31 — Singanallur', 'Ward 07 — Ukkadam', 'Ward 45 — Saibaba Colony',
  'Ward 52 — Ganapathy', 'Ward 63 — Kuniyamuthur', 'Ward 09 — Town Hall',
  'Ward 38 — Vadavalli',
];

/** A rough square boundary around a point — enough for the GIS layer to draw. */
function boxAround(lat, lng, size = 0.012) {
  const h = size / 2;
  return {
    type: 'Polygon',
    coordinates: [[
      [lng - h, lat - h], [lng + h, lat - h],
      [lng + h, lat + h], [lng - h, lat + h],
      [lng - h, lat - h],
    ]],
  };
}

async function seedFoundation() {
  heading('Foundation');

  // ── Org units ─────────────────────────────────────────────────────────────
  const orgUnits = [];
  for (const b of BODIES) {
    const existing = await prisma.orgUnit.findFirst({ where: { name: b.name } });
    const data = {
      name: b.name,
      tenant_id: 'default',
      branch_type: b.branch_type,
      branch_status: 'ACTIVE',
      branch_code: b.branch_code,
      district: b.district,
      taluk: b.taluk,
      ward_count: b.ward_count,
      area_sq_km: b.area_sq_km,
      center_lat: b.lat,
      center_lng: b.lng,
      address: `${b.name} Office, ${b.district} District, Tamil Nadu`,
      contact_phone: phone(),
      contact_email: `${b.branch_code.toLowerCase()}@tn.gov.in`,
      ivr_number: `+91422${int(2000000, 2999999)}`,
      software_name_ta: 'ஊராட்சி குரல்',
      software_name_en: 'Ooraatchi Kural',
      state_code: 'TN',
      is_active: true,
    };
    orgUnits.push(
      existing
        ? await prisma.orgUnit.update({ where: { id: existing.id }, data })
        : await prisma.orgUnit.create({ data }),
    );
  }

  // Adopt the two pre-existing village panchayats rather than leaving them
  // orphaned with no district or contact details.
  const villages = await prisma.orgUnit.findMany({
    where: { branch_type: 'VILLAGE_PANCHAYAT' },
  });
  for (const v of villages) {
    await prisma.orgUnit.update({
      where: { id: v.id },
      data: {
        district: 'Coimbatore',
        taluk: 'Annur',
        ward_count: int(6, 12),
        area_sq_km: dec(3, 14, 1),
        center_lat: BASE_LAT + (Math.random() - 0.5) * 0.2,
        center_lng: BASE_LNG + (Math.random() - 0.5) * 0.2,
        contact_phone: phone(),
        contact_email: `${v.name.toLowerCase().replace(/\s+/g, '')}@tn.gov.in`,
        branch_code: v.branch_code ?? `VP-${v.id}`,
        parent_org_unit_id: orgUnits.find((o) => o.branch_type === 'PANCHAYAT_UNION')?.id,
      },
    });
    orgUnits.push(v);
  }
  step('org units', orgUnits.length);

  const all = await prisma.orgUnit.findMany({ where: { tenant_id: 'default' } });
  const primary = all.find((o) => o.branch_code === 'CBE-MC') ?? all[0];

  // ── Feature configs: every module on, so nothing is gated off in a demo ───
  for (const o of all) {
    const flags = {
      street_light_mgmt: true, water_supply_mgmt: true, complaint_mgmt: true,
      tender_mgmt: true, certificate_mgmt: true, market_mgmt: true,
      asset_booking: true, ad_campaign: true, penalty_mgmt: true,
      ivr_system: true, zone_management: true, solid_waste_mgmt: true,
      building_permit: true, birth_death_reg: true, drainage_mgmt: true,
      road_mgmt: true, parks_mgmt: true, public_health: true,
      vehicle_fleet_mgmt: true, cemetery_mgmt: true, encroachment_mgmt: true,
    };
    await prisma.branchFeatureConfig.upsert({
      where: { org_unit_id: o.id },
      update: flags,
      create: { org_unit_id: o.id, ...flags },
    });
  }
  step('feature configs', all.length);

  // ── Departments ───────────────────────────────────────────────────────────
  let deptCount = 0;
  for (const o of all) {
    for (const d of DEPARTMENTS) {
      const exists = await prisma.department.findFirst({
        where: { org_unit_id: o.id, name: d.name },
      });
      if (exists) continue;
      await prisma.department.create({
        data: {
          tenant_id: 'default',
          org_unit_id: o.id,
          name: d.name,
          code: `${o.branch_code}-${d.code}`,
          is_active: true,
        },
      });
      deptCount++;
    }
  }
  step('departments', deptCount);

  // ── Zones with real boundaries ────────────────────────────────────────────
  if ((await prisma.zone.count()) === 0) {
    const palette = ['#2563EB', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#0EA5E9'];
    let z = 0;
    for (const o of all.slice(0, 4)) {
      for (const name of pickN(ZONE_NAMES, 4)) {
        const lat = (o.center_lat ?? BASE_LAT) + (Math.random() - 0.5) * 0.05;
        const lng = (o.center_lng ?? BASE_LNG) + (Math.random() - 0.5) * 0.05;
        await prisma.zone.create({
          data: {
            org_unit_id: o.id,
            name,
            boundary_geojson: boxAround(lat, lng),
            color: palette[z % palette.length],
            opacity: 0.32,
            places: pickN(['Gandhipuram', 'Peelamedu', 'Ukkadam', 'Ganapathy', 'Saibaba Colony'], 2),
            is_active: true,
          },
        });
        z++;
      }
    }
    step('zones', z);
  } else {
    step('zones (already present)');
  }

  // ── Role assignments: give every seeded account a real branch ─────────────
  //
  // Without this the accounts exist but resolve to no org unit, so their
  // sidebar is empty and half the API calls reject on a missing branch.
  const roles = await prisma.role.findMany({ where: { tenant_id: '__system__' } });
  const roleByName = new Map(roles.map((r) => [r.name, r]));
  const users = await prisma.user.findMany({
    where: { email: { endsWith: '@ooraatchi.local' } },
  });

  const byType = (t) => all.filter((o) => o.branch_type === t);
  /** Where a role's holder should sit, honouring the role's body-type limits. */
  function branchFor(role) {
    if (role.applicable_branch_types.length === 0) return primary;
    for (const t of role.applicable_branch_types) {
      const candidates = byType(t);
      if (candidates.length) return candidates[0];
    }
    return primary;
  }

  let assigned = 0;
  for (const u of users) {
    const role = roleByName.get(u.role);
    if (!role) continue;
    const branch = role.is_super_admin ? primary : branchFor(role);

    // Match on the user, not on user+branch. Field staff are created further
    // down at a *random* branch, so re-running would otherwise see "no
    // assignment at the branch I would have picked" and add a second one.
    const existing = await prisma.userRole.findFirst({
      where: { user_id: u.id },
    });
    if (!existing) {
      await prisma.userRole.create({
        data: {
          user_id: u.id,
          role_id: role.id,
          org_unit_id: branch.id,
          is_primary: true,
          access_scope: role.is_super_admin
            ? 'all_org_units'
            : role.hierarchy_level <= 2
              ? 'child_org_units'
              : 'own_org_unit',
        },
      });
      assigned++;
    }
    if (!u.primary_org_unit_id) {
      await prisma.user.update({
        where: { id: u.id },
        data: { primary_org_unit_id: branch.id },
      });
    }
  }

  // The two pre-existing hand-made accounts deserve assignments too, or they
  // log in to an empty shell.
  for (const email of ['superadmin@sengotics.com', 'admin@sengotics.com']) {
    const u = await prisma.user.findFirst({ where: { email } });
    if (!u) continue;
    const role = roleByName.get(u.role);
    if (!role) continue;
    const branch = u.primary_org_unit_id
      ? all.find((o) => o.id === u.primary_org_unit_id) ?? primary
      : primary;
    const existing = await prisma.userRole.findFirst({
      where: { user_id: u.id, role_id: role.id, org_unit_id: branch.id },
    });
    if (!existing) {
      await prisma.userRole.create({
        data: {
          user_id: u.id, role_id: role.id, org_unit_id: branch.id,
          is_primary: true,
          access_scope: role.is_super_admin ? 'all_org_units' : 'own_org_unit',
        },
      });
      assigned++;
    }
    if (!u.primary_org_unit_id) {
      await prisma.user.update({
        where: { id: u.id }, data: { primary_org_unit_id: branch.id },
      });
    }
  }
  step('role assignments', assigned);

  // ── Field staff: electricians, plumbers, agents per branch ────────────────
  const bcrypt = require('bcrypt');
  const fieldHash = await bcrypt.hash('Demo@1234', 10);
  const FIELD = [
    { role: 'electrician', n: 6 },
    { role: 'plumber', n: 5 },
    { role: 'agent', n: 4 },
  ];
  let fieldCount = 0;
  for (const f of FIELD) {
    const role = roleByName.get(f.role);
    for (let i = 1; i <= f.n; i++) {
      const email = `${f.role}${i}@ooraatchi.local`;
      if (await prisma.user.findFirst({ where: { email } })) continue;
      const branch = pick(all);
      const u = await prisma.user.create({
        data: {
          tenant_id: 'default',
          email,
          password_hash: fieldHash,
          role: f.role,
          user_type: 'employee',
          phone_e164: phone(),
          primary_org_unit_id: branch.id,
          is_active: true,
          is_verified: true,
          must_change_password: false,
        },
      });
      if (role) {
        await prisma.userRole.create({
          data: { user_id: u.id, role_id: role.id, org_unit_id: branch.id, is_primary: true },
        });
      }
      fieldCount++;
    }
  }
  step('field staff accounts', fieldCount);

  // ── Employee service records ──────────────────────────────────────────────
  if ((await prisma.employee.count()) === 0) {
    const staff = await prisma.user.findMany({
      where: { user_type: 'employee', primary_org_unit_id: { not: null } },
      include: { user_roles: { include: { role: true } } },
    });
    let e = 0;
    for (const u of staff) {
      const dept = await prisma.department.findFirst({
        where: { org_unit_id: u.primary_org_unit_id },
      });
      const role = u.user_roles[0]?.role;
      await prisma.employee.create({
        data: {
          tenant_id: 'default',
          user_id: u.id,
          employee_code: `EMP-${String(1000 + e).padStart(5, '0')}`,
          service_book_number: `SB/${int(2005, 2023)}/${int(1000, 9999)}`,
          org_unit_id: u.primary_org_unit_id,
          department_id: dept?.id ?? null,
          designation: role?.display_name ?? 'Staff',
          hierarchy_level: role?.hierarchy_level ?? 5,
          cadre: pick(['TNMS', 'TNES', 'TNCS', 'Municipal Service']),
          date_of_joining: daysAgo(int(400, 6000)),
          pay_level: `Level ${int(4, 14)}`,
          qualification: pick(['B.E. Civil', 'B.Sc.', 'M.A.', 'Diploma', 'B.Com', 'MBA']),
          status: 'active',
        },
      });
      e++;
    }
    step('employee records', e);
  } else {
    step('employee records (already present)');
  }

  return { all, primary };
}

module.exports = { seedFoundation, boxAround };
