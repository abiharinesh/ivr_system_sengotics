import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_empty_state.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_models.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/rbac_grants.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/rbac_repository.dart';

/// Which grant list the detail pane is showing.
enum _GrantKind { screens, permissions }

/// Pick a role, then set what it can see and what it can do.
///
/// Screens and permissions are edited as whole sets and saved with one PUT
/// each, matching the API. Nothing is written until Save: the tick boxes edit
/// a [GrantSelection] that knows what changed, so an operator can look at the
/// consequences before committing them.
class RoleAccessPane extends StatefulWidget {
  const RoleAccessPane({super.key, this.onChanged});

  /// Fired after any successful write, so the shell can refresh its counters.
  final VoidCallback? onChanged;

  @override
  State<RoleAccessPane> createState() => _RoleAccessPaneState();
}

class _RoleAccessPaneState extends State<RoleAccessPane> {
  final _repo = RbacRepository();

  bool _loading = true;
  String? _error;

  List<RoleSummary> _roles = const [];
  ScreenCatalogue _screens = ScreenCatalogue.empty;
  List<PermissionModule> _permissions = const [];

  RoleSummary? _selected;
  RoleDetail? _detail;
  bool _detailLoading = false;

  GrantSelection _screenGrants = GrantSelection.empty;
  GrantSelection _permGrants = GrantSelection.empty;

  _GrantKind _kind = _GrantKind.screens;
  bool _saving = false;

