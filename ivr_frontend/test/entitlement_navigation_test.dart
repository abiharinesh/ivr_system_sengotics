import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/core/models/user_model.dart';
import 'package:ivr_frontend/core/navigation/role_navigation_config.dart';

/// Proves the sidebar actually follows server-resolved entitlements.
///
/// This is the behaviour the whole RBAC redevelopment exists for: switching a
/// screen on for a role in the super admin console must make it appear, and
/// switching it off must make it vanish. Before this, the sidebar read a
/// hardcoded map of role-name strings and the console changed nothing.
void main() {
  List<String> routesFor(
    String role, {
    List<String>? screens,
    bool isSuperAdmin = false,
  }) =>
      RoleNavigationConfig.allRoutesFor(
        role,
        entitledScreens: screens,
        isSuperAdmin: isSuperAdmin,
      );

  List<String> labelsFor(String role, {List<String>? screens}) => [
        for (final s in RoleNavigationConfig.sectionsFor(
          role,
          entitledScreens: screens,
        ))
          ...s.items.map((i) => i.label),
      ];

  group('entitlements drive the sidebar', () {
    test('granting a screen makes it appear', () {
      final without = labelsFor('registrar', screens: ['home', 'vital_events']);
      final with_ = labelsFor(
        'registrar',
        screens: ['home', 'vital_events', 'trade_licences'],
      );

      expect(without, isNot(contains('Trade licences')));
      expect(with_, contains('Trade licences'));
    });

    test('revoking a screen makes it disappear', () {
      final before = labelsFor(
        'revenue_officer',
        screens: ['home', 'property_tax', 'markets'],
      );
      final after = labelsFor('revenue_officer', screens: ['home', 'markets']);

      expect(before, contains('Property tax'));
      expect(after, isNot(contains('Property tax')));
    });

    test('two roles with the same entitlements get the same sidebar', () {
      const granted = ['home', 'complaints', 'inspections'];
      expect(
        labelsFor('junior_engineer', screens: granted),
        equals(labelsFor('sanitary_inspector', screens: granted)),
      );
    });

    test('an entitlement list overrides the role default entirely', () {
      // licensing_clerk's built-in default has no complaints screen.
      expect(labelsFor('licensing_clerk'), isNot(contains('Complaints')));
      expect(
        labelsFor('licensing_clerk', screens: ['home', 'complaints']),
        contains('Complaints'),
      );
    });

    test('an unknown key from the server is ignored, not fatal', () {
      final labels = labelsFor(
        'registrar',
        screens: ['home', 'a_screen_that_does_not_exist', 'vital_events'],
      );
      expect(labels, contains('Birth & death register'));
      expect(labels.length, 2);
    });

    test('grouping still applies to a server-supplied list', () {
      final sections = RoleNavigationConfig.sectionsFor(
        'revenue_officer',
        entitledScreens: ['home', 'property_tax', 'building_permits'],
      );
      expect(
        sections.map((s) => s.title),
        containsAll(['OVERVIEW', 'REVENUE', 'REGULATORY SERVICES']),
      );
      // No group is rendered with nothing under it.
      for (final s in sections) {
        expect(s.items, isNotEmpty);
      }
    });
  });

  group('safe fallbacks', () {
    test('an empty list falls back to the role default, not an empty menu', () {
      // A token issued before `screens` existed, or a database without the
      // RBAC migration. Locking a legitimate user out of their own menu is a
      // worse failure than showing them their long-standing defaults.
      final fallback = routesFor('revenue_officer', screens: const []);
      final defaults = routesFor('revenue_officer');

      expect(fallback, isNotEmpty);
      expect(fallback, equals(defaults));
    });

    test('a null list falls back to the role default', () {
      expect(routesFor('registrar', screens: null), isNotEmpty);
    });

    test('super admin ignores the granted list and follows the catalogue', () {
      final routes = routesFor(
        'super_admin',
        screens: const ['home'],
        isSuperAdmin: true,
      );
      // A newly shipped module must be reachable without anyone ticking a box.
      expect(routes.length, greaterThan(1));
      expect(routes, contains('/admin/tenants'));
    });

    test('field roles keep their fixed shell regardless of entitlements', () {
      for (final role in ['agent', 'electrician', 'plumber']) {
        final routes = routesFor(role, screens: const ['home', 'tenants']);
        expect(routes, isNot(contains('/admin/tenants')));
        expect(routes, isNotEmpty);
      }
    });
  });

  group('UserModel.canSeeScreen', () {
    UserModel user({
      String role = 'registrar',
      List<String> screens = const [],
    }) =>
        UserModel.fromJson({
          'id': 1,
          'email': 'x@y.z',
          'role': role,
          'screens': screens,
        });

    test('honours the granted list', () {
      final u = user(screens: ['vital_events']);
      expect(u.canSeeScreen('vital_events'), isTrue);
      expect(u.canSeeScreen('trade_licences'), isFalse);
    });

    test('super admin sees everything', () {
      final u = user(role: 'super_admin');
      expect(u.canSeeScreen('anything_at_all'), isTrue);
    });

    test('an empty list means "server did not say", not "deny all"', () {
      final u = user(screens: const []);
      expect(u.canSeeScreen('vital_events'), isTrue);
      expect(u.hasResolvedScreens, isFalse);
    });

    test('reports resolved once the server sends anything', () {
      expect(user(screens: ['home']).hasResolvedScreens, isTrue);
    });
  });
}
