import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/core/models/user_model.dart';
import 'package:ivr_frontend/core/widgets/app_empty_state.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_models.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/rbac_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';

/// Whether the pane is answering "who holds this role" or "what does this
/// person hold".
enum _MemberView { byRole, byUser }

/// One row of `user_roles` as the legacy per-user endpoint returns it.
///
/// That endpoint includes only the user, so the role and branch arrive as bare
/// ids and are resolved against the lists this pane already holds.
class _UserAssignment {
  final int id;
  final int roleId;
  final int orgUnitId;
  final bool isPrimary;

  const _UserAssignment({
    required this.id,
    required this.roleId,
    required this.orgUnitId,
    required this.isPrimary,
  });

  factory _UserAssignment.fromJson(Map<String, dynamic> json) => _UserAssignment(
        id: (json['id'] as num?)?.toInt() ?? 0,
        roleId: (json['role_id'] as num?)?.toInt() ?? 0,
        orgUnitId: (json['org_unit_id'] as num?)?.toInt() ?? 0,
        isPrimary: json['is_primary'] == true,
      );
}

/// Who holds which role, and where.
///
/// An assignment is (user, role, branch) — the same person can be a Revenue
/// Officer at one branch and nothing at another, so the branch is picked
/// alongside the role rather than inferred from the person's home posting.
///
/// Both directions are offered because both questions get asked: "who are my
/// sanitary inspectors" when staffing, and "why can this person not see the
/// register" when something is wrong.
class RoleMembersPane extends StatefulWidget {
  const RoleMembersPane({super.key, this.onChanged, this.initialUserId});

  final VoidCallback? onChanged;

  /// Open on this person's assignments — the target of the per-user shortcut
  /// on the Accounts tab.
  final int? initialUserId;

  @override
  State<RoleMembersPane> createState() => _RoleMembersPaneState();
}

class _RoleMembersPaneState extends State<RoleMembersPane> {
  final _rbac = RbacRepository();
  final _admin = SuperAdminRepository();

  bool _loading = true;
  String? _error;

  List<RoleSummary> _roles = const [];
  List<UserModel> _users = const [];
  List<PanchayatModel> _branches = const [];

  late _MemberView _view =
      widget.initialUserId == null ? _MemberView.byRole : _MemberView.byUser;

  RoleSummary? _selectedRole;
  List<RoleMember> _members = const [];
  bool _membersLoading = false;

