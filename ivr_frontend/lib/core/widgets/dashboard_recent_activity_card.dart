import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../models/dashboard_insights_model.dart';
import 'app_shimmer.dart';

String formatActivityTime(DateTime at) {
  final now = DateTime.now();
  final diff = now.difference(at);
  if (diff.isNegative) return 'Just now';
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${at.day}/${at.month}/${at.year}';
}

(IconData, Color) _iconForKind(String kind) {
  switch (kind) {
    case 'resolved':
      return (Icons.check_circle_outline_rounded, AppTheme.accent);
    case 'resolution_submitted':
      return (Icons.cloud_upload_outlined, AppTheme.warning);
    case 'new_complaint':
    default:
      return (Icons.add_circle_outline_rounded, AppTheme.primary);
  }
}


class DashboardRecentActivityCard extends StatelessWidget {
  final List<RecentActivityItem> items;
  final VoidCallback? onViewAll;
  final bool isLoading;

  const DashboardRecentActivityCard({
    super.key,
    required this.items,
    this.onViewAll,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: isLoading ? null : onViewAll,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              ...List.generate(3, (i) {
                final widths = [180.0, 140.0, 190.0];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppShimmer.rectangular(width: widths[i], height: 12),
                            const SizedBox(height: 6),
                            const AppShimmer.rectangular(width: 100, height: 10),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const AppShimmer.rectangular(width: 30, height: 10),
                    ],
                  ),
                );
              })
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No recent activity',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              )
            else
              ...items.map((e) {
                final ic = _iconForKind(e.kind);
                return _ActivityLine(
                  icon: ic.$1,
                  color: ic.$2,
                  title: e.title,
                  subtitle: e.subtitle,
                  time: formatActivityTime(e.at),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ActivityLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  const _ActivityLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:       TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:       TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style:       TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}