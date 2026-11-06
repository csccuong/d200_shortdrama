import 'package:flutter/material.dart';
import '../utils/screen_utils.dart';

export 'app_colors.dart';
export 'app_text_styles.dart';

/// Global Theme Configuration for Android & iOS.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.gold,
        surface: AppColors.surfaceSheet,
      ),
      pageTransitionsTheme: AppScreenUtils.pageTransitionsTheme,
      splashFactory: AppScreenUtils.isIOS
          ? NoSplash.splashFactory
          : InkSparkle.splashFactory,
      useMaterial3: true,
    );
  }
}
