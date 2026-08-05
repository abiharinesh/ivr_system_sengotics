import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/modules/insights/data/service_analytics_repository.dart';

/// Service performance, computed from the complaint and SLA tables.
///
/// Serves both Insights tabs. They were two hardcoded screens — one asserting
/// "94% SLA Compliance", the other a fixed resolution time — sitting on top of
/// real data. [slaFocus] picks which half is emphasised; the underlying figures
/// are one query either way, so the two can never disagree.
class ServiceAnalyticsScreen extends StatefulWidget {
  const ServiceAnalyticsScreen({
    super.key,
    this.slaFocus = false,
    this.repository,
  });

  /// Injected by tests. The screen builds its own against the live API when
  /// this is null, so nothing at the call sites has to know it exists.
  final ServiceAnalyticsRepository? repository;

  /// True for the "SLA performance" tab, false for "Analytics".
  final bool slaFocus;

  @override
  State<ServiceAnalyticsScreen> createState() => _ServiceAnalyticsScreenState();
}

class _ServiceAnalyticsScreenState extends State<ServiceAnalyticsScreen> {
  late final _repo = widget.repository ?? ServiceAnalyticsRepository();

  ServiceAnalytics _data = ServiceAnalytics.empty;
  bool _loading = true;
  String? _error;
  int _days = 30;

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
      final d = await _repo.overview(days: _days);
      if (!mounted) return;
      setState(() {
        _data = d;
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
    if (_loading && _data.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data.isEmpty) return _errorState();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _windowPicker(),
          const SizedBox(height: 14),
          _metrics(),
          const SizedBox(height: 16),
          if (widget.slaFocus) ...[
            _slaBreakdown(),
            _slowestCategories(),
            _volumeTrend(),
          ] else ...[
            _volumeTrend(),
            _categoryMix(),
            _slaBreakdown(),
          ],
        ],
      ),
    );
  }

  Widget _windowPicker() {
    // A Wrap, not a Row: the heading, a three-segment picker and a button
    // overflowed by 246px at phone width. Below that the picker takes its own
    // line rather than running off the edge.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Text(
          widget.slaFocus ? 'SLA performance' : 'Service analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7d', style: TextStyle(fontSize: 11.5))),
            ButtonSegment(value: 30, label: Text('30d', style: TextStyle(fontSize: 11.5))),
            ButtonSegment(value: 90, label: Text('90d', style: TextStyle(fontSize: 11.5))),
          ],
          selected: {_days},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            setState(() => _days = s.first);
            _load();
          },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Reload',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ],
    );
  }

  // ── Metrics ────────────────────────────────────────────────────────────────

  Widget _metrics() {
    final d = _data;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _tile(
          'SLA COMPLIANCE',
          '${d.slaCompliancePct}%',
          Icons.speed_rounded,
          caption: '${d.slaBreached} breached of ${d.slaTracked} tracked',
          accent: d.slaCompliancePct >= 90
              ? AppTheme.accent
              : d.slaCompliancePct >= 70
                  ? AppTheme.warning
                  : AppTheme.error,
        ),
        _tile(
          'MEDIAN RESOLUTION',
          d.medianHours >= 48
              ? '${(d.medianHours / 24).toStringAsFixed(1)}d'
              : '${d.medianHours}h',
          Icons.timer_outlined,
          // The mean is shown beside it because the gap between the two is
          // itself the story: a long tail of stale tickets.
          caption: 'mean ${d.avgHours}h · p90 ${d.p90Hours}h',
          accent: d.medianHours <= 24
              ? AppTheme.accent
              : d.medianHours <= 72
                  ? AppTheme.warning
                  : AppTheme.error,
        ),
        _tile(
          'RESOLUTION RATE',
          '${d.resolutionRatePct}%',
          Icons.task_alt_rounded,
          caption: '${d.resolved} closed · ${d.open} still open',
          accent: d.resolutionRatePct >= 80 ? AppTheme.accent : AppTheme.warning,
        ),
        _tile(
          'SATISFACTION',
          d.satisfaction == null ? '—' : d.satisfaction!.toStringAsFixed(1),
          Icons.sentiment_satisfied_rounded,
          caption: 'out of 5, from ${d.satisfactionResponses} response(s)',
          accent: (d.satisfaction ?? 0) >= 4
              ? AppTheme.accent
              : (d.satisfaction ?? 0) >= 3
                  ? AppTheme.warning
                  : AppTheme.error,
        ),
      ],
    );
  }

  Widget _tile(
    String label,
    String value,
    IconData icon, {
    String? caption,
    Color? accent,
  }) {
    final c = accent ?? AppTheme.primary;
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.3)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: c),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              height: 1,
              letterSpacing: -0.6,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 5),
            Text(
              caption,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _volumeTrend() {
    final series = _data.dailyVolume;
    if (series.isEmpty) return const SizedBox.shrink();
    final max = series.map((s) => s.count).reduce(math.max).toDouble();
    final safeMax = max <= 0 ? 1.0 : max;

    return _section(
      title: 'Complaint volume',
      subtitle: 'What came in each day over the last ${_data.windowDays} days.',
      icon: Icons.show_chart_rounded,
      child: SizedBox(
        height: 190,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: safeMax * 1.25,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: safeMax / 2,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppTheme.stroke, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppTheme.textPrimary,
                tooltipRoundedRadius: 8,
                getTooltipItems: (spots) => spots.map((s) {
                  final date = DateTime.tryParse(series[s.x.toInt()].label);
                  return LineTooltipItem(
                    '${date == null ? series[s.x.toInt()].label : DateFormat('d MMM').format(date)}\n',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: '${s.y.round()} complaint(s)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < series.length; i++)
                    FlSpot(i.toDouble(), series[i].count.toDouble()),
                ],
                isCurved: true,
                curveSmoothness: 0.28,
                preventCurveOverShooting: true,
                barWidth: 2.6,
                isStrokeCapRound: true,
                color: AppTheme.primary,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.26),
                      AppTheme.primary.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryMix() {
    final cats = _data.byCategory.take(8).toList();
    if (cats.isEmpty) return const SizedBox.shrink();
    final max = cats.map((c) => c.count).reduce(math.max);

    return _section(
      title: 'What residents are reporting',
      subtitle: 'Complaints by category, all time.',
      icon: Icons.donut_large_rounded,
      child: Column(
        children: [
          for (final c in cats) _bar(_pretty(c.label), c.count, max, AppTheme.primary),
        ],
      ),
    );
  }

  Widget _slowestCategories() {
    final rows = _data.resolutionByCategory.take(8).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final max = rows.map((r) => r.medianHours).reduce(math.max);

    return _section(
      title: 'Slowest to resolve',
      subtitle: 'Median hours from report to resolution, by category. The '
          'median rather than the mean, so one stale ticket does not skew it.',
      icon: Icons.hourglass_bottom_rounded,
      child: Column(
        children: [
          for (final r in rows)
            _bar(
              _pretty(r.category),
              r.medianHours,
              max,
              r.medianHours > 72 ? AppTheme.error : AppTheme.warning,
              suffix: 'h',
              note: '${r.resolved} resolved',
            ),
        ],
      ),
    );
  }

  Widget _slaBreakdown() {
    final rows = _data.slaByStatus;
    if (rows.isEmpty) return const SizedBox.shrink();
    final total = rows.fold<int>(0, (n, r) => n + r.count);
    if (total == 0) return const SizedBox.shrink();

    Color colourFor(String s) => switch (s) {
          'breached' => AppTheme.error,
          'escalated' => AppTheme.warning,
          'warning' => AppTheme.warning,
          'resolved' => AppTheme.accent,
          _ => AppTheme.accent,
        };

    return _section(
      title: 'Where the clock stands',
      subtitle: 'Every tracked complaint against its SLA target.',
      icon: Icons.speed_rounded,
      child: Row(
        children: [
          SizedBox(
            width: 118,
            height: 118,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                startDegreeOffset: -90,
                sections: [
                  for (final r in rows)
                    PieChartSectionData(
                      value: r.count.toDouble(),
                      color: colourFor(r.label),
                      radius: 22,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: colourFor(r.label),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _pretty(r.label),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${r.count}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${((r.count / total) * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(
    String label,
    int value,
    int max,
    Color colour, {
    String suffix = '',
    String? note,
  }) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (note != null) ...[
                Text(
                  note,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(width: 9),
              ],
              Text(
                '$value$suffix',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              children: [
                Container(height: 9, color: AppTheme.bgSurface),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: ratio == 0 ? 0.004 : ratio),
                  builder: (context, t, _) => FractionallySizedBox(
                    widthFactor: t,
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colour.withValues(alpha: 0.6), colour],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              'Could not load analytics',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  static String _pretty(String raw) {
    if (raw.isEmpty) return raw;
    final s = raw.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }
}
