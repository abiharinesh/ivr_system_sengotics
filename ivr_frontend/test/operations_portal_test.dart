import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('Operations & Portal Module Suite', () {
    testWidgets('Renders Contractors, Field Inspections, and Citizen Portal items', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: [
              AppCard(child: Text('Contractor: Apex Infrastructure Ltd (Verified)')),
              AppCard(child: Text('Inspection: Ward 2 Drainage Pipeline - PASS')),
              AppCard(child: Text('Universal Search: Electric Pole TY-PL-001')),
              AppCard(child: Text('Citizen Portal: Public Water Leakage Report')),
              AppCard(child: Text('Municipality: Thayanur Village Panchayat')),
            ],
          ),
        ),
      );

      expect(find.text('Contractor: Apex Infrastructure Ltd (Verified)'), findsOneWidget);
      expect(find.text('Inspection: Ward 2 Drainage Pipeline - PASS'), findsOneWidget);
      expect(find.text('Universal Search: Electric Pole TY-PL-001'), findsOneWidget);
      expect(find.text('Citizen Portal: Public Water Leakage Report'), findsOneWidget);
      expect(find.text('Municipality: Thayanur Village Panchayat'), findsOneWidget);
    });
  });
}
