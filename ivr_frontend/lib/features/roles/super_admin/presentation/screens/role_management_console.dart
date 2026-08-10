import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_state.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/panchayat_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/user_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_analytics.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/rbac_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/user_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/branch_modules_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/dashboard_layout_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/rbac_geography_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/rbac_matrix_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/rbac_overview_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/role_access_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/role_members_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/role_templates_pane.dart';

/// The one screen for administering who can do what.
///
/// It replaces four screens that each held a piece of the answer: a role
/// editor, a mocked assignment table, a user list, and a branch feature
/// matrix. Splitting them meant no single place showed why a given person
/// could not open a given screen, which needs all four to agree:
///
/// 1. the branch has the module switched on   (Branch modules)
/// 2. the role is granted the screen          (Roles & access)
/// 3. the person holds that role at that branch (People)
/// 4. their account is active                 (Accounts)
///
/// The three views in front of those — Overview, Matrix, Geography — exist
/// because the editing panes can only ever answer questions about one role at
/// a time. "Which screens can nobody open", "which branch is understaffed" and
/// "which two roles have drifted apart" are questions about the whole grant
/// set, and they were previously unanswerable without reading the database.
class RoleManagementConsole extends StatefulWidget {
  const RoleManagementConsole({super.key, this.initialUserId});

  /// Open straight onto this person's assignments. Set by the per-user
  /// shortcut on the Accounts tab and by `/superadmin/roles?user_id=`.
  final int? initialUserId;

  @override
  State<RoleManagementConsole> createState() => _RoleManagementConsoleState();
}

