import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/customization/admin_customization_provider.dart';
import '../../../../core/widgets/map_theme_picker.dart';
import '../../../../app.dart';

/// Full admin customization settings screen with sections for
/// appearance, typography, map settings, dashboard widgets, and sidebar.
class AdminCustomizationScreen extends StatefulWidget {
  const AdminCustomizationScreen({super.key});

  @override
  State<AdminCustomizationScreen> createState() =>
      _AdminCustomizationScreenState();
}

class _AdminCustomizationScreenState extends State<AdminCustomizationScreen> {
  late AdminCustomizationProvider _provider;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.adminCustomizationProvider;
    _isInitialized = true;
  }


  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
                    Text(
                'Customization',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
                    Text(
                'Personalize your dashboard experience — colors, fonts, widgets, and map appearance.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // ── Appearance ──
              _SectionCard(
                title: 'Appearance',
                subtitle: 'Theme mode and brand colors',
                icon: Icons.palette_rounded,
                children: [
                  // Theme Mode
                  const _SectionLabel('Theme Mode'),
                  const SizedBox(height: 8),
                  _ThemeModeSelector(
                    current: _provider.settings.themeMode,
                    onChanged: _provider.updateThemeMode,
                  ),
                  const SizedBox(height: 20),

                  // Primary Color
                  const _SectionLabel('Primary Color'),
                  const SizedBox(height: 8),
                  _ColorPalette(
                    selected: _provider.settings.primaryColor,
                    onChanged: _provider.updatePrimaryColor,
                    colors: const [
                      Color(0xFF2563EB), Color(0xFF4F46E5), Color(0xFF7C3AED),
                      Color(0xFF9333EA), Color(0xFFDB2777), Color(0xFFE11D48),
                      Color(0xFFEA580C), Color(0xFFCA8A04), Color(0xFF16A34A),
                      Color(0xFF0D9488), Color(0xFF0284C7), Color(0xFF475569),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Preview
                  _ColorPreviewBar(
                    primary: _provider.settings.primaryColor,
                    accent: _provider.settings.accentColor,
                  ),
                  const SizedBox(height: 20),

                  // Accent Color
                  const _SectionLabel('Accent Color'),
                  const SizedBox(height: 8),
                  _ColorPalette(
                    selected: _provider.settings.accentColor,
                    onChanged: _provider.updateAccentColor,
                    colors: const [
                      Color(0xFF10B981), Color(0xFF14B8A6), Color(0xFF06B6D4),
                      Color(0xFF0EA5E9), Color(0xFF6366F1), Color(0xFFA855F7),
                      Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFEF4444),
                      Color(0xFFEC4899), Color(0xFF84CC16), Color(0xFF64748B),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Typography ──
              _SectionCard(
                title: 'Typography',
                subtitle: 'Font family and size scaling',
                icon: Icons.text_fields_rounded,
                children: [
                  const _SectionLabel('Font Family'),
                  const SizedBox(height: 8),
                  _FontFamilySelector(
                    current: _provider.settings.fontFamily,
                    onChanged: _provider.updateFontFamily,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const _SectionLabel('Font Scale'),
                      const Spacer(),
                      Text(
                        '${(_provider.settings.fontScaleFactor * 100).round()}%',
                        style:       TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _provider.settings.fontScaleFactor,
                    min: 0.8,
                    max: 1.4,
                    divisions: 12,
                    label:
                        '${(_provider.settings.fontScaleFactor * 100).round()}%',
                    onChanged: _provider.updateFontScale,
                  ),
                  // Font preview
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview: The quick brown fox jumps over the lazy dog.',
                          style: TextStyle(
                            fontSize:
                                14 * _provider.settings.fontScaleFactor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bold: Dashboard Analytics Overview',
                          style: TextStyle(
                            fontSize:
                                16 * _provider.settings.fontScaleFactor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Map Settings ──
              _SectionCard(
                title: 'Map Settings',
                subtitle: 'Choose your preferred map theme',
                icon: Icons.map_rounded,
                children: [
                  const _SectionLabel('Map Theme'),
                  const SizedBox(height: 10),
                  MapThemePicker(
                    selectedThemeId: context.mapThemeProvider.currentTheme.id,
                    onThemeSelected: (theme) {
                      context.readMapThemeProvider.selectTheme(theme.id);
                      _provider.updateMapTheme(theme.id);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Dashboard Widgets ──
              _SectionCard(
                title: 'Dashboard Widgets',
                subtitle: 'Toggle and reorder widgets on your dashboard',
                icon: Icons.dashboard_customize_rounded,
                children: [
                  const _SectionLabel('Widget Visibility & Order'),
                  const SizedBox(height: 8),
                  ..._provider.sortedWidgets.asMap().entries.map((entry) {
                    final i = entry.key;
                    final widget = entry.value;
                    return _WidgetToggleRow(
                      config: widget,
                      index: i,
                      total: _provider.sortedWidgets.length,
                      onToggle: () =>
                          _provider.toggleWidgetVisibility(widget.widgetId),
                      onMoveUp: i > 0
                          ? () => _provider.reorderWidgets(i, i - 1)
                          : null,
                      onMoveDown: i < _provider.sortedWidgets.length - 1
                          ? () => _provider.reorderWidgets(i, i + 2)
                          : null,
                    );
                  }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _provider.settings.widgetConfigs =
                            AdminCustomizationSettings.defaultWidgetConfigs();
                        _provider.saveSettings();
                      },
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: const Text('Reset Widget Layout'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Sidebar ──
              _SectionCard(
                title: 'Sidebar',
                subtitle: 'Navigation sidebar preferences',
                icon: Icons.view_sidebar_rounded,
                children: [
                  SwitchListTile(
                    title: const Text('Compact Mode'),
                    subtitle: const Text(
                      'Collapse sidebar to icons only',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _provider.settings.sidebarCompact,
                    onChanged: (_) => _provider.toggleSidebarCompact(),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Bottom actions ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      _provider.resetToDefaults();
                      context.readMapThemeProvider.resetToDefault();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All settings reset to defaults'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Reset All to Defaults'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _provider.saveSettings();
                      ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                          content: Text('Settings saved successfully'),
                          backgroundColor: AppTheme.accent,
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Save Changes'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable Sub-Widgets ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:       TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style:       TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style:       TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _ThemeModeSelector({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeChip('Light', 'light', Icons.light_mode_rounded, current, onChanged),
        const SizedBox(width: 8),
        _ModeChip('Dark', 'dark', Icons.dark_mode_rounded, current, onChanged),
        const SizedBox(width: 8),
        _ModeChip('System', 'system', Icons.settings_brightness_rounded, current, onChanged),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String current;
  final ValueChanged<String> onChanged;

  const _ModeChip(this.label, this.value, this.icon, this.current, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: AppTheme.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.stroke,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPalette extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;
  final List<Color> colors;

  const _ColorPalette({
    required this.selected,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final isSelected = color.toARGB32() == selected.toARGB32();
        return GestureDetector(
          onTap: () => onChanged(color),
          child: AnimatedContainer(
            duration: AppTheme.durationFast,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.textPrimary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _ColorPreviewBar extends StatelessWidget {
  final Color primary;
  final Color accent;

  const _ColorPreviewBar({required this.primary, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Button preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Button',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Badge preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Active',
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text preview
          Text(
            'Primary Text',
            style: TextStyle(
              fontSize: 13,
              color: primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FontFamilySelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _FontFamilySelector({
    required this.current,
    required this.onChanged,
  });

  static const fonts = [
    'Inter',
    'Roboto',
    'Outfit',
    'Poppins',
    'Lato',
    'Nunito',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fonts.map((font) {
        final isSelected = current == font;
        return GestureDetector(
          onTap: () => onChanged(font),
          child: AnimatedContainer(
            duration: AppTheme.durationFast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.stroke,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              font,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WidgetToggleRow extends StatelessWidget {
  final DashboardWidgetConfig config;
  final int index;
  final int total;
  final VoidCallback onToggle;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _WidgetToggleRow({
    required this.config,
    required this.index,
    required this.total,
    required this.onToggle,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: config.isVisible ? AppTheme.bgCard : AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        children: [
          // Reorder controls
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onMoveUp,
                child: Icon(
                  Icons.arrow_drop_up_rounded,
                  size: 20,
                  color: onMoveUp != null
                      ? AppTheme.textSecondary
                      : AppTheme.stroke,
                ),
              ),
              GestureDetector(
                onTap: onMoveDown,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: onMoveDown != null
                      ? AppTheme.textSecondary
                      : AppTheme.stroke,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Icon(
            config.icon,
            size: 18,
            color: config.isVisible
                ? AppTheme.primary
                : AppTheme.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              config.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: config.isVisible
                    ? AppTheme.textPrimary
                    : AppTheme.textMuted,
              ),
            ),
          ),
          Switch(
            value: config.isVisible,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}