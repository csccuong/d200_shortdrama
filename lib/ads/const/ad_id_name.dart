import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../main.dart' as app_main;

class MyAdIdName {
  MyAdIdName._();

  static String get appID {
    final isProd = app_main.env == Environment.prod;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    if (isProd) {
      return isIOS
          ? 'ca-app-pub-3940256099942544~1458002511'
          : 'ca-app-pub-9900730300733887~9617844331';
    }
    return isIOS
        ? 'ca-app-pub-3940256099942544~1458002511'
        : 'ca-app-pub-9900730300733887~9617844331';
  }

  static const String appOpenResume = 'appOpenResume';
  static const String bannerSplash = 'bannerSplash';
  static const String interSplash = 'interSplash';
  static const String interSplashHigh = 'interSplashHigh';
  static const String nativeLanguage = 'nativeLanguage';
  static const String nativeLanguageHigh = 'nativeLanguageHigh';
  static const String nativeLanguageClick = 'nativeLanguageClick';
  static const String nativeLanguageClickHigh = 'nativeLanguageClickHigh';
  static const String nativeOnboard1Ad = 'nativeOnboard1Ad';
  static const String nativeOnboardFull1Ad = 'nativeOnboardFull1Ad';
  static const String nativeOnboardFull2Ad = 'nativeOnboardFull2Ad';
  static const String nativeOnboard4Ad = 'nativeOnboard4Ad';
  static const String interAll = 'interAll';
  static const String nativeFull = 'nativeFull';
  static const String rewardedAd = 'rewardedAd';
  static const String interOnboard = 'interOnboard';
  static const String nativeAll = 'nativeAll';
  static const String nativeCollap = 'nativeCollap';
  static const String bannerAll = 'bannerAll';
  static const String nativePip = 'nativePip';
}

enum AdType { nativeExpand, nativeCollapse }
