import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/panchayat_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/user_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_models.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/rbac_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/user_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/branch_modules_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/role_access_pane.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/widgets/role_members_pane.dart';

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
/// Ordered that way on purpose — it is the order you check them in.
class RoleManagementConsole extends StatefulWidget {
  const RoleManagementConsole({super.key, this.initialUserId});

  /// Open straight onto this person's assignments. Set by the per-user
  /// shortcut on the Accounts tab and by `/superadmin/roles?user_id=`.
  final int? initialUserId;

  @override
  State<RoleManagementConsole> createState() => _RoleManagementConsoleState();
}

class _RoleManagementConsoleState extends State<RoleManagementConsole> {
  final _repo = RbacRepository();
  RbacSummary _summary = RbacSummary.empty;
  bool _summaryLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final s = await _repo.getSummary(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _summaryLoaded = true;
      });
    } catch (_) {
      // The counters are context, not the point of the screen. The panes below
      // surface their own failures.
      if (!mounted) return;
      setState(() => _summaryLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialUserId == null ? 0 : 1,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          backgroundColor: AppTheme.bgCard,
          title: const Text('Role management'),
          actions: [
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadSummary,
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Roles & access'),
              Tab(icon: Icon(Icons.groups_rounded), text: 'People'),
              Tab(icon: Icon(Icons.manage_accounts_rounded), text: 'Accounts'),
              Tab(icon: Icon(Icons.tune_rounded), text: 'Branch modules'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildSummaryStrip(),
            Expanded(
              child: TabBarView(
                children: [
                  RoleAccessPane(onChanged: _loadSummary),
                  RoleMembersPane(
                    onChanged: _loadSummary,
                    initialUserId: widget.initialUserId,
                  ),
                  _buildAccountsTab(),
                  const BranchModulesPane(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsTab() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => UserMgmtBloc()..add(LoadUsers())),
        BlocProvider(create: (_) => PanchayatBloc()..add(LoadPanchayats())),
      ],
      child: const UserManagement(),
    );
  }

  Widget _buildSummaryStrip() {
    if (!_summaryLoaded) return const SizedBox(height: 1);

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
            _counter('Roles', _summary.roles, Icons.badge_rounded),
            _counter('Screens', _summary.screens, Icons.view_sidebar_rounded),
            _counter('Assignments', _summary.assignments, Icons.link_rounded),
            // Both of these are states a person is stuck in rather than
            // statistics, so they are called out rather than merely counted.
            _counter(
              'No role',
              _summary.usersWithoutRole,
              Icons.person_off_rounded,
              alert: _summary.usersWithoutRole > 0,
              tooltip: 'Users with no role at all — they sign in to an empty '
                  'menu and cannot work.',
            ),
            _counter(
              'Password not set',
              _summary.usersPendingPasswordChange,
              Icons.key_off_rounded,
              alert: _summary.usersPendingPasswordChange > 0,
              tooltip: 'Users who have not yet changed their issued password.',
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
        color: alert
            ? AppTheme.warning.withValues(alpha: 0.1)
            : AppTheme.bgDark,
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
