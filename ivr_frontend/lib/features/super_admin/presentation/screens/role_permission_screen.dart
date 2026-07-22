import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/super_admin_repository.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/panchayat_model.dart';

class RolePermissionScreen extends StatefulWidget {
  final int? preselectedUserId;

  const RolePermissionScreen({super.key, this.preselectedUserId});

  @override
  State<RolePermissionScreen> createState() => _RolePermissionScreenState();
}

class _RolePermissionScreenState extends State<RolePermissionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = SuperAdminRepository();

  bool _isLoading = true;
  String? _error;

  List<dynamic> _roles = [];
  List<dynamic> _permissionGroups = [];
  Map<String, dynamic> _permissionsData = {};
  List<UserModel> _users = [];
  List<PanchayatModel> _panchayats = [];

  // Tab 3 State
  UserModel? _selectedUser;
  List<dynamic> _userRoles = [];
  bool _isLoadingUserRoles = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.preselectedUserId != null) {
      _tabController.index = 2;
    }
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rolesF = _repo.listRoles();
      final groupsF = _repo.listPermissionGroups();
      final permsF = _repo.listPermissions();
      final usersF = _repo.listUsers();
      final panchayatsF = _repo.listPanchayats();

      final results = await Future.wait([
        rolesF,
        groupsF,
        permsF,
        usersF,
        panchayatsF,
      ]);

      setState(() {
        _roles = results[0] as List<dynamic>;
        _permissionGroups = results[1] as List<dynamic>;
        _permissionsData = results[2] as Map<String, dynamic>;
        _users = results[3] as List<UserModel>;
        _panchayats = results[4] as List<PanchayatModel>;

        if (widget.preselectedUserId != null) {
          final found =
              _users.where((u) => u.id == widget.preselectedUserId).firstOrNull;
          if (found != null) {
            _selectedUser = found;
            _loadUserRoles(found.id);
          }
        } else if (_users.isNotEmpty) {
          _selectedUser = _users.first;
          _loadUserRoles(_users.first.id);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserRoles(int userId) async {
    setState(() => _isLoadingUserRoles = true);
    try {
      final list = await _repo.listUserRoles(userId);
      setState(() => _userRoles = list);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load user roles: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      setState(() => _isLoadingUserRoles = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Role & Permission Management'),
        backgroundColor: AppTheme.bgCard,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(
              icon: Icon(Icons.admin_panel_settings_rounded),
              text: 'System Roles',
            ),
            Tab(icon: Icon(Icons.security_rounded), text: 'Permission Groups'),
            Tab(
              icon: Icon(Icons.person_add_rounded),
              text: 'User Role Assignments',
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const AppLoadingState(
                message: 'Loading Roles & Permissions...',
                style: AppLoadingStyle.list,
              )
              : _error != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: AppTheme.error),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadAllData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildRolesTab(),
                  _buildPermissionGroupsTab(),
                  _buildUserAssignmentsTab(),
                ],
              ),
    );
  }

  // ── TAB 1: ROLES ──────────────────────────────────────────────────────────
  Widget _buildRolesTab() {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoleDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Role', style: TextStyle(color: Colors.white)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _roles.length,
        itemBuilder: (context, index) {
          final r = _roles[index];
          final isSystem = r['is_system'] == true;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor:
                    isSystem
                        ? AppTheme.warning.withValues(alpha: 0.15)
                        : AppTheme.primary.withValues(alpha: 0.15),
                child: Icon(
                  isSystem ? Icons.stars_rounded : Icons.badge_rounded,
                  color: isSystem ? AppTheme.warning : AppTheme.primary,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    r['display_name'] ?? r['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (r['display_name_ta'] != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${r['display_name_ta']})',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (isSystem)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'System',
                        style: TextStyle(
                          color: AppTheme.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Chip(
                      label: Text(
                        'Level ${r['hierarchy_level'] ?? 5}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    if (r['department'] != null)
                      Chip(
                        avatar: const Icon(Icons.business_rounded, size: 14),
                        label: Text(
                          r['department'],
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_rounded, color: AppTheme.primary),
                    onPressed: () => _showEditRoleDialog(r),
                  ),
                  if (!isSystem)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.error,
                      ),
                      onPressed: () => _deleteRole(r['id']),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── TAB 2: PERMISSION GROUPS ──────────────────────────────────────────────
  Widget _buildPermissionGroupsTab() {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupDialog,
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add_moderator_rounded, color: Colors.white),
        label: const Text(
          'New Permission Group',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _permissionGroups.length,
        itemBuilder: (context, index) {
          final group = _permissionGroups[index];
          final List<dynamic> perms = group['permissions'] ?? [];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        group['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_rounded,
                              color: AppTheme.primary,
                            ),
                            onPressed: () => _showEditGroupDialog(group),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.error,
                            ),
                            onPressed: () => _deleteGroup(group['id']),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        perms
                            .map(
                              (p) => Chip(
                                label: Text(
                                  p.toString(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: AppTheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── TAB 3: USER ASSIGNMENTS ───────────────────────────────────────────────
  Widget _buildUserAssignmentsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.person_search_rounded, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  const Text(
                    'Select User:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<UserModel>(
                        value: _selectedUser,
                        isExpanded: true,
                        items:
                            _users
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text('${u.email} (${u.role})'),
                                  ),
                                )
                                .toList(),
                        onChanged: (u) {
                          if (u != null) {
                            setState(() => _selectedUser = u);
                            _loadUserRoles(u.id);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed:
                        _selectedUser == null ? null : _showAssignRoleDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Assign Role'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Assigned Roles for User:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                _isLoadingUserRoles
                    ? const AppLoadingState(
                      message: 'Loading user role assignments...',
                    )
                    : _userRoles.isEmpty
                    ? const EmptyState(
                      icon: Icons.shield_outlined,
                      title: 'No Roles Assigned',
                      subtitle:
                          'Assign a role to grant branch-level permissions to this user.',
                    )
                    : ListView.builder(
                      itemCount: _userRoles.length,
                      itemBuilder: (context, index) {
                        final ur = _userRoles[index];
                        final roleId = ur['role_id'];
                        final roleMatch =
                            _roles.where((r) => r['id'] == roleId).firstOrNull;
                        final roleName =
                            roleMatch?['display_name'] ?? 'Role #$roleId';
                        final branchId = ur['branch_id'];
                        final panchayatMatch =
                            _panchayats
                                .where((p) => p.id == branchId)
                                .firstOrNull;
                        final branchName =
                            panchayatMatch?.name ?? 'Branch #$branchId';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary,
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              roleName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Branch: $branchName ${ur['is_temporary'] == true ? ' (Temporary)' : ''}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                color: AppTheme.error,
                              ),
                              onPressed: () => _revokeUserRole(ur['id']),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // ── DIALOGS & ACTIONS ─────────────────────────────────────────────────────

  void _showCreateRoleDialog() {
    final nameCtrl = TextEditingController();
    final dispCtrl = TextEditingController();
    final dispTaCtrl = TextEditingController();
    final deptCtrl = TextEditingController();
    int level = 5;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Create System Role'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dispCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Name (e.g. Municipal Engineer)',
                    ),
                  ),
                  TextField(
                    controller: dispTaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tamil Display Name (Optional)',
                    ),
                  ),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Role Key Code (e.g. municipal_engineer)',
                    ),
                  ),
                  TextField(
                    controller: deptCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Department (e.g. Engineering)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (dispCtrl.text.isEmpty) return;
                  final key =
                      nameCtrl.text.isNotEmpty
                          ? nameCtrl.text
                          : dispCtrl.text.toLowerCase().replaceAll(' ', '_');
                  await _repo.createRole({
                    'name': key,
                    'display_name': dispCtrl.text,
                    'display_name_ta':
                        dispTaCtrl.text.isNotEmpty ? dispTaCtrl.text : null,
                    'department':
                        deptCtrl.text.isNotEmpty ? deptCtrl.text : null,
                    'hierarchy_level': level,
                  });
                  Navigator.pop(ctx);
                  _loadAllData();
                },
                child: const Text('Save Role'),
              ),
            ],
          ),
    );
  }

  void _showEditRoleDialog(dynamic r) {
    final dispCtrl = TextEditingController(text: r['display_name']);
    final dispTaCtrl = TextEditingController(text: r['display_name_ta'] ?? '');
    final deptCtrl = TextEditingController(text: r['department'] ?? '');

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Edit Role: ${r['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dispCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                    ),
                  ),
                  TextField(
                    controller: dispTaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tamil Display Name',
                    ),
                  ),
                  TextField(
                    controller: deptCtrl,
                    decoration: const InputDecoration(labelText: 'Department'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _repo.updateRole(r['id'], {
                    'display_name': dispCtrl.text,
                    'display_name_ta':
                        dispTaCtrl.text.isNotEmpty ? dispTaCtrl.text : null,
                    'department':
                        deptCtrl.text.isNotEmpty ? deptCtrl.text : null,
                  });
                  Navigator.pop(ctx);
                  _loadAllData();
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteRole(int id) async {
    try {
      await _repo.deleteRole(id);
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete role: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showCreateGroupDialog() {
    final nameCtrl = TextEditingController();
    final Map<String, dynamic> grouped = _permissionsData['grouped'] ?? {};
    final Set<String> selectedPerms = {};

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDlgState) => AlertDialog(
                  title: const Text('New Permission Group'),
                  content: SizedBox(
                    width: 500,
                    height: 400,
                    child: Column(
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Group Name (e.g. Revenue Full Access)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Select Permissions:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children:
                                grouped.entries.map((e) {
                                  final moduleName = e.key;
                                  final List perms = e.value;
                                  return ExpansionTile(
                                    title: Text(
                                      moduleName.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    children:
                                        perms.map((p) {
                                          final code = p['code'].toString();
                                          final desc =
                                              p['description']?.toString() ??
                                              code;
                                          return CheckboxListTile(
                                            title: Text(
                                              code,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Text(
                                              desc,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            value: selectedPerms.contains(code),
                                            onChanged: (val) {
                                              setDlgState(() {
                                                if (val == true)
                                                  selectedPerms.add(code);
                                                else
                                                  selectedPerms.remove(code);
                                              });
                                            },
                                          );
                                        }).toList(),
                                  );
                                }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty) return;
                        await _repo.createPermissionGroup(
                          name: nameCtrl.text,
                          permissions: selectedPerms.toList(),
                        );
                        Navigator.pop(ctx);
                        _loadAllData();
                      },
                      child: const Text('Save Group'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditGroupDialog(dynamic group) {
    final nameCtrl = TextEditingController(text: group['name']);
    final Map<String, dynamic> grouped = _permissionsData['grouped'] ?? {};
    final Set<String> selectedPerms = Set<String>.from(
      group['permissions'] ?? [],
    );

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDlgState) => AlertDialog(
                  title: Text('Edit Group: ${group['name']}'),
                  content: SizedBox(
                    width: 500,
                    height: 400,
                    child: Column(
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Group Name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Permissions:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children:
                                grouped.entries.map((e) {
                                  final moduleName = e.key;
                                  final List perms = e.value;
                                  return ExpansionTile(
                                    title: Text(
                                      moduleName.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    children:
                                        perms.map((p) {
                                          final code = p['code'].toString();
                                          final desc =
                                              p['description']?.toString() ??
                                              code;
                                          return CheckboxListTile(
                                            title: Text(
                                              code,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Text(
                                              desc,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            value: selectedPerms.contains(code),
                                            onChanged: (val) {
                                              setDlgState(() {
                                                if (val == true)
                                                  selectedPerms.add(code);
                                                else
                                                  selectedPerms.remove(code);
                                              });
                                            },
                                          );
                                        }).toList(),
                                  );
                                }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await _repo.updatePermissionGroup(
                          group['id'],
                          name: nameCtrl.text,
                          permissions: selectedPerms.toList(),
                        );
                        Navigator.pop(ctx);
                        _loadAllData();
                      },
                      child: const Text('Update Group'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _deleteGroup(int id) async {
    try {
      await _repo.deletePermissionGroup(id);
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete group: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showAssignRoleDialog() {
    if (_selectedUser == null || _roles.isEmpty || _panchayats.isEmpty) return;

    dynamic selectedRole = _roles.first;
    PanchayatModel selectedBranch = _panchayats.first;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDlgState) => AlertDialog(
                  title: Text('Assign Role to ${_selectedUser!.email}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<dynamic>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Select Role',
                        ),
                        items:
                            _roles
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r['display_name'] ?? r['name']),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (val) => setDlgState(() => selectedRole = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PanchayatModel>(
                        initialValue: selectedBranch,
                        decoration: const InputDecoration(
                          labelText: 'Select Panchayat Branch',
                        ),
                        items:
                            _panchayats
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.name),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null)
                            setDlgState(() => selectedBranch = val);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await _repo.assignUserRole(
                            userId: _selectedUser!.id,
                            roleId: selectedRole['id'],
                            branchId: selectedBranch.id,
                          );
                          Navigator.pop(ctx);
                          _loadUserRoles(_selectedUser!.id);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Assignment failed: $e'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      },
                      child: const Text('Assign'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _revokeUserRole(int id) async {
    try {
      await _repo.revokeUserRole(id);
      if (_selectedUser != null) _loadUserRoles(_selectedUser!.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revoke role: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
