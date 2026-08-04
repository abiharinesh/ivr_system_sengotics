import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ivr_frontend/features/dashboard/data/dashboard_models.dart';
import 'package:ivr_frontend/features/dashboard/presentation/widgets/dashboard_widget_card.dart';

/// Every widget type has to survive being built.
///
/// The panels are composed from database rows, so a widget type can arrive
/// that this build has never rendered, and the charts are driven by data whose
/// shape the server decides. A chart library call that is subtly wrong throws
/// at build time and takes the whole dashboard with it — which no amount of
/// analyzer cleanliness catches.

DashboardWidgetData widget_({
  String type = 'counter',
  num? value,
  String? caption,
  int? delta,
  WidgetTone tone = WidgetTone.neutral,
  List<SeriesPoint> series = const [],
  List<MapPoint> points = const [],
  List<String> columns = const [],
  List<Map<String, dynamic>> rows = const [],
  String? route,
  String? error,
  String code = 'demo',
}) =>
    DashboardWidgetData(
      code: code,
      title: 'Panel title',
      widgetType: type,
      dataSource: 'complaints',
      size: 'small',
      value: value,
      caption: caption,
      delta: delta,
      tone: tone,
      series: series,
      points: points,
      columns: columns,
      rows: rows,
      route: route,
      error: error,
    );

Future<void> pumpCard(WidgetTester tester, DashboardWidgetData data,
    {Size size = const Size(420, 300)}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: DashboardWidgetCard(data: data),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final series = [
    for (var i = 0; i < 6; i++)
      SeriesPoint(label: 'Category $i', value: (i + 1) * 12.0),
  ];
  final longSeries = [
    for (var i = 0; i < 30; i++)
      SeriesPoint(label: '2026-08-${(i % 28) + 1}', value: (i % 7) * 3.0),
  ];

  group('renders every widget type', () {
    testWidgets('counter', (tester) async {
      await pumpCard(
        tester,
        widget_(value: 1234567, caption: 'of 44 logged', delta: 12),
      );
      // Grouped in the Indian convention, which is what the figure means here.
      expect(find.text('12,34,567'), findsOneWidget);
      expect(find.text('of 44 logged'), findsOneWidget);
      expect(find.text('12%'), findsOneWidget);
    });

    testWidgets('kpi renders a gauge for a percentage', (tester) async {
      await pumpCard(tester, widget_(type: 'kpi', value: 72, caption: 'on time'));
      await tester.pumpAndSettle();
      expect(find.text('%'), findsOneWidget);
      expect(find.text('on time'), findsOneWidget);
    });

    testWidgets('kpi falls back to a counter for a non-percentage', (tester) async {
      // Satisfaction is out of 5; gauging it to 100 would be a lie.
      await pumpCard(
        tester,
        widget_(type: 'kpi', value: 3.4, code: 'citizen_satisfaction'),
      );
      expect(find.text('3.4'), findsOneWidget);
      expect(find.byType(PieChart), findsNothing);
    });

    testWidgets('bar chart', (tester) async {
      await pumpCard(tester, widget_(type: 'bar_chart', series: series));
      await tester.pumpAndSettle();
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('a long series becomes a trend line, not bars', (tester) async {
      await pumpCard(
        tester,
        widget_(type: 'bar_chart', series: longSeries, value: 90, delta: -8),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('pie chart with legend', (tester) async {
      await pumpCard(tester, widget_(type: 'pie_chart', series: series));
      await tester.pumpAndSettle();
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text('Category 0'), findsOneWidget);
    });

    testWidgets('table', (tester) async {
      await pumpCard(
        tester,
        widget_(
          type: 'table',
          columns: ['Action', 'When'],
          rows: [
            {'Action': 'Role assigned', 'When': '2026-08-04T10:30:00.000Z'},
          ],
        ),
      );
      expect(find.text('Role assigned'), findsOneWidget);
      // An ISO timestamp is unreadable raw, so it is formatted.
      expect(find.textContaining('Aug'), findsOneWidget);
    });

    testWidgets('map', (tester) async {
      await pumpCard(
        tester,
        widget_(
          type: 'map',
          caption: '16 located',
          points: [
            const MapPoint(lat: 11.01, lng: 76.95, label: 'A', value: '1', tone: WidgetTone.bad),
            const MapPoint(lat: 11.05, lng: 76.99, label: 'B', value: '2', tone: WidgetTone.good),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('16 located'), findsOneWidget);
    });

    testWidgets('an unknown type degrades to a counter', (tester) async {
      // The catalogue is editable from the console and can gain types without
      // a client release; throwing would take the whole dashboard down.
      await pumpCard(tester, widget_(type: 'sunburst_3d', value: 7));
      expect(find.text('7'), findsOneWidget);
    });
  });

  group('degenerate data', () {
    testWidgets('a failed panel says so instead of throwing', (tester) async {
      await pumpCard(tester, widget_(error: 'Could not load'));
      expect(find.text('Could not load'), findsOneWidget);
    });

    testWidgets('an empty series does not crash the chart', (tester) async {
      for (final type in ['bar_chart', 'pie_chart', 'map', 'table']) {
        await pumpCard(tester, widget_(type: type));
        expect(find.text('Nothing recorded yet'), findsOneWidget,
            reason: '$type with no data');
      }
    });

    testWidgets('an all-zero series does not divide by zero', (tester) async {
      final zeros = [
        for (var i = 0; i < 4; i++) SeriesPoint(label: 'x$i', value: 0),
      ];
      await pumpCard(tester, widget_(type: 'bar_chart', series: zeros));
      await tester.pumpAndSettle();
      expect(find.byType(BarChart), findsOneWidget);

      // A pie of nothing has no slices to draw, so it says so rather than
      // rendering an empty ring.
      await pumpCard(tester, widget_(type: 'pie_chart', series: zeros));
      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });

    testWidgets('points at one location do not collapse the map', (tester) async {
      await pumpCard(
        tester,
        widget_(
          type: 'map',
          points: List.generate(
            3,
            (_) => const MapPoint(
              lat: 11.0,
              lng: 76.9,
              label: 'same',
              value: null,
              tone: WidgetTone.warn,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a null value shows a dash rather than "null"', (tester) async {
      await pumpCard(tester, widget_());
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('a zero delta is not shown as a trend', (tester) async {
      await pumpCard(tester, widget_(value: 5, delta: 0));
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('narrow layout', () {
    testWidgets('survives a single-column width', (tester) async {
      // The dashboard drops to one column under 620px; panels must not
      // overflow when the grid squeezes them.
      for (final type in ['counter', 'kpi', 'bar_chart', 'pie_chart', 'map']) {
        await pumpCard(
          tester,
          widget_(type: type, value: 88, series: series, points: const [
            MapPoint(lat: 11.0, lng: 76.9, label: 'a', value: null, tone: WidgetTone.good),
          ]),
          size: const Size(260, 300),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$type at 260px');
      }
    });
  });
}
