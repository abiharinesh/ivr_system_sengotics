import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/stat_card.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('Ad Campaigns & Technician Penalties Suite', () {
    testWidgets('Renders Ad campaign metrics and Technician SLA penalty shell', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          ListScreenShell(
            title: 'Ad Campaigns & Penalties',
            subtitle: 'Track digital impressions and technician SLA deductions',
            countLabel: '5 Active Campaigns',
            action: ElevatedButton(
              onPressed: () {},
              child: const Text('Create Campaign'),
            ),
            child: const StatCard(
              title: 'Total Penalty Deductions',
              value: '₹ 4,500',
              icon: Icons.gavel_rounded,
              gradient: AppTheme.primaryGradient,
            ),
          ),
        ),
      );

      expect(find.text('Ad Campaigns & Penalties'), findsOneWidget);
      expect(find.text('5 Active Campaigns'), findsOneWidget);
      expect(find.text('Total Penalty Deductions'), findsOneWidget);
      expect(find.text('₹ 4,500'), findsOneWidget);
    });
  });
}
