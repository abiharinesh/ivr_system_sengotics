import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/status_badge.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('Certificate Reviews Suite', () {
    testWidgets('Displays certificate approval status badges correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          Row(
            children: const [
              StatusBadge(status: 'resolved'),
              StatusBadge(status: 'pending'),
            ],
          ),
        ),
      );

      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });
  });
}
