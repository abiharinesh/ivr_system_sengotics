/**
 * Seed: screen registry, role roster for all six TN local-body types, the
 * permission and screen grants behind each role, and one login per role.
 *
 * This is what makes the super admin console meaningful: `app_screens` is the
 * tickable catalogue, `role_screen_access` is what the console writes, and
 * `role_permissions` is what the API guards read. All three are seeded here so
 * a fresh database comes up with a working, sensible default rather than every
 * role seeing nothing.
 *
 * ── Credentials ────────────────────────────────────────────────────────────
 * Every account is created with a RANDOM temporary password and
 * `must_change_password = true`. Passwords are written to
 * `prisma/.seeded-credentials.txt` (gitignored) and printed once. They are
 * never committed and never reused between runs.
 *
 * Re-running is safe: everything upserts on a natural key, and an existing
 * user's password is left alone rather than being reset under them.
 *
 * Run: node prisma/seed-rbac.js
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter: new PrismaPg(pool) });

/**
 * Roles are seeded into the operating tenant, not into `__system__`.
 *
 * `__system__` is the cross-tenant template shelf, and `RbacAdminService`
 * deliberately refuses to edit anything on it — one council editing a shared
 * template would silently change every other council's roles. Seeding the
 * whole designation roster there made every role read-only, which defeats the
 * console: the super admin could not switch a single sidebar entry on or off
 * without cloning first. They stay `is_system: true`, so they cannot be
 * deleted, but they belong to the tenant that uses them.
 */
const ROLE_TENANT = 'default';

// ── Groups, matching RoleNavigationConfig ───────────────────────────────────
const G = {
  OVERVIEW: 'OVERVIEW',
  CITIZEN: 'CITIZEN SERVICES',
  REVENUE: 'REVENUE',
  REGULATORY: 'REGULATORY SERVICES',
  WORKS: 'PUBLIC WORKS',
  PROCUREMENT: 'PROCUREMENT',
  WORKFORCE: 'WORKFORCE',
  INSIGHTS: 'INSIGHTS',
  ADMIN: 'ADMINISTRATION',
};

/**
 * The screen registry.
 *
 * `key` must match the id in the Dart nav catalogue exactly — that pairing is
 * what lets the server decide what the client renders. `permission_code` ties
 * the menu entry to the API permission behind it so a role can never be shown
 * a destination whose endpoints would reject it.
 */
