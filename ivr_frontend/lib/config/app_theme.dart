import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 20;
  static const double spaceXl = 24;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const Duration durationFast = Duration(milliseconds: 140);
  static const Duration durationNormal = Duration(milliseconds: 220);

  static List<String> _fontFallback() {
    final tamil = GoogleFonts.notoSansTamil().fontFamily;
    return [
      if (tamil != null) tamil,
      'Noto Sans Tamil',
      'Noto Sans',
      'sans-serif',
    ];
  }

  static TextStyle _inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    ).copyWith(fontFamilyFallback: _fontFallback());
  }

  static TextTheme _withFontFallback(TextTheme textTheme) {
    final fallback = _fontFallback();
    TextStyle? add(TextStyle? s) => s?.copyWith(fontFamilyFallback: fallback);
    return textTheme.copyWith(
      displayLarge: add(textTheme.displayLarge),
      displayMedium: add(textTheme.displayMedium),
      displaySmall: add(textTheme.displaySmall),
      headlineLarge: add(textTheme.headlineLarge),
      headlineMedium: add(textTheme.headlineMedium),
      headlineSmall: add(textTheme.headlineSmall),
      titleLarge: add(textTheme.titleLarge),
      titleMedium: add(textTheme.titleMedium),
      titleSmall: add(textTheme.titleSmall),
      bodyLarge: add(textTheme.bodyLarge),
      bodyMedium: add(textTheme.bodyMedium),
      bodySmall: add(textTheme.bodySmall),
      labelLarge: add(textTheme.labelLarge),
      labelMedium: add(textTheme.labelMedium),
      labelSmall: add(textTheme.labelSmall),
    );
  }

  // Brand
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // Semantic
  static const Color accent = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // Light Enterprise Palette
  static const Color bgDark = Color(0xFFF6F8FC);
  static const Color bgCard = Colors.white;
  static const Color bgSurface = Color(0xFFF1F5F9);
  static const Color bgElevated = Color(0xFFE2E8F0);
  static const Color stroke = Color(0xFFE2E8F0);
  static const Color strokeStrong = Color(0xFFCBD5E1);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);

  static const Color dividerColor = stroke;

  static Color statusColor(String status) {
    switch (status) {
      case 'ready':
      case 'resolved':
      case 'closed':
      case 'approved':
        return accent;
      case 'pending':
      case 'published':
      case 'field_verification':
        return warning;
      case 'failed':
      case 'rejected':
        return error;
      case 'draft':
      default:
        return textMuted;
    }
  }

  // ── Gradients ──────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softCardGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  // ── Theme Data ────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final textTheme = _withFontFallback(
      GoogleFonts.interTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgDark,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
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
        titleTextStyle: _inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: stroke, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled))
              return primary.withValues(alpha: 0.45);
            if (states.contains(WidgetState.pressed)) return primaryDark;
            if (states.contains(WidgetState.hovered)) return primaryLight;
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed))
              return Colors.black.withValues(alpha: 0.10);
            if (states.contains(WidgetState.hovered))
              return Colors.white.withValues(alpha: 0.08);
            return null;
          }),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            if (states.contains(WidgetState.hovered)) return 1;
            return 0;
          }),
          animationDuration: durationFast,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            _inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled))
              return primary.withValues(alpha: 0.45);
            if (states.contains(WidgetState.pressed)) return primaryDark;
            if (states.contains(WidgetState.hovered)) return primaryLight;
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed))
              return Colors.black.withValues(alpha: 0.10);
            if (states.contains(WidgetState.hovered))
              return Colors.white.withValues(alpha: 0.08);
            return null;
          }),
          animationDuration: durationFast,
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            _inter(fontSize: 14, fontWeight: FontWeight.w600),
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
            if (states.contains(WidgetState.pressed))
              return primary.withValues(alpha: 0.14);
            if (states.contains(WidgetState.hovered))
              return primary.withValues(alpha: 0.08);
            return null;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return const BorderSide(color: primary, width: 1.2);
            }
            return const BorderSide(color: strokeStrong);
          }),
          animationDuration: durationFast,
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
            if (states.contains(WidgetState.pressed))
              return primary.withValues(alpha: 0.14);
            if (states.contains(WidgetState.hovered))
              return primary.withValues(alpha: 0.08);
            return null;
          }),
          animationDuration: durationFast,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: _inter(color: textMuted),
        labelStyle: _inter(color: textSecondary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: _inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF111827),
        contentTextStyle: _inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: stroke, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: bgSurface,
        selectedColor: primary.withValues(alpha: 0.12),
        labelStyle: _inter(color: textSecondary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        tileColor: Colors.transparent,
        iconColor: textSecondary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: bgCard),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        dataRowColor: WidgetStateProperty.all(Colors.white),
        headingTextStyle: _inter(
          color: textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        dataTextStyle: _inter(color: textPrimary, fontSize: 13),
        dividerThickness: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: stroke),
          ),
        ),
      ),
    );
  }
}
