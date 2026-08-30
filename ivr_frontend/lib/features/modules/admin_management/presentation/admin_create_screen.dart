import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/features/modules/admin_management/data/admin_management_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';

class AdminCreateScreen extends StatefulWidget {
  const AdminCreateScreen({super.key});

  @override
  State<AdminCreateScreen> createState() => _AdminCreateScreenState();
}

class _AdminCreateScreenState extends State<AdminCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = AdminManagementRepository();
  final _saRepo = SuperAdminRepository();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  List<PanchayatModel> _panchayats = [];
  List<RoleRecord> _roles = [];

  int? _selectedOrgUnitId;
  final Set<int> _selectedRoleIds = {};
  String _accessScope = 'own_org_unit';
  bool _isTemporary = false;
  DateTime? _validUntil;

  @override
  void initState() {
    super.initState();
    _loadDependencies();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _saRepo.listPanchayats(forceRefresh: true),
        _repo.listRoles(),
      ]);
      if (mounted) {
        setState(() {
          _panchayats = results[0] as List<PanchayatModel>;
          _roles = results[1] as List<RoleRecord>;
          if (_panchayats.isNotEmpty) {
            _selectedOrgUnitId = _panchayats.first.id;
          }
          if (_roles.isNotEmpty) {
            final defaultRole = _roles.firstWhere(
              (r) => r.name == 'panchayat_admin',
              orElse: () => _roles.first,
            );
            _selectedRoleIds.add(defaultRole.id);
          }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOrgUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Org Unit / Panchayat'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (_selectedRoleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one RBAC role'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repo.createAdmin(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        orgUnitId: _selectedOrgUnitId!,
        roleIds: _selectedRoleIds.toList(),
        accessScope: _accessScope,
        isTemporary: _isTemporary,
        validUntil: _validUntil?.toIso8601String(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Admin created successfully with RBAC roles!'),
            backgroundColor: AppTheme.accent,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create admin: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListScreenShell(
      title: 'Create Admin User',
      subtitle:
          'Provision a new administrative user with granular RBAC roles and organizational access scoping.',
      countLabel: 'New Admin',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: _submitting ? null : () => context.pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_submitting ? 'Creating...' : 'Create Admin'),
            onPressed: _submitting ? null : _submit,
          ),
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
                        onPressed: _loadDependencies,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAccountDetailsCard(theme),
                            const SizedBox(height: 16),
                            _buildOrgUnitCard(theme),
                            const SizedBox(height: 16),
                            _buildRolesCard(theme),
                            const SizedBox(height: 16),
                            _buildScopeAndValidityCard(theme),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: _submitting ? null : () => context.pop(),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  icon: _submitting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded, size: 18),
                                  label: Text(_submitting
                                      ? 'Creating...'
                                      : 'Create Admin Account'),
                                  onPressed: _submitting ? null : _submit,
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildAccountDetailsCard(ThemeData theme) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Account Credentials',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                hintText: 'admin.localbody@tn.gov.in',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password *',
                hintText: 'Minimum 8 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number (Optional)',
                hintText: '+919876543210',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgUnitCard(ThemeData theme) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_outlined,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Primary Org Unit / Jurisdiction',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedOrgUnitId,
              decoration: const InputDecoration(
                labelText: 'Select Panchayat / Municipality / Corporation *',
                prefixIcon: Icon(Icons.location_city_rounded, size: 20),
                border: OutlineInputBorder(),
              ),
              items: _panchayats.map((p) {
                return DropdownMenuItem<int>(
                  value: p.id,
                  child: Text('${p.name} (${p.branchType ?? "Local Body"})'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedOrgUnitId = val),
              validator: (v) => v == null ? 'Please select an org unit' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesCard(ThemeData theme) {
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
                      'RBAC Roles Assignment',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_selectedRoleIds.length} selected',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select one or more roles. The first selected role will be assigned as the primary role.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roles.map((role) {
                final isSelected = _selectedRoleIds.contains(role.id);
                return FilterChip(
                  label: Text(
                    role.displayName.isNotEmpty
                        ? role.displayName
                        : role.name,
                  ),
                  selected: isSelected,
                  selectedColor:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                  checkmarkColor: theme.colorScheme.primary,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedRoleIds.add(role.id);
                      } else {
                        _selectedRoleIds.remove(role.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeAndValidityCard(ThemeData theme) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Access Scope & Validity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _accessScope,
              decoration: const InputDecoration(
                labelText: 'Data Access Scope',
                prefixIcon: Icon(Icons.travel_explore_rounded, size: 20),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'own_org_unit',
                  child: Text('Own Org Unit Only (Standard)'),
                ),
                DropdownMenuItem(
                  value: 'child_org_units',
                  child: Text('Own + Child Org Units (Hierarchical)'),
                ),
                DropdownMenuItem(
                  value: 'all_org_units',
                  child: Text('All Org Units (Full Tenant Access)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _accessScope = val);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Temporary Access'),
              subtitle: const Text(
                'Set an automatic expiry date for this administrator account.',
              ),
              value: _isTemporary,
              onChanged: (val) => setState(() => _isTemporary = val),
            ),
            if (_isTemporary) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        _validUntil != null
                            ? 'Valid Until: ${_validUntil!.day}/${_validUntil!.month}/${_validUntil!.year}'
                            : 'Select Expiry Date',
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) {
                          setState(() => _validUntil = picked);
                        }
                      },
                    ),
                  ),
                  if (_validUntil != null)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _validUntil = null),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
