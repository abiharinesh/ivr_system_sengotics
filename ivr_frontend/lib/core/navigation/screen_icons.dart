import 'package:flutter/material.dart';

/// Material icon names, as stored on `app_screens.icon`, resolved to the
/// `IconData` the sidebar draws.
///
/// Written out rather than looked up by code point. Flutter's icon tree-shaking
/// only keeps icons it can see referenced as constants at compile time, so
/// constructing `IconData(codePoint, fontFamily: 'MaterialIcons')` from a
/// number would either ship the entire icon font or, with tree-shaking on, ship
/// none of them and render blank squares.
///
/// A name the server sends that is missing here falls back to [_fallback]
/// rather than throwing: a newly seeded screen should appear in the menu with a
/// dull icon, not take the menu down.
const Map<String, IconData> kScreenIcons = {
  'account_balance_rounded': Icons.account_balance_rounded,
  'ad_units_rounded': Icons.ad_units_rounded,
  'add_location_alt_rounded': Icons.add_location_alt_rounded,
  'admin_panel_settings_rounded': Icons.admin_panel_settings_rounded,
  'alt_route_rounded': Icons.alt_route_rounded,
  'assignment_rounded': Icons.assignment_rounded,
  'autorenew_rounded': Icons.autorenew_rounded,
  'badge_rounded': Icons.badge_rounded,
  'call_rounded': Icons.call_rounded,
  'campaign_outlined': Icons.campaign_outlined,
  'checklist_rtl_rounded': Icons.checklist_rtl_rounded,
  'corporate_fare_rounded': Icons.corporate_fare_rounded,
  'currency_rupee_rounded': Icons.currency_rupee_rounded,
  'dashboard_rounded': Icons.dashboard_rounded,
  'delete_outline_rounded': Icons.delete_outline_rounded,
  'domain_rounded': Icons.domain_rounded,
  'electrical_services_rounded': Icons.electrical_services_rounded,
  'engineering_outlined': Icons.engineering_outlined,
  'engineering_rounded': Icons.engineering_rounded,
  'folder_rounded': Icons.folder_rounded,
  'gavel_rounded': Icons.gavel_rounded,
  'history_edu_rounded': Icons.history_edu_rounded,
  'home_work_outlined': Icons.home_work_outlined,
  'insights_rounded': Icons.insights_rounded,
  'list_alt_rounded': Icons.list_alt_rounded,
  'manage_search_rounded': Icons.manage_search_rounded,
  'map_rounded': Icons.map_rounded,
  'medical_services_rounded': Icons.medical_services_rounded,
  'menu_book_outlined': Icons.menu_book_outlined,
  'people_rounded': Icons.people_rounded,
  'plumbing_rounded': Icons.plumbing_rounded,
  'report_problem_rounded': Icons.report_problem_rounded,
  'settings_rounded': Icons.settings_rounded,
  'storefront_outlined': Icons.storefront_outlined,
  'storefront_rounded': Icons.storefront_rounded,
  'task_rounded': Icons.task_rounded,
  'warning_rounded': Icons.warning_rounded,
  'water_drop_rounded': Icons.water_drop_rounded,
};

const IconData _fallback = Icons.circle_outlined;

/// The icon for a catalogue name, or a neutral placeholder if it is unknown.
IconData screenIcon(String? name) =>
    name == null ? _fallback : (kScreenIcons[name] ?? _fallback);
