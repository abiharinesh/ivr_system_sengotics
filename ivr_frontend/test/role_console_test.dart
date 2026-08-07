import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_models.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/role_template_models.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/rbac_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/create_role_dialog.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/role_templates_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/sidebar_preview.dart';

/// The two things the console could not do, and the one it could not show.
///
/// A tenant could not define a role — `POST /api/rbac/roles` worked and nothing
/// called it — and could not see or apply catalogue updates, because all four
/// template endpoints shipped without a caller. Neither gap was visible: the
/// console looked complete.
void main() {
  ScreenCatalogue catalogue() => ScreenCatalogue.fromJson({
        'total': 4,
        'groups': [
          {
            'group_key': 'OVERVIEW',
            'items': [
              {
                'id': 1,
                'key': 'home',
                'route': '/dashboard',
                'group_key': 'OVERVIEW',
                'label_en': 'Dashboard',
                'icon': 'dashboard_rounded',
                'module': 'core',
                'sort_order': 0,
              },
            ],
          },
          {
            'group_key': 'REVENUE',
            'items': [
              {
                'id': 2,
                'key': 'property_tax',
                'route': '/revenue/property-tax',
                'group_key': 'REVENUE',
                'label_en': 'Property tax',
                'icon': 'currency_rupee_rounded',
                'module': 'property_tax',
                'sort_order': 1,
              },
              {
                'id': 3,
                'key': 'markets',
                'route': '/revenue/markets',
                'group_key': 'REVENUE',
                'label_en': 'Market stall fees',
                'icon': 'storefront_rounded',
                'module': 'markets',
                'sort_order': 2,
              },
            ],
          },
        ],
      });

  Future<void> pump(WidgetTester tester, Widget child, {Size? size}) async {
    if (size != null) {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  group('CreateRoleDialog', () {
    testWidgets('suggests an identifier from the designation', (tester) async {
      await pump(tester, const CreateRoleDialog());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Designation').first,
        'Ward Committee Secretary',
      );
      await tester.pump();

      expect(find.text('ward_committee_secretary'), findsOneWidget);
    });

    testWidgets('stops suggesting once the identifier is edited by hand',
        (tester) async {
      await pump(tester, const CreateRoleDialog());

      final identifier = find.widgetWithText(TextFormField, 'Identifier');
      await tester.enterText(identifier, 'my_own_name');
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Designation').first,
        'Something Else Entirely',
      );
      await tester.pump();

      // Retyping over a deliberate choice is worse than being out of step.
      expect(find.text('my_own_name'), findsOneWidget);
      expect(find.text('something_else_entirely'), findsNothing);
    });

    testWidgets('will not submit without a designation', (tester) async {
      var submitted = false;
      await pump(
        tester,
        CreateRoleDialog(onSubmit: (_) async {
          submitted = true;
          return null;
        }),
      );

      await tester.tap(find.text('Create role'));
      await tester.pump();

      expect(submitted, isFalse);
      expect(find.textContaining('recognise'), findsOneWidget);
    });

    testWidgets('shows the server\'s objection without closing', (tester) async {
      // The rules live on the server. A name collision should cost a
      // correction, not the whole form.
      await pump(
        tester,
        CreateRoleDialog(
          onSubmit: (_) async =>
              '"registrar" is a shipped role name. Clone it instead.',
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Designation').first,
        'Registrar',
      );
      await tester.pump();
      await tester.tap(find.text('Create role'));
      await tester.pump();

      expect(find.textContaining('shipped role name'), findsOneWidget);
      expect(find.text('Create role'), findsOneWidget);
    });

    testWidgets('hands back what was filled in', (tester) async {
      NewRoleDraft? got;
      await pump(
        tester,
        CreateRoleDialog(onSubmit: (d) async {
          got = d;
          return null;
        }),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Designation').first,
        'Ward Liaison',
      );
      await tester.pump();
      await tester.tap(find.text('Create role'));
      await tester.pump();

      expect(got, isNotNull);
      expect(got!.name, 'ward_liaison');
      expect(got!.displayName, 'Ward Liaison');
      // Level 0 is the platform operator's rung and is not offered.
      expect(got!.hierarchyLevel, greaterThanOrEqualTo(1));
    });
  });

  group('SidebarPreview', () {
    testWidgets('shows the menu the ticked screens produce', (tester) async {
      await pump(
        tester,
        SidebarPreview(
          screenKeys: const {'home', 'property_tax'},
          catalogue: catalogue(),
          roleName: 'Revenue Officer',
        ),
      );

      expect(find.text('What Revenue Officer sees'), findsOneWidget);
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('REVENUE'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Property tax'), findsOneWidget);
      // Not ticked, so not in the menu.
      expect(find.text('Market stall fees'), findsNothing);
      expect(find.text('2 items'), findsOneWidget);
    });

    testWidgets('says so plainly when a role would reach nothing',
        (tester) async {
      await pump(
        tester,
        SidebarPreview(screenKeys: const {}, catalogue: catalogue()),
      );

      expect(find.text('No menu at all'), findsOneWidget);
      expect(find.textContaining('can reach nothing'), findsOneWidget);
    });

    testWidgets('renders no group that has nothing in it', (tester) async {
      await pump(
        tester,
        SidebarPreview(
          screenKeys: const {'home'},
          catalogue: catalogue(),
        ),
      );

      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('REVENUE'), findsNothing);
    });
  });

  group('RoleTemplatesPane', () {
    testWidgets('says everything matches when nothing is pending',
        (tester) async {
      await pump(
        tester,
        RoleTemplatesPane(repository: _FakeRepo(pending: SyncReport.empty)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('match the shipped catalogue'), findsOneWidget);
      expect(find.text('Apply updates'), findsNothing);
    });

    testWidgets('counts the roles with updates and names what changes',
        (tester) async {
      await pump(
        tester,
        RoleTemplatesPane(
          repository: _FakeRepo(
            pending: SyncReport.fromJson({
              'tenant_id': 'coimbatore',
              'dry_run': true,
              'unchanged': 24,
              'untemplated': 2,
              // Deliberately not the name the fake catalogue carries, so the
              // assertions below can only be satisfied by the pending section.
              'updated': [
                {
                  'role_id': 5,
                  'name': 'sanitary_inspector',
                  'display_name': 'Sanitary Inspector',
                  'screens_added': ['water_quality'],
                  'screens_removed': ['legacy_screen'],
                  'permissions_added': [],
                  'permissions_removed': [],
                },
              ],
              'skipped_customised': [],
            }),
          ),
        ),
        size: const Size(900, 1400),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1 role has updates'), findsOneWidget);
      expect(find.text('Sanitary Inspector'), findsOneWidget);
      expect(find.text('water_quality'), findsOneWidget);
      expect(find.text('legacy_screen'), findsOneWidget);
      expect(find.text('Apply updates'), findsOneWidget);
    });

    testWidgets('promises nothing is applied without confirmation',
        (tester) async {
      await pump(
        tester,
        RoleTemplatesPane(
          repository: _FakeRepo(
            pending: SyncReport.fromJson({
              'tenant_id': 't',
              'updated': [
                {
                  'role_id': 1,
                  'name': 'a',
                  'display_name': 'A',
                  'screens_added': ['x'],
                  'screens_removed': [],
                  'permissions_added': [],
                  'permissions_removed': [],
                },
              ],
              'skipped_customised': [],
              'unchanged': 0,
              'untemplated': 0,
            }),
          ),
        ),
        size: const Size(900, 1400),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('until you confirm'), findsOneWidget);
    });

    testWidgets('names the roles it will leave alone', (tester) async {
      await pump(
        tester,
        RoleTemplatesPane(
          repository: _FakeRepo(
            pending: SyncReport.fromJson({
              'tenant_id': 't',
              'updated': [],
              'skipped_customised': [
                {
                  'role_id': 9,
                  'name': 'sanitary_inspector',
                  'customised_at': '2026-07-01T00:00:00.000Z',
                },
              ],
              'unchanged': 25,
              'untemplated': 0,
            }),
          ),
        ),
        size: const Size(900, 1400),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Yours to keep'), findsOneWidget);
      expect(find.textContaining('sanitary_inspector'), findsOneWidget);
    });

    testWidgets('lists the catalogue with how many clients use each entry',
        (tester) async {
      await pump(
        tester,
        RoleTemplatesPane(repository: _FakeRepo(pending: SyncReport.empty)),
        size: const Size(900, 1400),
      );
      await tester.pumpAndSettle();

      expect(find.text('City Health Officer'), findsOneWidget);
      expect(find.textContaining('12 screens'), findsOneWidget);
      expect(find.text('3'), findsWidgets); // in_use_by
    });

    testWidgets('offers a retry rather than a blank pane when loading fails',
        (tester) async {
      await pump(tester, RoleTemplatesPane(repository: _FailingRepo()));
      await tester.pumpAndSettle();

      expect(find.text('Could not load the catalogue'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}

class _FakeRepo implements RbacRepository {
  _FakeRepo({required this.pending});

  final SyncReport pending;

  @override
  Future<List<RoleTemplate>> listTemplates({
    String? branchType,
    bool forceRefresh = false,
  }) async =>
      [
        RoleTemplate.fromJson({
          'id': 100,
          'name': 'health_officer',
          'display_name': 'City Health Officer',
          'department': 'Public Health',
          'hierarchy_level': 4,
          'applicable_branch_types': [],
          'screen_count': 12,
          'permission_count': 20,
          'in_use_by': 3,
        }),
      ];

  @override
  Future<SyncReport> pendingSync({bool forceRefresh = true}) async => pending;

  @override
  Future<SyncReport> syncTemplates({List<int>? roleIds, bool dryRun = false}) async =>
      pending;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used by this test');
}

class _FailingRepo implements RbacRepository {
  @override
  Future<List<RoleTemplate>> listTemplates({
    String? branchType,
    bool forceRefresh = false,
  }) async =>
      throw Exception('the network is down');

  @override
  Future<SyncReport> pendingSync({bool forceRefresh = true}) async =>
      throw Exception('the network is down');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used by this test');
}
