import 'package:ivr_frontend/core/api/api_client.dart';

import 'dashboard_models.dart';

/// `/api/dashboard` — the per-role landing page and the endpoints the super
/// admin console uses to decide what it contains.
class DashboardRepository {
  final ApiClient _api;

  DashboardRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/dashboard';

  /// The signed-in user's own dashboard, computed server-side.
  Future<RoleDashboardData> mine({bool forceRefresh = true}) async {
    final data = await _api.get(_base, forceRefresh: forceRefresh);
    return RoleDashboardData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Another role's dashboard, rendered as they would see it. Lets an
  /// administrator check a layout without signing in as somebody else.
  Future<RoleDashboardData> preview(String role) async {
    final data = await _api.get('$_base/preview/$role', forceRefresh: true);
    return RoleDashboardData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// The widget palette, grouped by module.
  Future<List<DashboardWidgetGroup>> palette({bool forceRefresh = false}) async {
    final data = await _api.get('$_base/widgets', forceRefresh: forceRefresh);
    final map = Map<String, dynamic>.from(data as Map);
    return (map['groups'] as List? ?? [])
        .map((e) => DashboardWidgetGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Every role's layout, configured or not.
  Future<List<RoleLayout>> layouts({bool forceRefresh = true}) async {
    final data = await _api.get('$_base/layouts', forceRefresh: forceRefresh);
    return (data as List)
        .map((e) => RoleLayout.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Replace a role's panels. The order of [widgetIds] is the layout.
  Future<void> setLayout(String role, List<int> widgetIds) async {
    await _api.put('$_base/layouts/$role', data: {'widget_ids': widgetIds});
  }
}
