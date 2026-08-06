import 'package:flutter/material.dart';

import 'package:ivr_frontend/core/navigation/screen_icons.dart';

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

/// One row of `app_screens`, as the server resolved it for this user.
///
/// The server sends these already filtered by the three access gates — the
/// tenant's plan, the branch's provisioning and the role's grant — and already
/// in catalogue order. The client's job is to draw them, not to decide them.
class NavScreen {
  const NavScreen({
    required this.key,
    required this.route,
    required this.groupKey,
    required this.labelEn,
    required this.labelTa,
    required this.icon,
    required this.sortOrder,
  });

  final String key;
  final String route;
  final String groupKey;
  final String labelEn;
  final String? labelTa;

  /// A Material icon name, resolved through [screenIcon].
  final String icon;
  final int sortOrder;

  factory NavScreen.fromJson(Map<String, dynamic> json) => NavScreen(
        key: (json['key'] ?? '') as String,
        route: (json['route'] ?? '/') as String,
        groupKey: (json['group_key'] ?? '') as String,
        labelEn: (json['label_en'] ?? json['key'] ?? '') as String,
        labelTa: json['label_ta'] as String?,
        icon: (json['icon'] ?? '') as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'route': route,
        'group_key': groupKey,
        'label_en': labelEn,
        'label_ta': labelTa,
        'icon': icon,
        'sort_order': sortOrder,
      };
}

/// Turns the server's resolved screens into a sidebar.
///
/// ## Why there is nothing else in this file
///
/// There used to be a great deal: a 34-entry copy of the screen catalogue with
/// its own labels, routes and icons; a map of role name to screen ids; a
/// separate set for super admins; a default set for everyone else; and a
/// special case giving `agent`, `electrician` and `plumber` a fixed menu.
///
/// Every one of those was a second opinion about a question the database had
/// already answered, and second opinions drift. The field-role special case was
/// the worst of them: those three roles' screen grants were read from the
/// database, stored, and displayed in the role console — and then ignored,
/// because the menu came from a constant in Dart. An administrator could tick
/// and untick screens for an electrician all day and change nothing.
///
/// Now `app_screens` is the catalogue, `role_screen_access` is the grant, and
/// the server resolves them together. This file groups the result.
///
/// Sidebar entries remain **destinations, not actions**: "Report Birth" and
/// "New Application" belong on the screen that owns them, next to the list they
/// add to, and the catalogue does not carry them.
class RoleNavigationConfig {
  RoleNavigationConfig._();

  /// Group the resolved screens into sidebar sections.
  ///
  /// Groups appear in the order their first screen does, which is catalogue
  /// order — sorting the group names instead would be alphabetical, and put
  /// ADMINISTRATION above OVERVIEW.
  static List<NavSection> sectionsFrom(List<NavScreen> screens) {
    final byGroup = <String, List<NavSpec>>{};
    final order = <String>[];

    // The previous design made a duplicate structurally impossible: a role was
    // a *set* of screen ids. That mattered — `super_admin` and
    // `panchayat_admin` had both shown "Trade Licences" twice, from two
    // sections that each claimed it. The server de-duplicates now, but a
    // merged cache or a stale response must not be able to bring it back.
    final seen = <String>{};

    for (final s in screens) {
      if (!seen.add(s.key)) continue;
      final items = byGroup.putIfAbsent(s.groupKey, () {
        order.add(s.groupKey);
        return <NavSpec>[];
      });
      items.add(
        NavSpec(icon: screenIcon(s.icon), label: s.labelEn, route: s.route),
      );
    }

    return [
      for (final group in order)
        NavSection(title: group, items: byGroup[group]!),
    ];
  }

  /// Where this user lands after signing in.
  ///
  /// The first screen they were granted, in catalogue order — which sends an
  /// office role to `/dashboard` and a field worker into their own shell,
  /// without either being named here. Nine office roles used to point at a
  /// hardcoded screen of their own, which predated the dashboard being composed
  /// from `role_dashboards` and meant those nine never saw the dashboard the
  /// administrator had arranged for them.
  static String homeRouteFrom(List<NavScreen> screens) =>
      screens.isEmpty ? '/dashboard' : screens.first.route;

  /// Every route the sidebar can reach, for deciding which item is active.
  static List<String> routesFrom(List<NavScreen> screens) =>
      screens.map((s) => s.route).toList();
}
