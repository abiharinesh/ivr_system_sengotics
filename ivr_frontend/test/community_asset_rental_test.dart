import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/stat_card.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('Community Asset Rental Suite', () {
    testWidgets('Renders asset rental stats and hall booking title', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: [
              StatCard(
                title: 'Total Rentable Assets',
                value: '14',
                icon: Icons.location_city_rounded,
                gradient: AppTheme.primaryGradient,
              ),
              AppCard(
                child: Text('Thayanur Community Hall - Booked'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Total Rentable Assets'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Thayanur Community Hall - Booked'), findsOneWidget);
    });
  });
}
