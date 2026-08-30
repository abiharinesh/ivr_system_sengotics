import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/empty_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/features/modules/exotel_management/data/exotel_management_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';

class PhoneAssignmentScreen extends StatefulWidget {
  const PhoneAssignmentScreen({super.key});

  @override
  State<PhoneAssignmentScreen> createState() => _PhoneAssignmentScreenState();
}

class _PhoneAssignmentScreenState extends State<PhoneAssignmentScreen> {
  final _repo = ExotelManagementRepository();
  final _saRepo = SuperAdminRepository();

  List<ExotelPhoneNumberRecord> _phones = [];
  List<PanchayatModel> _panchayats = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  String _search = '';

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
        _repo.listPhoneNumbers(),
        _saRepo.listPanchayats(forceRefresh: true),
      ]);
      if (mounted) {
        setState(() {
          _phones = results[0] as List<ExotelPhoneNumberRecord>;
          _panchayats = results[1] as List<PanchayatModel>;
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

  Future<void> _syncPhoneNumbers() async {
    setState(() => _syncing = true);
    try {
      final res = await _repo.syncPhoneNumbers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully synced ${res['synced'] ?? 0} virtual phone numbers from Exotel!',
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
            content: Text('Sync failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _showAssignDialog(ExotelPhoneNumberRecord phone) async {
    int? selectedOrgId = phone.assignedOrgId;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Assign ${phone.phoneNumber}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select the Panchayat or Local Body that will receive calls on this Exotel virtual line:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: selectedOrgId,
                  decoration: const InputDecoration(
                    labelText: 'Target Org Unit / Panchayat',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Unassigned (Return to Pool)'),
                    ),
                    ..._panchayats.map((p) => DropdownMenuItem<int?>(
                          value: p.id,
                          child: Text('${p.name} (${p.branchType ?? "Local Body"})'),
                        )),
                  ],
                  onChanged: (val) => setDlgState(() => selectedOrgId = val),
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
              onPressed: () async {
                try {
                  await _repo.assignPhoneNumber(phone.id, selectedOrgId);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error assigning phone number: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              },
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      _load();
    }
  }

  List<ExotelPhoneNumberRecord> get _filteredPhones {
    if (_search.trim().isEmpty) return _phones;
    final q = _search.toLowerCase();
    return _phones.where((p) {
      final phoneMatch = p.phoneNumber.toLowerCase().contains(q);
      final nameMatch = p.friendlyName?.toLowerCase().contains(q) ?? false;
      final orgMatch = p.assignedOrgName?.toLowerCase().contains(q) ?? false;
      return phoneMatch || nameMatch || orgMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredPhones;

    return ListScreenShell(
      title: 'Exotel Phone Number Inventory',
      subtitle:
          'Virtual phone numbers synced from your Exotel account and mapped to local bodies.',
      countLabel: '${filtered.length} numbers',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _syncing ? null : _load,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_download_rounded, size: 18),
            label: Text(_syncing ? 'Syncing...' : 'Sync from Exotel'),
            onPressed: _syncing ? null : _syncPhoneNumbers,
          ),
        ],
      ),
      filters: TextField(
        decoration: InputDecoration(
          hintText: 'Search phone numbers, friendly names, or org units...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
        ),
        onChanged: (val) => setState(() => _search = val),
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
              : filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.phone_disabled_outlined,
                      title: 'No Phone Numbers Found',
                      subtitle: _search.isNotEmpty
                          ? 'No numbers match your search.'
                          : 'Click "Sync from Exotel" to pull incoming virtual lines from your account.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            _buildPhoneCard(filtered[i], theme),
                      ),
                    ),
    );
  }

  Widget _buildPhoneCard(ExotelPhoneNumberRecord phone, ThemeData theme) {
    final isAssigned = phone.assignedOrgId != null;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isAssigned ? AppTheme.accent : AppTheme.primary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.call_rounded,
                color: isAssigned ? AppTheme.accent : AppTheme.primary,
                size: 22,
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
                        phone.phoneNumber,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(isAssigned),
                    ],
                  ),
                  if (phone.friendlyName != null &&
                      phone.friendlyName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone.friendlyName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.account_balance_rounded,
                          size: 14,
                          color: isAssigned
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        isAssigned
                            ? 'Assigned to: ${phone.assignedOrgName ?? "Org #${phone.assignedOrgId}"}'
                            : 'Not mapped to any local body',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isAssigned ? FontWeight.w600 : FontWeight.normal,
                          color: isAssigned
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: Icon(
                isAssigned ? Icons.edit_rounded : Icons.link_rounded,
                size: 16,
              ),
              label: Text(isAssigned ? 'Reassign' : 'Assign'),
              onPressed: () => _showAssignDialog(phone),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isAssigned) {
    final color = isAssigned ? AppTheme.accent : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isAssigned ? 'Assigned' : 'Available Pool',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
