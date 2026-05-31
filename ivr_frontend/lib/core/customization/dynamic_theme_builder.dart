import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_customization_provider.dart';

/// Dynamically builds a styled [ThemeData] from custom [AdminCustomizationSettings].
class DynamicThemeBuilder {
  static List<String> _fontFallback() {
    final tamil = GoogleFonts.notoSansTamil().fontFamily;
    return [
      if (tamil != null) ...[tamil],
      'Noto Sans Tamil',
      'Noto Sans',
      'sans-serif',
    ];
  }

  static ThemeData buildTheme(AdminCustomizationSettings settings) {
    final isDark = settings.themeMode == 'dark' ||
        (settings.themeMode == 'system' &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    final primary = settings.primaryColor;
    final accent = settings.accentColor;

    // Derived color shades
    final primaryLight = primary.withAlpha(210); // ~0.8 opacity
    final primaryDark = primary.withAlpha(255);

    // Dynamic brand colors based on darkness
    final bgDark = isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F8FC);
    final bgCard = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgSurface = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final stroke = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final strokeStrong = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    const error = Color(0xFFEF4444);

    // Font selection logic
    TextTheme baseTextTheme;
    switch (settings.fontFamily) {
      case 'Roboto':
        baseTextTheme = GoogleFonts.robotoTextTheme();
        break;
      case 'Outfit':
        baseTextTheme = GoogleFonts.outfitTextTheme();
        break;
      case 'Poppins':
        baseTextTheme = GoogleFonts.poppinsTextTheme();
        break;
      case 'Lato':
        baseTextTheme = GoogleFonts.latoTextTheme();
        break;
      case 'Nunito':
        baseTextTheme = GoogleFonts.nunitoTextTheme();
        break;
      case 'Inter':
      default:
        baseTextTheme = GoogleFonts.interTextTheme();
        break;
    }

    // Apply Tamil fallback and font size factor
    final fallback = _fontFallback();
    TextStyle addProps(TextStyle? style, Color color) {
      final base = style ?? const TextStyle();
      return base.copyWith(
        fontFamilyFallback: fallback,
        color: color,
        fontSize: base.fontSize != null ? base.fontSize! * settings.fontScaleFactor : null,
      );
    }

    final scaledTextTheme = baseTextTheme.copyWith(
      displayLarge: addProps(baseTextTheme.displayLarge, textPrimary),
      displayMedium: addProps(baseTextTheme.displayMedium, textPrimary),
      displaySmall: addProps(baseTextTheme.displaySmall, textPrimary),
      headlineLarge: addProps(baseTextTheme.headlineLarge, textPrimary),
      headlineMedium: addProps(baseTextTheme.headlineMedium, textPrimary),
      headlineSmall: addProps(baseTextTheme.headlineSmall, textPrimary),
      titleLarge: addProps(baseTextTheme.titleLarge, textPrimary),
      titleMedium: addProps(baseTextTheme.titleMedium, textPrimary),
      titleSmall: addProps(baseTextTheme.titleSmall, textPrimary),
      bodyLarge: addProps(baseTextTheme.bodyLarge, textPrimary),
      bodyMedium: addProps(baseTextTheme.bodyMedium, textSecondary),
      bodySmall: addProps(baseTextTheme.bodySmall, textMuted),
      labelLarge: addProps(baseTextTheme.labelLarge, textSecondary),
      labelMedium: addProps(baseTextTheme.labelMedium, textSecondary),
      labelSmall: addProps(baseTextTheme.labelSmall, textMuted),
    );

    TextStyle customFontFamilyStyle({
      double? fontSize,
      FontWeight? fontWeight,
      Color? color,
    }) {
      TextStyle base;
      switch (settings.fontFamily) {
        case 'Roboto':
          base = GoogleFonts.roboto(fontSize: fontSize, fontWeight: fontWeight, color: color);
          break;
        case 'Outfit':
          base = GoogleFonts.outfit(fontSize: fontSize, fontWeight: fontWeight, color: color);
          break;
        case 'Poppins':
          base = GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight, color: color);
          break;
        case 'Lato':
          base = GoogleFonts.lato(fontSize: fontSize, fontWeight: fontWeight, color: color);
          break;
        case 'Nunito':
          base = GoogleFonts.nunito(fontSize: fontSize, fontWeight: fontWeight, color: color);
          break;
        case 'Inter':
        default:
          base = GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight, color: color);
          break;
      }
      return base.copyWith(fontFamilyFallback: fallback);
    }

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bgDark,
      textTheme: scaledTextTheme,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primary,
              secondary: accent,
              surface: bgCard,
              error: error,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: Colors.white,
              onError: Colors.white,
            )
          : ColorScheme.light(
              primary: primary,
              secondary: accent,
              surface: bgCard,
              error: error,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: textPrimary,
              onError: Colors.white,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: customFontFamilyStyle(
          fontSize: 20 * settings.fontScaleFactor,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: stroke, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return primary.withAlpha(115);
            }
            if (states.contains(WidgetState.pressed)) return primaryDark;
            if (states.contains(WidgetState.hovered)) return primaryLight;
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.black.withAlpha(25);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withAlpha(20);
            }
            return null;
          }),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 1;
            return 0;
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            customFontFamilyStyle(
              fontSize: 14 * settings.fontScaleFactor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return primary.withAlpha(115);
            }
            if (states.contains(WidgetState.pressed)) return primaryDark;
            if (states.contains(WidgetState.hovered)) return primaryLight;
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.black.withAlpha(25);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withAlpha(20);
            }
            return null;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            customFontFamilyStyle(
              fontSize: 14 * settings.fontScaleFactor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return textMuted;
            if (states.contains(WidgetState.pressed)) return primaryDark;
            if (states.contains(WidgetState.hovered)) return primary;
            return textPrimary;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return primary.withAlpha(35);
            }
            if (states.contains(WidgetState.hovered)) {
              return primary.withAlpha(20);
            }
            return null;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return BorderSide(color: primary, width: 1.2);
            }
            return BorderSide(color: strokeStrong);
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return primaryDark;
            if (states.contains(WidgetState.hovered)) return primary;
            return primaryLight;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return primary.withAlpha(35);
            }
            if (states.contains(WidgetState.hovered)) {
              return primary.withAlpha(20);
            }
            return null;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: customFontFamilyStyle(color: textMuted),
        labelStyle: customFontFamilyStyle(color: textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: customFontFamilyStyle(
          fontSize: 20 * settings.fontScaleFactor,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF111827),
        contentTextStyle: customFontFamilyStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: stroke, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: bgSurface,
        selectedColor: primary.withAlpha(30),
        labelStyle: customFontFamilyStyle(
          color: textSecondary,
          fontSize: 12 * settings.fontScaleFactor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: Colors.transparent,
        iconColor: textSecondary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: bgCard),
      popupMenuTheme: PopupMenuThemeData(
        color: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
