import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

class DashboardPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const DashboardPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:       TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style:       TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class MiniTrendChart extends StatelessWidget {
  final List<double> values;
  final Color? color;
  final Color? mutedColor;

  const MiniTrendChart({
    super.key,
    required this.values,
    this.color,
    this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(height: 140);
    }
    final activeColor = color ?? AppTheme.primary;
    final bgCol = mutedColor ?? AppTheme.bgSurface;

    return SizedBox(
      height: 160,
      child: CustomPaint(
        painter: _BarChartPainter(
          values: values,
          color: activeColor,
          mutedColor: bgCol,
        ),
      ),
    );
  }
}

class CategoryProgressList extends StatelessWidget {
  final List<CategoryProgressItem> items;

  const CategoryProgressList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.label,
                          style:       TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            backgroundColor: AppTheme.bgSurface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              item.color,
                            ),
                            value: item.progress.clamp(0, 1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${(item.progress * 100).round()}%',
                          textAlign: TextAlign.right,
                          style:       TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}

class CategoryProgressItem {
  final String label;
  final double progress;
  final Color color;

  const CategoryProgressItem({
    required this.label,
    required this.progress,
    required this.color,
  });
}

class ActivityFeed extends StatelessWidget {
  final List<ActivityFeedItem> items;

  const ActivityFeed({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, size: 15, color: item.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style:       TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          style:       TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.timeLabel,
                    style:       TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

class ActivityFeedItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String timeLabel;

  const ActivityFeedItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
  });
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color mutedColor;

  _BarChartPainter({
    required this.values,
    required this.color,
    required this.mutedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce(math.max);
    const barSpacing = 6.0;
    final barCount = values.length;
    final barWidth = (size.width - ((barCount - 1) * barSpacing)) / barCount;
    for (var i = 0; i < barCount; i++) {
      final ratio = maxValue <= 0 ? 0.0 : values[i] / maxValue;
      final barHeight = math.max<double>(8, size.height * ratio);
      final x = i * (barWidth + barSpacing);
      final y = size.height - barHeight;
      final rect = Rect.fromLTWH(x, y, barWidth, barHeight);
      final paint =
          Paint()
            ..color = i == barCount - 1 ? color : mutedColor
            ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}