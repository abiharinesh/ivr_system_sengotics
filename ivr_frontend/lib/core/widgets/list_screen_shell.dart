import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class ListScreenShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final String countLabel;
  final Widget action;
  final Widget child;
  final Widget? filters;

  const ListScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.countLabel,
    required this.action,
    required this.child,
    this.filters,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.stroke),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment:
                    isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
                children: [
                  if (isNarrow)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderText(),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: action,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: _buildHeaderText()),
                        action,
                      ],
                    ),
                  if (filters != null) ...[
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: filters!),
                  ],
                ],
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }

  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          countLabel,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
