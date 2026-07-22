import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

const PERMISSIONS = [
  // Complaints
  { code: 'complaints.read', module: 'complaints', action: 'read', description: 'View complaints and status' },
  { code: 'complaints.write', module: 'complaints', action: 'write', description: 'Create and edit complaints' },
  { code: 'complaints.assign', module: 'complaints', action: 'assign', description: 'Assign complaints to field staff' },
  { code: 'complaints.resolve', module: 'complaints', action: 'resolve', description: 'Resolve manual review complaints' },
  { code: 'complaints.delete', module: 'complaints', action: 'delete', description: 'Delete complaint records' },
  { code: 'complaints.export', module: 'complaints', action: 'export', description: 'Export complaint resolution reports' },

  // Poles
  { code: 'poles.read', module: 'poles', action: 'read', description: 'View electric poles' },
  { code: 'poles.write', module: 'poles', action: 'write', description: 'Create and edit pole details' },
  { code: 'poles.delete', module: 'poles', action: 'delete', description: 'Delete electric poles' },

  // Tenders
  { code: 'tenders.read', module: 'tenders', action: 'read', description: 'View tenders and quotations' },
  { code: 'tenders.write', module: 'tenders', action: 'write', description: 'Create and edit tenders' },
  { code: 'tenders.approve', module: 'tenders', action: 'approve', description: 'Approve and award tenders' },
  { code: 'tenders.publish', module: 'tenders', action: 'publish', description: 'Publish tenders to public' },
  { code: 'tenders.close', module: 'tenders', action: 'close', description: 'Close quotation windows' },
  { code: 'tenders.delete', module: 'tenders', action: 'delete', description: 'Delete tenders' },

  // Users & Staff
  { code: 'users.read', module: 'users', action: 'read', description: 'View users and employees' },
  { code: 'users.write', module: 'users', action: 'write', description: 'Create and update users and staff' },
  { code: 'users.delete', module: 'users', action: 'delete', description: 'Delete or deactivate users' },

  // Assets & Rentals
  { code: 'assets.read', module: 'assets', action: 'read', description: 'View community assets and bookings' },
  { code: 'assets.write', module: 'assets', action: 'write', description: 'Create and edit community assets' },
  { code: 'assets.approve', module: 'assets', action: 'approve', description: 'Approve asset rental requests' },

  // Certificates
  { code: 'certificates.read', module: 'certificates', action: 'read', description: 'View civic certificate applications' },
  { code: 'certificates.approve', module: 'certificates', action: 'approve', description: 'Approve and sign certificates' },
  { code: 'certificates.reject', module: 'certificates', action: 'reject', description: 'Reject certificate applications' },

  // Field Inspections
  { code: 'inspections.read', module: 'inspections', action: 'read', description: 'View field inspection audits' },
  { code: 'inspections.write', module: 'inspections', action: 'write', description: 'Conduct field inspections' },
  { code: 'inspections.approve', module: 'inspections', action: 'approve', description: 'Sign off on field inspections' },

  // Contractors
  { code: 'contractors.read', module: 'contractors', action: 'read', description: 'View contractor directory' },
  { code: 'contractors.write', module: 'contractors', action: 'write', description: 'Register and edit contractors' },

  // Municipality Modules
  { code: 'municipality.read', module: 'municipality', action: 'read', description: 'View municipality service records' },
  { code: 'municipality.write', module: 'municipality', action: 'write', description: 'Update municipal records' },

  // Water Supply
  { code: 'water_supply.read', module: 'water_supply', action: 'read', description: 'View water pipelines and borewells' },
  { code: 'water_supply.write', module: 'water_supply', action: 'write', description: 'Log flow data and infrastructure' },

  // Reports & Analytics
  { code: 'reports.read', module: 'reports', action: 'read', description: 'Access system analytics and reports' },
  { code: 'reports.export', module: 'reports', action: 'export', description: 'Export official PDF/Excel reports' },

  // System Settings
  { code: 'settings.read', module: 'settings', action: 'read', description: 'View system configurations' },
  { code: 'settings.write', module: 'settings', action: 'write', description: 'Modify AI, STT, and LLM settings' },
];

const DEFAULT_PERMISSION_GROUPS = [
  {
    name: 'Super Admin Group',
    permissions: PERMISSIONS.map((p) => p.code),
  },
  {
    name: 'Panchayat Admin Group',
    permissions: [
      'complaints.read', 'complaints.write', 'complaints.assign', 'complaints.resolve', 'complaints.export',
      'poles.read', 'poles.write',
      'tenders.read', 'tenders.write', 'tenders.publish',
      'users.read', 'users.write',
      'assets.read', 'assets.write', 'assets.approve',
      'certificates.read', 'certificates.approve', 'certificates.reject',
      'inspections.read', 'inspections.write',
      'contractors.read', 'contractors.write',
      'municipality.read', 'municipality.write',
      'water_supply.read', 'water_supply.write',
      'reports.read', 'reports.export',
    ],
  },
  {
    name: 'Field Operations Group',
    permissions: [
      'complaints.read', 'complaints.write', 'complaints.resolve',
      'poles.read', 'poles.write',
      'inspections.read', 'inspections.write',
      'water_supply.read', 'water_supply.write',
    ],
  },
];

