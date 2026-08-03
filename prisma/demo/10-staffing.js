/**
 * Staffing and access top-up.
 *
 * Three things the earlier sections left half-done, all of which show up as
 * blank or misleading screens:
 *
 *  1. Roles were seeded into `__system__`, the cross-tenant template shelf.
 *     `RbacAdminService` refuses to edit anything there, so every sidebar
 *     toggle in the console was read-only. They move to the operating tenant.
 *  2. Several roles carried no screen grants at all — `citizen`, `clerk`,
 *     `field_inspector`, `district_collector` — so anyone holding them signed
 *     in to an empty menu. The three field roles carried exactly one screen
 *     each, which also made them look 100% identical to each other.
 *  3. Only the flagship corporation had a real staff roster. Every other
 *     branch had two or three field workers and nobody in charge, which reads
 *     on the deployment map as a district that has barely been rolled out.
 */

require('dotenv').config();
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const { prisma, pick, int, chance, daysAgo, phone, step, heading } =
  require('./lib');

/** Screens each under-granted role should carry. */
const SCREEN_TOPUP = {
  // The citizen portal is a real destination, not a placeholder: a citizen
  // signs in to track their own complaints and requests.
  citizen: ['home', 'complaints', 'citizen_portal', 'search'],
  clerk: ['home', 'complaints', 'search', 'certificates', 'documents'],
  field_inspector: [
    'home', 'field_workforce', 'inspections', 'complaints', 'public_health',
  ],
  district_collector: [
    'home', 'complaints', 'insights', 'executive', 'audit_logs',
    'branches', 'property_tax', 'search',
  ],
  // The three field roles had `home` and nothing else, which is both useless
  // and indistinguishable. Each gets the work queue it actually attends to.
  electrician: ['home', 'poles', 'complaints', 'field_workforce'],
  plumber: ['home', 'water_supply', 'complaints', 'field_workforce'],
  // A survey agent captures assets in the field; a field inspector checks
  // work that has been done. Overlapping them entirely was what made the two
  // read as duplicates of each other.
  agent: ['home', 'field_workforce', 'complaints', 'poles', 'water_supply'],
  contractor: ['home', 'tenders', 'vendor_portal', 'documents'],
};

/**
 * Roles whose grant list is authoritative rather than a floor.
 *
 * Everything else is only ever topped up, so a list an operator has curated in
 * the console is never silently overwritten. These are seed-only field roles
 * that nobody curates, and leaving stale grants on them is what produced two
 * roles indistinguishable from each other.
 */
const EXACT_SCREENS = new Set([
  'electrician', 'plumber', 'agent', 'field_inspector',
]);

/** Who staffs each kind of body. Ordered senior first. */
const ROSTER = {
  MUNICIPAL_CORPORATION: [
    'municipal_commissioner', 'deputy_commissioner', 'municipal_engineer',
    'assistant_engineer', 'junior_engineer', 'health_officer',
    'sanitary_inspector', 'revenue_officer', 'revenue_inspector',
    'town_planning_officer', 'registrar', 'licensing_clerk',
    'accounts_officer', 'i3c_staff', 'clerk', 'field_inspector',
    'electrician', 'plumber', 'agent',
  ],
  MUNICIPALITY: [
    'municipal_commissioner', 'municipal_engineer', 'assistant_engineer',
    'junior_engineer', 'health_officer', 'sanitary_inspector',
    'revenue_officer', 'revenue_inspector', 'town_planning_officer',
    'registrar', 'licensing_clerk', 'accounts_officer', 'clerk',
    'field_inspector', 'electrician', 'plumber',
  ],
  TOWN_PANCHAYAT: [
    'executive_officer', 'municipal_engineer', 'assistant_engineer',
    'junior_engineer', 'sanitary_inspector', 'revenue_officer',
    'revenue_inspector', 'registrar', 'licensing_clerk', 'bill_collector',
    'clerk', 'electrician', 'plumber', 'agent',
  ],
  VILLAGE_PANCHAYAT: [
    'panchayat_president', 'panchayat_secretary', 'junior_engineer',
    'registrar', 'bill_collector', 'clerk', 'electrician', 'plumber', 'agent',
  ],
  PANCHAYAT_UNION: [
    'block_development_officer', 'assistant_engineer', 'junior_engineer',
    'clerk', 'field_inspector', 'electrician', 'plumber',
  ],
  DISTRICT_PANCHAYAT: [
    'district_panchayat_officer', 'district_collector', 'clerk',
    'field_inspector', 'electrician', 'plumber',
  ],
};

