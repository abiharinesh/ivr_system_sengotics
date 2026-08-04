import 'package:flutter/material.dart';

/// One sidebar link.
class NavSpec {
  final IconData icon;
  final String label;
  final String? route;

  const NavSpec({required this.icon, required this.label, this.route});
}

/// A titled group of links. Rendered only if [items] is non-empty.
class NavSection {
  final String title;
  final List<NavSpec> items;

  const NavSection({required this.title, required this.items});
}

/// Single source of truth for what each role's sidebar shows.
///
/// ## Why this is a catalogue, not per-role lists
///
/// The previous scheme kept a hand-written list per role plus four optional
/// shared sections. Three problems followed from that shape, all of which were
/// live in the product:
///
/// 1. **Duplicates.** Nothing stopped the same route appearing in a role's own
///    list *and* in a shared section. `super_admin` and `panchayat_admin` both
///    saw "Trade Licences" twice, from two different sections.
/// 2. **Label drift.** The same screen was "Solid Waste" in one place and
///    "Solid Waste Mgmt" in another; "Poles", "Pole Management" and "Pole Mgmt"
///    were all the same screen.
/// 3. **Volume.** `super_admin` reached 44 sidebar entries, which is not a
///    navigation menu, it is a sitemap.
///
/// Now every destination is declared exactly once in [_catalogue], keyed by an
/// id. A role is a *set of ids*. A set cannot contain a duplicate, and a label
/// exists in exactly one place, so both classes of bug are structurally
/// impossible rather than merely fixed.
///
/// ## What is deliberately not here
///
/// Sidebar entries are **destinations, not actions**. "Report Birth", "New
/// Application" and similar were entries that opened a create form — those
/// belong on the screen that owns them, next to the list they add to, and they
/// have been removed. The `/municipality` hub page is also gone: it was a menu
/// of links to modules that are now themselves in this menu.
class RoleNavigationConfig {
  RoleNavigationConfig._();

  // ── Groups ────────────────────────────────────────────────────────────────
  //
  // Ordered as a working day runs: what needs attention, then the service
  // lines, then the back office.

  static const String gOverview = 'OVERVIEW';
  static const String gCitizen = 'CITIZEN SERVICES';
  static const String gRevenue = 'REVENUE';
  static const String gRegulatory = 'REGULATORY SERVICES';
  static const String gWorks = 'PUBLIC WORKS';
  static const String gProcurement = 'PROCUREMENT';
  static const String gWorkforce = 'WORKFORCE';
  static const String gInsights = 'INSIGHTS';
  static const String gAdmin = 'ADMINISTRATION';

  static const List<String> _groupOrder = [
    gOverview,
    gCitizen,
    gRevenue,
    gRegulatory,
    gWorks,
    gProcurement,
    gWorkforce,
    gInsights,
    gAdmin,
  ];

