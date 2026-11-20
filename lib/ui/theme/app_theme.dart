import 'package:flutter/material.dart';

class AppTheme {
  static const Color seedBlue = Color(0xFF1D4ED8);
  static const String fontFamily = 'PlusJakartaSans';
  static const List<String> fontFallback = ['Roboto'];

  /// Exact Stitch "Inha Campus Portal" Material 3 Expressive light ColorScheme.
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0037B0),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF1D4ED8),
    onPrimaryContainer: Color(0xFFCAD3FF),
    primaryFixed: Color(0xFFDCE1FF),
    primaryFixedDim: Color(0xFFB7C4FF),
    onPrimaryFixed: Color(0xFF001551),
    onPrimaryFixedVariant: Color(0xFF0039B5),
    secondary: Color(0xFF006398),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFF5BB8FE),
    onSecondaryContainer: Color(0xFF00476E),
    secondaryFixed: Color(0xFFCCE5FF),
    secondaryFixedDim: Color(0xFF93CCFF),
    onSecondaryFixed: Color(0xFF001D31),
    onSecondaryFixedVariant: Color(0xFF004B73),
    tertiary: Color(0xFF7C2900),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFA33900),
    onTertiaryContainer: Color(0xFFFFC9B6),
    tertiaryFixed: Color(0xFFFFDBCE),
    tertiaryFixedDim: Color(0xFFFFB599),
    onTertiaryFixed: Color(0xFF370E00),
    onTertiaryFixedVariant: Color(0xFF7F2B00),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFFAF8FF),
    onSurface: Color(0xFF131B2E),
    onSurfaceVariant: Color(0xFF434655),
    surfaceDim: Color(0xFFD2D9F4),
    surfaceBright: Color(0xFFFAF8FF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF2F3FF),
    surfaceContainer: Color(0xFFEAEDFF),
    surfaceContainerHigh: Color(0xFFE2E7FF),
    surfaceContainerHighest: Color(0xFFDAE2FD),
    outline: Color(0xFF747686),
    outlineVariant: Color(0xFFC4C5D7),
    inverseSurface: Color(0xFF283044),
    onInverseSurface: Color(0xFFEEF0FF),
    inversePrimary: Color(0xFFB7C4FF),
    surfaceTint: Color(0xFF2151DA),
  );

  /// Harmonious dark ColorScheme layered on deep indigo-slate surfaces.
  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: seedBlue,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    surface: const Color(0xFF0E1320),
    surfaceDim: const Color(0xFF0A0E19),
    surfaceBright: const Color(0xFF1F273D),
    surfaceContainerLowest: const Color(0xFF161C2E),
    surfaceContainerLow: const Color(0xFF131828),
    surfaceContainer: const Color(0xFF1C2338),
    surfaceContainerHigh: const Color(0xFF242C44),
    surfaceContainerHighest: const Color(0xFF2E3856),
    onSurface: const Color(0xFFEEF1FF),
    onSurfaceVariant: const Color(0xFFB8C0D9),
    outline: const Color(0xFF838BA4),
    outlineVariant: const Color(0xFF39425E),
  );

  static TextStyle _txt(
    double size,
    FontWeight weight,
    double heightPx, {
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: size,
      fontWeight: weight,
      height: heightPx / size,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme buildTextTheme(ColorScheme cs) {
    final base = TextTheme(
      displayLarge: _txt(57, FontWeight.w800, 64, letterSpacing: -0.25),
      displayMedium: _txt(45, FontWeight.w700, 52),
      displaySmall: _txt(36, FontWeight.w700, 44),
      headlineLarge: _txt(32, FontWeight.w700, 40),
      headlineMedium: _txt(26, FontWeight.w700, 34),
      headlineSmall: _txt(24, FontWeight.w600, 32),
      titleLarge: _txt(22, FontWeight.w600, 28),
      titleMedium: _txt(16, FontWeight.w600, 24, letterSpacing: 0.15),
      titleSmall: _txt(14, FontWeight.w600, 20, letterSpacing: 0.1),
      bodyLarge: _txt(16, FontWeight.w400, 24, letterSpacing: 0.3),
      bodyMedium: _txt(14, FontWeight.w400, 20, letterSpacing: 0.2),
      bodySmall: _txt(12, FontWeight.w400, 16, letterSpacing: 0.3),
      labelLarge: _txt(14, FontWeight.w600, 20, letterSpacing: 0.1),
      labelMedium: _txt(12, FontWeight.w600, 16, letterSpacing: 0.4),
      labelSmall: _txt(11, FontWeight.w600, 16, letterSpacing: 0.4),
    );
    return base.apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    );
  }

  static ThemeData buildTheme(ColorScheme cs) {
    final textTheme = buildTextTheme(cs);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      fontFamily: fontFamily,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primaryContainer,
        indicatorShape: const StadiumBorder(),
        height: 74,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? cs.onSurface : cs.onSurfaceVariant,
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Icon(Icons.check_rounded, size: 14, color: cs.primary);
          }
          return Icon(Icons.close_rounded,
              size: 14, color: cs.onSurfaceVariant);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: cs.onInverseSurface,
        ),
        shape: const StadiumBorder(),
      ),
    );
  }
}
