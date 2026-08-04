/// Models for `GET /api/dashboard` — the per-role widget layout and the data
/// computed for each panel.
///
/// The server decides both what appears and what it says. The client's job is
/// to render a widget type it recognises and to degrade gracefully when it
/// meets one it does not, because the widget catalogue is editable from the
/// super admin console and can gain entries without a client release.

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _double(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    : const [];

/// How a figure should be read. A rising complaint count is not good news, so
/// the server says what the number means rather than leaving the client to
/// guess from its direction.
enum WidgetTone { neutral, good, warn, bad }

WidgetTone _tone(dynamic v) => switch (v) {
      'good' => WidgetTone.good,
      'warn' => WidgetTone.warn,
      'bad' => WidgetTone.bad,
      _ => WidgetTone.neutral,
    };

/// One point on a bar or pie widget.
class SeriesPoint {
  final String label;
  final double value;

  const SeriesPoint({required this.label, required this.value});

  factory SeriesPoint.fromJson(Map<String, dynamic> j) => SeriesPoint(
        label: j['label'] as String? ?? '',
        value: _double(j['value']),
      );
}

/// One marker on a map widget.
class MapPoint {
  final double lat;
  final double lng;
  final String label;
  final String? value;
  final WidgetTone tone;

  const MapPoint({
    required this.lat,
    required this.lng,
    required this.label,
    required this.value,
    required this.tone,
  });

  factory MapPoint.fromJson(Map<String, dynamic> j) => MapPoint(
        lat: _double(j['lat']),
        lng: _double(j['lng']),
        label: j['label'] as String? ?? '',
        value: j['value'] as String?,
        tone: _tone(j['tone']),
      );
}

/// A single panel: its definition and the data computed for it.
class DashboardWidgetData {
  final String code;
  final String title;
  final String widgetType;
  final String dataSource;
  final String size;

  /// Headline figure. Kept as the raw value so an integer count and a 3.4
  /// average format differently without the server having to pre-render text.
  final num? value;
  final String? caption;
  final int? delta;
  final WidgetTone tone;

  final List<SeriesPoint> series;
  final List<MapPoint> points;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;

  /// Where tapping the panel goes, when the panel is a summary of a screen.
  final String? route;

  /// Set when the server could not compute this panel. One failed query must
  /// not blank the dashboard, so the panel says so and the rest still render.
  final String? error;

  const DashboardWidgetData({
    required this.code,
    required this.title,
    required this.widgetType,
    required this.dataSource,
    required this.size,
    required this.value,
    required this.caption,
    required this.delta,
    required this.tone,
    required this.series,
    required this.points,
    required this.columns,
    required this.rows,
    required this.route,
    required this.error,
  });

  bool get hasError => error != null;

  /// Panels claim one, two or four columns of the grid.
  int get columnSpan => switch (size) {
        'large' => 4,
        'medium' => 2,
        _ => 1,
      };

  factory DashboardWidgetData.fromJson(Map<String, dynamic> j) =>
      DashboardWidgetData(
        code: j['code'] as String? ?? '',
        title: j['title'] as String? ?? '',
        widgetType: j['widget_type'] as String? ?? 'counter',
        dataSource: j['data_source'] as String? ?? 'core',
        size: j['size'] as String? ?? 'small',
        value: j['value'] is num
            ? j['value'] as num
            : j['value'] is String
                ? num.tryParse(j['value'] as String)
                : null,
        caption: j['caption'] as String?,
        delta: j['delta'] == null ? null : _int(j['delta']),
        tone: _tone(j['tone']),
        series: _maps(j['series']).map(SeriesPoint.fromJson).toList(),
        points: _maps(j['points']).map(MapPoint.fromJson).toList(),
        columns: (j['columns'] as List? ?? []).map((e) => e.toString()).toList(),
        rows: _maps(j['rows']),
        route: j['route'] as String?,
        error: j['error'] as String?,
      );
}

/// The whole dashboard for one role.
class RoleDashboardData {
  final String role;
  final int? orgUnitId;
  final DateTime? generatedAt;

  /// False when the role has no `role_dashboards` row and is seeing the
  /// generic fallback. Worth telling an administrator, since it means nobody
  /// has arranged this role's dashboard yet.
  final bool configured;

  final List<DashboardWidgetData> widgets;

  const RoleDashboardData({
    required this.role,
    required this.orgUnitId,
    required this.generatedAt,
    required this.configured,
    required this.widgets,
  });

  static const empty = RoleDashboardData(
    role: '',
    orgUnitId: null,
    generatedAt: null,
    configured: false,
    widgets: [],
  );

  bool get isEmpty => widgets.isEmpty;

  factory RoleDashboardData.fromJson(Map<String, dynamic> j) => RoleDashboardData(
        role: j['role'] as String? ?? '',
        orgUnitId: j['org_unit_id'] == null ? null : _int(j['org_unit_id']),
        generatedAt: DateTime.tryParse(j['generated_at']?.toString() ?? ''),
        configured: j['configured'] == true,
        widgets:
            _maps(j['widgets']).map(DashboardWidgetData.fromJson).toList(),
      );
}

/// A widget in the palette an administrator composes a layout from.
class DashboardWidgetOption {
  final int id;
  final String code;
  final String title;
  final String widgetType;
  final String dataSource;
  final String defaultSize;

  const DashboardWidgetOption({
    required this.id,
    required this.code,
    required this.title,
    required this.widgetType,
    required this.dataSource,
    required this.defaultSize,
  });

  factory DashboardWidgetOption.fromJson(Map<String, dynamic> j) =>
      DashboardWidgetOption(
        id: _int(j['id']),
        code: j['code'] as String? ?? '',
        title: j['title'] as String? ?? '',
        widgetType: j['widget_type'] as String? ?? '',
        dataSource: j['data_source'] as String? ?? '',
        defaultSize: j['default_size'] as String? ?? 'small',
      );
}

/// Palette entries grouped by the module they report on.
class DashboardWidgetGroup {
  final String dataSource;
  final List<DashboardWidgetOption> items;

  const DashboardWidgetGroup({required this.dataSource, required this.items});

  factory DashboardWidgetGroup.fromJson(Map<String, dynamic> j) =>
      DashboardWidgetGroup(
        dataSource: j['data_source'] as String? ?? '',
        items: _maps(j['items']).map(DashboardWidgetOption.fromJson).toList(),
      );
}

/// One role's configured layout, as the console lists it.
class RoleLayout {
  final String roleName;
  final String displayName;
  final int hierarchyLevel;
  final bool configured;
  final List<int> widgetIds;
  final List<DashboardWidgetOption> widgets;

  const RoleLayout({
    required this.roleName,
    required this.displayName,
    required this.hierarchyLevel,
    required this.configured,
    required this.widgetIds,
    required this.widgets,
  });

  factory RoleLayout.fromJson(Map<String, dynamic> j) => RoleLayout(
        roleName: j['role_name'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        hierarchyLevel: _int(j['hierarchy_level'], 5),
        configured: j['configured'] == true,
        widgetIds:
            (j['widget_ids'] as List? ?? []).map((e) => _int(e)).toList(),
        widgets: _maps(j['widgets']).map(DashboardWidgetOption.fromJson).toList(),
      );
}
