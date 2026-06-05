import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/tender_models.dart';

class TenderKpiSection extends StatelessWidget {
  final List<TenderSummary> tenders;
  const TenderKpiSection({super.key, required this.tenders});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Active Tenders count
    final activeCount =
        tenders
            .where((t) => t.status != 'draft' && t.status != 'closed')
            .length;

    // 2. Calculate Total Awarded Value
    double totalAwarded = 0;
    for (final t in tenders) {
      if (t.awarded != null) {
        totalAwarded += double.tryParse(t.awarded!.amount) ?? 0.0;
      }
    }

    // 3. Calculate Awaiting Award Tenders count (status = quotations_closed or published with quotes)
    final awaitingCount =
        tenders
            .where(
              (t) =>
                  t.status == 'quotations_closed' ||
                  (t.status == 'published' && t.quotationsCount > 0),
            )
            .length;

    // 4. Calculate Verification Progress
    int totalPoints = 0;
    int donePoints = 0;
    for (final t in tenders) {
      if (t.verificationProgress != null) {
        totalPoints += t.verificationProgress!.total;
        donePoints += t.verificationProgress!.done;
      }
    }
    final double verificationRatio =
        totalPoints > 0 ? donePoints / totalPoints : 0.0;

    final numberFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Responsive columns count
        int crossAxisCount = 4;
        if (width < 600) {
          crossAxisCount = 1;
        } else if (width < 960) {
          crossAxisCount = 2;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.55,
          children: [
            // KPI Card 1: Active Tenders
            _buildKpiCard(
              context: context,
              title: 'Active Tenders',
              value: '$activeCount',
              subtitle: '+2 this week',
              icon: Icons.assignment_turned_in_outlined,
              accentColor: const Color(0xFF0F766E), // Teal
              rightWidget: _buildMicroBarChart(const Color(0xFF0F766E)),
            ),
            // KPI Card 2: Total Budget / Awarded Value
            _buildKpiCard(
              context: context,
              title: 'Awarded Budget',
              value: numberFormat.format(totalAwarded),
              subtitle: 'Across all selectees',
              icon: Icons.account_balance_wallet_outlined,
              accentColor: const Color(0xFF3B82F6), // Blue
              rightWidget: _buildMicroGauge(0.68, const Color(0xFF3B82F6)),
            ),
            // KPI Card 3: Awaiting Award
            _buildKpiCard(
              context: context,
              title: 'Awaiting Award',
              value: '$awaitingCount',
              subtitle: 'Pending L1 Award',
              icon: Icons.workspace_premium_outlined,
              accentColor: const Color(0xFFF59E0B), // Amber
              rightWidget: _buildMicroSparkline(const Color(0xFFF59E0B)),
            ),
            // KPI Card 4: Verification Progress
            _buildKpiCard(
              context: context,
              title: 'Pending Inspections',
              value: totalPoints > 0 ? '$donePoints/$totalPoints' : '0/0',
              subtitle:
                  '${(verificationRatio * 100).toStringAsFixed(0)}% Completed',
              icon: Icons.checklist_rtl_outlined,
              accentColor: const Color(0xFF10B981), // Green
              rightWidget: _buildMicroDonut(
                verificationRatio,
                const Color(0xFF10B981),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget rightWidget,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: accentColor.withValues(alpha: 0.7), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 54, height: 54, child: rightWidget),
          ],
        ),
      ),
    );
  }

  Widget _buildMicroBarChart(Color color) {
    final values = [0.4, 0.6, 0.3, 0.7, 0.5, 0.9, 0.8, 0.7];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children:
          values.map((val) {
            return Container(
              width: 4,
              height: 48 * val,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [color, color.withValues(alpha: 0.4)],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildMicroSparkline(Color color) {
    return CustomPaint(
      painter: _SparklinePainter([
        10.0,
        15.0,
        8.0,
        22.0,
        18.0,
        25.0,
        21.0,
        30.0,
      ], color),
    );
  }

  Widget _buildMicroGauge(double val, Color color) {
    return CustomPaint(painter: _GaugePainter(val, color));
  }

  Widget _buildMicroDonut(double val, Color color) {
    return CustomPaint(painter: _DonutPainter(val == 0.0 ? 0.05 : val, color));
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;

    final fillPaint =
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.0),
          ])
          ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final double dx = size.width / (data.length - 1);
    final double maxVal = data.reduce((a, b) => a > b ? a : b);
    final double minVal = data.reduce((a, b) => a < b ? a : b);
    final double range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    double getY(double val) {
      return size.height - ((val - minVal) / range) * (size.height - 4) - 2;
    }

    path.moveTo(0, getY(data.first));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(data.first));

    for (int i = 1; i < data.length; i++) {
      final x1 = (i - 1) * dx;
      final y1 = getY(data[i - 1]);
      final x2 = i * dx;
      final y2 = getY(data[i]);

      final cx = x1 + dx / 2;
      path.cubicTo(cx, y1, cx, y2, x2, y2);
      fillPath.cubicTo(cx, y1, cx, y2, x2, y2);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  _GaugePainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = size.width / 2 - 4;

    final bgPaint =
        Paint()
          ..color = const Color(0xFFF1F5F9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..strokeCap = StrokeCap.round;

    final valPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159,
      false,
      bgPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159 * value.clamp(0.0, 1.0),
      false,
      valPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DonutPainter extends CustomPainter {
  final double value;
  final Color color;
  _DonutPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final bgPaint =
        Paint()
          ..color = const Color(0xFFF1F5F9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0;

    final valPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.28318 * value.clamp(0.0, 1.0),
      false,
      valPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
