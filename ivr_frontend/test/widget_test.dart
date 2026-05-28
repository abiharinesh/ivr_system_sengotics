import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/core/widgets/stat_card.dart';
import 'package:ivr_frontend/core/widgets/status_badge.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child));
  }

  testWidgets('StatCard renders value and title', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const StatCard(
          title: 'Total Complaints',
          value: '1284',
          icon: Icons.report_problem_rounded,
          gradient: AppTheme.primaryGradient,
          delta: '+12%',
        ),
      ),
    );

    expect(find.text('Total Complaints'), findsOneWidget);
    expect(find.text('1284'), findsOneWidget);
    expect(find.text('+12%'), findsOneWidget);
  });

  testWidgets('StatusBadge maps pending label', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(const Center(child: StatusBadge(status: 'pending'))),
    );
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('ListScreenShell shows structure', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const ListScreenShell(
          title: 'Users',
          subtitle: 'Manage access',
          countLabel: '2 user(s)',
          action: Text('Action'),
          child: Center(child: Text('Body')),
        ),
      ),
    );

    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Manage access'), findsOneWidget);
    expect(find.text('2 user(s)'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });
}
