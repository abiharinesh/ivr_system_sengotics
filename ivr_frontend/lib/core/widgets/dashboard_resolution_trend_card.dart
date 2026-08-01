import 'package:flutter/material.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/models/dashboard_insights_model.dart';

import 'app_shimmer.dart';

/// Mon–Sun bar chart: primary = current week, light = last week (UTC weeks from API).
class DashboardResolutionTrendCard extends StatelessWidget {
  final ResolutionTrend trend;
  final bool isLoading;

  const DashboardResolutionTrendCard({
    super.key,
    required this.trend,
    this.isLoading = false,
  });

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke),
          boxShadow: AppTheme.softShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complaint Resolution Trend',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final hBase = 25.0 + ((i + 2) * 22) % 110;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AppShimmer.rectangular(
                              width: double.infinity,
                              height: hBase,
                            ),
                            const SizedBox(height: 6),
                            const AppShimmer.rectangular(width: 25, height: 10),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final base = trend.currentWeek;
    final overlay = trend.lastWeek;
    final maxVal = [
      ...base,
      ...overlay,
    ].fold<int>(0, (m, v) => v > m ? v : m);
    final scale = maxVal > 0 ? (160.0 / maxVal) : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 380;
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complaint Resolution Trend',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _LegendDot('Current Week', AppTheme.primary),
                          const _LegendDot('Last Week', Color(0xFFBFDBFE)),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Complaint Resolution Trend',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    _LegendDot('Current Week', AppTheme.primary),
                    const SizedBox(width: 12),
                    const _LegendDot('Last Week', Color(0xFFBFDBFE)),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 190,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final o = i < overlay.length ? overlay[i] : 0;
                  final b = i < base.length ? base[i] : 0;
                  final hOverlay = (o * scale).clamp(4.0, 180.0);
                  final hBase = (b * scale).clamp(0.0, 180.0);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Container(
                                height: hOverlay,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFBFDBFE),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Container(
                                height: hBase,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _days[i],
                            style:       TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style:       TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}