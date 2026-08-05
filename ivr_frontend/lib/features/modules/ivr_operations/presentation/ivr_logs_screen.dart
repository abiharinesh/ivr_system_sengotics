import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/data/ivr_operations_repository.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/presentation/widgets/ivr_shared.dart';

/// The IVR interaction log — what the caller pressed and where the flow ended.
///
/// Distinct from the voice-call list next to it: that one is about what was
/// said, this one about whether the menu worked. A call that reached the end
/// without producing a ticket is a flow problem, and it is the row an operator
/// needs to find.
class IvrLogsScreen extends StatefulWidget {
  const IvrLogsScreen({super.key, this.repository});

  /// Injected by tests. The screen builds its own against the live API when
  /// this is null, so nothing at the call sites has to know it exists.
  final IvrOperationsRepository? repository;

  @override
  State<IvrLogsScreen> createState() => _IvrLogsScreenState();
}

class _IvrLogsScreenState extends State<IvrLogsScreen> {
  late final _repo = widget.repository ?? IvrOperationsRepository();
  final _search = TextEditingController();

  List<IvrCallRecord> _rows = const [];
  IvrSummary _summary = IvrSummary.empty;
  bool _loading = true;
  String? _error;
  bool _problemsOnly = false;

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
        _repo.calls(search: _search.text.trim()),
        _repo.summary(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<IvrCallRecord>;
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

  List<IvrCallRecord> get _visible => _problemsOnly
      ? _rows.where((r) => r.hasError || !r.complaintCreated).toList()
      : _rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _metrics(),
        _controls(),
        Expanded(child: _table()),
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
            label: 'CALLS RECEIVED',
            value: '${_summary.totalCalls}',
            icon: Icons.phone_in_talk_rounded,
            caption: '${_summary.callsLast30Days} in the last 30 days',
          ),
          IvrMetric(
            label: 'CONTAINMENT',
            value: '${_summary.containmentPct}',
            icon: Icons.support_agent_rounded,
            tone: _summary.containmentPct >= 50
                ? MetricTone.good
                : MetricTone.warn,
            caption: 'handled without an agent',
          ),
          IvrMetric(
            label: 'TICKETS RAISED',
            value: '${_summary.complaintsRaised}',
            icon: Icons.assignment_rounded,
            tone: MetricTone.good,
            caption: 'straight from the call',
          ),
          IvrMetric(
            label: 'FLOW ERRORS',
            value: '${_summary.failedProcessing}',
            icon: Icons.warning_amber_rounded,
            tone: _summary.failedProcessing == 0
                ? MetricTone.good
                : MetricTone.bad,
            caption: 'a phase did not complete',
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return IvrControlBar(
      search: TextField(
        controller: _search,
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search by call id or caller number…',
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
      filters: [
          FilterChip(
            label: const Text('Needs a look', style: TextStyle(fontSize: 11.5)),
            selected: _problemsOnly,
            showCheckmark: false,
            avatar: Icon(
              Icons.report_problem_rounded,
              size: 14,
              color: _problemsOnly ? Colors.white : AppTheme.textMuted,
            ),
            onSelected: (v) => setState(() => _problemsOnly = v),
            backgroundColor: AppTheme.bgCard,
            selectedColor: AppTheme.warning,
            labelStyle: TextStyle(
              color: _problemsOnly ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(color: AppTheme.stroke),
          ),
          Text(
            '${_visible.length} of ${_rows.length}',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    );
  }

  Widget _table() {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows.isEmpty) {
      return IvrErrorState(message: _error!, onRetry: _load);
    }
    final rows = _visible;
    if (rows.isEmpty) {
      return IvrEmptyState(
        icon: Icons.receipt_long_rounded,
        title: _problemsOnly ? 'Nothing needs a look' : 'No calls logged yet',
        detail: _problemsOnly
            ? 'Every call reached the end of its flow.'
            : 'Calls appear here as the IVR handles them.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: rows.length + 1,
        itemBuilder: (context, i) =>
            i == 0 ? _header() : _row(rows[i - 1], i.isEven),
      ),
    );
  }

  Widget _header() {
    Widget cell(String label, int flex, {TextAlign? align}) => Expanded(
          flex: flex,
          child: Text(
            label,
            textAlign: align,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          cell('CALLER', 3),
          cell('WHEN', 3),
          cell('DURATION', 2),
          cell('PRESSED', 2),
          cell('OUTCOME', 3),
          cell('TICKET', 2, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _row(IvrCallRecord r, bool striped) {
    final fmt = DateFormat('d MMM, h:mm a');

    Widget cell(Widget child, int flex) => Expanded(flex: flex, child: child);
    Widget text(String? v, {FontWeight? weight, Color? color, TextAlign? align}) =>
        Text(
          v ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(
            fontSize: 12,
            fontWeight: weight ?? FontWeight.w400,
            color: color ?? AppTheme.textSecondary,
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: r.hasError
            ? AppTheme.error.withValues(alpha: 0.045)
            : striped
                ? AppTheme.bgCard
                : AppTheme.bgSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(9),
        border: r.hasError
            ? Border.all(color: AppTheme.error.withValues(alpha: 0.25))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              cell(
                text(r.callerNumber ?? r.callSid,
                    weight: FontWeight.w600, color: AppTheme.textPrimary),
                3,
              ),
              cell(
                text(r.startedAt == null
                    ? null
                    : fmt.format(r.startedAt!.toLocal())),
                3,
              ),
              cell(
                text(r.durationSeconds == null
                    ? null
                    : '${(r.durationSeconds! / 60).floor()}m ${r.durationSeconds! % 60}s'),
                2,
              ),
              cell(
                r.selections.isEmpty
                    ? text(null)
                    : Wrap(
                        spacing: 4,
                        children: [
                          for (final s in r.selections)
                            Container(
                              width: 19,
                              height: 19,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                2,
              ),
              cell(
                Align(
                  alignment: Alignment.centerLeft,
                  child: IvrTag(
                    label: prettyIvr(r.finalStatus ?? 'unknown'),
                    color: r.finalStatus == 'completed'
                        ? AppTheme.accent
                        : r.hasError
                            ? AppTheme.error
                            : AppTheme.textMuted,
                  ),
                ),
                3,
              ),
              cell(
                r.complaintCreated
                    ? text('#${r.complaintId ?? '—'}',
                        weight: FontWeight.w700,
                        color: AppTheme.accent,
                        align: TextAlign.right)
                    : text('—', align: TextAlign.right),
                2,
              ),
            ],
          ),
          if (r.hasError) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 13, color: AppTheme.error),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    r.lastError!,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
