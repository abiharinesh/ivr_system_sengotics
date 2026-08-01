import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/empty_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/core/models/user_model.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/user_bloc.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({
    super.key,
    this.initialRoleFilter,
    this.lockRoleFilter = false,
    this.customTitle,
    this.customSubtitle,
  });

  final String? initialRoleFilter;
  final bool lockRoleFilter;
  final String? customTitle;
  final String? customSubtitle;

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  final _repo = SuperAdminRepository();
  static const _roleOptions = <String>[
    'all',
    'super_admin',
    'panchayat_admin',
    'agent',
    'electrician',
  ];

  String _activeRole = 'all';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRoleFilter;
    if (initial != null && _roleOptions.contains(initial)) {
      _activeRole = initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserMgmtBloc, UserMgmtState>(
      listener: (context, state) {
        if (state is UserMgmtActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
        if (state is UserMgmtError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is UserMgmtLoading;
        if (state is UserMgmtLoaded || isLoading) {
          final users =
              state is UserMgmtLoaded ? state.users : const <UserModel>[];
          final filtered = _filteredUsers(users);
          return _buildList(context, filtered, isLoading: isLoading);
        }
        return const SizedBox.shrink();
      },
    );
  }

  List<UserModel> _filteredUsers(List<UserModel> users) {
    if (_activeRole == 'all') return users;
    return users.where((u) => u.role == _activeRole).toList();
  }

  String _labelForRole(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'panchayat_admin':
        return 'Panchayat Admin';
      case 'agent':
        return 'Agent';
      case 'electrician':
        return 'Electrician';
      default:
        return role;
    }
  }

  String _titleForFilter(String role) {
    if (widget.customTitle != null) return widget.customTitle!;
    switch (role) {
      case 'agent':
        return 'Agent Management';
      case 'electrician':
        return 'Electrician Management';
      default:
        return 'User Management';
    }
  }

  String _subtitleForFilter(String role) {
    if (widget.customSubtitle != null) return widget.customSubtitle!;
    switch (role) {
      case 'agent':
        return 'Create and manage field agents';
      case 'electrician':
        return 'Create and manage electricians';
      default:
        return 'Manage super-admin, admin, and field staff access';
    }
  }

  String _addLabelForFilter(String role) {
    switch (role) {
      case 'agent':
        return 'Add Agent';
      case 'electrician':
        return 'Add Electrician';
      default:
        return 'Add User';
    }
  }

  Widget _buildList(
    BuildContext context,
    List<UserModel> filteredUsers, {
    bool isLoading = false,
  }) {
    return ListScreenShell(
      title: _titleForFilter(_activeRole),
      subtitle: _subtitleForFilter(_activeRole),
      countLabel: isLoading ? 'Loading...' : '${filteredUsers.length} user(s)',
      action: ElevatedButton.icon(
        onPressed:
            isLoading ? null : () => _showCreateDialog(context, _activeRole),
        icon: const Icon(Icons.add, size: 18),
        label: Text(_addLabelForFilter(_activeRole)),
      ),
      filters:
          widget.lockRoleFilter
              ? null
              : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      _roleOptions.map((role) {
                        final selected = _activeRole == role;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              role == 'all' ? 'All' : _labelForRole(role),
                            ),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _activeRole = role);
                            },
                            selectedColor: AppTheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            checkmarkColor: AppTheme.primary,
                          ),
                        );
                      }).toList(),
                ),
              ),
      child:
          isLoading
              ? const AppLoadingState(
                message: 'Loading users...',
                style: AppLoadingStyle.list,
              )
              : (filteredUsers.isEmpty
                  ? EmptyState(
                    icon: Icons.people_rounded,
                    title: _titleForFilter(_activeRole),
                    subtitle: _subtitleForFilter(_activeRole),
                    action: ElevatedButton.icon(
                      onPressed: () => _showCreateDialog(context, _activeRole),
                      icon: const Icon(Icons.add),
                      label: Text(_addLabelForFilter(_activeRole)),
                    ),
                  )
                  : LayoutBuilder(
                    builder: (context, constraints) {
                      final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
                      return ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final isField = user.isFieldStaff;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor:
                                    user.isSuperAdmin
                                        ? AppTheme.warning.withValues(
                                          alpha: 0.15,
                                        )
                                        : isField
                                        ? AppTheme.primary.withValues(
                                          alpha: 0.15,
                                        )
                                        : AppTheme.accent.withValues(
                                          alpha: 0.12,
                                        ),
                                child: Icon(
                                  user.isSuperAdmin
                                      ? Icons.admin_panel_settings_rounded
                                      : user.isAgent
                                      ? Icons.group_rounded
                                      : user.isElectrician
                                      ? Icons.engineering_rounded
                                      : Icons.person_rounded,
                                  color:
                                      user.isSuperAdmin
                                          ? AppTheme.warning
                                          : isField
                                          ? AppTheme.primary
                                          : AppTheme.accent,
                                ),
                              ),
                              title: Text(
                                user.email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          user.isSuperAdmin
                                              ? AppTheme.warning.withValues(
                                                alpha: 0.12,
                                              )
                                              : AppTheme.accent.withValues(
                                                alpha: 0.12,
                                              ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _labelForRole(user.role),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            user.isSuperAdmin
                                                ? AppTheme.warning
                                                : AppTheme.accent,
                                      ),
                                    ),
                                  ),
                                  if (user.panchayatName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      user.panchayatName!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_note_rounded,
                                      color: AppTheme.primary,
                                    ),
                                    tooltip: 'Edit Profile & Details',
                                    onPressed: () => _showEditUserDialog(context, user),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.shield_outlined,
                                      color: AppTheme.primary,
                                    ),
                                    tooltip: 'Roles & Permissions',
                                    onPressed:
                                        () => context.go(
                                          '/superadmin/roles?user_id=${user.id}',
                                        ),
                                  ),
                                  if (!user.isSuperAdmin)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppTheme.error,
                                      ),
                                      onPressed:
                                          () => _showDeleteDialog(
                                            context,
                                            user.id,
                                            user.email,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )),
    );
  }

  Future<void> _showEditUserDialog(BuildContext context, UserModel user) async {
    final emailC = TextEditingController(text: user.email);
    int? selectedPanchayatId = user.panchayatId;
    String selectedRole = user.role;
    final formKey = GlobalKey<FormState>();

    List<dynamic> panchayats = const [];
    try {
      panchayats = await _repo.listPanchayats();
      if (selectedPanchayatId == null && panchayats.isNotEmpty) {
        selectedPanchayatId = panchayats.first.id as int;
      }
    } catch (_) {
      panchayats = [];
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Profile — ${user.email}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailC,
                    decoration: const InputDecoration(labelText: 'Email Address *'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role *'),
                    items: const [
                      DropdownMenuItem(value: 'panchayat_admin', child: Text('Panchayat Admin')),
                      DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                      DropdownMenuItem(value: 'agent', child: Text('Agent')),
                      DropdownMenuItem(value: 'electrician', child: Text('Electrician')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedRole = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedPanchayatId,
                    decoration: const InputDecoration(labelText: 'Panchayat Assignment'),
                    hint: const Text('Select panchayat'),
                    items: panchayats
                        .map((p) => DropdownMenuItem<int>(
                              value: p.id as int,
                              child: Text(p.name as String),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => selectedPanchayatId = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final payload = <String, dynamic>{
                    'email': emailC.text.trim(),
                    'role': selectedRole,
                    if (selectedPanchayatId != null) 'panchayat_id': selectedPanchayatId,
                  };
                  context.read<UserMgmtBloc>().add(UpdateUser(user.id, payload));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    String activeRole,
  ) async {
    final emailC = TextEditingController();
    final passC = TextEditingController();
    int? selectedPanchayatId;
    final formKey = GlobalKey<FormState>();
    final lockRole = widget.lockRoleFilter && widget.initialRoleFilter != null;
    String selectedRole =
        (activeRole != 'all' ? activeRole : 'panchayat_admin').toString();
    if (selectedRole == 'super_admin') {
      selectedRole = 'panchayat_admin';
    }

    List<dynamic> panchayats = const [];
    try {
      panchayats = await _repo.listPanchayats();
      if (panchayats.isNotEmpty) {
        selectedPanchayatId = panchayats.first.id as int;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load panchayats: $e')));
      return;
    }

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: Text('Create ${_labelForRole(selectedRole)}'),
                  content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!lockRole)
                            DropdownButtonFormField<String>(
                              initialValue: selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Role *',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'panchayat_admin',
                                  child: Text('Panchayat Admin'),
                                ),
                                DropdownMenuItem(
                                  value: 'agent',
                                  child: Text('Agent'),
                                ),
                                DropdownMenuItem(
                                  value: 'electrician',
                                  child: Text('Electrician'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setDialogState(() => selectedRole = v);
                              },
                            ),
                          if (!lockRole) const SizedBox(height: 12),
                          TextFormField(
                            controller: emailC,
                            decoration: const InputDecoration(
                              labelText: 'Email *',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (!v.contains('@')) return 'Invalid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passC,
                            decoration: const InputDecoration(
                              labelText: 'Password *',
                            ),
                            obscureText: true,
                            validator: (v) {
                              if (v == null || v.length < 8) {
                                return 'Min 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: selectedPanchayatId,
                            decoration: const InputDecoration(
                              labelText: 'Panchayat *',
                            ),
                            hint: const Text('Select panchayat'),
                            items:
                                panchayats
                                    .map(
                                      (p) => DropdownMenuItem<int>(
                                        value: p.id as int,
                                        child: Text(p.name as String),
                                      ),
                                    )
                                    .toList()
                                    .cast<DropdownMenuItem<int>>(),
                            onChanged: (v) {
                              setDialogState(() => selectedPanchayatId = v);
                            },
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate() &&
                            selectedPanchayatId != null) {
                          final payload = <String, dynamic>{
                            'email': emailC.text.trim(),
                            'password': passC.text,
                            'panchayat_id': selectedPanchayatId,
                          };
                          if (selectedRole == 'agent' ||
                              selectedRole == 'electrician') {
                            payload['role'] = selectedRole;
                          }
                          context.read<UserMgmtBloc>().add(CreateUser(payload));
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showDeleteDialog(BuildContext context, int id, String email) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete User'),
            content: Text('Delete admin "$email"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                onPressed: () {
                  context.read<UserMgmtBloc>().add(DeleteUser(id));
                  Navigator.pop(ctx);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