const SCREENS = [
  // Overview
  { key: 'home', route: '/dashboard', group_key: G.OVERVIEW, label_en: 'Dashboard', label_ta: 'கட்டுப்பாட்டு பலகை', icon: 'dashboard_rounded', module: 'core', permission_code: null },

  // Citizen services
  { key: 'complaints',     route: '/complaints',     group_key: G.CITIZEN, label_en: 'Complaints',       label_ta: 'புகார்கள்',        icon: 'report_problem_rounded', module: 'complaint_mgmt', permission_code: 'complaints.read' },
  { key: 'citizen_portal', route: '/citizen-portal', group_key: G.CITIZEN, label_en: 'Citizen portal',   label_ta: 'குடிமக்கள் வலைவாசல்', icon: 'campaign_outlined',      module: 'complaint_mgmt', permission_code: 'complaints.read' },
  { key: 'ivr',            route: '/voice-ivr',      group_key: G.CITIZEN, label_en: 'Voice & IVR',      label_ta: 'குரல் & IVR',       icon: 'call_rounded',           module: 'ivr_system',     permission_code: 'complaints.read' },
  { key: 'search',         route: '/search',         group_key: G.CITIZEN, label_en: 'Universal search', label_ta: 'தேடல்',             icon: 'manage_search_rounded',  module: 'core',           permission_code: null },

  // Revenue
  { key: 'property_tax',     route: '/revenue/property-tax',                   group_key: G.REVENUE, label_en: 'Property tax',        label_ta: 'சொத்து வரி',        icon: 'currency_rupee_rounded', module: 'property_tax',    permission_code: 'property_tax.read' },
  { key: 'trade_licences',   route: '/municipality/trade-licences',            group_key: G.REVENUE, label_en: 'Trade licences',      label_ta: 'வணிக உரிமங்கள்',     icon: 'storefront_outlined',    module: 'trade_licence',   permission_code: 'trade_licences.read' },
  { key: 'licence_renewals', route: '/municipality/trade-licences/renewals',   group_key: G.REVENUE, label_en: 'Licence renewals',    label_ta: 'உரிம புதுப்பித்தல்',  icon: 'autorenew_rounded',      module: 'trade_licence',   permission_code: 'trade_licences.write' },
  { key: 'markets',          route: '/revenue/markets',                        group_key: G.REVENUE, label_en: 'Market stall fees',   label_ta: 'சந்தை கட்டணம்',      icon: 'storefront_rounded',     module: 'market_mgmt',     permission_code: 'markets.read' },
  { key: 'asset_rental',     route: '/revenue/assets',                         group_key: G.REVENUE, label_en: 'Asset rental',        label_ta: 'சொத்து வாடகை',       icon: 'domain_rounded',         module: 'asset_booking',   permission_code: 'asset_booking.read' },
  { key: 'ad_campaigns',     route: '/revenue/ads',                            group_key: G.REVENUE, label_en: 'Ad campaigns',        label_ta: 'விளம்பரங்கள்',        icon: 'ad_units_rounded',       module: 'ad_campaign',     permission_code: 'ad_campaigns.read' },
  { key: 'penalties',        route: '/revenue/penalties',                      group_key: G.REVENUE, label_en: 'Technician penalties',label_ta: 'அபராதங்கள்',         icon: 'warning_rounded',        module: 'penalty_mgmt',    permission_code: 'penalties.read' },

  // Regulatory services
  { key: 'building_permits', route: '/municipality/building-permits', group_key: G.REGULATORY, label_en: 'Building permits',       label_ta: 'கட்டட அனுமதி',        icon: 'home_work_outlined',  module: 'building_permit', permission_code: 'building_permits.read' },
  { key: 'vital_events',     route: '/municipality/vital-events',     group_key: G.REGULATORY, label_en: 'Birth & death register', label_ta: 'பிறப்பு இறப்பு பதிவு', icon: 'menu_book_outlined',  module: 'birth_death_reg', permission_code: 'vital_events.read' },
  { key: 'certificates',     route: '/revenue/certificates',          group_key: G.REGULATORY, label_en: 'Certificate requests',   label_ta: 'சான்றிதழ் கோரிக்கை',   icon: 'task_rounded',        module: 'certificate_mgmt', permission_code: 'certificates.read' },

  // Public works
  { key: 'poles',        route: '/poles',                     group_key: G.WORKS, label_en: 'Street lighting',   label_ta: 'தெருவிளக்கு',      icon: 'alt_route_rounded',      module: 'street_light_mgmt', permission_code: 'street_lights.read' },
  { key: 'water_supply', route: '/water',                     group_key: G.WORKS, label_en: 'Water supply',      label_ta: 'குடிநீர் வழங்கல்',  icon: 'water_drop_rounded',     module: 'water_supply_mgmt', permission_code: 'water_supply.read' },
  { key: 'solid_waste',  route: '/municipality/solid-waste',  group_key: G.WORKS, label_en: 'Solid waste',       label_ta: 'திடக்கழிவு',        icon: 'delete_outline_rounded', module: 'solid_waste_mgmt',  permission_code: 'solid_waste.read' },
  { key: 'public_health',route: '/municipality/health',       group_key: G.WORKS, label_en: 'Public health',     label_ta: 'பொது சுகாதாரம்',    icon: 'medical_services_rounded', module: 'public_health',   permission_code: 'public_health.read' },
  { key: 'inspections',  route: '/inspections',               group_key: G.WORKS, label_en: 'Field inspections', label_ta: 'கள ஆய்வு',          icon: 'checklist_rtl_rounded',  module: 'core',              permission_code: 'inspections.read' },
  { key: 'zones',        route: '/zone-management',           group_key: G.WORKS, label_en: 'Zones & GIS',       label_ta: 'மண்டலங்கள்',        icon: 'map_rounded',            module: 'zone_management',   permission_code: 'zones.read' },

  // Procurement
  { key: 'tenders',       route: '/tenders',               group_key: G.PROCUREMENT, label_en: 'Tenders',        label_ta: 'டெண்டர்கள்',      icon: 'assignment_rounded',      module: 'tender_mgmt', permission_code: 'tenders.read' },
  { key: 'vendor_portal', route: '/tenders/vendor-portal', group_key: G.PROCUREMENT, label_en: 'Bidding portal', label_ta: 'ஏல வலைவாசல்',     icon: 'gavel_rounded',           module: 'tender_mgmt', permission_code: 'tenders.read' },
  { key: 'contractors',   route: '/contractors',           group_key: G.PROCUREMENT, label_en: 'Contractors',    label_ta: 'ஒப்பந்ததாரர்கள்',  icon: 'engineering_outlined',    module: 'tender_mgmt', permission_code: 'contractors.read' },
  { key: 'documents',     route: '/documents',             group_key: G.PROCUREMENT, label_en: 'Documents',      label_ta: 'ஆவணங்கள்',        icon: 'folder_rounded',          module: 'core',        permission_code: 'documents.read' },

  // Workforce
  { key: 'field_workforce',  route: '/workforce',                  group_key: G.WORKFORCE, label_en: 'Field workforce',   label_ta: 'கள பணியாளர்கள்',  icon: 'engineering_rounded',      module: 'core', permission_code: 'employees.read' },
  { key: 'employees',        route: '/admin/employees',            group_key: G.WORKFORCE, label_en: 'Employee directory',label_ta: 'பணியாளர் பட்டியல்', icon: 'badge_rounded',            module: 'core', permission_code: 'employees.read' },

  // Insights
  { key: 'insights',   route: '/insights',            group_key: G.INSIGHTS, label_en: 'Reports & analytics', label_ta: 'அறிக்கைகள்',   icon: 'insights_rounded',             module: 'core', permission_code: 'reports.read' },
  { key: 'audit_logs', route: '/admin/audit-logs',    group_key: G.INSIGHTS, label_en: 'Audit log',           label_ta: 'தணிக்கை பதிவு',  icon: 'history_edu_rounded',         module: 'core', permission_code: 'audit.read' },

  // Administration — platform-only screens are marked so a branch role is
  // never offered them in the console.
  { key: 'settings', route: '/settings',           group_key: G.ADMIN, label_en: 'Settings',           label_ta: 'அமைப்புகள்',      icon: 'settings_rounded',              module: 'core', permission_code: 'settings.manage' },
  { key: 'tenants',  route: '/admin/tenants',      group_key: G.ADMIN, label_en: 'Tenants (clients)',  label_ta: 'வாடிக்கையாளர்கள்', icon: 'corporate_fare_rounded',        module: 'core', permission_code: 'tenants.manage', is_platform_only: true },
  { key: 'branches', route: '/panchayats',         group_key: G.ADMIN, label_en: 'Branches & branding',label_ta: 'கிளைகள்',         icon: 'account_balance_rounded',       module: 'core', permission_code: 'branches.manage', is_platform_only: true },
  { key: 'users',    route: '/users',              group_key: G.ADMIN, label_en: 'User accounts',      label_ta: 'பயனர் கணக்குகள்',  icon: 'people_rounded',                module: 'core', permission_code: 'users.manage' },
  { key: 'roles',    route: '/superadmin/roles',   group_key: G.ADMIN, label_en: 'Roles & permissions',label_ta: 'பணி & அனுமதிகள்',  icon: 'admin_panel_settings_rounded',  module: 'core', permission_code: 'rbac.manage' },
];

