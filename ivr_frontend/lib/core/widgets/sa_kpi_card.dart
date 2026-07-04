import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import 'app_shimmer.dart';

/// A KPI card for the SuperAdmin dashboard — displays a title, large value,
/// icon with colored background, and a flexible trend/subtitle widget.
class SAKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Widget trendWidget;
  final bool isLoading;
  final VoidCallback? onTap;

  const SAKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.trendWidget,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.durationNormal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.stroke),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 8),
                    const AppShimmer.rectangular(width: 55, height: 32),
                    const SizedBox(height: 8),
                    const AppShimmer.rectangular(width: 100, height: 12),
                  ] else ...[
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Metropolis',
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    trendWidget,
                  ],
                ],
              ),
            ),
            if (isLoading)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
          ],
        ),
      ),
    );
  }
}