const DEFAULT_ROLES = [
  {
    name: 'super_admin',
    display_name: 'Super Admin',
    display_name_ta: 'சூப்பர் அட்மின்',
    department: 'Executive Governance',
    hierarchy_level: 1,
    can_approve: true,
    is_system: true,
  },
  {
    name: 'panchayat_admin',
    display_name: 'Panchayat Admin',
    display_name_ta: 'பஞ்சாயத்து நிர்வாகி',
    department: 'Local Administration',
    hierarchy_level: 2,
    can_approve: true,
    is_system: true,
  },
  {
    name: 'municipal_engineer',
    display_name: 'Municipal Engineer',
    display_name_ta: 'நகராட்சி பொறியாளர்',
    department: 'Engineering & Works',
    hierarchy_level: 3,
    can_approve: true,
    is_system: false,
  },
  {
    name: 'revenue_officer',
    display_name: 'Revenue Officer',
    display_name_ta: 'வருவாய் அலுவலர்',
    department: 'Revenue & Tax',
    hierarchy_level: 4,
    can_approve: true,
    is_system: false,
  },
  {
    name: 'field_agent',
    display_name: 'Field Agent',
    display_name_ta: 'கள அதிகாரி',
    department: 'Operations',
    hierarchy_level: 6,
    can_approve: false,
    is_system: false,
  },
  {
    name: 'electrician',
    display_name: 'Electrician',
    display_name_ta: 'மின்சார நிபுணர்',
    department: 'Electrical Maintenance',
    hierarchy_level: 7,
    can_approve: false,
    is_system: true,
  },
  {
    name: 'plumber',
    display_name: 'Plumber',
    display_name_ta: 'குழாய் நிபுணர்',
    department: 'Water & Sanitation',
    hierarchy_level: 7,
    can_approve: false,
    is_system: true,
  },
];

async function seedPermissions() {
  console.log('🌱 Seeding RBAC Permissions & System Roles...');

  // 1. Seed Permissions
  for (const perm of PERMISSIONS) {
    await prisma.permission.upsert({
      where: { code: perm.code },
      update: { description: perm.description, module: perm.module, action: perm.action },
      create: { code: perm.code, module: perm.module, action: perm.action, description: perm.description },
    });
  }
  console.log(`✅ Seeded ${PERMISSIONS.length} granular permissions.`);

  // 2. Seed Permission Groups
  for (const group of DEFAULT_PERMISSION_GROUPS) {
    await prisma.permissionGroup.upsert({
      where: { tenant_id_name: { tenant_id: 'default', name: group.name } },
      update: { permissions: group.permissions },
      create: { tenant_id: 'default', name: group.name, permissions: group.permissions },
    });
  }
  console.log(`✅ Seeded ${DEFAULT_PERMISSION_GROUPS.length} permission groups.`);

  // Get created group IDs
  const superAdminGroup = await prisma.permissionGroup.findUnique({
    where: { tenant_id_name: { tenant_id: 'default', name: 'Super Admin Group' } },
  });

  // 3. Seed Roles
  for (const r of DEFAULT_ROLES) {
    const existing = await prisma.role.findFirst({
      where: { tenant_id: 'default', branch_id: null, name: r.name },
    });
    if (existing) {
      await prisma.role.update({
        where: { id: existing.id },
        data: {
          display_name: r.display_name,
          display_name_ta: r.display_name_ta,
          department: r.department,
          hierarchy_level: r.hierarchy_level,
          can_approve: r.can_approve,
          is_system: r.is_system,
          permission_group_id: r.name === 'super_admin' ? superAdminGroup?.id : undefined,
        },
      });
    } else {
      await prisma.role.create({
        data: {
          tenant_id: 'default',
          branch_id: null,
          name: r.name,
          display_name: r.display_name,
          display_name_ta: r.display_name_ta,
          department: r.department,
          hierarchy_level: r.hierarchy_level,
          can_approve: r.can_approve,
          is_system: r.is_system,
          permission_group_id: r.name === 'super_admin' ? superAdminGroup?.id : undefined,
        },
      });
    }
  }
  console.log(`✅ Seeded ${DEFAULT_ROLES.length} system roles.`);
  console.log('🎉 RBAC Seeding completed successfully!');
}

seedPermissions()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
