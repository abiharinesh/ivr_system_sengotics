import 'package:flutter/material.dart';

/// One sidebar link.
class NavSpec {
  final IconData icon;
  final String label;
  final String? route;

  const NavSpec({required this.icon, required this.label, this.route});
}

/// A titled group of links (e.g. "WATER SUPPLY"). Rendered only if [items]
/// is non-empty — an empty group with just a floating header was one of the
/// concrete causes of sidebar clutter (every field-agnostic role saw four
/// section headers with nothing underneath).
class NavSection {
  final String title;
  final List<NavSpec> items;

  const NavSection({required this.title, required this.items});
}

/// Single source of truth for what each role's sidebar shows.
///
/// Replaces the previous scheme in `app_scaffold.dart`, where the primary
/// menu was a 15-branch if/else and the four secondary sections (Water
/// Supply, Revenue & Assets, Operations & Portal, Reports & System) were
/// shown to *every* role except agent/electrician/plumber — regardless of
/// whether the section had anything to do with that role's job, and
/// regardless of whether the same items were already duplicated in that
/// role's primary menu (e.g. `revenue_officer` had every revenue screen
/// listed twice: once in its own primary menu, once again in the shared
/// "REVENUE & ASSETS" section).
///
/// Section visibility below follows one rule: a role sees a section only if
/// it's relevant to that role's job *and* not already covered in its own
/// primary menu.
class RoleNavigationConfig {
  RoleNavigationConfig._();

  static const _waterSupply = NavSection(
    title: 'WATER SUPPLY',
    items: [
      NavSpec(icon: Icons.grid_on_rounded, label: 'Pipeline Grid', route: '/water/pipeline-grid'),
      NavSpec(icon: Icons.opacity_rounded, label: 'Tanks & Borewells', route: '/water/tanks'),
      NavSpec(icon: Icons.history_edu_rounded, label: 'Water Flow Logs', route: '/water/flow-logs'),
      NavSpec(icon: Icons.approval_rounded, label: 'Infra Approvals', route: '/water/approvals'),
    ],
  );

  static const _revenue = NavSection(
    title: 'REVENUE & ASSETS',
    items: [
      NavSpec(icon: Icons.currency_rupee_rounded, label: 'Property Tax', route: '/revenue/property-tax'),
      NavSpec(icon: Icons.storefront_rounded, label: 'Market Stall Fees', route: '/revenue/markets'),
      NavSpec(icon: Icons.domain_rounded, label: 'Community Asset Rental', route: '/revenue/assets'),
      NavSpec(icon: Icons.task_rounded, label: 'Certificate Reviews', route: '/revenue/certificates'),
      NavSpec(icon: Icons.ad_units_rounded, label: 'Ad Campaigns', route: '/revenue/ads'),
      NavSpec(icon: Icons.warning_rounded, label: 'Technician Penalties', route: '/revenue/penalties'),
    ],
  );

  static const _operations = NavSection(
    title: 'OPERATIONS & PORTAL',
    items: [
      NavSpec(icon: Icons.engineering_outlined, label: 'Contractors', route: '/contractors'),
      NavSpec(icon: Icons.checklist_rtl_outlined, label: 'Field Inspections', route: '/inspections'),
      NavSpec(icon: Icons.manage_search_rounded, label: 'Universal Search', route: '/search'),
      NavSpec(icon: Icons.campaign_outlined, label: 'Citizen Portal', route: '/citizen-portal'),
      NavSpec(icon: Icons.account_balance_outlined, label: 'Municipality Modules', route: '/municipality'),
    ],
  );

  static const _reportsSystem = NavSection(
    title: 'REPORTS & SYSTEM',
    items: [
      NavSpec(icon: Icons.document_scanner_rounded, label: 'Report Generation', route: '/report-generation'),
      NavSpec(icon: Icons.insights_rounded, label: 'Analytics', route: '/analytics'),
      NavSpec(icon: Icons.palette_rounded, label: 'Customization', route: '/settings/customization'),
      NavSpec(icon: Icons.description_outlined, label: 'Document templates', route: '/settings/document-templates'),
      NavSpec(icon: Icons.settings_rounded, label: 'AI Settings', route: '/ai-settings'),
    ],
  );