  /// Every destination in the product, declared once.
  ///
  /// The key is a stable id used by the per-role sets below. Renaming a label
  /// or moving a route touches one line here and nothing else.
  static const Map<String, ({String group, NavSpec spec})> _catalogue = {
    // ── Overview ──
    'home': (
      group: gOverview,
      spec: NavSpec(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: '/dashboard',
      ),
    ),

    // ── Citizen services ──
    'complaints': (
      group: gCitizen,
      spec: NavSpec(
        icon: Icons.report_problem_rounded,
        label: 'Complaints',
        route: '/complaints',
      ),
    ),
    'citizen_portal': (
      group: gCitizen,
      spec: NavSpec(
        icon: Icons.campaign_outlined,
        label: 'Citizen portal',
        route: '/citizen-portal',
      ),
    ),
    'ivr': (
      group: gCitizen,
      spec: NavSpec(
        icon: Icons.call_rounded,
        label: 'Voice & IVR',
        route: '/voice-ivr',
      ),
    ),
    'search': (
      group: gCitizen,
      spec: NavSpec(
        icon: Icons.manage_search_rounded,
        label: 'Universal search',
        route: '/search',
      ),
    ),

    // ── Revenue ──
    'property_tax': (
      group: gRevenue,
      spec: NavSpec(
        icon: Icons.currency_rupee_rounded,
        label: 'Property tax',
        route: '/revenue/property-tax',
      ),
    ),
    'trade_licences': (
      group: gRevenue,
      spec: NavSpec(
        icon: Icons.storefront_outlined,
        label: 'Trade licences',
        route: '/municipality/trade-licences',
      ),
    ),
    // The renewal board is a filtered view of the register, one tap away via
    // its own KPI cards — so it is an entry only for the two roles whose whole
    // job it is.
    'licence_renewals': (
      group: gRevenue,
      spec: NavSpec(
        icon: Icons.autorenew_rounded,
        label: 'Licence renewals',
        route: '/municipality/trade-licences/renewals',
      ),
    ),
    'markets': (
      group: gRevenue,
      spec: NavSpec(
        icon: Icons.storefront_rounded,
        label: 'Market stall fees',
        route: '/revenue/markets',
      ),
    ),
    'asset_rental': (
      group: gRevenue,
      spec: NavSpec(
        icon: Icons.domain_rounded,
        label: 'Asset rental',
        route: '/revenue/assets',
      ),
    ),
    'ad_campaigns': (
      group: gRevenue,
      spec: NavSpec(
        icon: Icons.ad_units_rounded,
        label: 'Ad campaigns',
        route: '/revenue/ads',
      ),
    ),
    'penalties': (
      group: gRevenue,
      spec: NavSpec(
        icon: Icons.warning_rounded,
        label: 'Technician penalties',
        route: '/revenue/penalties',
      ),
    ),

    // ── Regulatory services ──
    'building_permits': (
      group: gRegulatory,
      spec: NavSpec(
        icon: Icons.home_work_outlined,
        label: 'Building permits',
        route: '/municipality/building-permits',
      ),
    ),
    'vital_events': (
      group: gRegulatory,
      spec: NavSpec(
        icon: Icons.menu_book_outlined,
        label: 'Birth & death register',
        route: '/municipality/vital-events',
      ),
    ),
    'certificates': (
      group: gRegulatory,
      spec: NavSpec(
        icon: Icons.task_rounded,
        label: 'Certificate requests',
        route: '/revenue/certificates',
      ),
    ),

    // ── Public works ──
    'poles': (
      group: gWorks,
      spec: NavSpec(
        icon: Icons.alt_route_rounded,
        label: 'Street lighting',
        route: '/poles',
      ),
    ),
    // Pipelines, tanks, flow logs and approvals are tabs of one hub, not four
    // sidebar entries for one subsystem.
    'water_supply': (
      group: gWorks,
      spec: NavSpec(
        icon: Icons.water_drop_rounded,
        label: 'Water supply',
        route: '/water',
      ),
    ),
    'solid_waste': (
      group: gWorks,
      spec: NavSpec(
        icon: Icons.delete_outline_rounded,
        label: 'Solid waste',
        route: '/municipality/solid-waste',
      ),
    ),
    'public_health': (
      group: gWorks,
      spec: NavSpec(
        icon: Icons.medical_services_rounded,
        label: 'Public health',
        route: '/municipality/health',
      ),
    ),
    'inspections': (
      group: gWorks,
      spec: NavSpec(
        icon: Icons.checklist_rtl_rounded,
        label: 'Field inspections',
        route: '/inspections',
      ),
    ),
    'zones': (
      group: gWorks,
      spec: NavSpec(
        icon: Icons.map_rounded,
        label: 'Zones & GIS',
        route: '/zone-management',
      ),
    ),
    // No 'assets' entry: the only asset route is `/assets/new`, a registration
    // form. A sidebar entry must be a place you can look at, not a form you
    // are forced to fill in to get there. It comes back when an asset register
    // list screen exists.

    // ── Procurement ──
    'tenders': (
      group: gProcurement,
      spec: NavSpec(
        icon: Icons.assignment_rounded,
        label: 'Tenders',
        route: '/tenders',
      ),
    ),
    'vendor_portal': (
      group: gProcurement,
      spec: NavSpec(
        icon: Icons.gavel_rounded,
        label: 'Bidding portal',
        route: '/tenders/vendor-portal',
      ),
    ),
    'contractors': (
      group: gProcurement,
      spec: NavSpec(
        icon: Icons.engineering_outlined,
        label: 'Contractors',
        route: '/contractors',
      ),
    ),
    // No 'work_orders' entry for the same reason as assets: the only route is
    // `/work-orders/new`, a creation form. It was previously labelled "My Work
    // Orders" for contractors, who cannot create work orders at all — so that
    // entry sent them to a form they had no business filling in. It returns
    // when a work order list screen exists.

    'documents': (
      group: gProcurement,
      spec: NavSpec(
        icon: Icons.folder_rounded,
        label: 'Documents',
        route: '/documents',
      ),
    ),

    // ── Workforce ──
    'field_workforce': (
      group: gWorkforce,
      spec: NavSpec(
        icon: Icons.engineering_rounded,
        label: 'Field workforce',
        route: '/workforce',
      ),
    ),
    'employees': (
      group: gWorkforce,
      spec: NavSpec(
        icon: Icons.badge_rounded,
        label: 'Employee directory',
        route: '/admin/employees',
      ),
    ),

    // ── Insights ──
    'insights': (
      group: gInsights,
      spec: NavSpec(
        icon: Icons.insights_rounded,
        label: 'Reports & analytics',
        route: '/insights',
      ),
    ),
    'audit_logs': (
      group: gInsights,
      spec: NavSpec(
        icon: Icons.history_edu_rounded,
        label: 'Audit log',
        route: '/admin/audit-logs',
      ),
    ),

    // ── Administration ──
    'settings': (
      group: gAdmin,
      spec: NavSpec(
        icon: Icons.settings_rounded,
        label: 'Settings',
        route: '/settings',
      ),
    ),
    'tenants': (
      group: gAdmin,
      spec: NavSpec(
        icon: Icons.corporate_fare_rounded,
        label: 'Tenants (clients)',
        route: '/admin/tenants',
      ),
    ),
    'branches': (
      group: gAdmin,
      spec: NavSpec(
        icon: Icons.account_balance_rounded,
        label: 'Branches & branding',
        route: '/panchayats',
      ),
    ),
    'users': (
      group: gAdmin,
      spec: NavSpec(
        icon: Icons.people_rounded,
        label: 'User accounts',
        route: '/users',
      ),
    ),
    // One destination for the whole access question: role grants, who holds
    // them, the accounts behind them, and which modules a branch has on.
    'roles': (
      group: gAdmin,
      spec: NavSpec(
        icon: Icons.admin_panel_settings_rounded,
        label: 'Roles & permissions',
        route: '/superadmin/roles',
      ),
    ),
  };

