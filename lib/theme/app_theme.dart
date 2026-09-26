import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'solar_icons.dart';

export 'app_colors.dart';
export 'app_motion.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

/// The app theme.
///
/// Replaces the ten-line `ThemeData` in `main.dart` that set only
/// `primarySwatch`, a green secondary, Roboto and a card radius — and left
/// every other role to Material 3's default purple seed.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final scheme = AppColors.scheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      textTheme: AppTypography.textTheme,
      scaffoldBackgroundColor: AppColors.field,
      splashFactory: InkSparkle.splashFactory,

      // App bars stay paper with a hairline. They previously picked up M3's
      // elevation tint on scroll, which turned the header lavender.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.heading,
        iconTheme: const IconThemeData(color: AppColors.ink, size: 24),
      ),

      cardTheme: CardThemeData(
        color: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      // A primary action should look like one. Every primary CTA in the app was
      // previously a near-white gradient with coloured text, which read as
      // disabled — including "Upgrade - $9.99/month" on the paywall.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.signal,
          foregroundColor: AppColors.onSignal,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.inkTertiary,
          minimumSize: const Size.fromHeight(52),
          textStyle: AppTypography.label.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.paper,
          minimumSize: const Size.fromHeight(52),
          textStyle: AppTypography.label.copyWith(fontSize: 16),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.signal,
          textStyle: AppTypography.label,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        hintStyle: AppTypography.body.copyWith(color: AppColors.inkTertiary),
        labelStyle: AppTypography.label.copyWith(color: AppColors.inkSecondary),
        floatingLabelStyle: AppTypography.label.copyWith(color: AppColors.signal),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x4,
        ),
        border: _inputBorder(AppColors.border),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(AppColors.signal, width: 2),
        errorBorder: _inputBorder(AppColors.stop),
        focusedErrorBorder: _inputBorder(AppColors.stop, width: 2),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.heading,
        contentTextStyle: AppTypography.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.paper,
        selectedItemColor: AppColors.signal,
        unselectedItemColor: AppColors.inkTertiary,
        selectedLabelStyle: AppTypography.caption.copyWith(color: AppColors.signal),
        unselectedLabelStyle: AppTypography.caption,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // The back and close buttons Flutter draws by itself (every app bar
      // with a previous route) use Solar too, not Material's stock glyphs.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(SolarIcons.altArrowLeftLinear),
        closeButtonIconBuilder: (_) => const Icon(SolarIcons.closeLinear),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );
}
