import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/empty_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/features/modules/exotel_management/data/exotel_management_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';

class BotAssignmentScreen extends StatefulWidget {
  const BotAssignmentScreen({super.key});

  @override
  State<BotAssignmentScreen> createState() => _BotAssignmentScreenState();
}

class _BotAssignmentScreenState extends State<BotAssignmentScreen> {
  final _repo = ExotelManagementRepository();
  final _saRepo = SuperAdminRepository();

  List<ExotelBotAssignmentRecord> _assignments = [];
  List<ExotelBotRecord> _bots = [];
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
        _repo.listAssignments(),
        _repo.listBots(),
        _repo.listPhoneNumbers(),
        _saRepo.listPanchayats(forceRefresh: true),
      ]);
      if (mounted) {
        setState(() {
          _assignments = results[0] as List<ExotelBotAssignmentRecord>;
          _bots = results[1] as List<ExotelBotRecord>;
          _phones = results[2] as List<ExotelPhoneNumberRecord>;
          _panchayats = results[3] as List<PanchayatModel>;
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

  Future<void> _syncBots() async {
    setState(() => _syncing = true);
    try {
      final res = await _repo.syncBots();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully synced ${res['synced'] ?? 0} AI bots from Exotel!',
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
            content: Text('Sync bots failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _showCreateAssignmentDialog() async {
    int? selectedBotId = _bots.isNotEmpty ? _bots.first.id : null;
    int? selectedPhoneId = _phones.isNotEmpty ? _phones.first.id : null;
    int? selectedOrgId = _panchayats.isNotEmpty ? _panchayats.first.id : null;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('New Bot + Phone Assignment'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Map an AI Voicebot and Virtual Phone Line to a Panchayat / Local Body:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selectedBotId,
                  decoration: const InputDecoration(
                    labelText: 'Select Exotel AI Bot *',
                    prefixIcon: Icon(Icons.smart_toy_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _bots.map((b) {
                    return DropdownMenuItem<int>(
                      value: b.id,
                      child: Text('${b.botName} (${b.botVersion ?? "v1"})'),
                    );
                  }).toList(),
                  onChanged: (val) => setDlgState(() => selectedBotId = val),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: selectedPhoneId,
                  decoration: const InputDecoration(
                    labelText: 'Select Virtual Phone Line *',
                    prefixIcon: Icon(Icons.call_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _phones.map((p) {
                    return DropdownMenuItem<int>(
                      value: p.id,
                      child: Text(
                        '${p.phoneNumber} ${p.friendlyName != null ? "(${p.friendlyName})" : ""}',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDlgState(() => selectedPhoneId = val),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: selectedOrgId,
                  decoration: const InputDecoration(
                    labelText: 'Select Panchayat / Local Body *',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _panchayats.map((p) {
                    return DropdownMenuItem<int>(
                      value: p.id,
                      child: Text('${p.name} (${p.branchType ?? "Local Body"})'),
                    );
                  }).toList(),
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
              onPressed: (selectedBotId == null ||
                      selectedPhoneId == null ||
                      selectedOrgId == null)
                  ? null
                  : () async {
                      try {
                        await _repo.createAssignment(
                          botId: selectedBotId!,
                          phoneNumberId: selectedPhoneId!,
                          orgUnitId: selectedOrgId!,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to assign bot: $e'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    },
              child: const Text('Assign Bot'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bot assigned to Panchayat successfully!'),
            backgroundColor: AppTheme.accent,
          ),
        );
        _load();
      }
    }
  }

  Future<void> _deleteAssignment(ExotelBotAssignmentRecord assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Bot Assignment?'),
        content: Text(
          'Are you sure you want to disconnect ${assignment.botName} from ${assignment.orgUnitName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deleteAssignment(assignment.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Assignment removed successfully'),
              backgroundColor: AppTheme.accent,
            ),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove assignment: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  List<ExotelBotAssignmentRecord> get _filteredAssignments {
    if (_search.trim().isEmpty) return _assignments;
    final q = _search.toLowerCase();
    return _assignments.where((a) {
      final botMatch = a.botName.toLowerCase().contains(q);
      final phoneMatch = a.phoneNumber.toLowerCase().contains(q);
      final orgMatch = a.orgUnitName.toLowerCase().contains(q);
      return botMatch || phoneMatch || orgMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredAssignments;

    return ListScreenShell(
      title: 'Exotel Bot Assignments',
      subtitle:
          'Map AI voicebots and phone numbers to local bodies so incoming IVR interactions are handled correctly.',
      countLabel: '${filtered.length} assignments',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _syncing ? null : _load,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, size: 16),
            label: const Text('Sync Bots'),
            onPressed: _syncing ? null : _syncBots,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.add_link_rounded, size: 18),
            label: const Text('Assign Bot'),
            onPressed: _showCreateAssignmentDialog,
          ),
        ],
      ),
      filters: TextField(
        decoration: InputDecoration(
          hintText: 'Search by bot name, phone number, or org unit...',
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
                      icon: Icons.smart_toy_outlined,
                      title: 'No Bot Assignments',
                      subtitle: _search.isNotEmpty
                          ? 'No assignments match your search query.'
                          : 'Click "Assign Bot" to map an Exotel AI bot and phone line to a Panchayat.',
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
                            _buildAssignmentCard(filtered[i], theme),
                      ),
                    ),
    );
  }

  Widget _buildAssignmentCard(
      ExotelBotAssignmentRecord item, ThemeData theme) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: AppTheme.accent,
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
                        item.botName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Active Assignment',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.call_rounded,
                          size: 14, color: theme.colorScheme.secondary),
                      const SizedBox(width: 4),
                      Text(
                        item.phoneNumber,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.account_balance_rounded,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        item.orgUnitName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.error, size: 20),
              tooltip: 'Disconnect Bot',
              onPressed: () => _deleteAssignment(item),
            ),
          ],
        ),
      ),
    );
  }
}