// ── Permissions the screens above reference, plus the write/approve verbs ───
const MODULES = [
  'complaints', 'property_tax', 'trade_licences', 'markets', 'asset_booking',
  'ad_campaigns', 'penalties', 'building_permits', 'vital_events',
  'certificates', 'street_lights', 'water_supply', 'solid_waste',
  'public_health', 'inspections', 'zones', 'tenders', 'contractors',
  'documents', 'employees', 'reports', 'audit', 'settings', 'tenants',
  'branches', 'users', 'rbac',
];
const ACTIONS = ['read', 'write', 'approve', 'delete', 'export', 'manage'];

/** Screen sets, by job. Roles below compose these rather than repeat them. */
const S = {
  base: ['home'],
  citizen: ['complaints', 'citizen_portal', 'search'],
  ivr: ['ivr'],
  revenue: ['property_tax', 'trade_licences', 'licence_renewals', 'markets', 'asset_rental', 'ad_campaigns'],
  regulatory: ['building_permits', 'vital_events', 'certificates'],
  works: ['poles', 'water_supply', 'solid_waste', 'public_health', 'inspections', 'zones'],
  procurement: ['tenders', 'contractors', 'vendor_portal'],
  workforce: ['field_workforce', 'employees'],
  insights: ['insights', 'audit_logs'],
  admin: ['settings', 'users', 'roles'],
};
const flat = (...sets) => [...new Set(sets.flat())];

