import 'package:flutter/material.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'app_card.dart';

class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXl),
        child: AppCard(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 36),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                message,
                textAlign: TextAlign.center,
                style:       TextStyle(
                  color: AppTheme.textSecondary,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppTheme.spaceMd),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}