/**
 * Seed: Permissions, Permission Groups, and the single merged Role vocabulary.
 *
 * Replaces prisma/seed-permissions.js — that file's SYSTEM_ROLES list had
 * drifted from the role strings actually used in @Roles() decorators across
 * the NestJS controllers (e.g. it had "commissioner"/"clerk"/"district_collector"
 * while the code checks "municipal_commissioner"/"revenue_officer"/"i3c_staff"/
 * "contractor"). This file is the single source of truth going forward: every
 * role name here matches a real @Roles() string, plus a few reserved
 * (is_active: false) designations kept for future controllers to adopt.
 *
 * Role.tenant_id = "__system__" marks these as global templates available to
 * every tenant, distinct from any tenant-specific Role customization.
 *
 * Run: node prisma/seed-roles.js
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const TENANT_ID = '__system__';

// ── 1. Permission Definitions ────────────────────────────────────────────────
const PERMISSIONS = [
  // Complaints
  { code: 'complaints.read',    module: 'complaints',    action: 'read',    description: 'View complaints' },
  { code: 'complaints.write',   module: 'complaints',    action: 'write',   description: 'Create/edit complaints' },
  { code: 'complaints.assign',  module: 'complaints',    action: 'assign',  description: 'Assign complaints to staff' },
  { code: 'complaints.resolve', module: 'complaints',    action: 'resolve', description: 'Resolve complaints' },
  { code: 'complaints.delete',  module: 'complaints',    action: 'delete',  description: 'Delete complaints' },
  { code: 'complaints.export',  module: 'complaints',    action: 'export',  description: 'Export complaint reports' },

  // Assets (generic)
  { code: 'assets.read',    module: 'assets',    action: 'read',    description: 'View assets' },
  { code: 'assets.write',   module: 'assets',    action: 'write',   description: 'Create/edit assets' },
  { code: 'assets.approve', module: 'assets',    action: 'approve', description: 'Approve asset changes' },
  { code: 'assets.delete',  module: 'assets',    action: 'delete',  description: 'Delete assets' },
  { code: 'assets.inspect', module: 'assets',    action: 'inspect', description: 'Perform asset inspections' },

  // Street Lights
  { code: 'street_lights.read',    module: 'street_lights', action: 'read',    description: 'View street light poles' },
  { code: 'street_lights.write',   module: 'street_lights', action: 'write',   description: 'Create/edit poles' },
  { code: 'street_lights.approve', module: 'street_lights', action: 'approve', description: 'Approve pole changes' },
  { code: 'street_lights.delete',  module: 'street_lights', action: 'delete',  description: 'Delete poles' },

  // Water Supply
  { code: 'water_supply.read',    module: 'water_supply', action: 'read',    description: 'View water infrastructure' },
  { code: 'water_supply.write',   module: 'water_supply', action: 'write',   description: 'Create/edit water infra' },
  { code: 'water_supply.approve', module: 'water_supply', action: 'approve', description: 'Approve water changes' },
  { code: 'water_supply.delete',  module: 'water_supply', action: 'delete',  description: 'Delete water infra' },

  // Tenders
  { code: 'tenders.read',    module: 'tenders', action: 'read',    description: 'View tenders' },
  { code: 'tenders.write',   module: 'tenders', action: 'write',   description: 'Create/edit tenders' },
  { code: 'tenders.approve', module: 'tenders', action: 'approve', description: 'Approve tender actions' },
  { code: 'tenders.publish', module: 'tenders', action: 'publish', description: 'Publish tenders' },
  { code: 'tenders.award',   module: 'tenders', action: 'award',   description: 'Award tenders to vendors' },
  { code: 'tenders.delete',  module: 'tenders', action: 'delete',  description: 'Delete tenders' },

  // Certificates
  { code: 'certificates.read',    module: 'certificates', action: 'read',    description: 'View certificate requests' },
  { code: 'certificates.write',   module: 'certificates', action: 'write',   description: 'Create certificate requests' },
  { code: 'certificates.approve', module: 'certificates', action: 'approve', description: 'Approve/reject certificates' },
  { code: 'certificates.issue',   module: 'certificates', action: 'issue',   description: 'Issue certificates' },
  { code: 'certificates.delete',  module: 'certificates', action: 'delete',  description: 'Delete certificate requests' },

  // Users
  { code: 'users.read',         module: 'users', action: 'read',         description: 'View user accounts' },
  { code: 'users.write',        module: 'users', action: 'write',        description: 'Create/edit users' },
  { code: 'users.delete',       module: 'users', action: 'delete',       description: 'Delete users' },
  { code: 'users.assign_roles', module: 'users', action: 'assign_roles', description: 'Assign roles to users' },

  // Roles
  { code: 'roles.read',   module: 'roles', action: 'read',   description: 'View roles' },
  { code: 'roles.write',  module: 'roles', action: 'write',  description: 'Create/edit roles' },
  { code: 'roles.delete', module: 'roles', action: 'delete', description: 'Delete roles' },

  // Branches
  { code: 'branches.read',               module: 'branches', action: 'read',               description: 'View branches' },
  { code: 'branches.write',              module: 'branches', action: 'write',              description: 'Create/edit branches' },
  { code: 'branches.delete',             module: 'branches', action: 'delete',             description: 'Delete branches' },
  { code: 'branches.configure_features', module: 'branches', action: 'configure_features', description: 'Toggle feature modules' },

  // Market
  { code: 'market.read',    module: 'market', action: 'read',    description: 'View market data' },
  { code: 'market.write',   module: 'market', action: 'write',   description: 'Create/edit market data' },
  { code: 'market.approve', module: 'market', action: 'approve', description: 'Approve market actions' },
  { code: 'market.delete',  module: 'market', action: 'delete',  description: 'Delete market data' },

  // Zone Management
  { code: 'zone_management.read',   module: 'zone_management', action: 'read',   description: 'View zones' },
  { code: 'zone_management.write',  module: 'zone_management', action: 'write',  description: 'Create/edit zones' },
  { code: 'zone_management.delete', module: 'zone_management', action: 'delete', description: 'Delete zones' },

  // Reports
  { code: 'reports.read',     module: 'reports', action: 'read',     description: 'View reports' },
  { code: 'reports.generate', module: 'reports', action: 'generate', description: 'Generate reports' },
  { code: 'reports.export',   module: 'reports', action: 'export',   description: 'Export reports' },

  // Settings
  { code: 'settings.read',  module: 'settings', action: 'read',  description: 'View system settings' },
  { code: 'settings.write', module: 'settings', action: 'write', description: 'Modify system settings' },

  // Audit
  { code: 'audit.read', module: 'audit', action: 'read', description: 'View audit logs' },

  // Workflows
  { code: 'workflows.read',    module: 'workflows', action: 'read',    description: 'View workflows' },
  { code: 'workflows.write',   module: 'workflows', action: 'write',   description: 'Create/edit workflows' },
  { code: 'workflows.approve', module: 'workflows', action: 'approve', description: 'Approve workflow steps' },
  { code: 'workflows.delete',  module: 'workflows', action: 'delete',  description: 'Delete workflows' },

  // Employees
  { code: 'employees.read',     module: 'employees', action: 'read',     description: 'View employees' },
  { code: 'employees.write',    module: 'employees', action: 'write',    description: 'Create/edit employees' },
  { code: 'employees.transfer', module: 'employees', action: 'transfer', description: 'Transfer employees' },
  { code: 'employees.delete',   module: 'employees', action: 'delete',   description: 'Delete employees' },

  // Departments
  { code: 'departments.read',   module: 'departments', action: 'read',   description: 'View departments' },
  { code: 'departments.write',  module: 'departments', action: 'write',  description: 'Create/edit departments' },
  { code: 'departments.delete', module: 'departments', action: 'delete', description: 'Delete departments' },

  // IVR
  { code: 'ivr.read',      module: 'ivr', action: 'read',      description: 'View IVR call logs' },
  { code: 'ivr.configure', module: 'ivr', action: 'configure', description: 'Configure IVR settings' },

  // Dashboard
  { code: 'dashboard.read',      module: 'dashboard', action: 'read',      description: 'View dashboard' },
  { code: 'dashboard.configure', module: 'dashboard', action: 'configure', description: 'Configure dashboard widgets' },
];

// ── 2. Permission Group Definitions ──────────────────────────────────────────
const PERMISSION_GROUPS = [
  {
    name: 'Super Admin Full Access',
    permissions: PERMISSIONS.map(p => p.code),
  },
  {
    name: 'Branch Admin Access',
    permissions: [
      'complaints.read', 'complaints.write', 'complaints.assign', 'complaints.resolve', 'complaints.export',
      'assets.read', 'assets.write', 'assets.inspect',
      'street_lights.read', 'street_lights.write',
      'water_supply.read', 'water_supply.write',
      'tenders.read', 'tenders.write', 'tenders.publish', 'tenders.award',
      'certificates.read', 'certificates.write', 'certificates.approve', 'certificates.issue',
      'users.read', 'users.write', 'users.assign_roles',
      'roles.read',
      'branches.read',
      'market.read', 'market.write', 'market.approve',
      'zone_management.read', 'zone_management.write',
      'reports.read', 'reports.generate', 'reports.export',
      'settings.read',
      'audit.read',
      'workflows.read', 'workflows.write', 'workflows.approve',
      'employees.read', 'employees.write',
      'departments.read', 'departments.write',
      'ivr.read',
      'dashboard.read', 'dashboard.configure',
    ],
  },
  {
    name: 'Engineering Access',
    permissions: [
      'complaints.read', 'complaints.write', 'complaints.assign', 'complaints.resolve',
      'assets.read', 'assets.write', 'assets.inspect',
      'street_lights.read', 'street_lights.write',
      'water_supply.read', 'water_supply.write',
      'tenders.read', 'tenders.write',
      'zone_management.read',
      'reports.read', 'reports.generate',
      'workflows.read', 'workflows.approve',
      'dashboard.read',
    ],
  },
  {
    name: 'Revenue Access',
    permissions: [
      'certificates.read', 'certificates.write', 'certificates.approve', 'certificates.issue',
      'market.read', 'market.write', 'market.approve',
      'reports.read', 'reports.generate', 'reports.export',
      'dashboard.read',
    ],
  },
  {
    name: 'Field Staff Access',
    permissions: [
      'complaints.read', 'complaints.resolve',
      'assets.read', 'assets.inspect',
      'street_lights.read',
      'water_supply.read',
      'dashboard.read',
    ],
  },
  {
    name: 'Clerk Access',
    permissions: [
      'complaints.read', 'complaints.write',
      'certificates.read', 'certificates.write',
      'market.read', 'market.write',
      'reports.read',
      'users.read',
      'dashboard.read',
    ],
  },
  {
    name: 'Citizen Access',
    permissions: [
      'complaints.read', 'complaints.write',
      'certificates.read', 'certificates.write',
      'dashboard.read',
    ],
  },
];

// ── 3. System Role Definitions ───────────────────────────────────────────────
const SYSTEM_ROLES = [
  {
    name: 'super_admin',
    display_name: 'Super Administrator',
    display_name_ta: 'சூப்பர் நிர்வாகி',
    department: null,
    hierarchy_level: 1,
    can_approve: true,
    is_system: true,
    is_super_admin: true,
    permission_group_name: 'Super Admin Full Access',
  },
  // ── Reserved designations (real TN designations, not yet gated by any
  // controller's @Roles() list) — kept inactive until a controller adopts them.
  {
    name: 'district_collector',
    display_name: 'District Collector',
    display_name_ta: 'மாவட்ட ஆட்சியர்',
    department: 'administration',
    hierarchy_level: 2,
    can_approve: true,
    is_system: true,
    is_active: false,
    permission_group_name: 'Super Admin Full Access',
  },
  {
    name: 'panchayat_secretary',
    display_name: 'Panchayat Secretary',
    display_name_ta: 'ஊராட்சி செயலாளர்',
    department: 'administration',
    hierarchy_level: 3,
    can_approve: true,
    is_system: true,
    is_active: false,
    permission_group_name: 'Branch Admin Access',
  },
  {
    name: 'municipal_commissioner',
    display_name: 'Municipal Commissioner',
    display_name_ta: 'நகராட்சி ஆணையர்',
    department: 'administration',
    hierarchy_level: 3,
    can_approve: true,
    is_system: true,
    permission_group_name: 'Branch Admin Access',
  },
  {
    name: 'panchayat_admin',
    display_name: 'Branch Administrator',
    display_name_ta: 'கிளை நிர்வாகி',
    department: 'administration',
    hierarchy_level: 3,
    can_approve: true,
    is_system: true,
    permission_group_name: 'Branch Admin Access',
  },
  {
    name: 'municipal_engineer',
    display_name: 'Municipal Engineer',
    display_name_ta: 'நகராட்சி பொறியாளர்',
    department: 'engineering',
    hierarchy_level: 4,
    can_approve: true,
    is_system: true,
    permission_group_name: 'Engineering Access',
  },
  {
    name: 'assistant_engineer',
    display_name: 'Assistant Engineer',
    display_name_ta: 'உதவி பொறியாளர்',
    department: 'engineering',
    hierarchy_level: 5,
    can_approve: true,
    is_system: false,
    permission_group_name: 'Engineering Access',
  },
  {
    name: 'junior_engineer',
    display_name: 'Junior Engineer',
    display_name_ta: 'இளநிலை பொறியாளர்',
    department: 'engineering',
    hierarchy_level: 6,
    can_approve: false,
    is_system: false,
    permission_group_name: 'Engineering Access',
  },
  {
    name: 'health_officer',
    display_name: 'Health Officer',
    display_name_ta: 'சுகாதார அலுவலர்',
    department: 'health',
    hierarchy_level: 5,
    can_approve: true,
    is_system: false,
    permission_group_name: 'Branch Admin Access',
  },
  {
    name: 'revenue_officer',
    display_name: 'Revenue Officer',
    display_name_ta: 'வருவாய் அலுவலர்',
    department: 'revenue',
    hierarchy_level: 4,
    can_approve: true,
    is_system: true,
    permission_group_name: 'Revenue Access',
  },
  {
    name: 'revenue_inspector',
    display_name: 'Revenue Inspector',
    display_name_ta: 'வருவாய் ஆய்வாளர்',
    department: 'revenue',
    hierarchy_level: 5,
    can_approve: true,
    is_system: false,
    permission_group_name: 'Revenue Access',
  },
  {
    name: 'i3c_staff',
    display_name: 'I3C Command Center Staff',
    display_name_ta: 'I3C கட்டுப்பாட்டு மைய பணியாளர்',
    department: 'administration',
    hierarchy_level: 5,
    can_approve: false,
    is_system: true,
    permission_group_name: 'Branch Admin Access',
  },
  {
    name: 'contractor',
    display_name: 'Contractor / Vendor',
    display_name_ta: 'ஒப்பந்தக்காரர்',
    department: null,
    hierarchy_level: 9,
    can_approve: false,
    is_system: true,
    permission_group_name: 'Field Staff Access',
  },
  // ── Reserved (not yet gated by any controller's @Roles() list) ──
  {
    name: 'clerk',
    display_name: 'Office Clerk',
    display_name_ta: 'அலுவலக எழுத்தர்',
    department: 'administration',
    hierarchy_level: 7,
    can_approve: false,
    is_system: false,
    is_active: false,
    permission_group_name: 'Clerk Access',
  },
  {
    name: 'agent',
    display_name: 'Field Agent',
    display_name_ta: 'களப்பணி முகவர்',
    department: 'field_ops',
    hierarchy_level: 8,
    can_approve: false,
    is_system: true,
    permission_group_name: 'Field Staff Access',
  },
  {
    name: 'electrician',
    display_name: 'Electrician',
    display_name_ta: 'மின்சாரி',
    department: 'engineering',
    hierarchy_level: 8,
    can_approve: false,
    is_system: true,
    permission_group_name: 'Field Staff Access',
  },
  {
    name: 'plumber',
    display_name: 'Plumber',
    display_name_ta: 'குழாய் பொருத்துநர்',
    department: 'engineering',
    hierarchy_level: 8,
    can_approve: false,
    is_system: true,
    permission_group_name: 'Field Staff Access',
  },
  {
    name: 'field_inspector',
    display_name: 'Field Inspector',
    display_name_ta: 'கள ஆய்வாளர்',
    department: 'field_ops',
    hierarchy_level: 7,
    can_approve: false,
    is_system: false,
    is_active: false,
    permission_group_name: 'Field Staff Access',
  },
  {
    name: 'citizen',
    display_name: 'Citizen',
    display_name_ta: 'குடிமகன்',
    department: null,
    hierarchy_level: 10,
    can_approve: false,
    is_system: true,
    permission_group_name: 'Citizen Access',
  },
];

async function main() {
  console.log('🔧 Seeding Permissions, Permission Groups, and System Roles...\n');

  // ── Step 1: Seed Permissions ──────────────────────────────────────────────
  console.log('📋 Seeding permissions...');
  let permissionCount = 0;
  for (const perm of PERMISSIONS) {
    await prisma.permission.upsert({
      where: { code: perm.code },
      update: { module: perm.module, action: perm.action, description: perm.description },
      create: perm,
    });
    permissionCount++;
  }
  console.log(`   ✅ ${permissionCount} permissions seeded\n`);

  // ── Step 2: Seed Permission Groups ────────────────────────────────────────
  console.log('📦 Seeding permission groups...');
  const groupMap = {}; // name → id
  for (const group of PERMISSION_GROUPS) {
    const result = await prisma.permissionGroup.upsert({
      where: {
        tenant_id_name: { tenant_id: TENANT_ID, name: group.name },
      },
      update: { permissions: group.permissions },
      create: {
        tenant_id: TENANT_ID,
        name: group.name,
        permissions: group.permissions,
      },
    });
    groupMap[group.name] = result.id;
    console.log(`   ✅ "${group.name}" (${group.permissions.length} permissions)`);
  }
  console.log('');

  // ── Step 3: Ensure the __system__ tenant exists (role templates need a real FK) ──
  console.log('🏢 Ensuring __system__ tenant...');
  await prisma.tenant.upsert({
    where: { id: TENANT_ID },
    update: {},
    create: {
      id: TENANT_ID,
      slug: 'system',
      name: 'System Role Templates',
      subscription: 'enterprise',
      max_branches: 1000,
    },
  });
  console.log('   ✅ __system__ tenant ready\n');

  // ── Step 4: Seed the merged System Role vocabulary ────────────────────────
  console.log('👤 Seeding system roles...');
  for (const role of SYSTEM_ROLES) {
    const permGroupId = role.permission_group_name ? groupMap[role.permission_group_name] : null;

    const existingRole = await prisma.role.findFirst({
      where: {
        tenant_id: TENANT_ID,
        org_unit_id: null,
        name: role.name,
      },
    });

    const data = {
      display_name: role.display_name,
      display_name_ta: role.display_name_ta,
      department: role.department,
      hierarchy_level: role.hierarchy_level,
      can_approve: role.can_approve,
      is_system: role.is_system,
      is_super_admin: role.is_super_admin ?? false,
      is_active: role.is_active ?? true,
      permission_group_id: permGroupId,
    };

    if (existingRole) {
      await prisma.role.update({ where: { id: existingRole.id }, data });
    } else {
      await prisma.role.create({
        data: { tenant_id: TENANT_ID, name: role.name, org_unit_id: null, ...data },
      });
    }
    console.log(`   ✅ "${role.display_name}" (level ${role.hierarchy_level}${role.is_active === false ? ', reserved' : ''})`);
  }

  console.log('\n✅ All seed data inserted successfully!\n');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