  /// What each role can reach, as a set of catalogue ids.
  ///
  /// Read these as job descriptions. A registrar registers births and deaths
  /// and issues certificates against them — that is the whole job, so that is
  /// the whole menu. Padding it with screens they never open is what made the
  /// old sidebar unusable.
  static const Map<String, Set<String>> _accessByRole = {
    // ── Field roles: a single-purpose shell, no groups ──
    'agent': {'home'},
    'electrician': {'home'},
    'plumber': {'home'},

    // ── Specialist officers ──
    'town_planning_officer': {
      'home',
      'building_permits',
      'inspections',
      'zones',
      'insights',
      'audit_logs',
    },
    'registrar': {
      'home',
      'vital_events',
      'certificates',
      'insights',
      'audit_logs',
    },
    'licensing_clerk': {
      'home',
      'trade_licences',
      'licence_renewals',
      'inspections',
      'insights',
    },
    'sanitary_inspector': {
      'home',
      'solid_waste',
      'public_health',
      'complaints',
      'inspections',
      'zones',
      'insights',
    },
    'health_officer': {
      'home',
      'solid_waste',
      'public_health',
      'vital_events',
      'trade_licences',
      'complaints',
      'inspections',
      'insights',
    },
    'revenue_officer': {
      'home',
      'property_tax',
      'trade_licences',
      'licence_renewals',
      'markets',
      'asset_rental',
      'ad_campaigns',
      'certificates',
      'insights',
      'audit_logs',
    },
    'revenue_inspector': {
      'home',
      'markets',
      'ad_campaigns',
      'asset_rental',
      'insights',
    },

    // ── Engineering ──
    'municipal_engineer': {
      'home',
      'complaints',
      'poles',
      'water_supply',
      'inspections',
      'tenders',
      'contractors',
      'insights',
    },
    'assistant_engineer': {
      'home',
      'complaints',
      'poles',
      'water_supply',
      'inspections',
      'insights',
    },
    'junior_engineer': {
      'home',
      'complaints',
      'poles',
      'water_supply',
      'inspections',
    },

    // ── Command & control ──
    'municipal_commissioner': {
      'home',
      'complaints',
      'building_permits',
      'trade_licences',
      'vital_events',
      'solid_waste',
      'tenders',
      'contractors',
      'insights',
      'audit_logs',
    },
    'i3c_staff': {
      'home',
      'complaints',
      'ivr',
      'search',
      'zones',
      'citizen_portal',
    },

    // ── External ──
    'contractor': {'home', 'vendor_portal', 'work_orders', 'documents'},
  };