  /// Extra items only `super_admin` sees — platform-wide client management,
  /// added once the Tenant concept became real (previously these screens
  /// existed but were unreachable from any sidebar).
  static const _superAdminPlatform = NavSection(
    title: 'PLATFORM',
    items: [
      NavSpec(icon: Icons.corporate_fare_rounded, label: 'Tenants (Clients)', route: '/admin/tenants'),
      NavSpec(icon: Icons.badge_rounded, label: 'Employee Directory', route: '/admin/employees'),
      NavSpec(icon: Icons.assignment_ind_rounded, label: 'Role Assignments', route: '/admin/rbac/user-assignments'),
    ],
  );

  static const Map<String, List<NavSpec>> _primaryByRole = {
    'agent': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Home', route: '/agent'),
      NavSpec(icon: Icons.list_alt_rounded, label: 'Poles', route: '/agent/poles'),
      NavSpec(icon: Icons.add_location_alt_rounded, label: 'New pole', route: '/agent/poles/add'),
      NavSpec(icon: Icons.water_drop_rounded, label: 'Pipeline & Tap Capture', route: '/agent/pipeline-tap-capture'),
    ],
    'electrician': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Home', route: '/electrician'),
      NavSpec(icon: Icons.electrical_services_rounded, label: 'My jobs', route: '/electrician/jobs'),
    ],
    'plumber': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Home', route: '/plumber'),
      NavSpec(icon: Icons.plumbing_rounded, label: 'My jobs', route: '/plumber/jobs'),
    ],
    'municipal_commissioner': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/commissioner'),
      NavSpec(icon: Icons.report_problem_rounded, label: 'Complaints', route: '/complaints'),
      NavSpec(icon: Icons.assignment_rounded, label: 'Tenders', route: '/tenders'),
      NavSpec(icon: Icons.insights_rounded, label: 'SLA Analytics', route: '/analytics/sla'),
      NavSpec(icon: Icons.dashboard_customize_rounded, label: 'Executive View', route: '/dashboard/executive'),
      NavSpec(icon: Icons.approval_rounded, label: 'Approvals Inbox', route: '/approvals'),
    ],
    'municipal_engineer': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/municipal-engineer'),
      NavSpec(icon: Icons.alt_route_rounded, label: 'Pole Management', route: '/poles'),
      NavSpec(icon: Icons.grid_on_rounded, label: 'Water Supply', route: '/water/pipeline-grid'),
      NavSpec(icon: Icons.engineering_outlined, label: 'Contractors', route: '/contractors'),
      NavSpec(icon: Icons.assignment_rounded, label: 'Tenders', route: '/tenders'),
      NavSpec(icon: Icons.checklist_rtl_rounded, label: 'Field Inspections', route: '/inspections'),
    ],
    'revenue_officer': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/revenue-officer'),
      NavSpec(icon: Icons.currency_rupee_rounded, label: 'Property Tax', route: '/revenue/property-tax'),
      NavSpec(icon: Icons.storefront_rounded, label: 'Market Stall Fees', route: '/revenue/markets'),
      NavSpec(icon: Icons.domain_rounded, label: 'Asset Rental', route: '/revenue/assets'),
      NavSpec(icon: Icons.ad_units_rounded, label: 'Ad Campaigns', route: '/revenue/ads'),
      NavSpec(icon: Icons.task_rounded, label: 'Certificates', route: '/revenue/certificates'),
      NavSpec(icon: Icons.history_edu_rounded, label: 'Audit Logs', route: '/admin/audit-logs'),
    ],
    'assistant_engineer': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/assistant-engineer'),
      NavSpec(icon: Icons.report_problem_rounded, label: 'Complaints', route: '/complaints'),
      NavSpec(icon: Icons.checklist_rtl_rounded, label: 'Inspections', route: '/inspections'),
      NavSpec(icon: Icons.grid_on_rounded, label: 'Water Supply', route: '/water/pipeline-grid'),
      NavSpec(icon: Icons.alt_route_rounded, label: 'Poles', route: '/poles'),
    ],
    'health_officer': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/health-officer'),
      NavSpec(icon: Icons.delete_rounded, label: 'Solid Waste Mgmt', route: '/municipality/solid-waste'),
      NavSpec(icon: Icons.medical_services_rounded, label: 'Public Health', route: '/municipality/health'),
      NavSpec(icon: Icons.checklist_rtl_rounded, label: 'Inspections', route: '/inspections'),
      NavSpec(icon: Icons.report_problem_rounded, label: 'Complaints', route: '/complaints'),
    ],
    'revenue_inspector': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/revenue-inspector'),
      NavSpec(icon: Icons.storefront_rounded, label: 'Market Fees', route: '/revenue/markets'),
      NavSpec(icon: Icons.ad_units_rounded, label: 'Ad Campaigns', route: '/revenue/ads'),
      NavSpec(icon: Icons.domain_rounded, label: 'Asset Rentals', route: '/revenue/assets'),
      NavSpec(icon: Icons.document_scanner_rounded, label: 'Reports', route: '/report-generation'),
    ],
    'junior_engineer': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/junior-engineer'),
      NavSpec(icon: Icons.checklist_rtl_rounded, label: 'Field Inspections', route: '/inspections'),
      NavSpec(icon: Icons.alt_route_rounded, label: 'Pole Mgmt', route: '/poles'),
      NavSpec(icon: Icons.grid_on_rounded, label: 'Water Supply', route: '/water/pipeline-grid'),
      NavSpec(icon: Icons.report_problem_rounded, label: 'Complaints', route: '/complaints'),
    ],
    'i3c_staff': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/i3c'),
      NavSpec(icon: Icons.report_problem_rounded, label: 'Route Complaints', route: '/complaints'),
      NavSpec(icon: Icons.map_rounded, label: 'Zone Mgmt / GIS', route: '/zone-management'),
      NavSpec(icon: Icons.call_rounded, label: 'Voice Calls', route: '/voice-calls'),
      NavSpec(icon: Icons.receipt_long_rounded, label: 'IVR Logs', route: '/ivr-logs'),
      NavSpec(icon: Icons.manage_search_rounded, label: 'Universal Search', route: '/search'),
    ],
    'contractor': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/contractor-dashboard'),
      NavSpec(icon: Icons.gavel_rounded, label: 'Tender Bidding Portal', route: '/tenders/vendor-portal'),
      NavSpec(icon: Icons.assignment_rounded, label: 'My Work Orders', route: '/work-orders/new'),
      NavSpec(icon: Icons.folder_rounded, label: 'My Documents', route: '/documents'),
    ],
    'super_admin': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
      NavSpec(icon: Icons.report_problem_rounded, label: 'Complaints', route: '/complaints'),
      NavSpec(icon: Icons.map_rounded, label: 'Zone Management', route: '/zone-management'),
      NavSpec(icon: Icons.engineering_rounded, label: 'Electricians', route: '/superadmin/electricians'),
      NavSpec(icon: Icons.plumbing_rounded, label: 'Plumbers', route: '/superadmin/plumbers'),
      NavSpec(icon: Icons.group_rounded, label: 'Agents', route: '/fieldops/agents'),
      NavSpec(icon: Icons.alt_route_rounded, label: 'Pole Management', route: '/poles'),
      NavSpec(icon: Icons.call_rounded, label: 'Voice Calls', route: '/voice-calls'),
      NavSpec(icon: Icons.receipt_long_rounded, label: 'IVR Logs', route: '/ivr-logs'),
      NavSpec(icon: Icons.account_balance_rounded, label: 'Panchayat & Branding', route: '/panchayats'),
      NavSpec(icon: Icons.people_rounded, label: 'User Management', route: '/users'),
      NavSpec(icon: Icons.admin_panel_settings_rounded, label: 'Roles & Permissions', route: '/superadmin/roles'),
      NavSpec(icon: Icons.tune_rounded, label: 'Feature Toggles', route: '/superadmin/feature-toggles'),
      NavSpec(icon: Icons.assignment_rounded, label: 'Tenders', route: '/superadmin/tenders'),
      NavSpec(icon: Icons.store_mall_directory_rounded, label: 'Vendors', route: '/superadmin/vendors'),
      NavSpec(icon: Icons.gavel_rounded, label: 'Vendor Bidding Portal', route: '/tenders/vendor-portal'),
    ],
  };

  /// Default/fallback primary menu — used for `panchayat_admin` and any
  /// other general-purpose admin role not listed above.
  static const List<NavSpec> _defaultPrimary = [
    NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
    NavSpec(icon: Icons.report_problem_rounded, label: 'Complaints', route: '/complaints'),
    NavSpec(icon: Icons.map_rounded, label: 'Zone Management', route: '/zone-management'),
    NavSpec(icon: Icons.electrical_services_rounded, label: 'Poles', route: '/poles'),
    NavSpec(icon: Icons.call_rounded, label: 'Voice Calls', route: '/voice-calls'),
    NavSpec(icon: Icons.receipt_long_rounded, label: 'IVR Logs', route: '/ivr-logs'),
    NavSpec(icon: Icons.engineering_rounded, label: 'Electricians', route: '/admin/electricians'),
    NavSpec(icon: Icons.plumbing_rounded, label: 'Plumbers', route: '/admin/plumbers'),
    NavSpec(icon: Icons.assignment_rounded, label: 'Tenders', route: '/tenders'),
    NavSpec(icon: Icons.store_mall_directory_rounded, label: 'Vendors', route: '/vendors'),
    NavSpec(icon: Icons.gavel_rounded, label: 'Vendor Bidding Portal', route: '/tenders/vendor-portal'),
  ];

  /// Roles that get NO secondary sections at all — dedicated single-purpose
  /// field-work shells with their own compact primary menu.
  static const Set<String> _fieldOnlyRoles = {'agent', 'electrician', 'plumber'};

  /// Which of the 4 shared sections apply to each role, following the rule:
  /// relevant to the job AND not already duplicated in that role's own
  /// primary menu. Roles not listed default to none of these 4 (e.g.
  /// contractor, i3c_staff, revenue roles already have their own full menu).
  static const Map<String, Set<String>> _sectionsByRole = {
    'super_admin': {'water', 'revenue', 'operations', 'reports'},
    'panchayat_admin': {'water', 'revenue', 'operations', 'reports'},
    'municipal_commissioner': {'operations', 'reports'},
    'municipal_engineer': {'water', 'operations'},
    'assistant_engineer': {'water', 'operations'},
    'junior_engineer': {'water', 'operations'},
    'health_officer': {'operations'},
  };

  static List<NavSpec> primaryFor(String role) =>
      _primaryByRole[role] ?? _defaultPrimary;

  /// `super_admin` gets the platform/tenant-management links prepended to
  /// its main menu.
  static List<NavSpec> platformSectionFor(String role) =>
      role == 'super_admin' ? _superAdminPlatform.items : const [];

  static List<NavSection> sectionsFor(String role) {
    if (_fieldOnlyRoles.contains(role)) return const [];
    final enabled = _sectionsByRole[role] ?? const <String>{};
    final sections = <NavSection>[];
    if (enabled.contains('water')) sections.add(_waterSupply);
    if (enabled.contains('revenue')) sections.add(_revenue);
    if (enabled.contains('operations')) sections.add(_operations);
    if (enabled.contains('reports')) sections.add(_reportsSystem);
    return sections;
  }

  /// Every route this role's sidebar can reach — primary + platform + all
  /// enabled sections. Used to compute which nav item is "active".
  static List<String> allRoutesFor(String role) {
    final routes = <String>[
      ...primaryFor(role).map((s) => s.route).whereType<String>(),
      ...platformSectionFor(role).map((s) => s.route).whereType<String>(),
    ];
    for (final section in sectionsFor(role)) {
      routes.addAll(section.items.map((s) => s.route).whereType<String>());
    }
    return routes;
  }
}
