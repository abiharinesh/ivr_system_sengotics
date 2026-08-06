import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/core/navigation/role_navigation_config.dart';
import 'package:ivr_frontend/core/navigation/screen_icons.dart';

/// The sidebar, resolved from what the server sent.
///
/// This used to be answered by a 742-line Dart file: a copy of the screen
/// catalogue, four hardcoded role→screens maps, and a special case that gave
/// three field roles a fixed menu no administrator could change. Ticking a
/// screen for an electrician in the role console did nothing at all, because
/// nothing ever read the grant.
///
/// Now one thing decides: the `nav` the server resolved for this user. These
/// tests pin that, because a navigation bug is invisible until somebody cannot
/// reach their work.
void main() {
  /// A nav entry shaped like the server's `NavScreen`.
  Map<String, dynamic> nav(
    String key, {
    String? route,
    String group = 'OVERVIEW',
    String? label,
    String icon = 'dashboard_rounded',
    int order = 0,
  }) =>
      {
        'key': key,
        'route': route ?? '/$key',
        'group_key': group,
        'label_en': label ?? key,
        'label_ta': null,
        'icon': icon,
        'sort_order': order,
        'module': 'core',
      };

  List<NavSection> sections(List<Map<String, dynamic>> rows) =>
      RoleNavigationConfig.sectionsFrom(rows.map(NavScreen.fromJson).toList());

  group('grouping', () {
    test('groups by the server group, in the order the server sent', () {
      final out = sections([
        nav('home', group: 'OVERVIEW', order: 0),
        nav('complaints', group: 'CITIZEN SERVICES', order: 1),
        nav('property_tax', group: 'REVENUE', order: 2),
        nav('settings', group: 'ADMINISTRATION', order: 3),
      ]);

      // Not alphabetical — that would put ADMINISTRATION first.
      expect(out.map((s) => s.title), [
        'OVERVIEW',
        'CITIZEN SERVICES',
        'REVENUE',
        'ADMINISTRATION',
      ]);
    });

    test('keeps items of one group together even when sent apart', () {
      final out = sections([
        nav('a', group: 'REVENUE', order: 0),
        nav('b', group: 'WORKS', order: 1),
        nav('c', group: 'REVENUE', order: 2),
      ]);

      expect(out.map((s) => s.title), ['REVENUE', 'WORKS']);
      expect(out.first.items.map((i) => i.label), ['a', 'c']);
    });

    test('renders no empty group', () {
      expect(sections([]), isEmpty);
    });

    test('preserves the order within a group', () {
      final out = sections([
        nav('first', group: 'REVENUE', order: 0),
        nav('second', group: 'REVENUE', order: 1),
        nav('third', group: 'REVENUE', order: 2),
      ]);

      expect(out.single.items.map((i) => i.label), ['first', 'second', 'third']);
    });
  });

  group('rendering one entry', () {
    test('carries the label, route and icon the server chose', () {
      final out = sections([
        nav('tenders',
            route: '/tenders',
            group: 'PROCUREMENT',
            label: 'Tenders',
            icon: 'gavel_rounded'),
      ]);

      final item = out.single.items.single;
      expect(item.label, 'Tenders');
      expect(item.route, '/tenders');
      expect(item.icon, Icons.gavel_rounded);
    });

    test('an unknown icon name falls back rather than throwing', () {
      // A screen seeded with an icon this build has never heard of must appear
      // in the menu with a dull icon, not take the menu down.
      final out = sections([nav('mystery', icon: 'not_a_real_icon')]);

      expect(out.single.items.single.icon, isNotNull);
      expect(out.single.items.single.label, 'mystery');
    });
  });

  group('the field worker, who used to be a special case', () {
    // These three had a hardcoded menu that ignored their grants entirely.
    final electrician = [
      nav('electrician_home',
          route: '/electrician', group: 'FIELD WORK', label: 'Home', order: 40),
      nav('electrician_jobs',
          route: '/electrician/jobs',
          group: 'FIELD WORK',
          label: 'My jobs',
          icon: 'electrical_services_rounded',
          order: 41),
    ];

    test('gets exactly the two items the database grants', () {
      final out = sections(electrician);

      expect(out.single.title, 'FIELD WORK');
      expect(out.single.items.map((i) => i.label), ['Home', 'My jobs']);
      expect(out.single.items.map((i) => i.route),
          ['/electrician', '/electrician/jobs']);
    });

    test('a screen taken away in the console disappears', () {
      // The whole point. Under the old hardcoded menu this was impossible.
      final out = sections([electrician.first]);

      expect(out.single.items.map((i) => i.label), ['Home']);
    });

    test('a screen added in the console appears', () {
      // Passed in the order the server sends — catalogue order, complaints
      // (5) before the field shell (40, 41). The client groups what it is
      // given and does not re-sort it; deciding the order here as well would
      // be a second opinion about a question the server already answered.
      final out = sections([
        nav('complaints',
            route: '/complaints', group: 'CITIZEN SERVICES', label: 'Complaints', order: 5),
        ...electrician,
      ]);

      expect(out.map((s) => s.title), ['CITIZEN SERVICES', 'FIELD WORK']);
      expect(out.last.items, hasLength(2));
    });
  });

  group('landing route', () {
    test('is the first entry the server sent', () {
      expect(
        RoleNavigationConfig.homeRouteFrom([
          NavScreen.fromJson(nav('home', route: '/dashboard', order: 0)),
          NavScreen.fromJson(nav('complaints', route: '/complaints', order: 1)),
        ]),
        '/dashboard',
      );
    });

    test('sends a field worker into their own shell, not the dashboard', () {
      expect(
        RoleNavigationConfig.homeRouteFrom([
          NavScreen.fromJson(
              nav('electrician_home', route: '/electrician', group: 'FIELD WORK')),
        ]),
        '/electrician',
      );
    });

    test('falls back to the dashboard when nothing was resolved', () {
      // A user mid-provisioning must land somewhere rather than nowhere.
      expect(RoleNavigationConfig.homeRouteFrom([]), '/dashboard');
    });
  });

  group('reachable routes', () {
    test('lists every route in the menu, for highlighting the active item', () {
      final routes = RoleNavigationConfig.routesFrom([
        NavScreen.fromJson(nav('home', route: '/dashboard')),
        NavScreen.fromJson(nav('complaints', route: '/complaints')),
      ]);

      expect(routes, ['/dashboard', '/complaints']);
    });
  });

  group('invariants that used to be checked per hardcoded role', () {
    // `role_navigation_test.dart` asserted these against the Dart maps, one
    // role at a time. They are properties of the resolver now, so they hold
    // for every role including ones a tenant invents.
    final realistic = [
      nav('home', route: '/dashboard', group: 'OVERVIEW', label: 'Dashboard', order: 0),
      nav('complaints',
          route: '/complaints', group: 'CITIZEN SERVICES', label: 'Complaints', order: 1),
      nav('property_tax',
          route: '/revenue/property-tax', group: 'REVENUE', label: 'Property tax', order: 2),
      nav('markets', route: '/revenue/markets', group: 'REVENUE', label: 'Markets', order: 3),
      nav('settings',
          route: '/settings', group: 'ADMINISTRATION', label: 'Settings', order: 4),
    ];

    test('shows each route at most once', () {
      final routes = sections(realistic)
          .expand((s) => s.items)
          .map((i) => i.route)
          .toList();

      expect(routes.toSet().length, routes.length);
    });

    test('shows each label at most once', () {
      final labels = sections(realistic)
          .expand((s) => s.items)
          .map((i) => i.label)
          .toList();

      expect(labels.toSet().length, labels.length);
    });

    test('renders no group without items', () {
      expect(sections(realistic).every((s) => s.items.isNotEmpty), isTrue);
    });

    test('lands on a route that is in its own sidebar', () {
      // A landing route outside the menu leaves the user on a page with
      // nothing highlighted and no way back to it.
      final screens = realistic.map(NavScreen.fromJson).toList();

      expect(
        RoleNavigationConfig.routesFrom(screens),
        contains(RoleNavigationConfig.homeRouteFrom(screens)),
      );
    });

    test('a duplicate key from the server does not double the entry', () {
      // The server de-duplicates, but a bad cache or a merged response must
      // not produce two identical rows in the menu.
      final out = sections([...realistic, realistic.first]);
      final routes = out.expand((s) => s.items).map((i) => i.route).toList();

      expect(routes.where((r) => r == '/dashboard'), hasLength(1));
    });
  });

  group('the icon table', () {
    test('covers every icon the seeded catalogue uses', () {
      // If the seed gains a screen with a new icon, this fails here rather
      // than rendering a blank square in front of a government official.
      const seeded = [
        'account_balance_rounded', 'ad_units_rounded', 'add_location_alt_rounded',
        'admin_panel_settings_rounded', 'alt_route_rounded', 'assignment_rounded',
        'autorenew_rounded', 'badge_rounded', 'call_rounded', 'campaign_outlined',
        'checklist_rtl_rounded', 'corporate_fare_rounded', 'currency_rupee_rounded',
        'dashboard_rounded', 'delete_outline_rounded', 'domain_rounded',
        'electrical_services_rounded', 'engineering_outlined', 'engineering_rounded',
        'folder_rounded', 'gavel_rounded', 'history_edu_rounded',
        'home_work_outlined', 'insights_rounded', 'list_alt_rounded',
        'manage_search_rounded', 'map_rounded', 'medical_services_rounded',
        'menu_book_outlined', 'people_rounded', 'plumbing_rounded',
        'report_problem_rounded', 'settings_rounded', 'storefront_outlined',
        'storefront_rounded', 'task_rounded', 'warning_rounded',
        'water_drop_rounded',
      ];

      final missing = seeded.where((n) => !kScreenIcons.containsKey(n)).toList();
      expect(missing, isEmpty, reason: 'add these to screen_icons.dart: $missing');
    });
  });
}