  /// Fallback for `panchayat_admin` and any general-purpose admin role.
  ///
  /// A branch administrator does genuinely need breadth, but this is still a
  /// curated set rather than everything — the platform-level entries below are
  /// reserved for `super_admin`.
  static const Set<String> _defaultAccess = {
    'home',
    'complaints',
    'citizen_portal',
    'ivr',
    'search',
    'property_tax',
    'trade_licences',
    'licence_renewals',
    'markets',
    'asset_rental',
    'ad_campaigns',
    'certificates',
    'building_permits',
    'vital_events',
    'poles',
    'water_supply',
    'solid_waste',
    'inspections',
    'zones',
    'tenders',
    'contractors',
    'field_workforce',
    'employees',
    'insights',
    'audit_logs',
    'settings',
  };

  /// `super_admin` is the **platform operator** — Sengotics, not the council.
  ///
  /// It previously inherited every operational screen a branch admin has and
  /// reached 41 entries. But a platform operator does not work the market
  /// stall fee counter or approve a birth registration; a branch's own staff
  /// do. What it needs is tenants, branches, accounts, roles, system config,
  /// and enough operational visibility to support a client.
  ///
  /// Anything branch-specific is still reachable by switching into a branch
  /// context (`/select-context`), which is what that screen is for.
  static const Set<String> _superAdminAccess = {
    'home',
    'complaints',
    'ivr',
    'search',
    'poles',
    'zones',
    'tenders',
    'vendor_portal',
    'field_workforce',
    'employees',
    'insights',
    'audit_logs',
    'settings',
    'tenants',
    'branches',
    'users',
    'roles',
  };

  /// Roles whose shell is a single screen — no grouped navigation at all.
  static const Set<String> _fieldOnlyRoles = {'agent', 'electrician', 'plumber'};

