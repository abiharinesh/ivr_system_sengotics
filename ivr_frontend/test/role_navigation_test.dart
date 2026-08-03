import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/core/navigation/role_navigation_config.dart';

/// Guards the properties that made the old sidebar unusable, so they cannot
/// come back silently as roles and modules are added.
void main() {
  const roles = <String>[
    'super_admin',
    'panchayat_admin',
    'municipal_commissioner',
    'municipal_engineer',
    'assistant_engineer',
    'junior_engineer',
    'revenue_officer',
    'revenue_inspector',
    'health_officer',
    'sanitary_inspector',
    'town_planning_officer',
    'registrar',
    'licensing_clerk',
    'i3c_staff',
    'contractor',
    'agent',
    'electrician',
    'plumber',
  ];

  group('no duplicate destinations', () {
    for (final role in roles) {
      test('$role sees each route at most once', () {
        final routes = RoleNavigationConfig.allRoutesFor(role);
        final seen = <String>{};
        final dupes = <String>[];
        for (final r in routes) {
          if (!seen.add(r)) dupes.add(r);
        }
        expect(
          dupes,
          isEmpty,
          reason: '$role has duplicate sidebar routes: $dupes',
        );
      });

      test('$role sees each label at most once', () {
        final labels = [
          for (final s in RoleNavigationConfig.sectionsFor(role))
            ...s.items.map((i) => i.label),
        ];
        final seen = <String>{};
        final dupes = <String>[];
        for (final l in labels) {
          if (!seen.add(l)) dupes.add(l);
        }
        expect(dupes, isEmpty, reason: '$role has duplicate labels: $dupes');
      });
    }
  });

  group('sidebar stays navigable', () {
    for (final role in roles) {
      test('$role has a workable number of entries', () {
        final count = RoleNavigationConfig.allRoutesFor(role).length;
        expect(count, greaterThan(0), reason: '$role has an empty sidebar');
        // super_admin previously reached 44 entries. Past roughly 30 a sidebar
        // stops being a menu and becomes a sitemap.
        expect(
          count,
          lessThanOrEqualTo(30),
          reason: '$role sidebar has grown to $count entries',
        );
      });

      test('$role has no empty groups', () {
        for (final section in RoleNavigationConfig.sectionsFor(role)) {
          expect(
            section.items,
            isNotEmpty,
            reason: '$role has an empty "${section.title}" heading',
          );
        }
      });

      test('$role has a landing route inside its own sidebar', () {
        final home = RoleNavigationConfig.homeRouteFor(role);
        expect(home, isNotEmpty);
        expect(
          RoleNavigationConfig.allRoutesFor(role),
          contains(home),
          reason: '$role lands on $home, which is not in its sidebar',
        );
      });
    }
  });

  group('destinations, not actions', () {
    test('no sidebar entry opens a create form', () {
      // "Report Birth", "New Application" and similar were sidebar entries
      // that opened a create form. Those belong on the screen that owns the
      // list, not in the navigation menu.
      for (final role in roles) {
        for (final route in RoleNavigationConfig.allRoutesFor(role)) {
          expect(
            route.endsWith('/new'),
            isFalse,
            reason: '$role has a create form in the sidebar: $route',
          );
          expect(
            route.contains('?'),
            isFalse,
            reason: '$role has a pre-filtered action in the sidebar: $route',
          );
        }
      }
    });
  });

  group('field roles keep a single-purpose shell', () {
    for (final role in ['agent', 'electrician', 'plumber']) {
      test('$role gets one compact group', () {
        final sections = RoleNavigationConfig.sectionsFor(role);
        expect(sections.length, 1);
        expect(sections.first.items.length, lessThanOrEqualTo(4));
      });
    }
  });
}
