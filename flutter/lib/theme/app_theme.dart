import 'package:flutter/material.dart';

class AppTheme {
  static const _blue = Color(0xFF2563EB);
  static const _darkBlue = Color(0xFF60A5FA);
  static const _lime = Color(0xFF65A30D);
  static const _darkLime = Color(0xFFA3E635);
  static const _rose = Color(0xFFE11D48);
  static const _darkRose = Color(0xFFFB7185);
  static const _lightBackground = Color(0xFFF5F7FB);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceAlt = Color(0xFFF8FAFC);
  static const _lightSurfaceContainer = Color(0xFFF1F5F9);
  static const _lightSurfaceContainerHigh = Color(0xFFEFF2F7);
  static const _lightSurfaceContainerHighest = Color(0xFFE2E8F0);
  static const _lightBorder = Color(0xFFE2E8F0);
  static const _lightText = Color(0xFF111827);
  static const _lightMutedText = Color(0xFF475569);
  static const _darkBackground = Color(0xFF090D16);
  static const _darkSurface = Color(0xFF111827);
  static const _darkSurfaceAlt = Color(0xFF172033);
  static const _darkSurfaceContainer = Color(0xFF1E293B);
  static const _darkSurfaceContainerHigh = Color(0xFF22314A);
  static const _darkSurfaceContainerHighest = Color(0xFF26344B);
  static const _darkBorder = Color(0xFF26344B);
  static const _darkText = Color(0xFFE5E7EB);
  static const _darkMutedText = Color(0xFFCBD5E1);

  static const _radiusSmall = BorderRadius.all(Radius.circular(10));
  static const _radiusMedium = BorderRadius.all(Radius.circular(16));
  static const _radiusLarge = BorderRadius.all(Radius.circular(22));
  static const _radiusXLarge = BorderRadius.all(Radius.circular(28));
  static const _quickMotion = Duration(milliseconds: 180);

  static const _buttonShape = RoundedSuperellipseBorder(
    borderRadius: _radiusMedium,
  );
  static const _chipShape = RoundedSuperellipseBorder(
    borderRadius: _radiusSmall,
  );
  static const _indicatorShape = RoundedSuperellipseBorder(
    borderRadius: _radiusXLarge,
  );

  static const _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData blueWhite() => _build(Brightness.light);

