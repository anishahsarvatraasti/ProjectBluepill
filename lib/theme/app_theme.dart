import 'package:flutter/material.dart';

class AppTheme {
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
    const seed = Color(0xFF2563EB);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      fontFamily: 'Roboto',
      pageTransitionsTheme: _pageTransitions,
      hoverColor: seed.withValues(alpha: 0.14),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFFF7F9FC),
        foregroundColor: Color(0xFF101828),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shadowColor: const Color(0x1A101828),
        surfaceTintColor: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFDBEAFE),
        indicatorShape: StadiumBorder(),
        minWidth: 104,
        selectedIconTheme: IconThemeData(color: seed, size: 30),
        unselectedIconTheme: IconThemeData(color: Color(0xFF334155), size: 26),
        selectedLabelTextStyle: TextStyle(
          color: seed,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Color(0xFF334155),
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        indicatorColor: const Color(0xFFDBEAFE),
        height: 80,
        elevation: 6,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return seed.withValues(alpha: 0.16);
          }
          if (states.contains(WidgetState.pressed)) {
            return seed.withValues(alpha: 0.20);
          }
          return null;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: states.contains(WidgetState.selected) ? 28 : 25,
            color: states.contains(WidgetState.selected)
                ? seed
                : const Color(0xFF334155),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? seed
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData blueBlack() {
    const seed = Color(0xFF3B82F6);
    const background = Color(0xFF070B14);
    const surface = Color(0xFF0D1321);
    const border = Color(0xFF243044);
    const text = Color(0xFFE5E7EB);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        surface: surface,
        primary: seed,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      pageTransitionsTheme: _pageTransitions,
      hoverColor: seed.withValues(alpha: 0.18),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: text,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: surface,
        shadowColor: const Color(0x66000000),
        surfaceTintColor: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surface,
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
        backgroundColor: const Color(0xFF111827),
        indicatorColor: const Color(0xFF1E3A8A),
        height: 80,
        elevation: 8,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: border),
    );
  }
}