  String _roleQuery = '';
  String _grantQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _msg(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.listRoles(forceRefresh: true),
        _repo.listScreens(),
        _repo.listPermissions(),
      ]);
      if (!mounted) return;
      setState(() {
        _roles = results[0] as List<RoleSummary>;
        _screens = results[1] as ScreenCatalogue;
        _permissions = results[2] as List<PermissionModule>;
        _loading = false;
      });

      final keep = _selected;
      if (keep != null) {
        final still = _roles.where((r) => r.id == keep.id);
        if (still.isNotEmpty) {
          await _selectRole(still.first);
          return;
        }
      }
      if (_roles.isNotEmpty) await _selectRole(_roles.first);
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
      _selected = role;
      _detailLoading = true;
      _grantQuery = '';
    });
    try {
      final detail = await _repo.getRole(role.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _screenGrants = GrantSelection.from(detail.screenKeys);
        _permGrants = GrantSelection.from(detail.permissionCodes);
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailLoading = false);
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

  GrantSelection get _active =>
      _kind == _GrantKind.screens ? _screenGrants : _permGrants;

  void _setActive(GrantSelection next) {
    setState(() {
      if (_kind == _GrantKind.screens) {
        _screenGrants = next;
      } else {
        _permGrants = next;
      }
    });
  }

  Future<void> _save() async {
    final role = _selected;
    if (role == null || _saving) return;

    setState(() => _saving = true);
    try {
      final updated = _kind == _GrantKind.screens
          ? await _repo.setRoleScreens(role.id, _screenGrants.payload)
          : await _repo.setRolePermissions(role.id, _permGrants.payload);

      if (!mounted) return;
      setState(() {
        _detail = updated;
        _screenGrants = GrantSelection.from(updated.screenKeys);
        _permGrants = GrantSelection.from(updated.permissionCodes);
        _saving = false;
      });
      _toast(_kind == _GrantKind.screens
          ? 'Screens updated. Holders of this role see the change at their next sign-in.'
          : 'Permissions updated.');
      widget.onChanged?.call();
      await _refreshRoleCounts();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(_msg(e), isError: true);
    }
  }

  /// Re-read the list so the per-role counters match what was just saved,
  /// without disturbing the detail pane the operator is looking at.
  Future<void> _refreshRoleCounts() async {
    try {
      final roles = await _repo.listRoles(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _roles = roles;
        final match = roles.where((r) => r.id == _selected?.id);
        if (match.isNotEmpty) _selected = match.first;
      });
    } catch (_) {
      // A stale counter is not worth interrupting the operator over; the next
      // full load corrects it.
    }
  }

  Future<void> _clone() async {
    final role = _selected;
    if (role == null) return;

    final controller = TextEditingController(text: role.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clone "${role.displayName}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shared system roles are used by every council on the platform, '
              'so they cannot be edited directly. Cloning copies this role and '
              'its current grants into your tenant, where you can change it.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Role name',
                helperText: 'Lowercase identifier, e.g. municipal_engineer',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Clone'),
          ),
        ],
      ),
    );
    if (name == null) return;

    setState(() => _saving = true);
    try {
      final clone = await _repo.cloneRole(role.id, name: name);
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Cloned to "${clone.role.displayName}". Editing the copy.');
      widget.onChanged?.call();
      await _load();
      if (!mounted) return;
      final made = _roles.where((r) => r.id == clone.role.id);
      if (made.isNotEmpty) await _selectRole(made.first);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(_msg(e), isError: true);
    }
  }

  Future<void> _setActiveState(bool isActive) async {
    final role = _selected;
    if (role == null) return;

    final blocked = disableBlockedReason(role);
    if (!isActive && blocked != null) {
      _toast(blocked, isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.setRoleActive(role.id, isActive);
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(isActive ? 'Role enabled.' : 'Role disabled.');
      widget.onChanged?.call();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(_msg(e), isError: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingState(message: 'Loading roles and catalogue...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_roles.isEmpty) {
      return const AppEmptyState(
        icon: Icons.admin_panel_settings_rounded,
        title: 'No roles yet',
        subtitle:
            'Run the RBAC seed to populate the role and screen catalogue.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 320, child: _buildRoleList()),
              VerticalDivider(width: 1, color: AppTheme.stroke),
              Expanded(child: _buildDetail()),
            ],
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildRoleDropdown(),
            ),
            Expanded(child: _buildDetail()),
          ],
        );
      },
    );
  }

  List<RoleSummary> get _visibleRoles =>
      filterRoles(_roles, query: _roleQuery);

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selected?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Role',
        border: OutlineInputBorder(),
      ),
      items: _roles
          .map((r) => DropdownMenuItem(
                value: r.id,
                child: Text(
                  r.isEditable ? r.displayName : '${r.displayName} (system)',
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (id) {
        if (id == null) return;
        final match = _roles.where((r) => r.id == id);
        if (match.isNotEmpty) _selectRole(match.first);
      },
    );
  }

  Widget _buildRoleList() {
    final roles = _visibleRoles;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search roles',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (v) => setState(() => _roleQuery = v),
          ),
        ),
        Expanded(
          child: roles.isEmpty
              ? Center(
                  child: Text(
                    'No roles match "$_roleQuery"',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                )
              : ListView.builder(
                  itemCount: roles.length,
                  itemBuilder: (context, i) => _roleTile(roles[i]),
                ),
        ),
      ],
    );
  }

  Widget _roleTile(RoleSummary role) {
    final isSelected = role.id == _selected?.id;
    return Material(
      color: isSelected
          ? AppTheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: () => _selectRole(role),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(color: AppTheme.stroke, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      role.displayName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: role.isActive
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!role.isEditable)
                    Tooltip(
                      message: 'Shared system role — clone to edit',
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                [
                  if (role.department != null && role.department!.isNotEmpty)
                    role.department!,
                  '${role.screenCount} screens',
                  '${role.permissionCount} perms',
                  '${role.userCount} users',
                ].join(' · '),
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail() {
    final role = _selected;
    if (role == null) {
      return const AppEmptyState(
        icon: Icons.touch_app_rounded,
        title: 'Pick a role',
        subtitle: 'Choose a role on the left to see and change its access.',
      );
    }
    if (_detailLoading || _detail == null) {
      return const AppLoadingState(message: 'Loading role...', compact: true);
    }

    return Column(
      children: [
        _buildDetailHeader(role),
        if (!role.isEditable) _buildSystemRoleBanner(role),
        Expanded(child: _buildGrantList(role)),
        if (_active.isDirty && role.isEditable) _buildSaveBar(),
      ],
    );
  }

  Widget _buildDetailHeader(RoleSummary role) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.stroke)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.displayName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.displayNameTa?.isNotEmpty == true
                          ? '${role.name} · ${role.displayNameTa}'
                          : role.name,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (role.isEditable)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      role.isActive ? 'Enabled' : 'Disabled',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Switch(
                      value: role.isActive,
                      onChanged: _saving ? null : _setActiveState,
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _saving ? null : _clone,
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Clone to edit'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (role.isSuperAdmin)
                _badge('Platform super admin', AppTheme.error),
              if (role.canApprove) _badge('Can approve', AppTheme.info),
              if (role.isSystem) _badge('System', AppTheme.textMuted),
              _badge('Level ${role.hierarchyLevel}', AppTheme.textMuted),
              if (role.applicableBranchTypes.isEmpty)
                _badge('All body types', AppTheme.textMuted)
              else
                ...role.applicableBranchTypes.map(
                  (t) => _badge(
                    t.toLowerCase().replaceAll('_', ' '),
                    AppTheme.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SegmentedButton<_GrantKind>(
                segments: [
                  ButtonSegment(
                    value: _GrantKind.screens,
                    label: Text('Screens (${_screenGrants.selected.length})'),
                    icon: const Icon(Icons.view_sidebar_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: _GrantKind.permissions,
                    label: Text('Permissions (${_permGrants.selected.length})'),
                    icon: const Icon(Icons.key_rounded, size: 16),
                  ),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _grantQuery = '';
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: ValueKey('grant-search-${role.id}-$_kind'),
                  decoration: InputDecoration(
                    hintText: _kind == _GrantKind.screens
                        ? 'Search screens'
                        : 'Search permissions',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => setState(() => _grantQuery = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSystemRoleBanner(RoleSummary role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppTheme.info.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Read-only. This role is shared with every council on the '
              'platform — clone it to make changes that apply only to yours.',
              style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrantList(RoleSummary role) {
    return _kind == _GrantKind.screens
        ? _buildScreenList(role)
        : _buildPermissionList(role);
  }

  Widget _buildScreenList(RoleSummary role) {
    final groups = filterScreenGroups(_screens.groups, _grantQuery);
    if (groups.isEmpty) {
      return Center(
        child: Text(
          'No screens match "$_grantQuery"',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final group = groups[i];
        // Group-level ticking only offers what this role is allowed to hold,
        // so "select all" can never compose a payload the server will reject.
        final grantable =
            group.items.where((s) => screenGrantableTo(s, role)).toList();
        final keys = grantable.map((s) => s.key).toList();
        final onCount = keys.where(_screenGrants.contains).length;

        return _grantGroup(
          title: group.groupKey,
          subtitle: '$onCount of ${group.items.length} granted',
          allOn: keys.isNotEmpty && onCount == keys.length,
          someOn: onCount > 0 && onCount < keys.length,
          enabled: role.isEditable && keys.isNotEmpty,
          onToggleAll: (on) =>
              _setActive(_screenGrants.setAll(keys, on)),
          children: group.items.map((s) {
            final allowed = screenGrantableTo(s, role);
            return CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _screenGrants.contains(s.key),
              onChanged: role.isEditable && allowed
                  ? (v) => _setActive(_screenGrants.toggle(s.key, v ?? false))
                  : null,
              title: Text(
                s.labelEn,
                style: const TextStyle(fontSize: 13.5),
              ),
              subtitle: Text(
                allowed
                    ? '${s.route}  ·  ${s.module}'
                    : '${s.route}  ·  platform-only, not grantable to this role',
                style: TextStyle(
                  fontSize: 11,
                  color: allowed ? AppTheme.textMuted : AppTheme.warning,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPermissionList(RoleSummary role) {
    final modules = filterPermissionModules(_permissions, _grantQuery);
    if (modules.isEmpty) {
      return Center(
        child: Text(
          'No permissions match "$_grantQuery"',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: modules.length,
      itemBuilder: (context, i) {
        final module = modules[i];
        final codes = module.items.map((p) => p.code).toList();
        final onCount = codes.where(_permGrants.contains).length;

        return _grantGroup(
          title: module.module,
          subtitle: '$onCount of ${codes.length} granted',
          allOn: onCount == codes.length && codes.isNotEmpty,
          someOn: onCount > 0 && onCount < codes.length,
          enabled: role.isEditable,
          onToggleAll: (on) => _setActive(_permGrants.setAll(codes, on)),
          children: module.items.map((p) {
            return CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _permGrants.contains(p.code),
              onChanged: role.isEditable
                  ? (v) => _setActive(_permGrants.toggle(p.code, v ?? false))
                  : null,
              title: Text(p.code, style: const TextStyle(fontSize: 13.5)),
              subtitle: p.description == null || p.description!.isEmpty
                  ? null
                  : Text(
                      p.description!,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _grantGroup({
    required String title,
    required String subtitle,
    required bool allOn,
    required bool someOn,
    required bool enabled,
    required ValueChanged<bool> onToggleAll,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Row(
          children: [
            Checkbox(
              tristate: true,
              value: allOn ? true : (someOn ? null : false),
              onChanged: enabled ? (v) => onToggleAll(v ?? false) : null,
            ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.only(left: 12, right: 8),
        children: children,
      ),
    );
  }

  Widget _buildSaveBar() {
    final sel = _active;
    final what = _kind == _GrantKind.screens ? 'screen' : 'permission';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.stroke)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, size: 20, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${sel.changeCount} unsaved $what change'
              '${sel.changeCount == 1 ? '' : 's'}'
              '  ·  +${sel.added.length} granted, −${sel.removed.length} revoked',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : () => _setActive(sel.reset()),
            child: const Text('Discard'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