  static ThemeData blueBlack() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = _expressiveColorScheme(brightness);
    final isDark = brightness == Brightness.dark;
    final borderColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.52 : 0.74,
    );
    final textTheme = _textTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      canvasColor: colorScheme.surfaceContainerLowest,
      fontFamily: 'Roboto',
      pageTransitionsTheme: _pageTransitions,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      hoverColor: colorScheme.primary.withValues(alpha: 0.10),
      focusColor: colorScheme.secondary.withValues(alpha: 0.14),
      highlightColor: colorScheme.tertiary.withValues(alpha: 0.10),
      splashColor: colorScheme.primary.withValues(alpha: 0.10),
      dividerColor: borderColor,
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surfaceContainerLowest,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: colorScheme.tertiary,
        textColor: colorScheme.onTertiary,
        textStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerLow,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
        surfaceTintColor: colorScheme.surfaceTint.withValues(alpha: 0.36),
        margin: EdgeInsets.zero,
        shape: _surfaceShape(borderColor, radius: 22),
      ),
      inputDecorationTheme: _inputDecorationTheme(colorScheme, borderColor),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        selectedColor: colorScheme.onSecondaryContainer,
        selectedTileColor: colorScheme.secondaryContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minTileHeight: 54,
        shape: _surfaceShape(Colors.transparent, radius: 18),
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: 0,
        useIndicator: true,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: _indicatorShape,
        minWidth: 104,
        selectedIconTheme: IconThemeData(
          color: colorScheme.onSecondaryContainer,
          size: 30,
        ),
        unselectedIconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 25,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: _indicatorShape,
        height: 78,
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint,
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => _stateLayer(states, colorScheme.primary),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 29 : 25,
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor:
              colorScheme.onSurface.withValues(alpha: 0.12),
          foregroundColor: colorScheme.onPrimary,
          disabledForegroundColor:
              colorScheme.onSurface.withValues(alpha: 0.38),
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
          shape: _buttonShape,
          animationDuration: _quickMotion,
          backgroundBuilder: _filledButtonBackground(colorScheme),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          disabledBackgroundColor:
              colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor:
              colorScheme.onSurface.withValues(alpha: 0.38),
          surfaceTintColor: colorScheme.surfaceTint,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.36 : 0.12),
          elevation: 1,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
          shape: _buttonShape,
          animationDuration: _quickMotion,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor:
              colorScheme.onSurface.withValues(alpha: 0.38),
          side: BorderSide(color: borderColor),
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
          shape: _buttonShape,
          animationDuration: _quickMotion,
          backgroundBuilder: _quietButtonBackground(colorScheme),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor:
              colorScheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
          shape: _buttonShape,
          animationDuration: _quickMotion,
          backgroundBuilder: _quietButtonBackground(colorScheme),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          disabledForegroundColor:
              colorScheme.onSurface.withValues(alpha: 0.38),
          hoverColor: colorScheme.primary.withValues(alpha: 0.10),
          focusColor: colorScheme.secondary.withValues(alpha: 0.14),
          highlightColor: colorScheme.tertiary.withValues(alpha: 0.14),
          shape: _surfaceShape(Colors.transparent, radius: 18),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          selectedForegroundColor: colorScheme.onSecondaryContainer,
          backgroundColor: colorScheme.surfaceContainerLow,
          selectedBackgroundColor: colorScheme.secondaryContainer,
          disabledBackgroundColor:
              colorScheme.onSurface.withValues(alpha: 0.08),
          disabledForegroundColor:
              colorScheme.onSurface.withValues(alpha: 0.38),
          side: BorderSide(color: borderColor),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
          shape: _buttonShape,
        ),
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.secondaryContainer;
          }
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.tertiaryContainer.withValues(alpha: 0.72);
          }
          if (states.contains(WidgetState.hovered)) {
            return colorScheme.primaryContainer.withValues(alpha: 0.56);
          }
          return colorScheme.surfaceContainerHigh;
        }),
        side: BorderSide(color: borderColor),
        shape: _chipShape,
        showCheckmark: true,
        checkmarkColor: colorScheme.onSecondaryContainer,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w900,
        ),
        iconTheme: IconThemeData(color: colorScheme.primary, size: 18),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.tertiaryContainer,
        foregroundColor: colorScheme.onTertiaryContainer,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 4,
        highlightElevation: 4,
        shape: const RoundedSuperellipseBorder(borderRadius: _radiusLarge),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: _surfaceShape(borderColor, radius: 28),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.48 : 0.16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        modalBackgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        showDragHandle: true,
        dragHandleColor: colorScheme.outline,
        elevation: 0,
        modalElevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
        actionTextColor: colorScheme.inversePrimary,
        elevation: 0,
        showCloseIcon: true,
        closeIconColor: colorScheme.onInverseSurface,
        shape: const RoundedSuperellipseBorder(borderRadius: _radiusMedium),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll<double>(0),
        backgroundColor: WidgetStatePropertyAll<Color>(
          colorScheme.surfaceContainerHigh,
        ),
        surfaceTintColor: WidgetStatePropertyAll<Color>(
          colorScheme.surfaceTint,
        ),
        side:
            WidgetStatePropertyAll<BorderSide>(BorderSide(color: borderColor)),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(_indicatorShape),
        textStyle: WidgetStatePropertyAll<TextStyle?>(
          textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        hintStyle: WidgetStatePropertyAll<TextStyle?>(
          textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        constraints: const BoxConstraints(minHeight: 54),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(
            colorScheme.surfaceContainerHigh,
          ),
          surfaceTintColor: WidgetStatePropertyAll<Color>(
            colorScheme.surfaceTint,
          ),
          shadowColor: WidgetStatePropertyAll<Color>(
            Colors.black.withValues(alpha: isDark ? 0.48 : 0.14),
          ),
          elevation: const WidgetStatePropertyAll<double>(2),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.all(8),
          ),
          side: WidgetStatePropertyAll<BorderSide>(
              BorderSide(color: borderColor)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            _surfaceShape(Colors.transparent, radius: 18),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: _surfaceShape(borderColor, radius: 18),
        elevation: 2,
        menuPadding: const EdgeInsets.all(8),
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: _inputDecorationTheme(colorScheme, borderColor),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(
            colorScheme.surfaceContainerHigh,
          ),
          surfaceTintColor: WidgetStatePropertyAll<Color>(
            colorScheme.surfaceTint,
          ),
          side: WidgetStatePropertyAll<BorderSide>(
              BorderSide(color: borderColor)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            _surfaceShape(Colors.transparent, radius: 18),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onTertiaryContainer;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.tertiaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : borderColor,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => _selectionFill(states, colorScheme),
        ),
        checkColor: WidgetStatePropertyAll<Color>(colorScheme.onTertiary),
        side: BorderSide(color: borderColor, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => _selectionFill(states, colorScheme),
        ),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.tertiaryContainer.withValues(alpha: 0.46);
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: borderColor, width: 1.4),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        secondaryActiveTrackColor: colorScheme.secondary,
        thumbColor: colorScheme.tertiary,
        overlayColor: colorScheme.tertiary.withValues(alpha: 0.14),
        valueIndicatorColor: colorScheme.inverseSurface,
        valueIndicatorTextStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w900,
        ),
        showValueIndicator: ShowValueIndicator.onlyForDiscrete,
        trackHeight: 6,
        trackGap: 6,
        // ignore: deprecated_member_use
        year2023: false,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
        linearMinHeight: 6,
        strokeWidth: 5,
        strokeCap: StrokeCap.round,
        trackGap: 4,
        borderRadius: const BorderRadius.all(Radius.circular(99)),
        stopIndicatorColor: colorScheme.tertiary,
        stopIndicatorRadius: 3,
        // ignore: deprecated_member_use
        year2023: false,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: colorScheme.onSecondaryContainer,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        unselectedLabelStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: ShapeDecoration(
          color: colorScheme.secondaryContainer,
          shape: _surfaceShape(Colors.transparent, radius: 18),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: colorScheme.tertiary,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint,
        headerBackgroundColor: colorScheme.primaryContainer,
        headerForegroundColor: colorScheme.onPrimaryContainer,
        shape: _surfaceShape(borderColor, radius: 28),
        dayShape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
        yearShape: const WidgetStatePropertyAll<OutlinedBorder>(_buttonShape),
        todayBorder: BorderSide(color: colorScheme.tertiary, width: 1.6),
        todayForegroundColor:
            WidgetStatePropertyAll<Color>(colorScheme.tertiary),
        todayBackgroundColor: WidgetStatePropertyAll<Color>(
          colorScheme.tertiaryContainer.withValues(alpha: 0.42),
        ),
        inputDecorationTheme: _inputDecorationTheme(colorScheme, borderColor),
        confirmButtonStyle: FilledButton.styleFrom(shape: _buttonShape),
        cancelButtonStyle: TextButton.styleFrom(shape: _buttonShape),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: _surfaceShape(borderColor, radius: 28),
        dayPeriodColor: colorScheme.secondaryContainer,
        dayPeriodTextColor: colorScheme.onSecondaryContainer,
        dayPeriodBorderSide: BorderSide(color: borderColor),
        dayPeriodShape: _buttonShape,
        dialBackgroundColor: colorScheme.surfaceContainerHighest,
        dialHandColor: colorScheme.primary,
        entryModeIconColor: colorScheme.primary,
        hourMinuteColor: colorScheme.primaryContainer,
        hourMinuteTextColor: colorScheme.onPrimaryContainer,
        hourMinuteShape: const RoundedSuperellipseBorder(
          borderRadius: _radiusLarge,
        ),
        inputDecorationTheme: _inputDecorationTheme(colorScheme, borderColor),
        confirmButtonStyle: FilledButton.styleFrom(shape: _buttonShape),
        cancelButtonStyle: TextButton.styleFrom(shape: _buttonShape),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: colorScheme.inverseSurface,
          shape: const RoundedSuperellipseBorder(borderRadius: _radiusSmall),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static ColorScheme _expressiveColorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: isDark ? _darkBlue : _blue,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      contrastLevel: 0.18,
    );

    return base.copyWith(
      primary: isDark ? _darkBlue : _blue,
      onPrimary: isDark ? const Color(0xFF082F49) : Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
      onPrimaryContainer:
          isDark ? const Color(0xFFDBEAFE) : const Color(0xFF172554),
      primaryFixed: const Color(0xFFDBEAFE),
      primaryFixedDim: const Color(0xFFBFDBFE),
      onPrimaryFixed: const Color(0xFF172554),
      onPrimaryFixedVariant: const Color(0xFF1D4ED8),
      secondary: isDark ? _darkLime : _lime,
      onSecondary: isDark ? const Color(0xFF1A2E05) : const Color(0xFF0F1A03),
      secondaryContainer:
          isDark ? const Color(0xFF365314) : const Color(0xFFECFCCB),
      onSecondaryContainer:
          isDark ? const Color(0xFFECFCCB) : const Color(0xFF1A2E05),
      secondaryFixed: const Color(0xFFECFCCB),
      secondaryFixedDim: const Color(0xFFD9F99D),
      onSecondaryFixed: const Color(0xFF1A2E05),
      onSecondaryFixedVariant: const Color(0xFF3F6212),
      tertiary: isDark ? _darkRose : _rose,
      onTertiary: isDark ? const Color(0xFF4C0519) : Colors.white,
      tertiaryContainer:
          isDark ? const Color(0xFF881337) : const Color(0xFFFFE4E6),
      onTertiaryContainer:
          isDark ? const Color(0xFFFFE4E6) : const Color(0xFF4C0519),
      tertiaryFixed: const Color(0xFFFFE4E6),
      tertiaryFixedDim: const Color(0xFFFECDD3),
      onTertiaryFixed: const Color(0xFF4C0519),
      onTertiaryFixedVariant: const Color(0xFFBE123C),
      surface: isDark ? _darkSurface : _lightSurface,
      onSurface: isDark ? _darkText : _lightText,
      surfaceDim: isDark ? _darkBackground : const Color(0xFFE5E7EB),
      surfaceBright: isDark ? _darkSurfaceContainerHighest : _lightSurface,
      surfaceContainerLowest: isDark ? _darkBackground : _lightBackground,
      surfaceContainerLow: isDark ? _darkSurfaceAlt : _lightSurfaceAlt,
      surfaceContainer: isDark ? _darkSurfaceContainer : _lightSurfaceContainer,
      surfaceContainerHigh:
          isDark ? _darkSurfaceContainerHigh : _lightSurfaceContainerHigh,
      surfaceContainerHighest:
          isDark ? _darkSurfaceContainerHighest : _lightSurfaceContainerHighest,
      onSurfaceVariant: isDark ? _darkMutedText : _lightMutedText,
      outline: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      outlineVariant: isDark ? _darkBorder : _lightBorder,
      surfaceTint: isDark ? _darkBlue : _blue,
      inversePrimary: isDark ? _blue : _darkBlue,
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    ColorScheme colorScheme,
    Color borderColor,
  ) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      hoverColor: colorScheme.primary.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      prefixIconColor: colorScheme.onSurfaceVariant,
      suffixIconColor: colorScheme.onSurfaceVariant,
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.tertiary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.error, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.error, width: 1.8),
      ),
    );
  }

  static RoundedSuperellipseBorder _surfaceShape(
    Color color, {
    double radius = 18,
    double width = 1,
  }) {
    return RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: color, width: width),
    );
  }

  static ButtonLayerBuilder _filledButtonBackground(ColorScheme colorScheme) {
    return (context, states, child) {
      final disabled = states.contains(WidgetState.disabled);
      final pressed = states.contains(WidgetState.pressed);
      final hovered = states.contains(WidgetState.hovered);

      Color backgroundColor;
      if (disabled) {
        backgroundColor = colorScheme.onSurface.withValues(alpha: 0.12);
      } else if (pressed) {
        backgroundColor = colorScheme.primaryContainer;
      } else if (hovered) {
        backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.85);
      } else {
        backgroundColor = colorScheme.primaryContainer;
      }

      return ClipPath.shape(
        shape: _buttonShape,
        child: AnimatedContainer(
          duration: _quickMotion,
          curve: Easing.emphasizedDecelerate,
          decoration: ShapeDecoration(
            color: backgroundColor,
            shape: _buttonShape,
          ),
          child: child,
        ),
      );
    };
  }

  static ButtonLayerBuilder _quietButtonBackground(ColorScheme colorScheme) {
    return (context, states, child) {
      final layer = _stateLayer(states, colorScheme.primary);
      return ClipPath.shape(
        shape: _buttonShape,
        child: AnimatedContainer(
          duration: _quickMotion,
          curve: Easing.emphasizedDecelerate,
          decoration: ShapeDecoration(
            color: layer,
            shape: _buttonShape,
          ),
          child: child,
        ),
      );
    };
  }

  static Color? _stateLayer(Set<WidgetState> states, Color color) {
    if (states.contains(WidgetState.disabled)) return null;
    if (states.contains(WidgetState.pressed)) {
      return color.withValues(alpha: 0.16);
    }
    if (states.contains(WidgetState.focused)) {
      return color.withValues(alpha: 0.14);
    }
    if (states.contains(WidgetState.hovered)) {
      return color.withValues(alpha: 0.10);
    }
    return null;
  }

  static Color? _selectionFill(Set<WidgetState> states, ColorScheme scheme) {
    if (states.contains(WidgetState.disabled)) {
      return scheme.onSurface.withValues(alpha: 0.16);
    }
    if (states.contains(WidgetState.selected)) {
      return scheme.tertiary;
    }
    if (states.contains(WidgetState.hovered)) {
      return scheme.tertiary.withValues(alpha: 0.14);
    }
    return null;
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    final color = colorScheme.onSurface;
    final muted = colorScheme.onSurfaceVariant;

    return TextTheme(
      displayLarge: TextStyle(
        color: color,
        fontSize: 56,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.02,
      ),
      displayMedium: TextStyle(
        color: color,
        fontSize: 44,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.05,
      ),
      displaySmall: TextStyle(
        color: color,
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.08,
      ),
      headlineLarge: TextStyle(
        color: color,
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.10,
      ),
      headlineMedium: TextStyle(
        color: color,
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.12,
      ),
      headlineSmall: TextStyle(
        color: color,
        fontSize: 24,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.16,
      ),
      titleLarge: TextStyle(
        color: color,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.18,
      ),
      titleMedium: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        height: 1.25,
      ),
      titleSmall: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        height: 1.25,
      ),
      bodyLarge: TextStyle(
        color: color,
        fontSize: 16,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        color: color,
        fontSize: 14,
        height: 1.45,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        color: muted,
        fontSize: 12,
        height: 1.35,
        letterSpacing: 0,
      ),
      labelLarge: TextStyle(
        color: color,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        color: muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}
