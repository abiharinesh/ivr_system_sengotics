import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Configuration for a single dashboard widget's visibility and ordering.
class DashboardWidgetConfig {
  final String widgetId;
  final String displayName;
  final IconData icon;
  bool isVisible;
  int sortOrder;

  DashboardWidgetConfig({
    required this.widgetId,
    required this.displayName,
    required this.icon,
    this.isVisible = true,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
        'widgetId': widgetId,
        'displayName': displayName,
        'isVisible': isVisible,
        'sortOrder': sortOrder,
      };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json, IconData icon) {
    return DashboardWidgetConfig(
      widgetId: json['widgetId'] as String,
      displayName: json['displayName'] as String,
      icon: icon,
      isVisible: json['isVisible'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

/// All admin customization settings, persisted in Hive.
class AdminCustomizationSettings {
  String themeMode;         // 'light', 'dark', 'system'
  String language;          // 'en', 'ta'
  int primaryColorValue;    // ARGB int
  int accentColorValue;
  String fontFamily;
  double fontScaleFactor;   // 0.8 – 1.4
  String mapThemeId;
  bool sidebarCompact;
  int? sidebarColorValue;
  List<DashboardWidgetConfig> widgetConfigs;

  AdminCustomizationSettings({
    this.themeMode = 'light',
    this.language = 'en',
    this.primaryColorValue = 0xFF2563EB,
    this.accentColorValue = 0xFF10B981,
    this.fontFamily = 'Inter',
    this.fontScaleFactor = 1.0,
    this.mapThemeId = 'standard',
    this.sidebarCompact = false,
    this.sidebarColorValue,
    List<DashboardWidgetConfig>? widgetConfigs,
  }) : widgetConfigs = widgetConfigs ?? defaultWidgetConfigs();

  Color get primaryColor => Color(primaryColorValue);
  Color get accentColor => Color(accentColorValue);
  Color? get sidebarColor =>
      sidebarColorValue != null ? Color(sidebarColorValue!) : null;

  static List<DashboardWidgetConfig> defaultWidgetConfigs() => [
        DashboardWidgetConfig(
          widgetId: 'stat_cards',
          displayName: 'Statistics Cards',
          icon: Icons.analytics_rounded,
          sortOrder: 0,
        ),
        DashboardWidgetConfig(
          widgetId: 'map_overview',
          displayName: 'Asset Map (GIS View)',
          icon: Icons.map_rounded,
          sortOrder: 1,
        ),
        DashboardWidgetConfig(
          widgetId: 'resolution_trend',
          displayName: 'Resolution Trend',
          icon: Icons.trending_up_rounded,
          sortOrder: 2,
        ),
        DashboardWidgetConfig(
          widgetId: 'category_breakdown',
          displayName: 'Category Breakdown',
          icon: Icons.pie_chart_rounded,
          sortOrder: 3,
        ),
        DashboardWidgetConfig(
          widgetId: 'recent_activity',
          displayName: 'Recent Activity',
          icon: Icons.history_rounded,
          sortOrder: 4,
        ),
      ];
}

/// Provider that manages admin customization settings with Hive persistence.
class AdminCustomizationProvider extends ChangeNotifier {
  static const String _boxName = 'admin_customization';
  Box? _box;
  AdminCustomizationSettings _settings = AdminCustomizationSettings();

  AdminCustomizationSettings get settings => _settings;

  /// Initialize the provider, loading persisted settings from Hive.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _loadFromBox();
    notifyListeners();
  }

  void _loadFromBox() {
    if (_box == null) return;
    _settings = AdminCustomizationSettings(
      themeMode: _box!.get('themeMode', defaultValue: 'light') as String,
      language: _box!.get('language', defaultValue: 'en') as String,
      primaryColorValue:
          _box!.get('primaryColor', defaultValue: 0xFF2563EB) as int,
      accentColorValue:
          _box!.get('accentColor', defaultValue: 0xFF10B981) as int,
      fontFamily: _box!.get('fontFamily', defaultValue: 'Inter') as String,
      fontScaleFactor:
          (_box!.get('fontScale', defaultValue: 1.0) as num).toDouble(),
      mapThemeId:
          _box!.get('mapThemeId', defaultValue: 'standard') as String,
      sidebarCompact:
          _box!.get('sidebarCompact', defaultValue: false) as bool,
      sidebarColorValue: _box!.get('sidebarColor') as int?,
    );

    // Load widget configs
    final savedWidgets = _box!.get('widgetConfigs') as List<dynamic>?;
    if (savedWidgets != null && savedWidgets.isNotEmpty) {
      final defaults = AdminCustomizationSettings.defaultWidgetConfigs();
      final iconMap = {for (final w in defaults) w.widgetId: w.icon};

      _settings.widgetConfigs = savedWidgets
          .whereType<Map>()
          .map((json) {
            final map = Map<String, dynamic>.from(json);
            final icon = iconMap[map['widgetId']] ?? Icons.widgets_rounded;
            return DashboardWidgetConfig.fromJson(map, icon);
          })
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
  }

  /// Save all current settings to Hive.
  Future<void> saveSettings() async {
    if (_box == null) return;
    await _box!.put('themeMode', _settings.themeMode);
    await _box!.put('language', _settings.language);
    await _box!.put('primaryColor', _settings.primaryColorValue);
    await _box!.put('accentColor', _settings.accentColorValue);
    await _box!.put('fontFamily', _settings.fontFamily);
    await _box!.put('fontScale', _settings.fontScaleFactor);
    await _box!.put('mapThemeId', _settings.mapThemeId);
    await _box!.put('sidebarCompact', _settings.sidebarCompact);
    if (_settings.sidebarColorValue != null) {
      await _box!.put('sidebarColor', _settings.sidebarColorValue);
    } else {
      await _box!.delete('sidebarColor');
    }
    await _box!.put(
      'widgetConfigs',
      _settings.widgetConfigs.map((w) => w.toJson()).toList(),
    );
    notifyListeners();
  }

  /// Update a specific setting and save.
  void updateThemeMode(String mode) {
    _settings.themeMode = mode;
    saveSettings();
  }

  void updateLanguage(String lang) {
    _settings.language = lang;
    saveSettings();
  }

  void updatePrimaryColor(Color color) {
    _settings.primaryColorValue = color.toARGB32();
    saveSettings();
  }

  void updateAccentColor(Color color) {
    _settings.accentColorValue = color.toARGB32();
    saveSettings();
  }

  void updateFontFamily(String family) {
    _settings.fontFamily = family;
    saveSettings();
  }

  void updateFontScale(double scale) {
    _settings.fontScaleFactor = scale;
    saveSettings();
  }

  void updateMapTheme(String themeId) {
    _settings.mapThemeId = themeId;
    saveSettings();
  }

  void toggleSidebarCompact() {
    _settings.sidebarCompact = !_settings.sidebarCompact;
    saveSettings();
  }

  void updateSidebarColor(Color? color) {
    _settings.sidebarColorValue = color?.toARGB32();
    saveSettings();
  }

  void toggleWidgetVisibility(String widgetId) {
    final widget = _settings.widgetConfigs.firstWhere(
      (w) => w.widgetId == widgetId,
      orElse: () => DashboardWidgetConfig(
        widgetId: widgetId,
        displayName: widgetId,
        icon: Icons.widgets_rounded,
        sortOrder: 0,
      ),
    );
    widget.isVisible = !widget.isVisible;
    saveSettings();
  }

  void reorderWidgets(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _settings.widgetConfigs.removeAt(oldIndex);
    _settings.widgetConfigs.insert(newIndex, item);
    // Re-assign sort orders
    for (int i = 0; i < _settings.widgetConfigs.length; i++) {
      _settings.widgetConfigs[i].sortOrder = i;
    }
    saveSettings();
  }

  /// Check if a widget should be shown.
  bool isWidgetVisible(String widgetId) {
    return _settings.widgetConfigs
        .firstWhere(
          (w) => w.widgetId == widgetId,
          orElse: () => DashboardWidgetConfig(
            widgetId: widgetId,
            displayName: widgetId,
            icon: Icons.widgets_rounded,
            sortOrder: 99,
          ),
        )
        .isVisible;
  }

  /// Get widget configs sorted by order.
  List<DashboardWidgetConfig> get sortedWidgets {
    final list = List<DashboardWidgetConfig>.from(_settings.widgetConfigs);
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// Reset all settings to defaults.
  void resetToDefaults() {
    _settings = AdminCustomizationSettings();
    saveSettings();
  }
}
