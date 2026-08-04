import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/data/ivr_operations_repository.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/presentation/widgets/ivr_shared.dart';

/// Recorded citizen calls and what came of them.
///
/// This screen used to fabricate its rows from a loop counter while 140
/// transcribed calls sat in the database. The transcript is the point: a
/// resident describes a problem in Tamil, the system extracts it, and the row
/// shows whether that turned into a ticket.
class VoiceCallsScreen extends StatefulWidget {
  const VoiceCallsScreen({super.key});

  @override
  State<VoiceCallsScreen> createState() => _VoiceCallsScreenState();
}

class _VoiceCallsScreenState extends State<VoiceCallsScreen> {
  final _repo = IvrOperationsRepository();
  final _search = TextEditingController();

  List<VoiceCallRecord> _calls = const [];
  IvrSummary _summary = IvrSummary.empty;
  bool _loading = true;
  String? _error;
  String? _status;
  int? _expanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.voiceCalls(search: _search.text.trim(), status: _status),
        _repo.summary(),
      ]);
      if (!mounted) return;
      setState(() {
        _calls = results[0] as List<VoiceCallRecord>;
        _summary = results[1] as IvrSummary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _metrics(),
        _controls(),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _metrics() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          IvrMetric(
            label: 'TRANSCRIBED',
            value: '${_summary.transcribed}',
            icon: Icons.record_voice_over_rounded,
            caption: 'of ${_summary.totalCalls} calls',
          ),
          IvrMetric(
            label: 'RAISED A TICKET',
            value: '${_summary.complaintsRaised}',
            icon: Icons.assignment_turned_in_rounded,
            tone: MetricTone.good,
            caption: '${_summary.containmentPct}% of all calls',
          ),
          IvrMetric(
            label: 'AVG CONFIDENCE',
            value: _summary.avgConfidence == null
                ? '—'
                : _summary.avgConfidence!.toStringAsFixed(2),
            icon: Icons.graphic_eq_rounded,
            tone: (_summary.avgConfidence ?? 1) >= 0.8
                ? MetricTone.good
                : MetricTone.warn,
            caption: 'speech recognition',
          ),
          IvrMetric(
            label: 'FAILED PROCESSING',
            value: '${_summary.failedProcessing}',
            icon: Icons.error_outline_rounded,
            tone: _summary.failedProcessing == 0
                ? MetricTone.good
                : MetricTone.bad,
            caption: 'need a manual listen',
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    const statuses = ['completed', 'manual_review', 'failed'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search transcripts or call id…',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: AppTheme.bgCard,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide(color: AppTheme.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide(color: AppTheme.stroke),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          for (final s in statuses) ...[
            FilterChip(
              label: Text(prettyIvr(s), style: const TextStyle(fontSize: 11.5)),
              selected: _status == s,
              showCheckmark: false,
              onSelected: (on) {
                setState(() => _status = on ? s : null);
                _load();
              },
              backgroundColor: AppTheme.bgCard,
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(
                color: _status == s ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: AppTheme.stroke),
            ),
            const SizedBox(width: 6),
          ],
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_loading && _calls.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _calls.isEmpty) {
      return IvrErrorState(message: _error!, onRetry: _load);
    }
    if (_calls.isEmpty) {
      return const IvrEmptyState(
        icon: Icons.voicemail_rounded,
        title: 'No recorded calls match that',
        detail: 'Clear the filters, or wait for the next call to come in.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _calls.length,
        itemBuilder: (context, i) => _callCard(_calls[i]),
      ),
    );
  }

  Widget _callCard(VoiceCallRecord c) {
    final open = _expanded == c.id;
    final fmt = DateFormat('d MMM, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = open ? null : c.id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.call_rounded,
                          size: 17, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.callerNumber ?? c.callSid ?? 'Unknown caller',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (c.startedAt != null)
                                fmt.format(c.startedAt!.toLocal()),
                              if (c.attempt > 1) 'attempt ${c.attempt}',
                              if (c.confidence != null)
                                'confidence ${c.confidence!.toStringAsFixed(2)}',
                            ].join('  ·  '),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (c.raisedTicket)
                      IvrTag(
                        label: 'Ticket #${c.complaintId}',
                        color: AppTheme.accent,
                        icon: Icons.assignment_turned_in_rounded,
                      )
                    else
                      IvrTag(
                        label: 'No ticket',
                        color: AppTheme.textMuted,
                        icon: Icons.remove_circle_outline_rounded,
                      ),
                    const SizedBox(width: 8),
                    IvrTag(
                      label: prettyIvr(c.status),
                      color: c.status == 'completed'
                          ? AppTheme.accent
                          : c.status == 'failed'
                              ? AppTheme.error
                              : AppTheme.warning,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ),
                if (c.transcript != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    c.transcript!,
                    maxLines: open ? null : 2,
                    overflow: open ? null : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (open) ..._detail(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _detail(VoiceCallRecord c) {
    return [
      // The English rendering is what a non-Tamil-reading officer works from,
      // so it is shown alongside rather than instead of the original.
      if (c.transcriptEnglish != null &&
          c.transcriptEnglish != c.transcript) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ENGLISH',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                c.transcriptEnglish!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (c.complaintCategory != null)
            IvrTag(label: prettyIvr(c.complaintCategory!), color: AppTheme.primary),
          if (c.urgency != null)
            IvrTag(
              label: '${prettyIvr(c.urgency!)} urgency',
              color: c.urgency == 'critical' || c.urgency == 'high'
                  ? AppTheme.error
                  : AppTheme.warning,
            ),
          if (c.complaintStatus != null)
            IvrTag(
              label: 'Ticket ${prettyIvr(c.complaintStatus!)}',
              color: AppTheme.textSecondary,
            ),
          if (c.callSid != null)
            IvrTag(label: c.callSid!, color: AppTheme.textMuted),
        ],
      ),
      if (c.audioUrl != null) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.graphic_eq_rounded, size: 15, color: AppTheme.textMuted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                c.audioUrl!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ],
    ];
  }
}
