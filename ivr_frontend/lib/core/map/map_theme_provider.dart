import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'map_themes.dart';

/// Manages the user's selected map theme with Hive persistence.
///
/// Usage:
/// ```dart
/// final provider = MapThemeProvider();
/// await provider.init();
/// provider.selectTheme('dark');
/// ```
class MapThemeProvider extends ChangeNotifier {
  static const String _boxName = 'map_theme_prefs';
  static const String _themeKey = 'selected_theme_id';

  MapThemePreset _currentTheme = MapThemes.standard;
  Box? _box;

  /// The currently active map theme preset.
  MapThemePreset get currentTheme => _currentTheme;

  /// All available map theme presets.
  List<MapThemePreset> get availableThemes => MapThemes.all;

  /// The encoded JSON style string for the current theme.
  /// Returns `null` for the standard/default theme.
  String? get currentStyleJson => _currentTheme.encodedStyleOrNull;

  /// Initialize the provider, loading the persisted theme from Hive.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    final savedId = _box?.get(_themeKey, defaultValue: 'standard') as String?;
    if (savedId != null) {
      _currentTheme = MapThemes.byId(savedId);
    }
    notifyListeners();
  }

  /// Select a theme by its [themeId] and persist the choice.
  void selectTheme(String themeId) {
    final theme = MapThemes.byId(themeId);
    if (theme.id == _currentTheme.id) return;
    _currentTheme = theme;
    _box?.put(_themeKey, theme.id);
    notifyListeners();
  }

  /// Reset to the default (standard) theme.
  void resetToDefault() {
    selectTheme('standard');
  }
}
