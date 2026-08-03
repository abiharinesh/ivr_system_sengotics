import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_models.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/rbac_grants.dart';

/// The arithmetic behind the role management console.
///
/// The console decides what to PUT from the difference between what the server
/// last returned and what the operator has ticked, so getting that difference
/// wrong either silently drops a grant or writes back one that was just
/// revoked. None of it needs a widget or a database to check.

AppScreenInfo screen(
  String key, {
  String group = 'REVENUE',
  String label = '',
  String module = 'core',
  bool platformOnly = false,
}) =>
    AppScreenInfo(
      id: key.hashCode,
      key: key,
      route: '/$key',
      groupKey: group,
      labelEn: label.isEmpty ? key : label,
      labelTa: null,
      icon: 'circle',
      module: module,
      permissionCode: null,
      sortOrder: 0,
      isPlatformOnly: platformOnly,
    );

PermissionInfo permission(String code, {String? description}) => PermissionInfo(
      id: code.hashCode,
      code: code,
      module: code.split('.').first,
      action: code.split('.').last,
      description: description,
    );

RoleSummary role({
  int id = 1,
  String tenantId = 'tenant-a',
  String name = 'revenue_officer',
  String displayName = 'Revenue Officer',
  String? department,
  bool isSuperAdmin = false,
  bool isActive = true,
  List<String> branchTypes = const [],
  int userCount = 0,
}) =>
    RoleSummary(
      id: id,
      tenantId: tenantId,
      name: name,
      displayName: displayName,
      displayNameTa: null,
      department: department,
      hierarchyLevel: 5,
      isSuperAdmin: isSuperAdmin,
      canApprove: false,
      isSystem: false,
      isActive: isActive,
      applicableBranchTypes: branchTypes,
      userCount: userCount,
      permissionCount: 0,
      screenCount: 0,
    );

