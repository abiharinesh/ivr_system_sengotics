import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/features/modules/admin_management/data/admin_management_repository.dart';

class AdminDetailScreen extends StatefulWidget {
  final int adminId;

  const AdminDetailScreen({super.key, required this.adminId});

  @override
  State<AdminDetailScreen> createState() => _AdminDetailScreenState();
}

class _AdminDetailScreenState extends State<AdminDetailScreen> {
  final _repo = AdminManagementRepository();
  Map<String, dynamic>? _admin;
  List<RoleRecord> _allRoles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getAdminDetail(widget.adminId),
        _repo.listRoles(),
      ]);
      if (mounted) {
        setState(() {
          _admin = results[0] as Map<String, dynamic>;
          _allRoles = results[1] as List<RoleRecord>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleStatus() async {
    if (_admin == null) return;
    final current = _admin!['is_active'] == true;
    try {
      await _repo.toggleAdminStatus(widget.adminId, !current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${!current ? "Active" : "Inactive"}'),
          backgroundColor: AppTheme.accent,
        ),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _showEditRolesDialog() async {
    if (_admin == null) return;
    final userRoles = (_admin!['user_roles'] as List? ?? []);
    final currentRoleIds = userRoles
        .map((ur) => (ur['role'] as Map?)?['id'] as int?)
        .where((id) => id != null)
        .cast<int>()
        .toSet();

    final selected = Set<int>.from(currentRoleIds);
    final orgUnitId = _admin!['primary_org_unit_id'] as int? ?? 1;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Update RBAC Roles'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the roles to assign to this administrator:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allRoles.map((role) {
                    final isSel = selected.contains(role.id);
                    return FilterChip(
                      label: Text(
                        role.displayName.isNotEmpty
                            ? role.displayName
                            : role.name,
                      ),
                      selected: isSel,
                      onSelected: (val) {
                        setDlgState(() {
                          if (val) {
                            selected.add(role.id);
                          } else {
                            selected.remove(role.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () async {
                      try {
                        await _repo.updateAdminRoles(
                          widget.adminId,
                          roleIds: selected.toList(),
                          orgUnitId: orgUnitId,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating roles: $e'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    },
              child: const Text('Save Roles'),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListScreenShell(
      title: 'Admin User Details',
      subtitle: _admin != null
          ? '${_admin!['email'] ?? "Admin"} (ID: #${widget.adminId})'
          : 'Loading user details...',
      countLabel: 'Admin Profile',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          if (_admin != null) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Manage Roles'),
              onPressed: _showEditRolesDialog,
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: Icon(
                _admin!['is_active'] == true
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
              ),
              label: Text(
                _admin!['is_active'] == true ? 'Deactivate' : 'Activate',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _admin!['is_active'] == true
                    ? AppTheme.error
                    : AppTheme.accent,
              ),
              onPressed: _toggleStatus,
            ),
          ],
        ],
      ),
      child: _loading
          ? const AppLoadingState()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: AppTheme.error)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _admin == null
                  ? const Center(child: Text('Admin not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfileCard(theme),
                              const SizedBox(height: 16),
                              _buildRolesCard(theme),
                              const SizedBox(height: 16),
                              _buildPermissionsMatrixCard(theme),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    final org = _admin!['primary_org_unit'] as Map? ?? {};
    final isActive = _admin!['is_active'] == true;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    ((_admin!['email'] as String? ?? 'A')[0]).toUpperCase(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _admin!['email'] ?? 'No email',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildStatusBadge(isActive),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Phone: ${_admin!['phone_e164'] ?? "Not provided"} • Created: ${_formatDate(_admin!['created_at'])}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    theme,
                    'Primary Org Unit',
                    org['name'] ?? 'None',
                    Icons.account_balance_rounded,
                    subtitle: org['branch_type']?.toString().replaceAll('_', ' '),
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    theme,
                    'Last Login',
                    _admin!['last_login_at'] != null
                        ? _formatDate(_admin!['last_login_at'])
                        : 'Never',
                    Icons.login_rounded,
                    subtitle: _admin!['last_login_ip'] != null
                        ? 'IP: ${_admin!['last_login_ip']}'
                        : null,
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    theme,
                    'Failed Logins',
                    '${_admin!['failed_attempts'] ?? 0}',
                    Icons.security_rounded,
                    subtitle: _admin!['locked_until'] != null ? 'Locked' : 'Normal',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    final color = isActive ? AppTheme.accent : AppTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    ThemeData theme,
    String title,
    String value,
    IconData icon, {
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRolesCard(ThemeData theme) {
    final userRoles = (_admin!['user_roles'] as List? ?? []);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned RBAC Roles (${userRoles.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                  onPressed: _showEditRolesDialog,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (userRoles.isEmpty)
              Text(
                'No RBAC roles assigned. User has legacy role: ${_admin!['role']}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: userRoles.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, i) {
                  final ur = userRoles[i] as Map;
                  final role = ur['role'] as Map? ?? {};
                  final isPrimary = ur['is_primary'] == true;
                  final scope = ur['access_scope'] as String? ?? 'own_org_unit';

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.verified_user_rounded,
                            color: AppTheme.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  role['display_name'] ?? role['name'] ?? 'Role',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isPrimary) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PRIMARY',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Scope: $scope • Level: ${role['hierarchy_level'] ?? "N/A"}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsMatrixCard(ThemeData theme) {
    final userRoles = (_admin!['user_roles'] as List? ?? []);
    final Set<String> permissions = {};
    final Set<String> screens = {};

    for (final ur in userRoles) {
      final role = (ur as Map)['role'] as Map? ?? {};
      final perms = (role['permissions'] as List? ?? []);
      for (final p in perms) {
        final code = ((p as Map)['permission'] as Map?)?['code'] as String?;
        if (code != null) permissions.add(code);
      }
      final scrns = (role['screen_access'] as List? ?? []);
      for (final s in scrns) {
        final label = ((s as Map)['screen'] as Map?)?['label_en'] as String?;
        if (label != null) screens.add(label);
      }
    }

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_open_rounded,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Resolved Entitlements Matrix',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Accessible Navigation Screens (${screens.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (screens.isEmpty)
              Text(
                'No navigation screens mapped.',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: screens.map((s) {
                  return Chip(
                    label: Text(s, style: const TextStyle(fontSize: 11)),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            const SizedBox(height: 18),
            Text(
              'Granted API Permissions (${permissions.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (permissions.isEmpty)
              Text(
                'No granular permissions listed.',
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: permissions.map((p) {
                  return Chip(
                    label: Text(p, style: const TextStyle(fontSize: 10)),
                    backgroundColor:
                        AppTheme.accent.withValues(alpha: 0.12),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return 'N/A';
    final dt = DateTime.tryParse(d.toString());
    if (dt == null) return d.toString();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
