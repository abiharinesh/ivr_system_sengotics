import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/empty_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/features/modules/admin_management/data/admin_management_repository.dart';

class AdminListScreen extends StatefulWidget {
  const AdminListScreen({super.key});

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  final _repo = AdminManagementRepository();
  List<AdminRecord> _admins = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  final String _selectedRole = 'ALL';
  bool? _activeFilter;

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
      final list = await _repo.listAdmins(
        role: _selectedRole == 'ALL' ? null : _selectedRole,
        isActive: _activeFilter,
      );
      if (mounted) {
        setState(() {
          _admins = list;
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

  Future<void> _toggleStatus(AdminRecord admin, bool newStatus) async {
    try {
      await _repo.toggleAdminStatus(admin.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${admin.email ?? "Admin"} is now ${newStatus ? "Active" : "Inactive"}',
            ),
            backgroundColor: AppTheme.accent,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  List<AdminRecord> get _filteredAdmins {
    if (_search.trim().isEmpty) return _admins;
    final q = _search.toLowerCase();
    return _admins.where((a) {
      final emailMatch = a.email?.toLowerCase().contains(q) ?? false;
      final phoneMatch = a.phone?.toLowerCase().contains(q) ?? false;
      final orgMatch = a.orgUnitName?.toLowerCase().contains(q) ?? false;
      final roleMatch =
          a.userRoles.any((r) => r.roleDisplayName.toLowerCase().contains(q));
      return emailMatch || phoneMatch || orgMatch || roleMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAdmins;

    return ListScreenShell(
      title: 'Admin Management (RBAC)',
      subtitle:
          'Create and manage administrative users with role-based access control and org unit scoping.',
      countLabel: '${filtered.length} admins',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Create Admin'),
            onPressed: () async {
              final res = await context.push('/admin/admins/create');
              if (res == true) _load();
            },
          ),
        ],
      ),
      filters: _buildSearchAndFilters(),
      child: _loading
          ? const AppLoadingState()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error loading admins: $_error',
                        style: const TextStyle(color: AppTheme.error),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'No Admins Found',
                      subtitle: _search.isNotEmpty
                          ? 'No administrators match your search query.'
                          : 'Create an admin to get started with RBAC assignments.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            _buildAdminCard(filtered[i]),
                      ),
                    ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by email, phone, org unit, or role...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            onChanged: (val) => setState(() => _search = val),
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<bool?>(
          tooltip: 'Filter by Status',
          initialValue: _activeFilter,
          icon: Icon(
            Icons.filter_list_rounded,
            color: _activeFilter != null ? AppTheme.primary : null,
          ),
          onSelected: (val) {
            setState(() => _activeFilter = val);
            _load();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: null,
              child: Text('All Statuses'),
            ),
            PopupMenuItem(
              value: true,
              child: Text('Active Only'),
            ),
            PopupMenuItem(
              value: false,
              child: Text('Inactive Only'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminCard(AdminRecord admin) {
    final theme = Theme.of(context);
    final roles = admin.userRoles;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    (admin.email?.isNotEmpty == true
                            ? admin.email![0]
                            : 'A')
                        .toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
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
                              admin.email ?? 'No email',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusChip(admin.isActive),
                        ],
                      ),
                      if (admin.phone != null && admin.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          admin.phone!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: admin.isActive,
                  onChanged: (val) => _toggleStatus(admin, val),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.account_balance_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  admin.orgUnitName ?? 'Unassigned Org Unit',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (admin.branchType != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      admin.branchType!.replaceAll('_', ' '),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: roles.isEmpty
                      ? Text(
                          admin.role ?? 'Legacy Admin',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: roles.map((r) {
                            return Chip(
                              labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: -2),
                              label: Text(
                                r.roleDisplayName.isNotEmpty
                                    ? r.roleDisplayName
                                    : r.roleName,
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: r.isSuperAdmin
                                  ? AppTheme.accent.withValues(alpha: 0.15)
                                  : theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.4),
                              side: BorderSide.none,
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  admin.lastLoginAt != null
                      ? 'Last login: ${_formatDate(admin.lastLoginAt!)}'
                      : 'Never logged in',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text('View Detail'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    final res =
                        await context.push('/admin/admins/${admin.id}');
                    if (res == true) _load();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