const ALL = 'ALL'; // sentinel: every branch type

/**
 * The role roster.
 *
 * Names match the `@Roles()` strings used by the controllers. `types` records
 * which local-body types actually have the post — a village panchayat has no
 * Municipal Commissioner and the console should not offer one.
 *
 * `perm_modules` grants read+write on those modules; `approve_modules` adds the
 * approving verbs. Screens are granted separately, because being able to call
 * an API and being shown a menu entry are different decisions.
 */
const ROLES = [
  // ── Platform ──
  {
    name: 'super_admin', display_name: 'Super Administrator', display_name_ta: 'மேலாளர்',
    hierarchy_level: 0, is_super_admin: true, can_approve: true, types: ALL,
    screens: 'ALL', perm_modules: MODULES, approve_modules: MODULES, seed_user: true,
  },

  // ── Urban: Corporation & Municipality ──
  {
    name: 'municipal_commissioner', display_name: 'Municipal Commissioner', display_name_ta: 'நகராட்சி ஆணையர்',
    hierarchy_level: 1, can_approve: true, department: 'Administration',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY'],
    screens: flat(S.base, S.citizen, S.regulatory, ['trade_licences', 'solid_waste'], S.procurement, S.insights),
    perm_modules: ['complaints', 'building_permits', 'vital_events', 'trade_licences', 'solid_waste', 'tenders', 'contractors', 'reports', 'audit'],
    approve_modules: ['building_permits', 'vital_events', 'trade_licences', 'tenders'],
    seed_user: true,
  },
  {
    name: 'deputy_commissioner', display_name: 'Deputy Commissioner', display_name_ta: 'துணை ஆணையர்',
    hierarchy_level: 2, can_approve: true, department: 'Administration',
    types: ['MUNICIPAL_CORPORATION'],
    screens: flat(S.base, S.citizen, S.regulatory, S.works, S.insights),
    perm_modules: ['complaints', 'building_permits', 'vital_events', 'solid_waste', 'water_supply', 'street_lights', 'reports'],
    approve_modules: ['building_permits', 'vital_events'],
    seed_user: true,
  },
  {
    name: 'municipal_engineer', display_name: 'Municipal Engineer', display_name_ta: 'நகராட்சி பொறியாளர்',
    hierarchy_level: 3, can_approve: true, department: 'Engineering',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY', 'TOWN_PANCHAYAT'],
    screens: flat(S.base, ['complaints'], S.works, S.procurement, ['insights']),
    perm_modules: ['complaints', 'street_lights', 'water_supply', 'inspections', 'zones', 'tenders', 'contractors', 'reports'],
    approve_modules: ['street_lights', 'water_supply', 'inspections'],
    seed_user: true,
  },
  {
    name: 'assistant_engineer', display_name: 'Assistant Engineer', display_name_ta: 'உதவி பொறியாளர்',
    hierarchy_level: 4, department: 'Engineering',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY', 'TOWN_PANCHAYAT', 'PANCHAYAT_UNION'],
    screens: flat(S.base, ['complaints', 'poles', 'water_supply', 'inspections', 'insights']),
    perm_modules: ['complaints', 'street_lights', 'water_supply', 'inspections', 'reports'],
    seed_user: true,
  },
  {
    name: 'junior_engineer', display_name: 'Junior Engineer', display_name_ta: 'இளநிலை பொறியாளர்',
    hierarchy_level: 5, department: 'Engineering',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY', 'TOWN_PANCHAYAT', 'PANCHAYAT_UNION', 'VILLAGE_PANCHAYAT'],
    screens: flat(S.base, ['complaints', 'poles', 'water_supply', 'inspections']),
    perm_modules: ['complaints', 'street_lights', 'water_supply', 'inspections'],
    seed_user: true,
  },
  {
    name: 'health_officer', display_name: 'City Health Officer', display_name_ta: 'நகர சுகாதார அலுவலர்',
    hierarchy_level: 3, can_approve: true, department: 'Public Health',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY'],
    screens: flat(S.base, ['complaints', 'solid_waste', 'public_health', 'vital_events', 'trade_licences', 'inspections', 'insights']),
    perm_modules: ['complaints', 'solid_waste', 'public_health', 'vital_events', 'trade_licences', 'inspections', 'reports'],
    approve_modules: ['trade_licences', 'public_health'],
    seed_user: true,
  },
  {
    name: 'sanitary_inspector', display_name: 'Sanitary Inspector', display_name_ta: 'சுகாதார ஆய்வாளர்',
    hierarchy_level: 5, department: 'Public Health',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY', 'TOWN_PANCHAYAT'],
    screens: flat(S.base, ['complaints', 'solid_waste', 'public_health', 'inspections', 'zones']),
    perm_modules: ['complaints', 'solid_waste', 'public_health', 'inspections'],
    seed_user: true,
  },
  {
    name: 'revenue_officer', display_name: 'Revenue Officer', display_name_ta: 'வருவாய் அலுவலர்',
    hierarchy_level: 3, can_approve: true, department: 'Revenue',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY', 'TOWN_PANCHAYAT'],
    screens: flat(S.base, S.revenue, ['certificates'], S.insights),
    perm_modules: ['property_tax', 'trade_licences', 'markets', 'asset_booking', 'ad_campaigns', 'certificates', 'reports', 'audit'],
    approve_modules: ['property_tax', 'trade_licences', 'certificates'],
    seed_user: true,
  },
  {
    name: 'revenue_inspector', display_name: 'Revenue Inspector', display_name_ta: 'வருவாய் ஆய்வாளர்',
    hierarchy_level: 5, department: 'Revenue',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY', 'TOWN_PANCHAYAT'],
    screens: flat(S.base, ['markets', 'ad_campaigns', 'asset_rental', 'insights']),
    perm_modules: ['markets', 'ad_campaigns', 'asset_booking', 'reports'],
    seed_user: true,
  },
  {
    name: 'town_planning_officer', display_name: 'Town Planning Officer', display_name_ta: 'நகர அமைப்பு அலுவலர்',
    hierarchy_level: 3, can_approve: true, department: 'Town Planning',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY'],
    screens: flat(S.base, ['building_permits', 'inspections', 'zones'], S.insights),
    perm_modules: ['building_permits', 'inspections', 'zones', 'reports', 'audit'],
    approve_modules: ['building_permits'],
    seed_user: true,
  },
  {
    name: 'registrar', display_name: 'Registrar of Births & Deaths', display_name_ta: 'பிறப்பு இறப்பு பதிவாளர்',
    hierarchy_level: 4, can_approve: true, department: 'Vital Statistics',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY', 'TOWN_PANCHAYAT', 'VILLAGE_PANCHAYAT'],
    screens: flat(S.base, ['vital_events', 'certificates'], S.insights),
    perm_modules: ['vital_events', 'certificates', 'reports', 'audit'],
    approve_modules: ['vital_events', 'certificates'],
    seed_user: true,
  },
  {
    name: 'licensing_clerk', display_name: 'Licensing Clerk', display_name_ta: 'உரிமம் எழுத்தர்',
    hierarchy_level: 6, department: 'Revenue',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY', 'TOWN_PANCHAYAT'],
    screens: flat(S.base, ['trade_licences', 'licence_renewals', 'inspections', 'insights']),
    perm_modules: ['trade_licences', 'inspections', 'reports'],
    seed_user: true,
  },
  {
    name: 'accounts_officer', display_name: 'Accounts Officer', display_name_ta: 'கணக்கு அலுவலர்',
    hierarchy_level: 4, department: 'Accounts',
    types: ['MUNICIPAL_CORPORATION', 'MUNICIPALITY'],
    screens: flat(S.base, ['property_tax', 'markets', 'asset_rental'], S.insights),
    perm_modules: ['property_tax', 'markets', 'asset_booking', 'reports', 'audit'],
    seed_user: true,
  },

  // ── Town & Village Panchayat ──
  {
    name: 'executive_officer', display_name: 'Executive Officer', display_name_ta: 'செயல் அலுவலர்',
    hierarchy_level: 1, can_approve: true, department: 'Administration',
    types: ['TOWN_PANCHAYAT'],
    screens: flat(S.base, S.citizen, S.revenue, S.regulatory, S.works, S.insights, ['settings']),
    perm_modules: ['complaints', 'property_tax', 'trade_licences', 'markets', 'building_permits', 'vital_events', 'certificates', 'solid_waste', 'water_supply', 'street_lights', 'reports', 'audit'],
    approve_modules: ['property_tax', 'trade_licences', 'building_permits', 'vital_events'],
    seed_user: true,
  },
  {
    name: 'panchayat_president', display_name: 'Panchayat President', display_name_ta: 'ஊராட்சி தலைவர்',
    hierarchy_level: 1, can_approve: true, department: 'Administration',
    types: ['VILLAGE_PANCHAYAT'],
    screens: flat(S.base, ['complaints', 'citizen_portal'], S.works, S.insights),
    perm_modules: ['complaints', 'street_lights', 'water_supply', 'solid_waste', 'reports'],
    approve_modules: ['street_lights', 'water_supply'],
    seed_user: true,
  },
  {
    name: 'panchayat_secretary', display_name: 'Panchayat Secretary', display_name_ta: 'ஊராட்சி செயலாளர்',
    hierarchy_level: 3, department: 'Administration',
    types: ['VILLAGE_PANCHAYAT'],
    screens: flat(S.base, S.citizen, ['property_tax', 'vital_events', 'certificates'], S.works, ['insights']),
    perm_modules: ['complaints', 'property_tax', 'vital_events', 'certificates', 'street_lights', 'water_supply', 'reports'],
    seed_user: true,
  },
  {
    name: 'bill_collector', display_name: 'Bill Collector', display_name_ta: 'வரி வசூலிப்பாளர்',
    hierarchy_level: 6, department: 'Revenue',
    types: ['VILLAGE_PANCHAYAT', 'TOWN_PANCHAYAT'],
    screens: flat(S.base, ['property_tax', 'markets']),
    perm_modules: ['property_tax', 'markets'],
    seed_user: true,
  },

  // ── Panchayat Union & District Panchayat ──
  {
    name: 'block_development_officer', display_name: 'Block Development Officer', display_name_ta: 'ஊராட்சி ஒன்றிய வளர்ச்சி அலுவலர்',
    hierarchy_level: 1, can_approve: true, department: 'Administration',
    types: ['PANCHAYAT_UNION'],
    screens: flat(S.base, S.citizen, S.works, S.procurement, S.insights),
    perm_modules: ['complaints', 'street_lights', 'water_supply', 'inspections', 'zones', 'tenders', 'contractors', 'reports', 'audit'],
    approve_modules: ['tenders', 'water_supply'],
    seed_user: true,
  },
  {
    name: 'district_panchayat_officer', display_name: 'District Panchayat Officer', display_name_ta: 'மாவட்ட ஊராட்சி அலுவலர்',
    hierarchy_level: 1, can_approve: true, department: 'Administration',
    types: ['DISTRICT_PANCHAYAT'],
    screens: flat(S.base, ['complaints'], S.procurement, S.insights),
    perm_modules: ['complaints', 'tenders', 'contractors', 'reports', 'audit'],
    approve_modules: ['tenders'],
    seed_user: true,
  },

  // ── Cross-cutting branch administration ──
  {
    name: 'panchayat_admin', display_name: 'Branch Administrator', display_name_ta: 'கிளை நிர்வாகி',
    hierarchy_level: 2, can_approve: true, department: 'Administration', types: ALL,
    // Gets `users` and `roles`, not just `settings`. A client that cannot
    // create its own staff accounts or define its own designations is not
    // administering anything — every new posting would have to come back to
    // the platform operator. `branches` and `tenants` stay platform-only:
    // those decide which bodies exist and what they have licensed.
    screens: flat(S.base, S.citizen, S.ivr, S.revenue, S.regulatory, S.works, S.procurement, S.workforce, S.insights, S.admin),
    perm_modules: MODULES.filter((m) => !['tenants', 'branches'].includes(m)),
    approve_modules: ['complaints', 'property_tax', 'trade_licences', 'building_permits', 'vital_events'],
    seed_user: true,
  },
  {
    name: 'i3c_staff', display_name: 'I3C Control Room Staff', display_name_ta: 'கட்டுப்பாட்டு அறை பணியாளர்',
    hierarchy_level: 5, department: 'Control Room', types: ALL,
    screens: flat(S.base, S.citizen, S.ivr, ['zones']),
    perm_modules: ['complaints', 'zones'],
    seed_user: true,
  },

  // ── External & field ──
  {
    name: 'contractor', display_name: 'Contractor', display_name_ta: 'ஒப்பந்ததாரர்',
    hierarchy_level: 8, department: 'External', types: ALL, user_type: 'contractor',
    screens: flat(S.base, ['vendor_portal', 'documents']),
    perm_modules: ['tenders', 'documents'],
    seed_user: true,
  },
  {
    name: 'electrician', display_name: 'Electrician', display_name_ta: 'மின் பணியாளர்',
    hierarchy_level: 7, department: 'Field', types: ALL,
    screens: ['home'], perm_modules: ['complaints', 'street_lights'], seed_user: true,
  },
  {
    name: 'plumber', display_name: 'Plumber', display_name_ta: 'குழாய் பணியாளர்',
    hierarchy_level: 7, department: 'Field', types: ALL,
    screens: ['home'], perm_modules: ['complaints', 'water_supply'], seed_user: true,
  },
  {
    name: 'agent', display_name: 'Survey Agent', display_name_ta: 'கள ஆய்வாளர்',
    hierarchy_level: 7, department: 'Field', types: ALL,
    screens: ['home'], perm_modules: ['street_lights', 'water_supply'], seed_user: true,
  },
];

