import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/app.dart';

/// User appearance preferences: theme mode and UI language.
///
/// This used to hold colour palettes, typography, map themes, dashboard widget
/// toggles and sidebar settings. All of those are admin branding concerns that
/// live in the Settings hub's Branding tab; this screen is the per-user slice
/// that affects their own session and nothing else.
class AdminCustomizationScreen extends StatefulWidget {
  const AdminCustomizationScreen({super.key});

  @override
  State<AdminCustomizationScreen> createState() =>
      _AdminCustomizationScreenState();
}

class _AdminCustomizationScreenState extends State<AdminCustomizationScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.adminCustomizationProvider;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Theme and language preferences for your session.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // ── Theme Mode ──
              _SectionCard(
                title: 'Theme',
                subtitle: 'Light, dark or follow your system setting',
                icon: Icons.palette_rounded,
                children: [
                  _ThemeModeSelector(
                    current: provider.settings.themeMode,
                    onChanged: provider.updateThemeMode,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Language ──
              _SectionCard(
                title: 'Language',
                subtitle: 'Choose the display language for the interface',
                icon: Icons.translate_rounded,
                children: [
                  _LanguageSelector(
                    current: provider.settings.language,
                    onChanged: provider.updateLanguage,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Bottom actions ──
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    provider.resetToDefaults();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings reset to defaults'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('Reset to Defaults'),
                ),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
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

class _ThemeModeSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _ThemeModeSelector({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _OptionChip(
          label: 'Light',
          value: 'light',
          icon: Icons.light_mode_rounded,
          current: current,
          onTap: onChanged,
        ),
        _OptionChip(
          label: 'Dark',
          value: 'dark',
          icon: Icons.dark_mode_rounded,
          current: current,
          onTap: onChanged,
        ),
        _OptionChip(
          label: 'System',
          value: 'system',
          icon: Icons.settings_brightness_rounded,
          current: current,
          onTap: onChanged,
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _LanguageSelector({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _OptionChip(
          label: 'English',
          value: 'en',
          icon: Icons.language_rounded,
          current: current,
          onTap: onChanged,
        ),
        _OptionChip(
          label: 'தமிழ்',
          value: 'ta',
          icon: Icons.language_rounded,
          current: current,
          onTap: onChanged,
        ),
      ],
    );
  }
}

/// A selectable chip used by both theme mode and language pickers.
class _OptionChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String current;
  final ValueChanged<String> onTap;

  const _OptionChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
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
          mainAxisSize: MainAxisSize.min,
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