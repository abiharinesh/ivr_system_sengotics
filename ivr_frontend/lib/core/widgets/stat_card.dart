import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

import 'app_shimmer.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final String? delta;
  final bool positiveDelta;
  final bool isLoading;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.delta,
    this.positiveDelta = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 240;
        final padding = compact ? 12.0 : 20.0;
        final titleSize = compact ? 15.0 : 13.0;
        final deltaSize = compact ? 13.0 : 11.0;
        final valueSize = compact ? 26.0 : 28.0;
        final iconSize = compact ? 20.0 : 22.0;
        final iconPadding = compact ? 8.0 : 10.0;

        final content = isLoading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(iconPadding),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: AppTheme.textMuted, size: iconSize),
                      ),
                      const SizedBox(width: 8),
                      const AppShimmer.rectangular(width: 40, height: 16),
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 12),
                  const AppShimmer.rectangular(width: 100, height: 12),
                  SizedBox(height: compact ? 6 : 8),
                  const AppShimmer.rectangular(width: 60, height: 24),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(iconPadding),
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Colors.white, size: iconSize),
                      ),
                      if (delta != null) ...[
                        SizedBox(width: compact ? 6 : 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 6 : 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (positiveDelta ? AppTheme.accent : AppTheme.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            delta!,
                            style: TextStyle(
                              fontSize: deltaSize,
                              color:
                                  positiveDelta ? AppTheme.accent : AppTheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(width: 8),
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: valueSize,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              );

        final hasBoundedHeight = constraints.maxHeight.isFinite;
        final tightHeight = hasBoundedHeight && constraints.maxHeight < 140;
        final useScaleDown = !compact || tightHeight;

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke),
            boxShadow: AppTheme.softShadow,
          ),
          child: useScaleDown
              ? FittedBox(
                  alignment: Alignment.topLeft,
                  fit: BoxFit.scaleDown,
                  child: content,
                )
              : content,
        );
      },
    );
  }
}