class _RoleManagementConsoleState extends State<RoleManagementConsole>
    with SingleTickerProviderStateMixin {
  final _repo = RbacRepository();

  late final TabController _tabs;
  RbacAnalytics _analytics = RbacAnalytics.empty;
  bool _loading = true;
  String? _error;

  /// Whether the logged-in user is a platform (super) admin.
  ///
  /// Resolved once from the auth bloc and used to gate platform-only tabs.
  /// A panchayat admin sees only the operational subset: Overview, Access
  /// matrix, Roles & access, People, Accounts.
  late final bool _isPlatformAdmin;

  /// Tab indices — resolved in [initState] because the tab set depends on
  /// [_isPlatformAdmin].
  late final int _tabOverview;
  late final int _tabAccess;
  late final int _tabPeople;

  @override
  void initState() {
    super.initState();

    final authState = context.read<AuthBloc>().state;
    _isPlatformAdmin =
        authState is Authenticated && authState.user.isPlatformAdmin;

    // Platform admin: all 9 tabs.
    // Branch admin:   5 tabs (Overview, Access matrix, Roles & access, People, Accounts).
    final tabCount = _isPlatformAdmin ? 9 : 5;

    _tabOverview = 0;
    // Access matrix is always tab 1.
    // Roles & access follows Geography (platform) or Access matrix (branch).
    _tabAccess = _isPlatformAdmin ? 3 : 2;
    // People follows Catalogue (platform) or Roles & access (branch).
    _tabPeople = _isPlatformAdmin ? 5 : 3;

    _tabs = TabController(
      length: tabCount,
      vsync: this,
      // A deep link to one person's assignments should land on People, not on
      // the analytics they didn't ask for.
      initialIndex: widget.initialUserId == null ? _tabOverview : _tabPeople,
    );
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a = await _repo.getAnalytics(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _analytics = a;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Jump to the role editor with a role selected. Called from the pills and
  /// matrix rows in the analytics views.
  void _openRole(int roleId) {
    setState(() => _pendingRoleId = roleId);
    _tabs.animateTo(_tabAccess);
  }

  int? _pendingRoleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Role management'),
        actions: [
          if (_analytics.generatedAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  'as of ${DateFormat('h:mm a').format(_analytics.generatedAt!.toLocal())}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Reload',
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(icon: Icon(Icons.insights_rounded), text: 'Overview'),
            const Tab(icon: Icon(Icons.grid_on_rounded), text: 'Access matrix'),
            if (_isPlatformAdmin)
              const Tab(icon: Icon(Icons.public_rounded), text: 'Geography'),
            const Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Roles & access'),
            if (_isPlatformAdmin)
              const Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Catalogue'),
            const Tab(icon: Icon(Icons.groups_rounded), text: 'People'),
            const Tab(icon: Icon(Icons.manage_accounts_rounded), text: 'Accounts'),
            if (_isPlatformAdmin)
              const Tab(icon: Icon(Icons.dashboard_customize_rounded), text: 'Dashboards'),
            if (_isPlatformAdmin)
              const Tab(icon: Icon(Icons.tune_rounded), text: 'Branch modules'),
          ],
        ),
      ),
      body: Column(
        children: [
          _summaryStrip(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _analyticsHost(
                  RbacOverviewPane(
                    analytics: _analytics,
                    onOpenRole: _openRole,
                    onOpenMatrix: () => _tabs.animateTo(1),
                    onOpenGeography: _isPlatformAdmin
                        ? () => _tabs.animateTo(2)
                        : null,
                  ),
                ),
                _analyticsHost(
                  RbacMatrixPane(analytics: _analytics, onOpenRole: _openRole),
                ),
                if (_isPlatformAdmin)
                  _analyticsHost(RbacGeographyPane(analytics: _analytics)),
                RoleAccessPane(
                  onChanged: _load,
                  initialRoleId: _pendingRoleId,
                ),
                if (_isPlatformAdmin)
                  RoleTemplatesPane(onChanged: _load),
                RoleMembersPane(
                  onChanged: _load,
                  initialUserId: widget.initialUserId,
                ),
                _accountsTab(),
                if (_isPlatformAdmin)
                  DashboardLayoutPane(onChanged: _load),
                if (_isPlatformAdmin)
                  const BranchModulesPane(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps an analytics view with the loading and failure states it shares.
  /// The editing panes below load independently, so a failure here must not
  /// take out the whole console.
  Widget _analyticsHost(Widget child) {
    if (_loading && _analytics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _analytics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(
                'Could not load access analytics',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(onRefresh: _load, child: child);
  }

  Widget _accountsTab() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => UserMgmtBloc()..add(LoadUsers())),
        BlocProvider(create: (_) => PanchayatBloc()..add(LoadPanchayats())),
      ],
      child: const UserManagement(),
    );
  }

  Widget _summaryStrip() {
    if (_analytics.isEmpty) return const SizedBox(height: 1);
    final t = _analytics.totals;
    final unreachable =
        _analytics.screenReach.where((s) => s.isUnreachable).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.stroke)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _counter('Roles', t.roles, Icons.badge_rounded),
            _counter('Screens', t.screens, Icons.view_sidebar_rounded),
            _counter('Assignments', t.assignments, Icons.link_rounded),
            _counter('Branches', t.branches, Icons.account_balance_rounded),
            // These are states somebody is stuck in rather than statistics, so
            // they are called out rather than merely counted.
            _counter(
              'No role',
              t.usersWithoutRole,
              Icons.person_off_rounded,
              alert: t.usersWithoutRole > 0,
              tooltip: 'Users with no role at all — they sign in to an empty '
                  'menu and cannot work.',
            ),
            _counter(
              'Password not set',
              t.usersPendingPasswordChange,
              Icons.key_off_rounded,
              alert: t.usersPendingPasswordChange > 0,
              tooltip: 'Users who have not yet changed their issued password.',
            ),
            _counter(
              'Unreachable screens',
              unreachable,
              Icons.block_rounded,
              alert: unreachable > 0,
              tooltip: 'Screens that no role has been granted — nobody in the '
                  'organisation can open them.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _counter(
    String label,
    int value,
    IconData icon, {
    bool alert = false,
    String? tooltip,
  }) {
    final color = alert ? AppTheme.warning : AppTheme.textMuted;
    final chip = Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: alert ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: alert ? AppTheme.warning.withValues(alpha: 0.35) : AppTheme.stroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: alert ? AppTheme.warning : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );

    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }
}