// ── Helpers ─────────────────────────────────────────────────────────────────

/** URL-safe temporary password. Random per account, never reused. */
const tempPassword = () =>
  crypto.randomBytes(9).toString('base64url').replace(/[^A-Za-z0-9]/g, 'x') + '#1';

const emailFor = (roleName) => `${roleName}@ooraatchi.local`;

async function main() {
  console.log('\n── Seeding RBAC ─────────────────────────────────────────\n');

  // 1. Permissions
  const permRows = [];
  for (const m of MODULES) {
    for (const a of ACTIONS) permRows.push({ code: `${m}.${a}`, module: m, action: a });
  }
  for (const p of permRows) {
    await prisma.permission.upsert({
      where: { code: p.code },
      update: { module: p.module, action: p.action },
      create: p,
    });
  }
  console.log(`  permissions      ${permRows.length}`);

  const permByCode = new Map(
    (await prisma.permission.findMany({ select: { id: true, code: true } })).map((p) => [p.code, p.id]),
  );

  // 2. Screen registry
  for (const [i, s] of SCREENS.entries()) {
    await prisma.appScreen.upsert({
      where: { key: s.key },
      update: { ...s, sort_order: i, is_active: true },
      create: { ...s, sort_order: i },
    });
  }
  console.log(`  screens          ${SCREENS.length}`);

  const screenByKey = new Map(
    (await prisma.appScreen.findMany({ select: { id: true, key: true } })).map((s) => [s.key, s.id]),
  );

  // 3. Roles, grants, screen access
  let userCount = 0;
  const credentials = [];

  for (const r of ROLES) {
    const fields = {
      display_name: r.display_name,
      display_name_ta: r.display_name_ta,
      department: r.department ?? null,
      hierarchy_level: r.hierarchy_level,
      is_super_admin: !!r.is_super_admin,
      can_approve: !!r.can_approve,
      is_system: true,
      is_active: true,
      applicable_branch_types: r.types === ALL ? [] : r.types,
    };

    // `upsert` is unusable here: the compound unique is
    // (tenant_id, org_unit_id, name) and `org_unit_id` is NULL for a
    // tenant-wide template. Prisma's generated compound-key `where` type
    // rejects null, because SQL NULL never equals NULL and the underlying
    // unique index would not match anyway. findFirst + create/update is the
    // shape that actually works for a nullable member of a compound key.
    const existingRole = await prisma.role.findFirst({
      where: { tenant_id: ROLE_TENANT, org_unit_id: null, name: r.name },
    });

    const role = existingRole
      ? await prisma.role.update({ where: { id: existingRole.id }, data: fields })
      : await prisma.role.create({
          data: {
            tenant_id: ROLE_TENANT,
            org_unit_id: null,
            name: r.name,
            ...fields,
          },
        });

    // Permission grants: read+write on listed modules, plus approving verbs.
    const codes = new Set();
    for (const m of r.perm_modules ?? []) {
      codes.add(`${m}.read`);
      codes.add(`${m}.write`);
    }
    for (const m of r.approve_modules ?? []) {
      codes.add(`${m}.approve`);
    }
    if (r.is_super_admin) {
      for (const m of MODULES) for (const a of ACTIONS) codes.add(`${m}.${a}`);
    }

    for (const code of codes) {
      const pid = permByCode.get(code);
      if (!pid) continue;
      await prisma.rolePermission.upsert({
        where: { role_id_permission_id: { role_id: role.id, permission_id: pid } },
        update: {},
        create: { role_id: role.id, permission_id: pid },
      });
    }

    // Screen access.
    const keys = r.screens === 'ALL' ? SCREENS.map((s) => s.key) : r.screens;
    for (const key of keys) {
      const sid = screenByKey.get(key);
      if (!sid) continue;
      await prisma.roleScreenAccess.upsert({
        where: { role_id_screen_id: { role_id: role.id, screen_id: sid } },
        update: { can_view: true },
        create: { role_id: role.id, screen_id: sid, can_view: true },
      });
    }

    // 4. One login per role.
    if (r.seed_user) {
      const email = emailFor(r.name);
      const existing = await prisma.user.findFirst({ where: { email } });

      if (existing) {
        console.log(`  · ${r.name.padEnd(28)} user exists, password untouched`);
      } else {
        const pwd = tempPassword();
        const user = await prisma.user.create({
          data: {
            tenant_id: 'default',
            email,
            password_hash: await bcrypt.hash(pwd, 10),
            role: r.name,
            user_type: r.user_type ?? 'employee',
            is_active: true,
            is_verified: true,
            must_change_password: true,
          },
        });
        await prisma.userRole
          .create({
            data: { user_id: user.id, role_id: role.id, org_unit_id: 1, is_primary: true },
          })
          .catch(() => {
            console.log(`     (no org unit #1 yet — assign ${r.name} a branch in the console)`);
          });
        credentials.push({ role: r.display_name, email, password: pwd });
        userCount++;
      }
    }
  }

  console.log(`\n  roles            ${ROLES.length}`);
  console.log(`  new accounts     ${userCount}`);

  // 5. Credentials file — gitignored, rewritten each run.
  if (credentials.length) {
    const out = path.join(__dirname, '.seeded-credentials.txt');
    const body = [
      'SEEDED LOGIN CREDENTIALS',
      `Generated ${new Date().toISOString()}`,
      '',
      'Every account below is flagged must_change_password: the user is forced',
      'to set a new password at first login. These are provisioning secrets —',
      'do not commit this file or paste it into chat.',
      '',
      ...credentials.map((c) => `${c.role.padEnd(34)} ${c.email.padEnd(42)} ${c.password}`),
      '',
    ].join('\n');
    fs.writeFileSync(out, body, { mode: 0o600 });
    console.log(`\n  credentials      ${out}`);
    console.log('                   (gitignored — read it, then distribute securely)\n');
  } else {
    console.log('\n  credentials      no new accounts; nothing written\n');
  }
}

main()
  .catch((e) => {
    console.error('\nSeed failed:', e.message, '\n');
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
