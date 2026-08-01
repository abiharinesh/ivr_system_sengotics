import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'app_card.dart';

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
        final isMobile = constraints.maxWidth < 400;
        final hMargin = isMobile ? 12.0 : 24.0;
        final innerPad = isMobile ? 12.0 : 18.0;
        return Column(
          children: [
            AppCard(
              margin: EdgeInsets.fromLTRB(hMargin, 20, hMargin, 12),
              padding: EdgeInsets.all(innerPad),
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
          style:       TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style:       TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          countLabel,
          style:       TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}