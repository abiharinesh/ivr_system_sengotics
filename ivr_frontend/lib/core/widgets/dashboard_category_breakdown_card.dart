import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../models/dashboard_insights_model.dart';

/// Top complaint types with counts and progress vs max bucket.
class DashboardCategoryBreakdownCard extends StatelessWidget {
  final List<CategoryCount> categories;

  const DashboardCategoryBreakdownCard({super.key, required this.categories});

  static const _palette = [
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    final maxCount = categories.isEmpty
        ? 1
        : categories.map((c) => c.count).reduce((a, b) => a > b ? a : b);

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
              'By Category',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
                    Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No complaints yet',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ...List.generate(categories.length, (i) {
                final row = categories[i];
                final color = _palette[i % _palette.length];
                final frac = maxCount > 0 ? row.count / maxCount : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.label,
                              style:       TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${row.count}',
                            style:       TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: frac.clamp(0.0, 1.0),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          backgroundColor: AppTheme.bgSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}