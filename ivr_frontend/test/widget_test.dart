import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    // App initializes without crashing
    expect(find.byType(App), findsOneWidget);
  });
}
