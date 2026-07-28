/**
 * seed-all-roles.ts
 * 
 * Seeds ALL 12 role-based logins for the Sengotics IVR Municipal System.
 * 
 * Roles seeded:
 *  1.  Super Administrator
 *  2.  Municipal Commissioner
 *  3.  Municipal Engineer
 *  4.  Revenue Officer
 *  5.  Assistant Engineer
 *  6.  Health Officer
 *  7.  Revenue Inspector
 *  8.  Field Agent (Electrician / Plumber)
 *  9.  Junior Engineer
 * 10.  Deputed Sengotics I3C Staff
 * 11.  Contractor / Vendor
 * 12.  Citizen
 * 
 * Usage:
 *   npx ts-node scripts/seed-all-roles.ts
 */

import { Client } from 'pg';
import * as dotenv from 'dotenv';
import * as bcrypt from 'bcrypt';

dotenv.config();

// ═══════════════════════════════════════════════════════════════════════
//  CONSTANTS
// ═══════════════════════════════════════════════════════════════════════

const DEFAULT_PASSWORD = 'Admin@1234';
const TENANT_ID = 'default';

// ═══════════════════════════════════════════════════════════════════════
//  MAIN
// ═══════════════════════════════════════════════════════════════════════

async function main() {
  const client = new Client({ connectionString: process.env.DATABASE_URL });

  try {
    await client.connect();
    console.log('🔗 Connected to database.');
    console.log('🌱 Starting ALL 12 Role-Based Login Seeding...\n');

    const passwordHash = await bcrypt.hash(DEFAULT_PASSWORD, 10);

    // ──────────────────────────────────────────────────────────────────
    //  Step 1: Ensure Panchayat exists (Thayanur)
    // ──────────────────────────────────────────────────────────────────
    console.log('🏘️  Ensuring Thayanur panchayat exists...');
    let branchId: number;

    const existingPanchayat = await client.query(
      `SELECT id FROM panchayats WHERE name = 'Thayanur' LIMIT 1`
    );

    if (existingPanchayat.rows.length > 0) {
      branchId = existingPanchayat.rows[0].id;
      console.log(`   ✅ Found existing Thayanur (id: ${branchId})`);
    } else {
      const res = await client.query(
        `INSERT INTO panchayats (name, center_lat, center_lng, ivr_number, tenant_id, branch_type, branch_status, effective_from)
         VALUES ('Thayanur', 11.0168, 76.9558, '04440115043', $1, 'VILLAGE_PANCHAYAT', 'ACTIVE', NOW())
         RETURNING id`,
        [TENANT_ID]
      );
      branchId = res.rows[0].id;
      console.log(`   ✅ Created Thayanur panchayat (id: ${branchId})`);
    }

    // ──────────────────────────────────────────────────────────────────
    //  Step 2: Create Departments
    // ──────────────────────────────────────────────────────────────────
    console.log('🏛️  Creating departments...');

    const departments = [
      { code: 'executive', name: 'Executive Governance', name_ta: 'நிர்வாக ஆளுமை' },
      { code: 'engineering', name: 'Engineering & Works', name_ta: 'பொறியியல் & பணிகள்' },
      { code: 'revenue', name: 'Revenue & Tax', name_ta: 'வருவாய் & வரி' },
      { code: 'health', name: 'Health & Sanitation', name_ta: 'சுகாதாரம் & துப்புரவு' },
      { code: 'electrical', name: 'Electrical Maintenance', name_ta: 'மின்சார பராமரிப்பு' },
      { code: 'water', name: 'Water & Sanitation', name_ta: 'நீர் & சுகாதாரம்' },
      { code: 'operations', name: 'Field Operations', name_ta: 'கள செயல்பாடுகள்' },
      { code: 'i3c', name: 'I3C Command Center', name_ta: 'I3C கட்டளை மையம்' },
    ];

    const deptIds: Record<string, number> = {};

    for (const dept of departments) {
      const existing = await client.query(
        `SELECT id FROM departments WHERE tenant_id = $1 AND branch_id = $2 AND code = $3`,
        [TENANT_ID, branchId, dept.code]
      );

      if (existing.rows.length > 0) {
        deptIds[dept.code] = existing.rows[0].id;
      } else {
        const res = await client.query(
          `INSERT INTO departments (tenant_id, branch_id, code, name, name_ta, is_active)
           VALUES ($1, $2, $3, $4, $5, true) RETURNING id`,
          [TENANT_ID, branchId, dept.code, dept.name, dept.name_ta]
        );
        deptIds[dept.code] = res.rows[0].id;
      }
    }

    console.log(`   ✅ ${Object.keys(deptIds).length} departments ready.`);

    // ──────────────────────────────────────────────────────────────────
    //  Step 3: Create Permission Groups for all roles
    // ──────────────────────────────────────────────────────────────────
    console.log('🔐 Creating permission groups...');

    const permissionGroups = [
      {
        name: 'Super Admin Group',
        permissions: [
          'complaints.read','complaints.write','complaints.assign','complaints.resolve','complaints.delete','complaints.export',
          'poles.read','poles.write','poles.delete',
          'tenders.read','tenders.write','tenders.approve','tenders.publish','tenders.close','tenders.delete',
          'users.read','users.write','users.delete',
          'assets.read','assets.write','assets.approve',
          'certificates.read','certificates.approve','certificates.reject',
          'inspections.read','inspections.write','inspections.approve',
          'contractors.read','contractors.write',
          'municipality.read','municipality.write',
          'water_supply.read','water_supply.write',
          'reports.read','reports.export',
          'settings.read','settings.write',
        ],
      },
      {
        name: 'Commissioner Group',
        permissions: [
          'complaints.read','complaints.write','complaints.assign','complaints.resolve','complaints.export',
          'tenders.read','tenders.approve','tenders.publish','tenders.close',
          'users.read','users.write',
          'assets.read','assets.approve',
          'certificates.read','certificates.approve','certificates.reject',
          'inspections.read','inspections.approve',
          'contractors.read',
          'municipality.read','municipality.write',
          'water_supply.read',
          'reports.read','reports.export',
          'settings.read',
        ],
      },
      {
        name: 'Municipal Engineer Group',
        permissions: [
          'complaints.read','complaints.write','complaints.assign','complaints.resolve',
          'poles.read','poles.write',
          'tenders.read','tenders.write','tenders.approve',
          'assets.read','assets.write','assets.approve',
          'inspections.read','inspections.write','inspections.approve',
          'contractors.read','contractors.write',
          'water_supply.read','water_supply.write',
          'reports.read','reports.export',
        ],
      },
      {
        name: 'Revenue Officer Group',
        permissions: [
          'complaints.read',
          'tenders.read',
          'assets.read','assets.write','assets.approve',
          'certificates.read','certificates.approve',
          'municipality.read','municipality.write',
          'reports.read','reports.export',
        ],
      },
      {
        name: 'Assistant Engineer Group',
        permissions: [
          'complaints.read','complaints.write','complaints.assign','complaints.resolve',
          'poles.read','poles.write',
          'inspections.read','inspections.write','inspections.approve',
          'contractors.read',
          'water_supply.read','water_supply.write',
          'reports.read',
        ],
      },
      {
        name: 'Health Officer Group',
        permissions: [
          'complaints.read','complaints.write','complaints.resolve',
          'inspections.read','inspections.write','inspections.approve',
          'municipality.read',
          'reports.read','reports.export',
        ],
      },
      {
        name: 'Revenue Inspector Group',
        permissions: [
          'complaints.read',
          'assets.read',
          'municipality.read',
          'reports.read',
        ],
      },
      {
        name: 'Field Agent Group',
        permissions: [
          'complaints.read','complaints.write','complaints.resolve',
          'poles.read','poles.write',
          'inspections.read','inspections.write',
          'water_supply.read','water_supply.write',
        ],
      },
      {
        name: 'Junior Engineer Group',
        permissions: [
          'complaints.read','complaints.write',
          'poles.read','poles.write',
          'inspections.read','inspections.write',
          'water_supply.read',
          'reports.read',
        ],
      },
      {
        name: 'I3C Staff Group',
        permissions: [
          'complaints.read','complaints.write','complaints.assign',
          'poles.read',
          'inspections.read',
          'municipality.read',
          'water_supply.read',
          'reports.read',
        ],
      },
      {
        name: 'Contractor Group',
        permissions: [
          'tenders.read',
          'contractors.read',
        ],
      },
      {
        name: 'Citizen Group',
        permissions: [
          'complaints.read','complaints.write',
          'certificates.read',
        ],
      },
    ];

    const pgIds: Record<string, number> = {};

    for (const pg of permissionGroups) {
      const existing = await client.query(
        `SELECT id FROM permission_groups WHERE tenant_id = $1 AND name = $2`,
        [TENANT_ID, pg.name]
      );

      if (existing.rows.length > 0) {
        // Update permissions
        await client.query(
          `UPDATE permission_groups SET permissions = $1 WHERE id = $2`,
          [JSON.stringify(pg.permissions), existing.rows[0].id]
        );
        pgIds[pg.name] = existing.rows[0].id;
      } else {
        const res = await client.query(
          `INSERT INTO permission_groups (tenant_id, name, permissions) VALUES ($1, $2, $3) RETURNING id`,
          [TENANT_ID, pg.name, JSON.stringify(pg.permissions)]
        );
        pgIds[pg.name] = res.rows[0].id;
      }
    }

    console.log(`   ✅ ${Object.keys(pgIds).length} permission groups ready.`);

    // ──────────────────────────────────────────────────────────────────
    //  Step 4: Create RBAC Roles
    // ──────────────────────────────────────────────────────────────────
    console.log('🎭 Creating RBAC roles...');

    const roles = [
      { name: 'super_admin', display_name: 'Super Administrator', display_name_ta: 'சூப்பர் நிர்வாகி', department: 'Executive Governance', hierarchy_level: 1, can_approve: true, is_system: true, pg_name: 'Super Admin Group' },
      { name: 'municipal_commissioner', display_name: 'Municipal Commissioner', display_name_ta: 'நகராட்சி ஆணையர்', department: 'Executive Governance', hierarchy_level: 2, can_approve: true, is_system: true, pg_name: 'Commissioner Group' },
      { name: 'municipal_engineer', display_name: 'Municipal Engineer', display_name_ta: 'நகராட்சி பொறியாளர்', department: 'Engineering & Works', hierarchy_level: 3, can_approve: true, is_system: true, pg_name: 'Municipal Engineer Group' },
      { name: 'revenue_officer', display_name: 'Revenue Officer', display_name_ta: 'வருவாய் அலுவலர்', department: 'Revenue & Tax', hierarchy_level: 4, can_approve: true, is_system: true, pg_name: 'Revenue Officer Group' },
      { name: 'assistant_engineer', display_name: 'Assistant Engineer', display_name_ta: 'உதவி பொறியாளர்', department: 'Engineering & Works', hierarchy_level: 5, can_approve: true, is_system: false, pg_name: 'Assistant Engineer Group' },
      { name: 'health_officer', display_name: 'Health Officer', display_name_ta: 'சுகாதார அலுவலர்', department: 'Health & Sanitation', hierarchy_level: 5, can_approve: true, is_system: false, pg_name: 'Health Officer Group' },
      { name: 'revenue_inspector', display_name: 'Revenue Inspector', display_name_ta: 'வருவாய் ஆய்வாளர்', department: 'Revenue & Tax', hierarchy_level: 6, can_approve: false, is_system: false, pg_name: 'Revenue Inspector Group' },
      { name: 'field_agent', display_name: 'Field Agent', display_name_ta: 'கள முகவர்', department: 'Field Operations', hierarchy_level: 7, can_approve: false, is_system: true, pg_name: 'Field Agent Group' },
      { name: 'electrician', display_name: 'Electrician', display_name_ta: 'மின்சார நிபுணர்', department: 'Electrical Maintenance', hierarchy_level: 7, can_approve: false, is_system: true, pg_name: 'Field Agent Group' },
      { name: 'plumber', display_name: 'Plumber', display_name_ta: 'குழாய் நிபுணர்', department: 'Water & Sanitation', hierarchy_level: 7, can_approve: false, is_system: true, pg_name: 'Field Agent Group' },
      { name: 'junior_engineer', display_name: 'Junior Engineer', display_name_ta: 'இளநிலை பொறியாளர்', department: 'Engineering & Works', hierarchy_level: 6, can_approve: false, is_system: false, pg_name: 'Junior Engineer Group' },
      { name: 'i3c_staff', display_name: 'Deputed Sengotics I3C Staff', display_name_ta: 'செங்கோடிக்ஸ் I3C பணியாளர்', department: 'I3C Command Center', hierarchy_level: 5, can_approve: false, is_system: false, pg_name: 'I3C Staff Group' },
      { name: 'contractor', display_name: 'Contractor / Vendor', display_name_ta: 'ஒப்பந்தக்காரர்', department: null, hierarchy_level: 8, can_approve: false, is_system: false, pg_name: 'Contractor Group' },
      { name: 'citizen', display_name: 'Citizen', display_name_ta: 'குடிமகன்', department: null, hierarchy_level: 9, can_approve: false, is_system: false, pg_name: 'Citizen Group' },
    ];

    const roleIds: Record<string, number> = {};

    for (const r of roles) {
      const existing = await client.query(
        `SELECT id FROM roles WHERE tenant_id = $1 AND name = $2 AND branch_id IS NULL`,
        [TENANT_ID, r.name]
      );

      if (existing.rows.length > 0) {
        await client.query(
          `UPDATE roles SET display_name = $1, display_name_ta = $2, department = $3, hierarchy_level = $4, 
           can_approve = $5, is_system = $6, permission_group_id = $7 WHERE id = $8`,
          [r.display_name, r.display_name_ta, r.department, r.hierarchy_level,
           r.can_approve, r.is_system, pgIds[r.pg_name], existing.rows[0].id]
        );
        roleIds[r.name] = existing.rows[0].id;
      } else {
        const res = await client.query(
          `INSERT INTO roles (tenant_id, name, display_name, display_name_ta, department, hierarchy_level, 
           can_approve, is_system, is_active, permission_group_id, created_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, $9, NOW()) RETURNING id`,
          [TENANT_ID, r.name, r.display_name, r.display_name_ta, r.department, r.hierarchy_level,
           r.can_approve, r.is_system, pgIds[r.pg_name]]
        );
        roleIds[r.name] = res.rows[0].id;
      }
    }

    console.log(`   ✅ ${Object.keys(roleIds).length} RBAC roles ready.`);

    // ──────────────────────────────────────────────────────────────────
    //  Step 5: Create ALL 12 User Accounts
    // ──────────────────────────────────────────────────────────────────
    console.log('\n👥 Creating all 12 role-based user accounts...');

    interface UserSpec {
      email: string;
      role: string;
      panchayat_id: number | null;
      phone: string;
      user_type: string;
      // Employee fields (null for non-employees)
      employee_code?: string;
      designation?: string;
      dept_code?: string;
      hierarchy_level?: number;
      access_scope?: string;
      // Citizen fields
      citizen_name?: string;
      citizen_address?: string;
      citizen_ward?: string;
      // Contractor fields
      contractor_name?: string;
      contractor_gst?: string;
      contractor_pan?: string;
      contractor_category?: string[];
    }

    const allUsers: UserSpec[] = [
      // 1. Super Administrator
      {
        email: 'superadmin@sengotics.com',
        role: 'super_admin',
        panchayat_id: null,
        phone: '+919999999999',
        user_type: 'system',
        employee_code: 'SA-001',
        designation: 'Super Administrator',
        dept_code: 'executive',
        hierarchy_level: 1,
        access_scope: 'all_branches',
      },
      // 2. Municipal Commissioner
      {
        email: 'commissioner@thayanur.com',
        role: 'municipal_commissioner',
        panchayat_id: branchId,
        phone: '+919876540001',
        user_type: 'employee',
        employee_code: 'MC-001',
        designation: 'Municipal Commissioner',
        dept_code: 'executive',
        hierarchy_level: 2,
        access_scope: 'all_branches',
      },
      // 3. Municipal Engineer
      {
        email: 'engineer@thayanur.com',
        role: 'municipal_engineer',
        panchayat_id: branchId,
        phone: '+919876540002',
        user_type: 'employee',
        employee_code: 'ME-001',
        designation: 'Municipal Engineer',
        dept_code: 'engineering',
        hierarchy_level: 3,
        access_scope: 'child_branches',
      },
      // 4. Revenue Officer
      {
        email: 'revenue.officer@thayanur.com',
        role: 'revenue_officer',
        panchayat_id: branchId,
        phone: '+919876540003',
        user_type: 'employee',
        employee_code: 'RO-001',
        designation: 'Revenue Officer',
        dept_code: 'revenue',
        hierarchy_level: 4,
        access_scope: 'own_branch',
      },
      // 5. Assistant Engineer
      {
        email: 'asst.engineer@thayanur.com',
        role: 'assistant_engineer',
        panchayat_id: branchId,
        phone: '+919876540004',
        user_type: 'employee',
        employee_code: 'AE-001',
        designation: 'Assistant Engineer',
        dept_code: 'engineering',
        hierarchy_level: 5,
        access_scope: 'own_branch',
      },
      // 6. Health Officer
      {
        email: 'health.officer@thayanur.com',
        role: 'health_officer',
        panchayat_id: branchId,
        phone: '+919876540005',
        user_type: 'employee',
        employee_code: 'HO-001',
        designation: 'Health Officer',
        dept_code: 'health',
        hierarchy_level: 5,
        access_scope: 'own_branch',
      },
      // 7. Revenue Inspector
      {
        email: 'revenue.inspector@thayanur.com',
        role: 'revenue_inspector',
        panchayat_id: branchId,
        phone: '+919876540006',
        user_type: 'employee',
        employee_code: 'RI-001',
        designation: 'Revenue Inspector',
        dept_code: 'revenue',
        hierarchy_level: 6,
        access_scope: 'own_branch',
      },
      // 8. Field Agent (Electrician)
      {
        email: 'electrician@thayanur.com',
        role: 'electrician',
        panchayat_id: branchId,
        phone: '+919876543210',
        user_type: 'employee',
        employee_code: 'FA-001',
        designation: 'Electrician',
        dept_code: 'electrical',
        hierarchy_level: 7,
        access_scope: 'own_branch',
      },
      // 8b. Field Agent (Plumber)
      {
        email: 'plumber@thayanur.com',
        role: 'plumber',
        panchayat_id: branchId,
        phone: '+919876543211',
        user_type: 'employee',
        employee_code: 'FA-002',
        designation: 'Plumber',
        dept_code: 'water',
        hierarchy_level: 7,
        access_scope: 'own_branch',
      },
      // 9. Junior Engineer
      {
        email: 'junior.engineer@thayanur.com',
        role: 'junior_engineer',
        panchayat_id: branchId,
        phone: '+919876540007',
        user_type: 'employee',
        employee_code: 'JE-001',
        designation: 'Junior Engineer',
        dept_code: 'engineering',
        hierarchy_level: 6,
        access_scope: 'own_branch',
      },
      // 10. Deputed Sengotics I3C Staff
      {
        email: 'i3c.staff@sengotics.com',
        role: 'i3c_staff',
        panchayat_id: branchId,
        phone: '+919876540008',
        user_type: 'employee',
        employee_code: 'I3C-001',
        designation: 'I3C Command Center Operator',
        dept_code: 'i3c',
        hierarchy_level: 5,
        access_scope: 'all_branches',
      },
      // 11. Contractor / Vendor
      {
        email: 'contractor@thayanur.com',
        role: 'contractor',
        panchayat_id: branchId,
        phone: '+919876540009',
        user_type: 'contractor',
        contractor_name: 'Murugan Electricals & Civil Works',
        contractor_gst: '33AADCM1234A1Z5',
        contractor_pan: 'AADCM1234A',
        contractor_category: ['electrical', 'civil'],
      },
      // 12. Citizen
      {
        email: 'citizen@thayanur.com',
        role: 'citizen',
        panchayat_id: branchId,
        phone: '+919876540010',
        user_type: 'citizen',
        citizen_name: 'Kavitha Sundaram',
        citizen_address: '12, Gandhi Nagar, Thayanur, Coimbatore - 641020',
        citizen_ward: 'Ward 1 North',
      },
    ];

    const createdUserIds: Record<string, number> = {};

    for (const u of allUsers) {
      // Check if user already exists by email or phone
      const existing = await client.query(
        `SELECT id FROM users WHERE (tenant_id = $1 AND email = $2) OR (tenant_id = $1 AND phone_e164 = $3) LIMIT 1`,
        [TENANT_ID, u.email, u.phone]
      );

      let userId: number;

      if (existing.rows.length > 0) {
        userId = existing.rows[0].id;
        // Update existing user
        await client.query(
          `UPDATE users SET role = $1, user_type = $2, is_active = true, is_verified = true, 
           password_hash = $3, failed_attempts = 0, locked_until = NULL WHERE id = $4`,
          [u.role, u.user_type, passwordHash, userId]
        );
        console.log(`   ♻️  Updated existing user: ${u.email} (id: ${userId})`);
      } else {
        const res = await client.query(
          `INSERT INTO users (tenant_id, email, password_hash, role, panchayat_id, phone_e164, user_type, is_active, is_verified, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, true, true, NOW(), NOW()) RETURNING id`,
          [TENANT_ID, u.email, passwordHash, u.role, u.panchayat_id, u.phone, u.user_type]
        );
        userId = res.rows[0].id;
        console.log(`   ✅ Created user: ${u.email} (id: ${userId})`);
      }

      createdUserIds[u.role + '_' + u.email] = userId;

      // ── Create Employee record for staff roles ──
      if (u.employee_code && u.designation && u.dept_code) {
        const empBranchId = u.panchayat_id || branchId;
        const empExisting = await client.query(
          `SELECT id FROM employees WHERE user_id = $1`,
          [userId]
        );

        if (empExisting.rows.length === 0) {
          await client.query(
            `INSERT INTO employees (tenant_id, user_id, employee_code, branch_id, department_id, designation, 
             hierarchy_level, access_scope, date_of_joining, status, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, '2024-01-15', 'active', NOW(), NOW())`,
            [
              TENANT_ID, userId, u.employee_code, empBranchId,
              deptIds[u.dept_code] || null, u.designation,
              u.hierarchy_level || 5, u.access_scope || 'own_branch',
            ]
          );
          console.log(`      📋 Employee record: ${u.employee_code} — ${u.designation}`);
        } else {
          console.log(`      ♻️  Employee record already exists for user ${userId}`);
        }
      }

      // ── Create CitizenProfile for citizen users ──
      if (u.user_type === 'citizen' && u.citizen_name) {
        const cpExisting = await client.query(
          `SELECT id FROM citizen_profiles WHERE user_id = $1`,
          [userId]
        );

        if (cpExisting.rows.length === 0) {
          await client.query(
            `INSERT INTO citizen_profiles (tenant_id, user_id, full_name, phone, email, address, ward, branch_id, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())`,
            [TENANT_ID, userId, u.citizen_name, u.phone, u.email, u.citizen_address, u.citizen_ward, branchId]
          );
          console.log(`      🏠 Citizen profile: ${u.citizen_name}`);
        }
      }

      // ── Create Contractor record for contractor users ──
      if (u.user_type === 'contractor' && u.contractor_name) {
        const ctExisting = await client.query(
          `SELECT id FROM contractors WHERE tenant_id = $1 AND name = $2`,
          [TENANT_ID, u.contractor_name]
        );

        if (ctExisting.rows.length === 0) {
          await client.query(
            `INSERT INTO contractors (tenant_id, name, phone, email, gst_number, pan_number, category, is_active, created_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, true, NOW())`,
            [TENANT_ID, u.contractor_name, u.phone, u.email, u.contractor_gst, u.contractor_pan, u.contractor_category || []]
          );
          console.log(`      🏗️  Contractor: ${u.contractor_name}`);
        }

        // Also create a vendor entry for tender portal
        const vnExisting = await client.query(
          `SELECT id FROM vendors WHERE panchayat_id = $1 AND phone_e164 = $2`,
          [branchId, u.phone]
        );

        if (vnExisting.rows.length === 0) {
          await client.query(
            `INSERT INTO vendors (panchayat_id, name, phone_e164, place, notes, active, created_at)
             VALUES ($1, $2, $3, 'Thayanur', 'Registered contractor for municipal works', true, NOW())`,
            [branchId, u.contractor_name, u.phone]
          );
          console.log(`      📦 Vendor portal entry created`);
        }
      }

      // ── Assign RBAC Role ──
      const roleKey = u.role;
      if (roleIds[roleKey]) {
        const urExisting = await client.query(
          `SELECT id FROM user_roles WHERE user_id = $1 AND role_id = $2 AND branch_id = $3`,
          [userId, roleIds[roleKey], u.panchayat_id || branchId]
        );

        if (urExisting.rows.length === 0) {
          await client.query(
            `INSERT INTO user_roles (user_id, role_id, branch_id, is_temporary, valid_from, created_at)
             VALUES ($1, $2, $3, false, NOW(), NOW())`,
            [userId, roleIds[roleKey], u.panchayat_id || branchId]
          );
          console.log(`      🔑 RBAC role assigned: ${roleKey}`);
        }
      }
    }

    // ──────────────────────────────────────────────────────────────────
    //  FINAL SUMMARY
    // ──────────────────────────────────────────────────────────────────
    console.log('\n' + '═'.repeat(70));
    console.log('  🎉  ALL 12 ROLE-BASED LOGINS SEEDED SUCCESSFULLY!');
    console.log('═'.repeat(70));
    console.log('');
    console.log('  All passwords: Admin@1234');
    console.log('  Login endpoint: POST /api/auth/login { email, password }');
    console.log('  Citizen OTP:    POST /api/auth/send-otp { phone }');
    console.log('                  POST /api/auth/verify-otp { phone, otp }');
    console.log('');
    console.log('  ┌────┬────────────────────────────────────┬────────────────────────────────────────┐');
    console.log('  │ #  │ Role                               │ Email                                  │');
    console.log('  ├────┼────────────────────────────────────┼────────────────────────────────────────┤');
    console.log('  │  1 │ Super Administrator                │ superadmin@sengotics.com                │');
    console.log('  │  2 │ Municipal Commissioner             │ commissioner@thayanur.com               │');
    console.log('  │  3 │ Municipal Engineer                 │ engineer@thayanur.com                   │');
    console.log('  │  4 │ Revenue Officer                    │ revenue.officer@thayanur.com            │');
    console.log('  │  5 │ Assistant Engineer                 │ asst.engineer@thayanur.com              │');
    console.log('  │  6 │ Health Officer                     │ health.officer@thayanur.com             │');
    console.log('  │  7 │ Revenue Inspector                  │ revenue.inspector@thayanur.com          │');
    console.log('  │  8 │ Field Agent (Electrician)           │ electrician@thayanur.com                │');
    console.log('  │  9 │ Field Agent (Plumber)               │ plumber@thayanur.com                    │');
    console.log('  │ 10 │ Junior Engineer                    │ junior.engineer@thayanur.com            │');
    console.log('  │ 11 │ Deputed Sengotics I3C Staff        │ i3c.staff@sengotics.com                 │');
    console.log('  │ 12 │ Contractor / Vendor                │ contractor@thayanur.com                 │');
    console.log('  │ 13 │ Citizen                            │ citizen@thayanur.com                    │');
    console.log('  └────┴────────────────────────────────────┴────────────────────────────────────────┘');
    console.log('');

  } catch (error) {
    console.error('❌ Error during seeding:', error);
    throw error;
  } finally {
    await client.end();
    console.log('🔌 Database connection closed.');
  }
}

main().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});
