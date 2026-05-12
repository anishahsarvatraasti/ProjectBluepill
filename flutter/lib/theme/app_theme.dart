import 'package:flutter/material.dart';

class AppTheme {
  static const _blue = Color(0xFF2563EB);
  static const _teal = Color(0xFF0F766E);
  static const _amber = Color(0xFFF59E0B);
  static const _lightBackground = Color(0xFFF5F7FB);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceAlt = Color(0xFFF8FAFC);
  static const _lightBorder = Color(0xFFE2E8F0);
  static const _lightText = Color(0xFF111827);
  static const _darkBackground = Color(0xFF090D16);
  static const _darkSurface = Color(0xFF111827);
  static const _darkSurfaceAlt = Color(0xFF172033);
  static const _darkBorder = Color(0xFF26344B);
  static const _darkText = Color(0xFFE5E7EB);

  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    },
  );

  static ThemeData blueWhite() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _blue,
        brightness: Brightness.light,
        primary: _blue,
        secondary: _teal,
        tertiary: _amber,
        surface: _lightSurface,
        onSurface: _lightText,
      ),
      scaffoldBackgroundColor: _lightBackground,
      fontFamily: 'Roboto',
      pageTransitionsTheme: _pageTransitions,
      hoverColor: _blue.withValues(alpha: 0.10),
      dividerTheme: const DividerThemeData(color: _lightBorder, thickness: 1),
      textTheme: _textTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _lightBackground,
        foregroundColor: _lightText,
        titleTextStyle: TextStyle(
          color: _lightText,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: _lightSurface,
        shadowColor: const Color(0x14101828),
        surfaceTintColor: _lightSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.6),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: Color(0xFFDBEAFE),
        indicatorShape: StadiumBorder(),
        minWidth: 104,
        selectedIconTheme: IconThemeData(color: _blue, size: 30),
        unselectedIconTheme: IconThemeData(color: Color(0xFF334155), size: 26),
        selectedLabelTextStyle: TextStyle(
          color: _blue,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Color(0xFF334155),
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: const Color(0xFFDBEAFE),
        height: 72,
        elevation: 0,
        surfaceTintColor: _lightSurface,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return _blue.withValues(alpha: 0.10);
          }
          if (states.contains(WidgetState.pressed)) {
            return _blue.withValues(alpha: 0.14);
          }
          return null;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: states.contains(WidgetState.selected) ? 28 : 25,
            color: states.contains(WidgetState.selected)
                ? _blue
                : const Color(0xFF334155),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? _blue
                : const Color(0xFF334155),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: _lightBorder),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurfaceAlt,
        selectedColor: const Color(0xFFDBEAFE),
        side: const BorderSide(color: _lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 1,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: _lightSurface,
        surfaceTintColor: _lightSurface,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData blueBlack() {
    const seed = Color(0xFF60A5FA);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        surface: _darkSurface,
        primary: seed,
        secondary: const Color(0xFF2DD4BF),
        tertiary: const Color(0xFFFBBF24),
        onSurface: _darkText,
      ),
      scaffoldBackgroundColor: _darkBackground,
      fontFamily: 'Roboto',
      pageTransitionsTheme: _pageTransitions,
      hoverColor: seed.withValues(alpha: 0.18),
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _darkBackground,
        foregroundColor: _darkText,
        titleTextStyle: TextStyle(
          color: _darkText,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: _darkSurface,
        shadowColor: const Color(0x66000000),
        surfaceTintColor: _darkSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: seed, width: 1.6),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: _darkSurface,
        indicatorColor: Color(0xFF1E3A8A),
        indicatorShape: StadiumBorder(),
        minWidth: 104,
        selectedIconTheme: IconThemeData(color: Color(0xFF93C5FD), size: 30),
        unselectedIconTheme: IconThemeData(color: Color(0xFFCBD5E1), size: 26),
        selectedLabelTextStyle: TextStyle(
          color: Color(0xFFBFDBFE),
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Color(0xFFCBD5E1),
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurface,
        indicatorColor: const Color(0xFF1E3A8A),
        height: 72,
        elevation: 0,
        surfaceTintColor: _darkSurface,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return seed.withValues(alpha: 0.20);
          }
          if (states.contains(WidgetState.pressed)) {
            return seed.withValues(alpha: 0.24);
          }
          return null;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: states.contains(WidgetState.selected) ? 28 : 25,
            color: states.contains(WidgetState.selected)
                ? const Color(0xFF93C5FD)
                : const Color(0xFFCBD5E1),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFBFDBFE)
                : const Color(0xFFCBD5E1),
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: _darkBorder),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceAlt,
        selectedColor: const Color(0xFF1E3A8A),
        side: const BorderSide(color: _darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 1,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: _darkSurface,
        surfaceTintColor: _darkSurface,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: _darkBorder, thickness: 1),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final color = brightness == Brightness.dark ? _darkText : _lightText;
    final muted = brightness == Brightness.dark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475569);

    return TextTheme(
      headlineMedium: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(color: color, height: 1.45, letterSpacing: 0),
      bodyMedium: TextStyle(color: color, height: 1.45, letterSpacing: 0),
      bodySmall: TextStyle(color: muted, height: 1.35, letterSpacing: 0),
      labelLarge: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}
