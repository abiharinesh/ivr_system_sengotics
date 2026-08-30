import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/empty_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/core/widgets/sa_kpi_card.dart';
import 'package:ivr_frontend/features/modules/exotel_management/data/exotel_management_repository.dart';

class ExotelDashboardScreen extends StatefulWidget {
  const ExotelDashboardScreen({super.key});

  @override
  State<ExotelDashboardScreen> createState() => _ExotelDashboardScreenState();
}

class _ExotelDashboardScreenState extends State<ExotelDashboardScreen> {
  final _repo = ExotelManagementRepository();
  ExotelDashboardStats _stats = const ExotelDashboardStats();
  List<ExotelInteractionRecord> _interactions = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  String _searchPhone = '';
  String? _statusFilter;

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
        _repo.getDashboardStats(),
        _repo.listInteractions(
          phone: _searchPhone.trim().isNotEmpty ? _searchPhone.trim() : null,
          status: _statusFilter,
          take: 50,
        ),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0] as ExotelDashboardStats;
          _interactions = results[1] as List<ExotelInteractionRecord>;
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

  Future<void> _triggerSync(String type) async {
    setState(() => _syncing = true);
    try {
      if (type == 'phones') {
        final res = await _repo.syncPhoneNumbers();
        _showSuccess('Phone numbers synced: ${res['synced'] ?? 0} numbers');
      } else if (type == 'bots') {
        final res = await _repo.syncBots();
        _showSuccess('Bots synced: ${res['synced'] ?? 0} bots');
      } else if (type == 'interactions') {
        final res = await _repo.syncInteractions();
        _showSuccess(
            'Interactions synced: ${res['synced'] ?? 0} new, ${res['skipped'] ?? 0} skipped');
      }
      _load();
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

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListScreenShell(
      title: 'Exotel Voicebot & Interaction Hub',
      subtitle:
          'Monitor real-time voicebot conversations, sync transcripts & recordings, and manage phone assignments.',
      countLabel: '${_interactions.length} interactions',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _syncing ? null : _load,
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Sync Data from Exotel API',
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            onSelected: (action) => _triggerSync(action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'interactions',
                child: ListTile(
                  leading: Icon(Icons.history_rounded, size: 20),
                  title: Text('Sync Interaction History'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'phones',
                child: ListTile(
                  leading: Icon(Icons.phone_in_talk_rounded, size: 20),
                  title: Text('Sync Phone Numbers'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'bots',
                child: ListTile(
                  leading: Icon(Icons.smart_toy_outlined, size: 20),
                  title: Text('Sync Voicebots'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.phone_forwarded_rounded, size: 16),
            label: const Text('Phone Numbers'),
            onPressed: () => context.push('/admin/exotel/phones'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.assignment_ind_rounded, size: 16),
            label: const Text('Bot Assignments'),
            onPressed: () => context.push('/admin/exotel/bots'),
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
                      Text('Error: $_error',
                          style: const TextStyle(color: AppTheme.error)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKpiGrid(theme),
                        const SizedBox(height: 24),
                        _buildInteractionsSection(theme),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildKpiGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : (constraints.maxWidth > 550 ? 2 : 1);
        final itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: SAKpiCard(
                title: 'Total Interactions',
                value: '${_stats.totalInteractions}',
                icon: Icons.record_voice_over_rounded,
                iconColor: AppTheme.primary,
                iconBg: AppTheme.primary.withValues(alpha: 0.1),
                trendWidget: Text(
                  '${_stats.interactionsLast30Days} in last 30 days',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: SAKpiCard(
                title: 'Active Phone Numbers',
                value: '${_stats.activePhoneNumbers}',
                icon: Icons.call_rounded,
                iconColor: AppTheme.accent,
                iconBg: AppTheme.accent.withValues(alpha: 0.1),
                trendWidget: Text(
                  'Virtual IVR lines',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: SAKpiCard(
                title: 'Active AI Voicebots',
                value: '${_stats.activeBots}',
                icon: Icons.smart_toy_rounded,
                iconColor: AppTheme.accent,
                iconBg: AppTheme.accent.withValues(alpha: 0.1),
                trendWidget: Text(
                  'Exotel Voicebot AI',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: SAKpiCard(
                title: 'Org Unit Assignments',
                value: '${_stats.activeAssignments}',
                icon: Icons.hub_rounded,
                iconColor: theme.colorScheme.secondary,
                iconBg: theme.colorScheme.secondary.withValues(alpha: 0.1),
                trendWidget: Text(
                  'Panchayat mappings',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInteractionsSection(ThemeData theme) {
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
                    Icon(Icons.history_rounded,
                        color: theme.colorScheme.primary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Synced Interaction History (${_interactions.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cloud_download_outlined, size: 16),
                  label: const Text('Pull Latest from Exotel'),
                  onPressed: _syncing ? null : () => _triggerSync('interactions'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Filter by caller phone number...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      _searchPhone = val;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String?>(
                  value: _statusFilter,
                  hint: const Text('All Statuses'),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All Statuses'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'failed',
                      child: Text('Failed'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _statusFilter = val);
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_interactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: EmptyState(
                  icon: Icons.phone_disabled_rounded,
                  title: 'No Interactions Found',
                  subtitle:
                      'Click "Pull Latest from Exotel" to sync interaction logs, recordings, and transcripts.',
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _interactions.length,
                separatorBuilder: (_, __) => const Divider(height: 20),
                itemBuilder: (context, i) =>
                    _buildInteractionItem(_interactions[i], theme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionItem(
      ExotelInteractionRecord item, ThemeData theme) {
    final hasAudio = item.audioUrl != null && item.audioUrl!.isNotEmpty;
    final isCompleted =
        item.status == 'completed' || item.status == 'success';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/admin/exotel/interactions/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (hasAudio ? AppTheme.accent : AppTheme.primary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasAudio
                    ? Icons.audiotrack_rounded
                    : Icons.chat_bubble_outline_rounded,
                color: hasAudio ? AppTheme.accent : AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.customerNumber ?? 'Unknown Caller',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(isCompleted, item.status ?? 'Unknown'),
                      if (hasAudio) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic_rounded,
                                  size: 11, color: AppTheme.accent),
                              const SizedBox(width: 3),
                              Text(
                                'Audio',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.botName != null) ...[
                        Icon(Icons.smart_toy_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${item.botName} (${item.botVersion ?? "v1"}) • ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (item.durationSeconds != null) ...[
                        Icon(Icons.timer_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${item.durationSeconds}s • ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      Text(
                        item.startedAt != null
                            ? _formatDate(item.startedAt!)
                            : 'Unknown Time',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (item.transcriptText != null &&
                      item.transcriptText!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.transcriptText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onPressed: () =>
                  context.push('/admin/exotel/interactions/${item.id}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isCompleted, String label) {
    final color = isCompleted ? AppTheme.accent : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
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
