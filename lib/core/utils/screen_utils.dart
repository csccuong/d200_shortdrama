import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

export 'package:flutter_screenutil/flutter_screenutil.dart';
export '../theme/app_theme.dart';

/// Cross-platform Screen & Platform Utilities for Android and iOS.
///
/// Design reference size: 390 x 844 (iPhone 14/15/16 Pro & modern 9:19.5 Android phones).
class AppScreenUtils {
  AppScreenUtils._();

  static const Size designSize = Size(390, 844);

  /// True when running on iOS (iPhone / iPad).
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// True when running on Android.
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Human-readable platform label for diagnostics/profile UI.
  static String get platformLabel {
    if (isIOS) return 'iOS (AVPlayer • Cupertino)';
    if (isAndroid) return 'Android (ExoPlayer • Material 3)';
    return defaultTargetPlatform.name;
  }

  /// System UI overlay style properly configured for BOTH Android and iOS.
  /// Note: iOS `statusBarBrightness: Brightness.dark` renders white status bar text/icons,
  /// whereas Android uses `statusBarIconBrightness: Brightness.light`.
  static const SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: AppColors.transparent,
    statusBarIconBrightness: Brightness.light, // Android: white icons
    statusBarBrightness: Brightness.dark, // iOS: white icons
    systemNavigationBarColor: AppColors.bottomBarBg, // Android bottom gesture bar
    systemNavigationBarIconBrightness: Brightness.light,
  );

  /// Configure orientation and system bars for both Android and iOS.
  static Future<void> configureSystemUI() async {
    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// True if the screen is a tablet / iPad (`shortestSide >= 600`).
  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 600;
  }

  /// Responsive grid columns for drama poster grids (3 columns on phones).
  static int posterGridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return 5;
    if (width >= 600) return 4;
    return 3;
  }

  /// Responsive grid columns for Watchlist cards.
  static int watchlistGridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return 5;
    if (width >= 600) return 4;
    return 3;
  }

  /// Responsive grid columns for Episode selector sheet.
  static int episodeGridColumns(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) return 8;
    return 5;
  }

  /// Top safe area inset (Notch / Dynamic Island / Android cutout).
  static double topSafeInset(BuildContext context) {
    return MediaQuery.paddingOf(context).top;
  }

  /// Bottom safe area inset (iOS Home Indicator / Android gesture bar).
  static double bottomSafeInset(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return bottom > 0 ? bottom : (isIOS ? 16.h : 8.h);
  }

  /// Platform-adaptive scroll physics (`BouncingScrollPhysics` on iOS, `ClampingScrollPhysics` on Android).
  static ScrollPhysics get adaptiveScrollPhysics {
    if (isIOS) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  /// Platform-adaptive page route:
  /// - iOS: `CupertinoPageRoute` (enables native interactive swipe-back from left edge)
  /// - Android: `MaterialPageRoute`
  static PageRoute<T> adaptivePageRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) {
    if (isIOS) {
      return CupertinoPageRoute<T>(
        builder: builder,
        settings: settings,
        fullscreenDialog: fullscreenDialog,
      );
    }
    return MaterialPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }

  /// Global theme page transitions matching native Android & iOS behavior.
  static const PageTransitionsTheme pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    },
  );
}