  /// Extra links for the three field roles, which do not use the catalogue
  /// because their routes are role-prefixed rather than shared.
  static const Map<String, List<NavSpec>> _fieldOnlyMenus = {
    'agent': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Home', route: '/agent'),
      NavSpec(icon: Icons.list_alt_rounded, label: 'Poles', route: '/agent/poles'),
      NavSpec(
        icon: Icons.add_location_alt_rounded,
        label: 'New pole',
        route: '/agent/poles/add',
      ),
      NavSpec(
        icon: Icons.water_drop_rounded,
        label: 'Pipeline & tap capture',
        route: '/agent/pipeline-tap-capture',
      ),
    ],
    'electrician': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Home', route: '/electrician'),
      NavSpec(
        icon: Icons.electrical_services_rounded,
        label: 'My jobs',
        route: '/electrician/jobs',
      ),
    ],
    'plumber': [
      NavSpec(icon: Icons.dashboard_rounded, label: 'Home', route: '/plumber'),
      NavSpec(
        icon: Icons.plumbing_rounded,
        label: 'My jobs',
        route: '/plumber/jobs',
      ),
    ],
  };

  /// Every office role lands on `/dashboard`.
  ///
  /// Nine roles used to point at a hardcoded screen of their own —
  /// `/commissioner`, `/municipal-engineer`, `/revenue-officer` and so on.
  /// That predates the dashboard being composed from `role_dashboards`, and
  /// leaving the overrides in place meant those nine never saw the dashboard
  /// the super admin had arranged for them: the console could be edited all
  /// day with no effect on the people it was edited for.
  ///
  /// The old screens are still routed at their own paths, so a bookmark still
  /// works; nothing in the sidebar sends anyone to them.
  ///
  /// Field roles are the exception and are handled by [_fieldOnlyMenus]: they
  /// get a single-purpose shell rather than a dashboard, and the router keeps
  /// them inside it.
  static Set<String> _idsFor(String role) {
    if (role == 'super_admin') return _superAdminAccess;
    return _accessByRole[role] ?? _defaultAccess;
  }

  static NavSpec _specFor(String role, String id) => _catalogue[id]!.spec;

  /// The whole sidebar, grouped and ordered.
  ///
  /// ## Where the answer comes from
  ///
  /// [entitledScreens] is the authoritative list, resolved server-side from
  /// the role's grants in `role_screen_access` and delivered on the JWT. When
  /// it is supplied, this method is a *filter over the catalogue*: switching a
  /// screen on for a role in the super admin console makes it appear here at
  /// the holder's next login, with no code change and no redeploy.
  ///
  /// The per-role sets below are the **fallback**, used only when the server
  /// has not resolved entitlements — an older token, or a database that has
  /// not had the RBAC migration applied. Without that fallback such a user
  /// would get an empty sidebar and be unable to work, which is a worse
  /// failure than showing them the defaults their role has always had.
  ///
  /// The catalogue itself stays in code because a menu entry must correspond
  /// to a route that actually exists; the database decides *whether* you see
  /// it, not whether it can be built.
  static List<NavSection> sectionsFor(
    String role, {
    List<String>? entitledScreens,
    bool isSuperAdmin = false,
  }) {
    if (_fieldOnlyRoles.contains(role)) {
      final items = _fieldOnlyMenus[role] ?? const <NavSpec>[];
      return items.isEmpty
          ? const []
          : [NavSection(title: gOverview, items: items)];
    }

    final Set<String> ids;
    if (isSuperAdmin) {
      // The platform operator's menu follows the catalogue, so a newly shipped
      // module is reachable without anyone ticking a box for it.
      ids = _superAdminAccess;
    } else if (entitledScreens != null && entitledScreens.isNotEmpty) {
      ids = entitledScreens.toSet();
    } else {
      ids = _idsFor(role);
    }

    final byGroup = <String, List<NavSpec>>{};

    // Walk the catalogue rather than the id set so ordering is the catalogue's,
    // not the set's — a Set has no meaningful iteration order. This also means
    // an unknown key from the server is ignored rather than crashing the menu.
    for (final entry in _catalogue.entries) {
      if (!ids.contains(entry.key)) continue;
      byGroup
          .putIfAbsent(entry.value.group, () => <NavSpec>[])
          .add(_specFor(role, entry.key));
    }

    return [
      for (final group in _groupOrder)
        if ((byGroup[group] ?? const []).isNotEmpty)
          NavSection(title: group, items: byGroup[group]!),
    ];
  }

  /// The role's landing route.
  ///
  /// Field roles land in their own shell; everyone else lands on the
  /// dashboard, which is composed per role from `role_dashboards`.
  static String homeRouteFor(String role) {
    if (_fieldOnlyRoles.contains(role)) {
      return _fieldOnlyMenus[role]?.first.route ?? '/dashboard';
    }
    return '/dashboard';
  }

  /// Every route this sidebar can reach. Used to decide which nav item is
  /// "active".
  static List<String> allRoutesFor(
    String role, {
    List<String>? entitledScreens,
    bool isSuperAdmin = false,
  }) =>
      [
        for (final section in sectionsFor(
          role,
          entitledScreens: entitledScreens,
          isSuperAdmin: isSuperAdmin,
        ))
          ...section.items.map((s) => s.route).whereType<String>(),
      ];

  // ── Back-compat shims ─────────────────────────────────────────────────────
  //
  // `app_scaffold` rendered a flat primary list above the grouped sections.
  // With everything grouped there is no separate primary list, but these keep
  // existing call sites compiling until they move to `sectionsFor`.

  @Deprecated('Use sectionsFor(role) — the sidebar is fully grouped now')
  static List<NavSpec> primaryFor(String role) => const [];

  @Deprecated('Platform links are part of the ADMINISTRATION group now')
  static List<NavSpec> platformSectionFor(String role) => const [];
}