void main() {
  group('GrantSelection tracks what changed', () {
    test('a freshly loaded selection has nothing to save', () {
      final sel = GrantSelection.from(['home', 'markets']);

      expect(sel.isDirty, isFalse);
      expect(sel.changeCount, 0);
      expect(sel.added, isEmpty);
      expect(sel.removed, isEmpty);
    });

    test('ticking a box reports it as added', () {
      final sel = GrantSelection.from(['home']).toggle('markets', true);

      expect(sel.isDirty, isTrue);
      expect(sel.added, {'markets'});
      expect(sel.removed, isEmpty);
      expect(sel.contains('markets'), isTrue);
    });

    test('unticking a box reports it as removed', () {
      final sel = GrantSelection.from(['home', 'markets']).toggle('markets', false);

      expect(sel.isDirty, isTrue);
      expect(sel.added, isEmpty);
      expect(sel.removed, {'markets'});
      expect(sel.contains('markets'), isFalse);
    });

    test('ticking then unticking the same box leaves nothing to save', () {
      final sel = GrantSelection.from(['home'])
          .toggle('markets', true)
          .toggle('markets', false);

      expect(sel.isDirty, isFalse);
      expect(sel.changeCount, 0);
    });

    test('a same-size swap still counts as dirty', () {
      // Equal lengths must not be mistaken for equal contents.
      final sel = GrantSelection.from(['home', 'markets'])
          .toggle('markets', false)
          .toggle('tenders', true);

      expect(sel.isDirty, isTrue);
      expect(sel.selected.length, sel.saved.length);
      expect(sel.added, {'tenders'});
      expect(sel.removed, {'markets'});
      expect(sel.changeCount, 2);
    });

    test('setAll ticks a whole group without disturbing the rest', () {
      final sel = GrantSelection.from(['home'])
          .setAll(['markets', 'tenders', 'property_tax'], true);

      expect(sel.selected, {'home', 'markets', 'tenders', 'property_tax'});
      expect(sel.added, {'markets', 'tenders', 'property_tax'});
    });

    test('setAll false clears a group and leaves the rest', () {
      final sel = GrantSelection.from(['home', 'markets', 'tenders'])
          .setAll(['markets', 'tenders'], false);

      expect(sel.selected, {'home'});
      expect(sel.removed, {'markets', 'tenders'});
    });

    test('reset throws away edits and returns to the saved state', () {
      final sel = GrantSelection.from(['home'])
          .toggle('markets', true)
          .toggle('tenders', true)
          .reset();

      expect(sel.isDirty, isFalse);
      expect(sel.selected, {'home'});
    });

    test('commit takes the server response as the new baseline', () {
      final edited = GrantSelection.from(['home']).toggle('markets', true);
      // The server is the authority on what was actually stored — it may have
      // normalised the list, so the response is what gets committed.
      final saved = edited.commit(['home', 'markets']);

      expect(saved.isDirty, isFalse);
      expect(saved.saved, {'home', 'markets'});
    });

    test('payload is sorted so audit-log diffs stay readable', () {
      final sel = GrantSelection.from(['zones', 'about', 'markets']);

      expect(sel.payload, ['about', 'markets', 'zones']);
    });

    test('toggling to the value already held is a no-op', () {
      final sel = GrantSelection.from(['home']);

      expect(identical(sel.toggle('home', true), sel), isTrue);
      expect(identical(sel.toggle('markets', false), sel), isTrue);
    });
  });

  group('platform-only screens', () {
    test('are not grantable to an ordinary role', () {
      expect(screenGrantableTo(screen('tenants', platformOnly: true), role()),
          isFalse);
    });

    test('are grantable to a super-admin role', () {
      expect(
        screenGrantableTo(
          screen('tenants', platformOnly: true),
          role(isSuperAdmin: true),
        ),
        isTrue,
      );
    });

    test('ordinary screens are grantable to anyone', () {
      expect(screenGrantableTo(screen('markets'), role()), isTrue);
    });
  });

  group('catalogue search', () {
    final groups = [
      ScreenGroup(groupKey: 'REVENUE', items: [
        screen('markets', label: 'Markets'),
        screen('property_tax', label: 'Property tax'),
      ]),
      ScreenGroup(groupKey: 'PUBLIC WORKS', items: [
        screen('roads', label: 'Roads & footpaths'),
      ]),
    ];

    test('an empty query returns everything untouched', () {
      expect(filterScreenGroups(groups, '   '), same(groups));
    });

    test('matches on label, case-insensitively', () {
      final out = filterScreenGroups(groups, 'ROADS');

      expect(out.length, 1);
      expect(out.single.groupKey, 'PUBLIC WORKS');
      expect(out.single.items.single.key, 'roads');
    });

    test('drops groups left with no matches', () {
      final out = filterScreenGroups(groups, 'property');

      expect(out.map((g) => g.groupKey), ['REVENUE']);
      expect(out.single.items.single.key, 'property_tax');
    });

    test('permission search matches code and description', () {
      final modules = [
        PermissionModule(module: 'complaints', items: [
          permission('complaints.read', description: 'View complaints'),
          permission('complaints.approve'),
        ]),
        PermissionModule(module: 'assets', items: [permission('assets.read')]),
      ];

      expect(
        filterPermissionModules(modules, 'approve').single.items.single.code,
        'complaints.approve',
      );
      expect(
        filterPermissionModules(modules, 'view').single.items.single.code,
        'complaints.read',
      );
    });
  });

  group('role list filtering', () {
    final roles = [
      role(id: 1, name: 'clerk', displayName: 'Clerk'),
      role(
        id: 2,
        name: 'municipal_commissioner',
        displayName: 'Municipal Commissioner',
        branchTypes: ['MUNICIPALITY', 'MUNICIPAL_CORPORATION'],
      ),
      role(
        id: 3,
        tenantId: RoleSummary.systemTenant,
        name: 'registrar',
        displayName: 'Registrar',
      ),
    ];

    test('a role with no branch types is offered everywhere', () {
      final out = filterRoles(roles, branchType: 'VILLAGE_PANCHAYAT');

      expect(out.map((r) => r.id), [1, 3]);
    });

    test('a role restricted to a body type is hidden elsewhere', () {
      expect(
        filterRoles(roles, branchType: 'MUNICIPALITY').map((r) => r.id),
        [1, 2, 3],
      );
      expect(
        filterRoles(roles, branchType: 'TOWN_PANCHAYAT').map((r) => r.id),
        isNot(contains(2)),
      );
    });

    test('system roles can be excluded', () {
      expect(filterRoles(roles, includeSystem: false).map((r) => r.id), [1, 2]);
    });

    test('query matches display name and internal name', () {
      expect(filterRoles(roles, query: 'commissioner').single.id, 2);
      expect(filterRoles(roles, query: 'municipal_comm').single.id, 2);
    });
  });

  group('disabling a role', () {
    test('is refused for a shared system role', () {
      final reason =
          disableBlockedReason(role(tenantId: RoleSummary.systemTenant));

      expect(reason, contains('system role'));
    });

    test('is refused while anyone still holds it', () {
      final reason = disableBlockedReason(role(userCount: 3));

      expect(reason, contains('3 user(s)'));
    });

    test('is allowed for an unheld tenant role', () {
      expect(disableBlockedReason(role()), isNull);
    });
  });

  group('RoleSummary.isEditable', () {
    test('is false for the shared template tenant', () {
      expect(role(tenantId: RoleSummary.systemTenant).isEditable, isFalse);
    });

    test('is true for the tenant\'s own roles', () {
      expect(role(tenantId: 'tenant-a').isEditable, isTrue);
    });
  });
}