/** URL-safe temporary password. Random per account, never reused. */
const tempPassword = () =>
  crypto.randomBytes(9).toString('base64url').replace(/[^A-Za-z0-9]/g, 'x') + '#1';

/** `annur-town-panchayat` from `Annur Town Panchayat`. */
const slug = (s) =>
  s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

async function seedStaffing(ctx) {
  heading('Staffing & access');
  const { all } = ctx;

  // ── 1. Move roles into the operating tenant so they can be edited ─────────
  const stranded = await prisma.role.findMany({
    where: { tenant_id: '__system__' },
    select: { id: true, name: true },
  });
  if (stranded.length) {
    let moved = 0;
    for (const r of stranded) {
      // The compound unique is (tenant_id, org_unit_id, name); a same-named
      // role may already exist in the tenant from an earlier run.
      const clash = await prisma.role.findFirst({
        where: { tenant_id: 'default', org_unit_id: null, name: r.name },
      });
      if (clash) continue;
      await prisma.role.update({
        where: { id: r.id },
        data: { tenant_id: 'default' },
      });
      moved++;
    }
    step('roles moved to the tenant', moved);
  } else {
    step('roles already tenant-owned');
  }

  // ── 1b. Re-enable roster designations left disabled ───────────────────────
  //
  // `clerk`, `field_inspector` and `district_collector` predate the RBAC
  // rebuild and were switched off when the new roster was seeded around them.
  // They are real designations in every one of these bodies, and an inactive
  // role cannot be staffed, so the branches that need them stayed empty.
  const revived = await prisma.role.updateMany({
    where: {
      name: { in: ['clerk', 'field_inspector', 'district_collector'] },
      is_active: false,
    },
    data: { is_active: true },
  });
  if (revived.count) step('roster designations re-enabled', revived.count);

  // ── 2. Screen grants for roles that had none ──────────────────────────────
  const screens = await prisma.appScreen.findMany({
    where: { is_active: true },
    select: { id: true, key: true },
  });
  const screenByKey = new Map(screens.map((s) => [s.key, s.id]));

  let granted = 0;
  for (const [roleName, keys] of Object.entries(SCREEN_TOPUP)) {
    const role = await prisma.role.findFirst({ where: { name: roleName } });
    if (!role) continue;
    const exact = EXACT_SCREENS.has(roleName);
    if (!exact) {
      const current = await prisma.roleScreenAccess.count({
        where: { role_id: role.id, can_view: true },
      });
      // Only top up a role that is clearly under-granted. A role someone has
      // already curated in the console must not be overwritten by a re-run.
      if (current >= keys.length) continue;
    } else {
      // Revoke rather than delete, so who granted what and when survives.
      const wanted = keys
        .map((k) => screenByKey.get(k))
        .filter((id) => id != null);
      await prisma.roleScreenAccess.updateMany({
        where: { role_id: role.id, screen_id: { notIn: wanted } },
        data: { can_view: false },
      });
    }

    for (const key of keys) {
      const sid = screenByKey.get(key);
      if (!sid) continue;
      await prisma.roleScreenAccess.upsert({
        where: { role_id_screen_id: { role_id: role.id, screen_id: sid } },
        update: { can_view: true },
        create: { role_id: role.id, screen_id: sid, can_view: true },
      });
      granted++;
    }
  }
  step('screen grants topped up', granted);

  // ── 3. Fill out the roster at every branch ────────────────────────────────
  const roles = await prisma.role.findMany({
    where: { is_active: true },
    select: {
      id: true, name: true, display_name: true, hierarchy_level: true,
      applicable_branch_types: true,
    },
  });
  const roleByName = new Map(roles.map((r) => [r.name, r]));

  // `phone_e164` is unique per tenant and citizens already hold a few hundred
  // numbers, so a random draw is not safe here. Take the taken set once and
  // hand out numbers that are known to be free.
  const taken = new Set(
    (await prisma.user.findMany({
      where: { tenant_id: 'default', phone_e164: { not: null } },
      select: { phone_e164: true },
    })).map((u) => u.phone_e164),
  );
  const freePhone = () => {
    for (let i = 0; i < 200; i++) {
      const p = phone();
      if (!taken.has(p)) {
        taken.add(p);
        return p;
      }
    }
    return null; // Give up rather than loop; the column is nullable.
  };

  const credentials = [];
  let created = 0;
  let assigned = 0;

  for (const org of all) {
    const wanted = ROSTER[org.branch_type] ?? [];
    const existing = await prisma.userRole.findMany({
      where: { org_unit_id: org.id },
      select: { role_id: true },
    });
    const held = new Set(existing.map((e) => e.role_id));

    for (const roleName of wanted) {
      const role = roleByName.get(roleName);
      if (!role || held.has(role.id)) continue;

      // Honour the role's own body-type restriction rather than working round
      // it — a village panchayat has no Municipal Commissioner, and inserting
      // one directly would put data in a state the API would reject.
      if (
        role.applicable_branch_types.length > 0 &&
        !role.applicable_branch_types.includes(org.branch_type)
      ) {
        continue;
      }

      const email = `${roleName}.${slug(org.name)}@example.gov.in`;
      let user = await prisma.user.findFirst({ where: { email } });

      if (!user) {
        const pwd = tempPassword();
        user = await prisma.user.create({
          data: {
            tenant_id: 'default',
            email,
            phone_e164: freePhone(),
            password_hash: await bcrypt.hash(pwd, 10),
            role: roleName,
            user_type: 'employee',
            is_active: true,
            is_verified: true,
            must_change_password: true,
            primary_org_unit_id: org.id,
            // A believable sign-in history: most staff use the system, a few
            // have been issued an account and never opened it.
            last_login_at: chance(0.72) ? daysAgo(int(0, 21)) : null,
          },
        });
        credentials.push({
          role: role.display_name,
          branch: org.name,
          email,
          password: pwd,
        });
        created++;

        // A staff record so the employee directory is not a list of logins.
        await prisma.employee
          .create({
            data: {
              tenant_id: 'default',
              user_id: user.id,
              org_unit_id: org.id,
              employee_code: `EMP-${org.id}-${String(created).padStart(4, '0')}`,
              designation: role.display_name,
              hierarchy_level: role.hierarchy_level,
              cadre: role.hierarchy_level <= 2
                ? 'TNCS'
                : role.hierarchy_level <= 4
                    ? 'TNMS'
                    : 'TNES',
              pay_level: `Level ${Math.max(1, 14 - role.hierarchy_level)}`,
              qualification: pick(['B.E. Civil', 'B.E. EEE', 'M.A. Public Admin', 'B.Sc.', 'Diploma (Civil)', 'M.B.A.']),
              date_of_joining: daysAgo(int(200, 4000)),
              status: 'active',
            },
          })
          .catch(() => {});
      }

      await prisma.userRole
        .create({
          data: {
            user_id: user.id,
            role_id: role.id,
            org_unit_id: org.id,
            is_primary: true,
            access_scope: role.hierarchy_level <= 2 ? 'child_org_units' : 'own_org_unit',
          },
        })
        .catch(() => {});
      held.add(role.id);
      assigned++;
    }
  }

  step('staff accounts created', created);
  step('role assignments added', assigned);

  // ── Credentials file — gitignored, appended per run ───────────────────────
  if (credentials.length) {
    const out = path.join(__dirname, '..', '.seeded-credentials.txt');
    const body = [
      '',
      `── Branch roster accounts, generated ${new Date().toISOString()} ──`,
      'Every account is flagged must_change_password: the holder is forced to',
      'set a new password at first sign-in. Do not commit or paste these.',
      '',
      ...credentials.map(
        (c) => `${c.role.padEnd(30)} ${c.branch.padEnd(38)} ${c.email.padEnd(52)} ${c.password}`,
      ),
      '',
    ].join('\n');
    fs.appendFileSync(out, body, { mode: 0o600 });
    step(`credentials appended to ${path.relative(process.cwd(), out)}`);
  }
}

module.exports = { seedStaffing, ROSTER, SCREEN_TOPUP };
