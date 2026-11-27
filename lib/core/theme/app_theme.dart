import 'package:flutter/material.dart';

/// Dark-first cinema theme optimized for low-glare video browsing and playback.
abstract final class AppTheme {
  static const Color background = Color(0xFF0A0C10);
  static const Color surface = Color(0xFF131720);
  static const Color surfaceElevated = Color(0xFF1B2130);
  static const Color surfaceHighlight = Color(0xFF252D40);
  static const Color accent = Color(0xFF38BDF8);
  static const Color accentSecondary = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFF3F6FC);
  static const Color textSecondary = Color(0xFF9AA5B8);
  static const Color divider = Color(0xFF232A3B);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: accent,
      onPrimary: Color(0xFF05131E),
      secondary: accentSecondary,
      onSecondary: Color(0xFF1E1302),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceElevated,
      error: danger,
      onError: Colors.white,
      outline: divider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: divider, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.16),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
