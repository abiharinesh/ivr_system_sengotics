import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

/// Presentation primitives shared by the console's insight views.
///
/// These are deliberately hand-painted rather than pulled from a charting
/// package: an access-coverage heatmap and a district deployment map are not
/// shapes a generic chart library draws, and mixing two rendering styles in one
/// screen reads as two screens stitched together.

/// A section heading with an optional explanation of what the reader is
/// looking at. Access analytics are only useful if the reader knows what the
/// numbers mean, so the subtitle is not decoration.
class InsightSection extends StatelessWidget {
  const InsightSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
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
                ],
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
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
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
}

/// A headline figure. [emphasis] pulls the eye to numbers that mean something
/// is wrong rather than to the largest number on screen.
class InsightMetric extends StatelessWidget {
  const InsightMetric({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    this.icon,
    this.caption,
    this.emphasis = MetricEmphasis.neutral,
    this.onTap,
  });

  final String label;
  final String value;
  final String? suffix;
  final String? caption;
  final IconData? icon;
  final MetricEmphasis emphasis;
  final VoidCallback? onTap;

  Color get _accent {
    switch (emphasis) {
      case MetricEmphasis.good:
        return AppTheme.accent;
      case MetricEmphasis.warn:
        return AppTheme.warning;
      case MetricEmphasis.bad:
        return AppTheme.error;
      case MetricEmphasis.neutral:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: emphasis == MetricEmphasis.neutral
                ? AppTheme.stroke
                : accent.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: accent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: emphasis == MetricEmphasis.neutral
                        ? AppTheme.textPrimary
                        : accent,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    suffix!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: 5),
              Text(
                caption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum MetricEmphasis { neutral, good, warn, bad }

/// A ring showing one proportion, with the figure in the middle.
class ProportionRing extends StatelessWidget {
  const ProportionRing({
    super.key,
    required this.value,
    required this.label,
    this.size = 132,
    this.color,
    this.caption,
  });

  /// 0…1.
  final double value;
  final String label;
  final String? caption;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(value: value.clamp(0, 1), color: c),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: size * 0.21,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.10;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.bgSurface;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);

    if (value <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.55), color],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.color != color;
}

/// A horizontal bar in a ranked list — used for module and action breakdowns
/// where the label matters as much as the magnitude.
class RankedBar extends StatelessWidget {
  const RankedBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.secondaryLabel,
    this.color,
    this.onTap,
  });

  final String label;
  final String? secondaryLabel;
  final int value;
  final int max;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
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
                if (secondaryLabel != null) ...[
                  Text(
                    secondaryLabel!,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '$value',
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
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 7, color: AppTheme.bgSurface),
                  FractionallySizedBox(
                    widthFactor: ratio == 0 ? 0.004 : ratio,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.withValues(alpha: 0.65), c],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sparkline of daily counts. Reads as "is anything changing", which is the
/// only question a 30-day audit series answers at a glance.
class ActivitySparkline extends StatelessWidget {
  const ActivitySparkline({
    super.key,
    required this.values,
    this.height = 90,
    this.color,
  });

  final List<int> values;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No access changes recorded yet.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color ?? AppTheme.primary,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce(math.max);
    final span = maxV == 0 ? 1 : maxV;
    final dx = values.length <= 1 ? size.width : size.width / (values.length - 1);

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(i * dx, size.height - (values[i] / span) * (size.height - 8) - 4),
    ];

    // Baseline grid — three lines is enough to read magnitude without clutter.
    final grid = Paint()
      ..color = AppTheme.stroke
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final midX = (prev.dx + cur.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, cur.dy, cur.dx, cur.dy);
    }

    final fill = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.01)],
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

    // Mark the most recent point so "today" is locatable.
    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
    canvas.drawCircle(
      points.last,
      3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppTheme.bgCard,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}

/// The shared colour ramp for coverage: red at none, amber part-way, green at
/// full. Used by both the matrix heatmap and the geography view so the same
/// colour means the same thing in both.
Color coverageColor(double ratio) {
  final r = ratio.clamp(0.0, 1.0);
  if (r <= 0) return AppTheme.bgSurface;
  if (r < 0.34) {
    return Color.lerp(const Color(0xFFFCA5A5), AppTheme.warning, r / 0.34)!;
  }
  if (r < 0.7) {
    return Color.lerp(AppTheme.warning, const Color(0xFF34D399), (r - 0.34) / 0.36)!;
  }
  return Color.lerp(const Color(0xFF34D399), AppTheme.accent, (r - 0.7) / 0.3)!;
}

/// Legend for [coverageColor].
class CoverageLegend extends StatelessWidget {
  const CoverageLegend({super.key, this.label = 'Coverage'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        const SizedBox(width: 8),
        Text('none', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(width: 4),
        Container(
          width: 96,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              colors: [
                coverageColor(0.02),
                coverageColor(0.34),
                coverageColor(0.7),
                coverageColor(1),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('all', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }
}

/// Turns `PUBLIC WORKS` / `public_works` into `Public works` for axis labels.
String prettyKey(String raw) {
  if (raw.isEmpty) return raw;
  final spaced = raw.replaceAll('_', ' ').toLowerCase();
  return spaced[0].toUpperCase() + spaced.substring(1);
}
