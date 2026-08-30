import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/features/modules/exotel_management/data/exotel_management_repository.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/presentation/widgets/ivr_audio_player.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/presentation/widgets/ivr_transcript_viewer.dart';

class InteractionDetailScreen extends StatefulWidget {
  final int interactionId;

  const InteractionDetailScreen({super.key, required this.interactionId});

  @override
  State<InteractionDetailScreen> createState() =>
      _InteractionDetailScreenState();
}

class _InteractionDetailScreenState extends State<InteractionDetailScreen> {
  final _repo = ExotelManagementRepository();
  ExotelInteractionRecord? _interaction;
  bool _loading = true;
  String? _error;
  bool _showRawJson = false;

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
      final record = await _repo.getInteractionDetail(widget.interactionId);
      if (mounted) {
        setState(() {
          _interaction = record;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListScreenShell(
      title: 'Exotel Interaction Details',
      subtitle: _interaction != null
          ? 'Call SID: ${_interaction!.callSid ?? _interaction!.interactionId}'
          : 'Loading interaction...',
      countLabel: 'Interaction Details',
      action: IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Refresh',
        onPressed: _load,
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
              : _interaction == null
                  ? const Center(child: Text('Interaction not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderCard(theme),
                              const SizedBox(height: 16),
                              if (_interaction!.audioUrl != null &&
                                  _interaction!.audioUrl!.isNotEmpty) ...[
                                IvrAudioPlayer(
                                  audioUrl: _interaction!.audioUrl!,
                                  title:
                                      'Exotel Voice Recording (${_interaction!.customerNumber ?? "Citizen"})',
                                ),
                                const SizedBox(height: 16),
                              ],
                              _buildTranscriptCard(theme),
                              const SizedBox(height: 16),
                              _buildRawPayloadCard(theme),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    final item = _interaction!;
    final isCompleted =
        item.status == 'completed' || item.status == 'success';

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.record_voice_over_rounded,
                    color: AppTheme.primary,
                    size: 24,
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
                            item.customerNumber ?? 'Unknown Customer',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildStatusBadge(isCompleted, item.status ?? 'Unknown'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bot: ${item.botName ?? "AI Bot"} (${item.botVersion ?? "v1"}) • ID: ${item.interactionId}',
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
                  child: _buildInfoItem(
                    theme,
                    'Started At',
                    item.startedAt != null
                        ? _formatDate(item.startedAt!)
                        : 'N/A',
                    Icons.schedule_rounded,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    theme,
                    'Duration',
                    item.durationSeconds != null
                        ? '${item.durationSeconds} seconds'
                        : 'N/A',
                    Icons.timer_outlined,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    theme,
                    'Call SID',
                    item.callSid ?? 'N/A',
                    Icons.tag_rounded,
                  ),
                ),
              ],
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

  Widget _buildInfoItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptCard(ThemeData theme) {
    final text = _interaction!.transcriptText;
    if (text == null || text.trim().isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No transcript text available for this interaction.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    return IvrTranscriptViewer(
      transcriptTamil: text,
      transcriptEnglish: null,
    );
  }

  Widget _buildRawPayloadCard(ThemeData theme) {
    final meta = _interaction!.metadata ?? _interaction!.transcriptJson;

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
                    Icon(Icons.data_object_rounded,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Exotel API Raw Payload',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: Icon(
                    _showRawJson
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(_showRawJson ? 'Hide' : 'View JSON'),
                  onPressed: () =>
                      setState(() => _showRawJson = !_showRawJson),
                ),
              ],
            ),
            if (_showRawJson && meta != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(meta),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
