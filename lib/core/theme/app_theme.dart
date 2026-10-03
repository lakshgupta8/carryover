import 'package:flutter/material.dart';

/// Gold-on-white palette.
class AppColors {
  AppColors._();

  static const Color ivory = Color(0xFFFFFCF5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color champagne = Color(0xFFFBF4E2);
  static const Color sand = Color(0xFFF3E7C9);
  static const Color line = Color(0xFFEADFC2);

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldBright = Color(0xFFE9CC6A);
  static const Color goldDeep = Color(0xFFB8902A);
  static const Color goldDark = Color(0xFF8A6A14);
  static const Color goldPale = Color(0xFFF6EBC8);

  static const Color ink = Color(0xFF2A2419);
  static const Color inkMuted = Color(0xFF7A6F5C);
  static const Color inkFaint = Color(0xFFB3A88F);

  static const Color error = Color(0xFFB3261E);

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldBright, gold, goldDeep],
  );

  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, champagne],
  );
}

class AppTheme {
  AppTheme._();

  /// Bundled font families (see pubspec.yaml), so the app looks the same
  /// offline and on first launch.
  static const String bodyFont = 'Inter';
  static const String displayFont = 'PlayfairDisplay';

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.goldDark,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.goldPale,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.goldDeep,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.sand,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.gold,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.champagne,
      onTertiaryContainer: AppColors.ink,
      error: AppColors.error,
      onError: AppColors.white,
      errorContainer: Color(0xFFFBE4E1),
      onErrorContainer: Color(0xFF5C1510),
      surface: AppColors.ivory,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.white,
      surfaceContainer: AppColors.champagne,
      surfaceContainerHigh: AppColors.sand,
      surfaceContainerHighest: AppColors.sand,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
      shadow: Color(0x33000000),
      scrim: Color(0x66000000),
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.ivory,
      inversePrimary: AppColors.goldBright,
      surfaceTint: AppColors.gold,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: bodyFont,
    );
    final body = base.textTheme;

    TextStyle? display(TextStyle? s, {FontWeight weight = FontWeight.w600}) =>
        s?.copyWith(fontFamily: displayFont, fontWeight: weight);

    final textTheme = body
        .copyWith(
          displayLarge: display(body.displayLarge, weight: FontWeight.w700),
          displayMedium: display(body.displayMedium, weight: FontWeight.w700),
          displaySmall: display(body.displaySmall, weight: FontWeight.w700),
          headlineLarge: display(body.headlineLarge),
          headlineMedium: display(body.headlineMedium),
          headlineSmall: display(body.headlineSmall),
          titleLarge: display(body.titleLarge),
        )
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    final roundedBorder = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.line),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ivory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: roundedBorder,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.goldPale,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.goldDark
                : AppColors.inkMuted,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.sand,
          disabledForegroundColor: AppColors.inkFaint,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.2),
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldDark,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.inkFaint),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.goldPale,
        side: const BorderSide(color: AppColors.line),
        labelStyle: textTheme.labelLarge?.copyWith(color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.white : AppColors.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.gold : AppColors.sand,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.ivory),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.gold,
        linearTrackColor: AppColors.sand,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.ink,
        elevation: 2,
      ),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.goldDark),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.white,
        dialBackgroundColor: AppColors.champagne,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.goldPale : AppColors.champagne,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