  int? _selectedUserId;
  List<_UserAssignment> _userAssignments = const [];
  bool _assignmentsLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.initialUserId;
    _load();
  }

  static String _msg(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roles = await _rbac.listRoles(forceRefresh: true);

      // The user and branch lists feed the pickers. A failure there must not
      // take the whole pane down — viewing by role still works without them.
      List<UserModel> users = const [];
      List<PanchayatModel> branches = const [];
      try {
        final side = await Future.wait([
          _admin.listUsers(),
          _admin.listPanchayats(),
        ]);
        users = side[0] as List<UserModel>;
        branches = side[1] as List<PanchayatModel>;
      } catch (_) {
        // Assigning will be unavailable; viewing still works.
      }

      if (!mounted) return;
      setState(() {
        _roles = roles;
        _users = users;
        _branches = branches;
        _loading = false;
      });

      if (_view == _MemberView.byUser) {
        final id = _selectedUserId ?? (users.isEmpty ? null : users.first.id);
        if (id != null) await _selectUser(id);
        return;
      }

      // Keep the operator on the role they were looking at if it survived the
      // reload, otherwise fall back to the first.
      final keep = _selectedRole;
      final stillThere = keep == null
          ? const <RoleSummary>[]
          : roles.where((r) => r.id == keep.id).toList();
      final next = stillThere.isNotEmpty
          ? stillThere.first
          : (roles.isEmpty ? null : roles.first);
      if (next != null) await _selectRole(next);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  Future<void> _selectRole(RoleSummary role) async {
    setState(() {
      _selectedRole = role;
      _membersLoading = true;
    });
    try {
      final members = await _rbac.listMembers(role.id);
      if (!mounted) return;
      setState(() {
        _members = members;
        _membersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _members = const [];
        _membersLoading = false;
      });
      _toast(_msg(e), isError: true);
    }
  }

  Future<void> _selectUser(int userId) async {
    setState(() {
      _selectedUserId = userId;
      _assignmentsLoading = true;
    });
    try {
      final raw = await _admin.listUserRoles(userId);
      if (!mounted) return;
      setState(() {
        _userAssignments = raw
            .map((e) => _UserAssignment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _assignmentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userAssignments = const [];
        _assignmentsLoading = false;
      });
      _toast(_msg(e), isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.accent,
      ),
    );
  }

  Future<void> _reloadCurrent() async {
    if (_view == _MemberView.byRole) {
      final role = _selectedRole;
      if (role != null) await _selectRole(role);
    } else {
      final id = _selectedUserId;
      if (id != null) await _selectUser(id);
    }
  }

  RoleSummary? _roleById(int id) {
    final match = _roles.where((r) => r.id == id);
    return match.isEmpty ? null : match.first;
  }

  PanchayatModel? _branchById(int id) {
    final match = _branches.where((b) => b.id == id);
    return match.isEmpty ? null : match.first;
  }

  UserModel? get _selectedUser {
    final id = _selectedUserId;
    if (id == null) return null;
    final match = _users.where((u) => u.id == id);
    return match.isEmpty ? null : match.first;
  }

  Future<void> _revoke({
    required int assignmentId,
    required String who,
    required String what,
    required String where,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke role?'),
        content: Text(
          '$who will lose "$what" at $where. If this is their only role they '
          'will sign in to an empty menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _rbac.revokeAssignment(assignmentId);
      _toast('Revoked.');
      widget.onChanged?.call();
      await _reloadCurrent();
    } catch (e) {
      _toast(_msg(e), isError: true);
    }
  }

  Future<void> _assign() async {
    if (_users.isEmpty || _branches.isEmpty) {
      _toast(
        'Could not load the user or branch list, so there is nothing to '
        'assign from. Reload and try again.',
        isError: true,
      );
      return;
    }

    final result = await showDialog<_AssignRequest>(
      context: context,
      builder: (ctx) => _AssignDialog(
        fixedRole: _view == _MemberView.byRole ? _selectedRole : null,
        fixedUser: _view == _MemberView.byUser ? _selectedUser : null,
        users: _users,
        roles: _roles,
        branches: _branches,
      ),
    );
    if (result == null) return;

    try {
      await _rbac.assignRole(
        userId: result.userId,
        roleId: result.roleId,
        orgUnitId: result.orgUnitId,
        isPrimary: result.isPrimary,
      );
      _toast('Assigned.');
      widget.onChanged?.call();
      await _reloadCurrent();
    } catch (e) {
      _toast(_msg(e), isError: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingState(message: 'Loading role assignments...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_roles.isEmpty) {
      return const AppEmptyState(
        icon: Icons.group_rounded,
        title: 'No roles yet',
        subtitle: 'Run the RBAC seed to populate the role catalogue.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SegmentedButton<_MemberView>(
            segments: const [
              ButtonSegment(
                value: _MemberView.byRole,
                label: Text('By role'),
                icon: Icon(Icons.badge_rounded, size: 16),
              ),
              ButtonSegment(
                value: _MemberView.byUser,
                label: Text('By person'),
                icon: Icon(Icons.person_rounded, size: 16),
              ),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() => _view = s.first);
              if (s.first == _MemberView.byUser) {
                final id = _selectedUserId ??
                    (_users.isEmpty ? null : _users.first.id);
                if (id != null) _selectUser(id);
              } else {
                final role = _selectedRole ??
                    (_roles.isEmpty ? null : _roles.first);
                if (role != null) _selectRole(role);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _view == _MemberView.byRole
                    ? _rolePicker()
                    : _userPicker(),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _assign,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Assign'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _view == _MemberView.byRole
              ? _buildMembersList()
              : _buildAssignmentsList(),
        ),
      ],
    );
  }

  Widget _rolePicker() => DropdownButtonFormField<int>(
        initialValue: _selectedRole?.id,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Role',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: _roles
            .map((r) => DropdownMenuItem(
                  value: r.id,
                  child: Text(
                    '${r.displayName}  (${r.userCount})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: (id) {
          if (id == null) return;
          final role = _roleById(id);
          if (role != null) _selectRole(role);
        },
      );

  Widget _userPicker() => DropdownButtonFormField<int>(
        initialValue: _users.any((u) => u.id == _selectedUserId)
            ? _selectedUserId
            : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Person',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: _users
            .map((u) => DropdownMenuItem(
                  value: u.id,
                  child: Text(u.email, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (id) {
          if (id != null) _selectUser(id);
        },
      );

  Widget _buildMembersList() {
    if (_membersLoading) {
      return const AppLoadingState(message: 'Loading members...', compact: true);
    }
    if (_members.isEmpty) {
      return AppEmptyState(
        icon: Icons.person_off_rounded,
        title: 'Nobody holds this role',
        subtitle: '"${_selectedRole?.displayName ?? ''}" is not assigned to '
            'anyone yet. Assign someone to put it to work.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _memberTile(_members[i]),
    );
  }

  Widget _buildAssignmentsList() {
    if (_assignmentsLoading) {
      return const AppLoadingState(
        message: 'Loading assignments...',
        compact: true,
      );
    }
    final user = _selectedUser;
    if (user == null) {
      return const AppEmptyState(
        icon: Icons.person_search_rounded,
        title: 'Pick a person',
        subtitle: 'Choose someone to see every role they hold.',
      );
    }
    if (_userAssignments.isEmpty) {
      return AppEmptyState(
        icon: Icons.person_off_rounded,
        title: '${user.email} holds no roles',
        subtitle: 'They will sign in to an empty menu until they are given '
            'one. Use Assign to fix that.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _userAssignments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _assignmentTile(user, _userAssignments[i]),
    );
  }

  Widget _shell({
    required IconData icon,
    required String title,
    required List<Widget> titleTags,
    required String subtitle,
    required VoidCallback onRevoke,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...titleTags,
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Revoke this role',
            icon: const Icon(Icons.link_off_rounded, size: 20, color: AppTheme.error),
            onPressed: onRevoke,
          ),
        ],
      ),
    );
  }

  Widget _memberTile(RoleMember m) => _shell(
        icon: Icons.person_rounded,
        title: m.email,
        titleTags: [
          if (m.isPrimary) ...[
            const SizedBox(width: 8),
            _tag('Primary', AppTheme.primary),
          ],
          if (!m.isUserActive) ...[
            const SizedBox(width: 6),
            _tag('Account disabled', AppTheme.error),
          ],
          if (m.mustChangePassword) ...[
            const SizedBox(width: 6),
            _tag('Password not set', AppTheme.warning),
          ],
        ],
        subtitle: [
          m.orgUnitName ?? 'Unknown branch',
          if (m.phone != null && m.phone!.isNotEmpty) m.phone!,
          m.lastLoginAt == null
              ? 'Never signed in'
              : 'Last seen ${_ago(m.lastLoginAt!)}',
        ].join('  ·  '),
        onRevoke: () => _revoke(
          assignmentId: m.assignmentId,
          who: m.email,
          what: _selectedRole?.displayName ?? 'this role',
          where: m.orgUnitName ?? 'their branch',
        ),
      );

  Widget _assignmentTile(UserModel user, _UserAssignment a) {
    final role = _roleById(a.roleId);
    final branch = _branchById(a.orgUnitId);
    final roleName = role?.displayName ?? 'Role #${a.roleId}';
    final branchName = branch?.name ?? 'Branch #${a.orgUnitId}';

    return _shell(
      icon: Icons.badge_rounded,
      title: roleName,
      titleTags: [
        if (a.isPrimary) ...[
          const SizedBox(width: 8),
          _tag('Primary', AppTheme.primary),
        ],
        if (role != null && !role.isActive) ...[
          const SizedBox(width: 6),
          _tag('Role disabled', AppTheme.error),
        ],
      ],
      subtitle: role == null
          ? branchName
          : '$branchName  ·  ${role.screenCount} screens  ·  '
              '${role.permissionCount} permissions',
      onRevoke: () => _revoke(
        assignmentId: a.id,
        who: user.email,
        what: roleName,
        where: branchName,
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  static String _ago(DateTime when) {
    final d = DateTime.now().difference(when);
    if (d.inDays > 30) return '${(d.inDays / 30).floor()} month(s) ago';
    if (d.inDays > 0) return '${d.inDays} day(s) ago';
    if (d.inHours > 0) return '${d.inHours} hour(s) ago';
    return 'just now';
  }
}

class _AssignRequest {
  final int userId;
  final int roleId;
  final int orgUnitId;
  final bool isPrimary;

  const _AssignRequest({
    required this.userId,
    required this.roleId,
    required this.orgUnitId,
    required this.isPrimary,
  });
}

/// Assign a role to someone at a branch.
///
/// Whichever of role or person the pane is already focused on is fixed; the
/// other two are picked here.
class _AssignDialog extends StatefulWidget {
  const _AssignDialog({
    required this.fixedRole,
    required this.fixedUser,
    required this.users,
    required this.roles,
    required this.branches,
  });

  final RoleSummary? fixedRole;
  final UserModel? fixedUser;
  final List<UserModel> users;
  final List<RoleSummary> roles;
  final List<PanchayatModel> branches;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  int? _userId;
  int? _roleId;
  int? _orgUnitId;
  bool _isPrimary = false;

  @override
  void initState() {
    super.initState();
    _userId = widget.fixedUser?.id;
    _roleId = widget.fixedRole?.id;
  }

  RoleSummary? get _role {
    final id = _roleId;
    if (id == null) return null;
    final match = widget.roles.where((r) => r.id == id);
    return match.isEmpty ? null : match.first;
  }

  /// Branches where the chosen role can actually exist.
  ///
  /// A role restricted to certain body types cannot be granted at a branch of
  /// another type — the server refuses it, so it is not offered here.
  List<PanchayatModel> get _eligibleBranches {
    final role = _role;
    if (role == null || role.applicableBranchTypes.isEmpty) {
      return widget.branches;
    }
    return widget.branches
        .where((b) =>
            b.branchType != null &&
            role.applicableBranchTypes.contains(b.branchType))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final eligible = _eligibleBranches;
    final noBranches = _role != null && eligible.isEmpty;

    return AlertDialog(
      title: Text(
        widget.fixedRole != null
            ? 'Assign "${widget.fixedRole!.displayName}"'
            : 'Give ${widget.fixedUser?.email ?? 'this person'} a role',
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.fixedUser == null) ...[
              DropdownButtonFormField<int>(
                initialValue: _userId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Person',
                  border: OutlineInputBorder(),
                ),
                items: widget.users
                    .map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(u.email, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _userId = v),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.fixedRole == null) ...[
              DropdownButtonFormField<int>(
                initialValue: _roleId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: widget.roles
                    .map((r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(
                            r.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                // Changing the role can invalidate the branch already picked.
                onChanged: (v) => setState(() {
                  _roleId = v;
                  _orgUnitId = null;
                }),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<int>(
              initialValue:
                  eligible.any((b) => b.id == _orgUnitId) ? _orgUnitId : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Branch',
                border: const OutlineInputBorder(),
                helperText: noBranches
                    ? 'No branch of yours is a ${_role!.applicableBranchTypes.join(' / ').toLowerCase()}'
                    : 'The role applies at this branch only',
                helperStyle: noBranches
                    ? const TextStyle(color: AppTheme.error)
                    : null,
              ),
              items: eligible
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _orgUnitId = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isPrimary,
              onChanged: (v) => setState(() => _isPrimary = v),
              title: const Text('Make this their primary role'),
              subtitle: Text(
                'The context they land in at sign-in. Any existing primary '
                'role is demoted.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _userId == null || _roleId == null || _orgUnitId == null
              ? null
              : () => Navigator.pop(
                    context,
                    _AssignRequest(
                      userId: _userId!,
                      roleId: _roleId!,
                      orgUnitId: _orgUnitId!,
                      isPrimary: _isPrimary,
                    ),
                  ),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
