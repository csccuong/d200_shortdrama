import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../ads/const/ad_id.dart';
import '../../ads/const/ad_id_name.dart';
import '../constants/app_constants.dart';

class FirebaseHelper {
  FirebaseHelper._();

  static bool get isReady => Firebase.apps.isNotEmpty;

  static FirebaseAnalytics? get analyticsOrNull =>
      isReady ? FirebaseAnalytics.instance : null;

  static const String languageView = 'language_view';
  static const String languageFoView = 'language_fo_view';
  static const String mainView = 'main_view';
  static const String onboard1View = 'onboard1_view';
  static const String onboard2View = 'onboard2_view';
  static const String onboard3View = 'onboard3_view';
  static const String onboard4View = 'onboard4_view';

  static void logLanguageView({bool isFirstLaunch = false}) {
    setTrackingScreenName('LanguageActivity');
    logEventName(isFirstLaunch ? languageFoView : languageView);
  }

  static Future<void> setTrackingScreenName(String screenName) async {
    if (!isReady) return;
    try {
      await FirebaseAnalytics.instance.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
    } catch (e) {
      debugPrint('FirebaseHelper setTrackingScreenName error: $e');
    }
  }

  static Future<void> logEventName(String eventName, {String param = ''}) async {
    if (!isReady) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: eventName,
        parameters: {'param': param},
      );
    } catch (e) {
      debugPrint('FirebaseHelper logEventName error: $e');
    }
  }

  static String? getAdPlacementEventName(
    String? adUnitId, {
    String? adIdName,
    AdUnitType? adUnitType,
  }) {
    if (adUnitId == null && adIdName == null) return null;

    String? keyName = adIdName;
    if (keyName == null || keyName.startsWith('ca-app-pub-')) {
      final searchId = adUnitId ?? adIdName;
      final prodMap = myAdsId[Environment.prod] ?? const {};
      final devMap = myAdsId[Environment.dev] ?? const {};

      keyName = null;
      prodMap.forEach((key, val) {
        if (val == searchId && keyName == null) keyName = key;
      });
      if (keyName == null) {
        devMap.forEach((key, val) {
          if (val == searchId && keyName == null) keyName = key;
        });
      }
    }

    switch (keyName) {
      case MyAdIdName.appOpenResume:
        return 'resume_open_app';
      case MyAdIdName.bannerSplash:
        return 'banner_splash_view';
      case MyAdIdName.interSplashHigh:
        return 'inter_splash_view';
      case MyAdIdName.interSplash:
        return 'inter_splash_view';
      case MyAdIdName.interAll:
        return 'inters_ad_view';
      case MyAdIdName.nativeLanguage:
        return 'native_language_view';
      case MyAdIdName.nativeLanguageHigh:
        return 'native_language_view';
      case MyAdIdName.nativeLanguageClick:
        return 'native_language_click_view';
      case MyAdIdName.nativeLanguageClickHigh:
        return 'native_language_click_view';
      case MyAdIdName.nativeOnboard1Ad:
        return 'native_ob_1_view';
      case MyAdIdName.nativeOnboardFull1Ad:
        return 'native_ob_full_1_2_view';
      case MyAdIdName.nativeOnboardFull2Ad:
        return 'native_ob_full_2_3_view';
      case MyAdIdName.nativeOnboard4Ad:
        return 'native_ob_4_view';
      case MyAdIdName.interOnboard:
        return 'inter_onboarding_view';
      case MyAdIdName.nativeFull:
        return 'native_full_view';
      case MyAdIdName.nativeAll:
        return 'native_all_view';
      case MyAdIdName.nativeCollap:
        return 'native_collap_view';
      case MyAdIdName.bannerAll:
        return 'banner_all_view';
      case MyAdIdName.nativePip:
        return 'native_pip_view';
      case MyAdIdName.rewardedAd:
        return 'rewarded_ad_view';
      default:
        return null;
    }
  }

  static Future<void> logAdmobAdImpression({
    required Ad ad,
    String? adIdName,
    AdUnitType? adUnitType,
  }) async {
    final analytics = analyticsOrNull;
    if (analytics == null) return;
    try {
      final placementEvent = getAdPlacementEventName(
        ad.adUnitId,
        adIdName: adIdName,
        adUnitType: adUnitType,
      );
      if (placementEvent != null) {
        await analytics.logEvent(name: placementEvent);
      }

      await analytics.logAdImpression(
        adFormat: ad is BannerAd
            ? 'Banner'
            : (ad is AppOpenAd
                ? 'OpenAd'
                : (ad is NativeAd ? 'Native' : 'Interstitial')),
        adPlatform: 'Admob',
        adSource: ad.responseInfo?.loadedAdapterResponseInfo?.adSourceName,
        adUnitName: ad.adUnitId,
        currency: 'USD',
      );
    } catch (e) {
      debugPrint('FirebaseHelper logAdmobAdImpression error: $e');
    }
  }
}
