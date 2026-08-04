import 'dart:math' as math;

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
class DashboardWidgetCard extends StatelessWidget {
  const DashboardWidgetCard({super.key, required this.data, this.onOpen});

  final DashboardWidgetData data;
  final void Function(String route)? onOpen;

  Color get _accent => switch (data.tone) {
        WidgetTone.good => AppTheme.accent,
        WidgetTone.warn => AppTheme.warning,
        WidgetTone.bad => AppTheme.error,
        WidgetTone.neutral => AppTheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final tappable = data.route != null && onOpen != null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: data.tone == WidgetTone.bad
              ? AppTheme.error.withValues(alpha: 0.3)
              : AppTheme.stroke,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tappable ? () => onOpen!(data.route!) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(tappable),
                const SizedBox(height: 10),
                Flexible(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool tappable) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_iconFor(data.dataSource), size: 15, color: _accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        if (tappable)
          Icon(Icons.arrow_outward_rounded, size: 14, color: AppTheme.textMuted),
      ],
    );
  }

  Widget _body() {
    if (data.hasError) return _errorBody();

    switch (data.widgetType) {
      case 'bar_chart':
        return _barChart();
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
        Icon(Icons.cloud_off_rounded, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            data.error!,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }

  // ── Counter / KPI ──────────────────────────────────────────────────────────

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
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _formattedValue,
                  style: TextStyle(
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: data.tone == WidgetTone.neutral
                        ? AppTheme.textPrimary
                        : _accent,
                  ),
                ),
              ),
            ),
            if (data.delta != null && data.delta != 0) ...[
              const SizedBox(width: 8),
              _deltaChip(data.delta!),
            ],
          ],
        ),
        if (data.caption != null) ...[
          const SizedBox(height: 6),
          Text(
            data.caption!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.3,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _kpi() {
    // A percentage-shaped figure gets a gauge; anything else is a big number
    // with the same treatment as a counter.
    final v = data.value;
    final isPct = v != null && v >= 0 && v <= 100 && data.code != 'citizen_satisfaction';
    if (!isPct) return _counter();

    return Row(
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: CustomPaint(
            painter: _GaugePainter(value: (v / 100).clamp(0, 1), color: _accent),
            child: Center(
              child: Text(
                '${v.round()}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            data.caption ?? '',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _deltaChip(int delta) {
    final up = delta > 0;
    // Rising is not automatically good — the server said which it is.
    final good = data.tone == WidgetTone.good;
    final color = good ? AppTheme.accent : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${delta.abs()}%',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bar chart ──────────────────────────────────────────────────────────────

  Widget _barChart() {
    if (data.series.isEmpty) return _noData();
    final max = data.series.map((s) => s.value).reduce(math.max);
    // A 30-day daily series is a trend; a handful of named categories is a
    // ranked list. They want different shapes.
    final dense = data.series.length > 12;

    if (dense) {
      return LayoutBuilder(
        builder: (context, c) => SizedBox(
          height: 120,
          child: CustomPaint(
            size: Size(c.maxWidth, 120),
            painter: _TrendPainter(
              values: data.series.map((s) => s.value).toList(),
              color: _accent,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in data.series.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(height: 8, color: AppTheme.bgSurface),
                          FractionallySizedBox(
                            widthFactor:
                                max == 0 ? 0 : (s.value / max).clamp(0.01, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _accent.withValues(alpha: 0.6),
                                    _accent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    child: Text(
                      NumberFormat.compact(locale: 'en_IN').format(s.value),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
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

  // ── Pie chart ──────────────────────────────────────────────────────────────

  static const _sliceColors = [
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF6366F1),
    Color(0xFFEC4899),
  ];

  Widget _pieChart() {
    if (data.series.isEmpty) return _noData();
    final total = data.series.fold<double>(0, (n, s) => n + s.value);
    if (total <= 0) return _noData();
    final shown = data.series.take(8).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _PiePainter(
              values: shown.map((s) => s.value).toList(),
              colors: _sliceColors,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _sliceColors[i % _sliceColors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          shown[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${((shown[i].value / total) * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11.5,
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
    final cols = data.columns.isNotEmpty
        ? data.columns
        : data.rows.first.keys.toList();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final c in cols)
                Expanded(
                  flex: c == cols.first ? 2 : 1,
                  child: Text(
                    c.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in data.rows.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  for (final c in cols)
                    Expanded(
                      flex: c == cols.first ? 2 : 1,
                      child: Text(
                        _cell(row[c]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
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
              color: AppTheme.bgSurface,
              child: CustomPaint(
                painter: _ScatterPainter(
                  points: data.points,
                  grid: AppTheme.stroke,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legendDot(AppTheme.error, 'Needs attention'),
            const SizedBox(width: 10),
            _legendDot(AppTheme.warning, 'Watch'),
            const SizedBox(width: 10),
            _legendDot(AppTheme.accent, 'OK'),
            const Spacer(),
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
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _noData() {
    return Row(
      children: [
        Icon(Icons.inbox_rounded, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          'Nothing recorded yet',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
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

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.12;
    final rect = Rect.fromLTWH(
      stroke / 2, stroke / 2, size.width - stroke, size.height - stroke,
    );
    canvas.drawArc(
      rect, -math.pi / 2, math.pi * 2, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppTheme.bgSurface,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect, -math.pi / 2, math.pi * 2 * value, false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.value != value || old.color != color;
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final stroke = size.width * 0.24;
    final rect = Rect.fromLTWH(
      stroke / 2, stroke / 2, size.width - stroke, size.height - stroke,
    );
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      canvas.drawArc(
        rect, start, sweep - 0.02, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => old.values != values;
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce(math.max);
    final span = maxV == 0 ? 1.0 : maxV;
    final dx = values.length <= 1 ? size.width : size.width / (values.length - 1);

    final grid = Paint()
      ..color = AppTheme.stroke
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(i * dx, size.height - (values[i] / span) * (size.height - 10) - 5),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final midX = (prev.dx + cur.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, cur.dy, cur.dx, cur.dy);
    }

    canvas.drawPath(
      Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.values != values;
}

/// Plots points in their own lat/lng space, with a margin so markers near the
/// edge are not clipped.
class _ScatterPainter extends CustomPainter {
  _ScatterPainter({required this.points, required this.grid});

  final List<MapPoint> points;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final x = size.width * (i / 5);
      final y = size.height * (i / 5);
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
    if ((maxLat - minLat).abs() < 0.001) { minLat -= 0.01; maxLat += 0.01; }
    if ((maxLng - minLng).abs() < 0.001) { minLng -= 0.01; maxLng += 0.01; }

    const margin = 14.0;
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
      canvas.drawCircle(Offset(x, y), 5.5, Paint()..color = c.withValues(alpha: 0.22));
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter old) => old.points != points;
}
