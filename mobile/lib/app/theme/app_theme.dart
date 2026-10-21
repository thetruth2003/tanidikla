import 'package:flutter/material.dart';

abstract final class AppColors {
  static const turquoise = Color(0xFF18A7A0);
  static const turquoiseDark = Color(0xFF087A78);
  static const turquoiseDeep = Color(0xFF075E5D);
  static const aqua = Color(0xFFDDF4F1);
  static const aquaSoft = Color(0xFFF0FAF8);
  static const canvas = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF172321);
  static const muted = Color(0xFF687773);
  static const outline = Color(0xFFDCE7E4);
  static const owner = Color(0xFFE9F4FF);
  static const rating = Color(0xFFFFB020);
  static const success = Color(0xFF258A55);
  static const danger = Color(0xFFD83A45);
}

abstract final class AppTheme {
  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.turquoise,
      brightness: Brightness.light,
      surface: AppColors.surface,
    );
    final colorScheme = baseScheme.copyWith(
      primary: AppColors.turquoise,
      onPrimary: Colors.white,
      primaryContainer: AppColors.aqua,
      onPrimaryContainer: AppColors.turquoiseDeep,
      secondary: AppColors.turquoiseDark,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.aquaSoft,
      onSecondaryContainer: AppColors.turquoiseDeep,
      tertiary: const Color(0xFF2E7DB6),
      tertiaryContainer: AppColors.owner,
      onTertiaryContainer: const Color(0xFF174F78),
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: const Color(0xFFB8C9C5),
      outlineVariant: AppColors.outline,
      error: AppColors.danger,
    );

    const radius = BorderRadius.all(Radius.circular(14));
    final textTheme = Typography.material2021().black.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: AppColors.muted),
        labelStyle: const TextStyle(color: AppColors.muted),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.outline),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.outline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.turquoise, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: AppColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppColors.turquoise),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.turquoiseDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.aqua,
        disabledColor: AppColors.canvas,
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.turquoise
                : AppColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.ink,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.outline),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.aqua,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.turquoiseDark
                : AppColors.muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.turquoiseDark
                : AppColors.ink,
            size: 23,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.turquoise,
        linearTrackColor: AppColors.aqua,
      ),
    );
  }
}
