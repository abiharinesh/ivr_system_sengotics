import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/dashboard/data/dashboard_models.dart';

/// Renders one panel of a role's dashboard.
///
/// The widget type comes from the database, so this switches on it rather than
/// being wired per screen. An unrecognised type falls through to the counter
/// rendering instead of throwing: the catalogue is editable from the super
/// admin console and can gain entries without a client release.
///
/// Charts are drawn with `fl_chart` rather than by hand. It was already a
/// dependency and unused, and a hand-rolled painter cannot give a government
/// officer a tooltip telling them which day the spike was.
class DashboardWidgetCard extends StatefulWidget {
  const DashboardWidgetCard({super.key, required this.data, this.onOpen});

  final DashboardWidgetData data;
  final void Function(String route)? onOpen;

  @override
  State<DashboardWidgetCard> createState() => _DashboardWidgetCardState();
}

class _DashboardWidgetCardState extends State<DashboardWidgetCard> {
  bool _hovered = false;

  DashboardWidgetData get data => widget.data;

  Color get _accent => switch (data.tone) {
        WidgetTone.good => AppTheme.accent,
        WidgetTone.warn => AppTheme.warning,
        WidgetTone.bad => AppTheme.error,
        WidgetTone.neutral => AppTheme.primary,
      };

  /// A palette for multi-series charts. Ordered so neighbouring slices stay
  /// distinguishable rather than shading into one another.
  static const _palette = [
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF6366F1),
    Color(0xFF84CC16),
  ];

  @override
  Widget build(BuildContext context) {
    final tappable = data.route != null && widget.onOpen != null;

    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppTheme.durationFast,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: data.tone == WidgetTone.bad
                ? AppTheme.error.withValues(alpha: 0.28)
                : _hovered
                    ? AppTheme.primary.withValues(alpha: 0.30)
                    : AppTheme.stroke,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ]
              : AppTheme.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: tappable ? () => widget.onOpen!(data.route!) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(tappable),
                  const SizedBox(height: 14),
                  Flexible(child: _body()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(bool tappable) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _accent.withValues(alpha: 0.16),
                _accent.withValues(alpha: 0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(_iconFor(data.dataSource), size: 19, color: _accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        if (tappable)
          AnimatedOpacity(
            duration: AppTheme.durationFast,
            opacity: _hovered ? 1 : 0.35,
            child: Icon(
              Icons.arrow_outward_rounded,
              size: 15,
              color: _hovered ? AppTheme.primary : AppTheme.textMuted,
            ),
          ),
      ],
    );
  }

  Widget _body() {
    if (data.hasError) return _errorBody();

    switch (data.widgetType) {
      case 'bar_chart':
        return data.series.length > 12 ? _trendChart() : _barChart();
      case 'pie_chart':
        return _pieChart();
      case 'table':
        return _table();
      case 'map':
        return _map();
      case 'kpi':
        return _kpi();
      case 'counter':
      default:
        return _counter();
    }
  }

  Widget _errorBody() {
    return Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 17, color: AppTheme.textMuted),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            data.error!,
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }

  // ── Counter ────────────────────────────────────────────────────────────────

  String get _formattedValue {
    final v = data.value;
    if (v == null) return '—';
    // Money and long counts read better grouped; a 3.4 average must not become
    // "3" and a percentage must not gain a comma.
    if (v is int || v == v.roundToDouble()) {
      return NumberFormat.decimalPattern('en_IN').format(v.round());
    }
    return v.toStringAsFixed(1);
  }

  Widget _counter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _formattedValue,
                  style: TextStyle(
                    fontSize: 32,
                    height: 1,
                    letterSpacing: -0.8,
                    fontWeight: FontWeight.w800,
                    color: data.tone == WidgetTone.neutral
                        ? AppTheme.textPrimary
                        : _accent,
                  ),
                ),
              ),
            ),
            if (data.delta != null && data.delta != 0) ...[
              const SizedBox(width: 9),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _deltaChip(data.delta!),
              ),
            ],
          ],
        ),
        if (data.caption != null) ...[
          const SizedBox(height: 8),
          Text(
            data.caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _deltaChip(int delta) {
    final up = delta > 0;
    // Rising is not automatically good — the server said which it is.
    final color = data.tone == WidgetTone.good ? AppTheme.accent : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${delta.abs()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI gauge ──────────────────────────────────────────────────────────────

  Widget _kpi() {
    final v = data.value;
    // A satisfaction score out of 5 is not a percentage; only gauge what is.
    final isPct =
        v != null && v >= 0 && v <= 100 && data.code != 'citizen_satisfaction';
    if (!isPct) return _counter();

    return Row(
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: (v / 100).clamp(0.0, 1.0)),
            builder: (context, t, _) => CustomPaint(
              painter: _GaugePainter(value: t, color: _accent),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(t * 100).round()}',
                      style: TextStyle(
                        fontSize: 21,
                        height: 1,
                        letterSpacing: -0.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            data.caption ?? '',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  // ── Bar chart ──────────────────────────────────────────────────────────────

  Widget _barChart() {
    if (data.series.isEmpty) return _noData();
    final series = data.series.take(8).toList();
    final max = series.map((s) => s.value).reduce(math.max);
    final safeMax = max <= 0 ? 1.0 : max;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: safeMax * 1.18,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: safeMax / 2,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.stroke, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= series.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      _shortLabel(series[i].label),
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.textPrimary,
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${series[group.x].label}\n',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: NumberFormat.decimalPattern('en_IN')
                        .format(rod.toY.round()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: series[i].value,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        _accent.withValues(alpha: 0.55),
                        _accent,
                      ],
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: safeMax * 1.18,
                      color: AppTheme.bgSurface,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Trend line ─────────────────────────────────────────────────────────────

  Widget _trendChart() {
    final series = data.series;
    if (series.isEmpty) return _noData();
    final max = series.map((s) => s.value).reduce(math.max);
    final safeMax = max <= 0 ? 1.0 : max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.value != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formattedValue,
                style: TextStyle(
                  fontSize: 24,
                  height: 1,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (data.delta != null && data.delta != 0) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _deltaChip(data.delta!),
                ),
              ],
              const Spacer(),
              if (data.caption != null)
                Flexible(
                  child: Text(
                    data.caption!,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Expanded(
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
                    final label = series[s.x.toInt()].label;
                    return LineTooltipItem(
                      '${_shortLabel(label)}\n',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: s.y.round().toString(),
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
                getTouchedSpotIndicator: (bar, indexes) => indexes
                    .map(
                      (_) => TouchedSpotIndicatorData(
                        FlLine(color: _accent.withValues(alpha: 0.4), strokeWidth: 1),
                        FlDotData(
                          getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                            radius: 4,
                            color: _accent,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < series.length; i++)
                      FlSpot(i.toDouble(), series[i].value),
                  ],
                  isCurved: true,
                  curveSmoothness: 0.28,
                  preventCurveOverShooting: true,
                  barWidth: 2.6,
                  isStrokeCapRound: true,
                  gradient: LinearGradient(
                    colors: [_accent.withValues(alpha: 0.75), _accent],
                  ),
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _accent.withValues(alpha: 0.26),
                        _accent.withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Pie ────────────────────────────────────────────────────────────────────

  Widget _pieChart() {
    if (data.series.isEmpty) return _noData();
    final total = data.series.fold<double>(0, (n, s) => n + s.value);
    if (total <= 0) return _noData();
    final shown = data.series.take(6).toList();

    return Row(
      children: [
        SizedBox(
          width: 108,
          height: 108,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              startDegreeOffset: -90,
              sections: [
                for (var i = 0; i < shown.length; i++)
                  PieChartSectionData(
                    value: shown[i].value,
                    color: _palette[i % _palette.length],
                    radius: 20,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shown[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${((shown[i].value / total) * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _table() {
    if (data.rows.isEmpty) return _noData();
    final cols =
        data.columns.isNotEmpty ? data.columns : data.rows.first.keys.toList();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final c in cols)
                  Expanded(
                    flex: c == cols.first ? 2 : 1,
                    child: Text(
                      c.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign:
                          c == cols.last && cols.length > 1 ? TextAlign.right : null,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < data.rows.take(8).length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              decoration: BoxDecoration(
                // Zebra striping rather than dividers: fewer lines, same
                // scannability on a dense panel.
                color: i.isEven ? AppTheme.bgSurface.withValues(alpha: 0.6) : null,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  for (final c in cols)
                    Expanded(
                      flex: c == cols.first ? 2 : 1,
                      child: Text(
                        _cell(data.rows[i][c]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: c == cols.last && cols.length > 1
                            ? TextAlign.right
                            : null,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: c == cols.first
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: c == cols.first
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
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

  /// Timestamps arrive as ISO strings; showing one raw in a table is unreadable.
  String _cell(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    final asDate = DateTime.tryParse(s);
    if (asDate != null && s.contains('T')) {
      return DateFormat('d MMM, h:mm a').format(asDate.toLocal());
    }
    return s;
  }

  // ── Map ────────────────────────────────────────────────────────────────────

  Widget _map() {
    if (data.points.isEmpty) return _noData();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.bgSurface,
                    AppTheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOut,
                tween: Tween(begin: 0, end: 1),
                builder: (context, t, _) => CustomPaint(
                  painter: _ScatterPainter(
                    points: data.points,
                    grid: AppTheme.stroke,
                    progress: t,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Wraps rather than a Row: three legend chips and a caption do not fit
        // across a single-column panel on a narrow window, and a legend that
        // overflows is worse than one that takes a second line.
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _legendDot(AppTheme.error, 'Needs attention'),
            _legendDot(AppTheme.warning, 'Watch'),
            _legendDot(AppTheme.accent, 'OK'),
            Text(
              data.caption ?? '${data.points.length} located',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 5),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _noData() {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.inbox_rounded, size: 15, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 10),
        Text(
          'Nothing recorded yet',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  /// Axis labels have to fit under a bar. `2026-08-04` becomes `4 Aug`, and a
  /// long category is truncated rather than overlapping its neighbour.
  static String _shortLabel(String raw) {
    final asDate = DateTime.tryParse(raw);
    if (asDate != null) return DateFormat('d MMM').format(asDate);
    return raw.length <= 9 ? raw : '${raw.substring(0, 8)}…';
  }

  static IconData _iconFor(String source) => switch (source) {
        'complaints' => Icons.report_problem_rounded,
        'property_tax' => Icons.currency_rupee_rounded,
        'trade_licences' => Icons.storefront_rounded,
        'building_permits' => Icons.home_work_rounded,
        'vital_events' => Icons.menu_book_rounded,
        'solid_waste' => Icons.delete_outline_rounded,
        'water_supply' => Icons.water_drop_rounded,
        'street_lights' => Icons.lightbulb_outline_rounded,
        'tenders' => Icons.gavel_rounded,
        'contractors' => Icons.engineering_rounded,
        'inspections' => Icons.checklist_rtl_rounded,
        'reports' => Icons.insights_rounded,
        _ => Icons.dashboard_rounded,
      };
}

// ── Painters ─────────────────────────────────────────────────────────────────

/// A ring gauge with a rounded, gradient sweep.
class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.115;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppTheme.bgSurface,
    );

    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [color.withValues(alpha: 0.5), color],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color;
}

/// Plots points in their own lat/lng space, with a margin so markers near the
/// edge are not clipped. Each marker gets a soft halo so a dense cluster reads
/// as density rather than as one blob.
class _ScatterPainter extends CustomPainter {
  _ScatterPainter({
    required this.points,
    required this.grid,
    this.progress = 1,
  });

  final List<MapPoint> points;
  final Color grid;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final x = size.width * (i / 6);
      final y = size.height * (i / 6);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    // Several points at the same spot would give a zero span.
    if ((maxLat - minLat).abs() < 0.001) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if ((maxLng - minLng).abs() < 0.001) {
      minLng -= 0.01;
      maxLng += 0.01;
    }

    const margin = 16.0;
    final w = size.width - margin * 2;
    final h = size.height - margin * 2;

    Color toneColor(WidgetTone t) => switch (t) {
          WidgetTone.bad => AppTheme.error,
          WidgetTone.warn => AppTheme.warning,
          WidgetTone.good => AppTheme.accent,
          WidgetTone.neutral => AppTheme.primary,
        };

    // Draw the calm ones first so problems sit on top rather than under.
    final ordered = [...points]..sort((a, b) => a.tone.index.compareTo(b.tone.index));
    for (final p in ordered) {
      final x = margin + ((p.lng - minLng) / (maxLng - minLng)) * w;
      final y = margin + (1 - (p.lat - minLat) / (maxLat - minLat)) * h;
      final c = toneColor(p.tone);
      final r = 3.2 * progress;
      canvas.drawCircle(
        Offset(x, y),
        r * 2.6,
        Paint()
          ..color = c.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(Offset(x, y), r, Paint()..color = c);
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter old) =>
      old.points != points || old.progress != progress;
}
