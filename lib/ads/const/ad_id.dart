import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import 'ad_id_name.dart';

bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

Map<String, Map<String, String>> get myAdsId => {
      Environment.dev: _isIOS
          ? {
              MyAdIdName.appOpenResume:
                  'ca-app-pub-3940256099942544/5575463023',
              MyAdIdName.bannerSplash:
                  'ca-app-pub-3940256099942544/2934735716',
              MyAdIdName.interSplash:
                  'ca-app-pub-3940256099942544/4411468910',
              MyAdIdName.interSplashHigh:
                  'ca-app-pub-3940256099942544/4411468910',
              MyAdIdName.nativeLanguage:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeLanguageHigh:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeLanguageClick:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeLanguageClickHigh:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeOnboard1Ad:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeOnboardFull1Ad:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeOnboardFull2Ad:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeOnboard4Ad:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.interAll: 'ca-app-pub-3940256099942544/4411468910',
              MyAdIdName.rewardedAd:
                  'ca-app-pub-3940256099942544/1712485313',
              MyAdIdName.nativeBanner:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.interOnboard:
                  'ca-app-pub-3940256099942544/4411468910',
              MyAdIdName.nativeHome:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeFull:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeAll:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeDramaPopup:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.nativeCollap:
                  'ca-app-pub-3940256099942544/3986624511',
              MyAdIdName.bannerAll:
                  'ca-app-pub-3940256099942544/2934735716',
              MyAdIdName.nativePip:
                  'ca-app-pub-3940256099942544/3986624511',
            }
          : {
              MyAdIdName.appOpenResume:
                  'ca-app-pub-3940256099942544/9257395921',
              MyAdIdName.bannerSplash:
                  'ca-app-pub-3940256099942544/6300978111',
              MyAdIdName.interSplash:
                  'ca-app-pub-3940256099942544/1033173712',
              MyAdIdName.interSplashHigh:
                  'ca-app-pub-3940256099942544/1033173712',
              MyAdIdName.nativeLanguage:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeLanguageHigh:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeLanguageClick:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeLanguageClickHigh:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeOnboard1Ad:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeOnboardFull1Ad:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeOnboardFull2Ad:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeOnboard4Ad:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.interAll: 'ca-app-pub-3940256099942544/1033173712',
              MyAdIdName.rewardedAd:
                  'ca-app-pub-3940256099942544/5224354917',
              MyAdIdName.nativeBanner:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.interOnboard:
                  'ca-app-pub-3940256099942544/1033173712',
              MyAdIdName.nativeHome:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeFull:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeAll:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeDramaPopup:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeCollap:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.bannerAll:
                  'ca-app-pub-3940256099942544/6300978111',
              MyAdIdName.nativePip:
                  'ca-app-pub-3940256099942544/2247696110',
            },
      // Replace with production AdMob unit IDs for DXX ShortDrama when releasing
      Environment.prod: _isIOS
          ? {}
          : {
              MyAdIdName.appOpenResume:
                  'ca-app-pub-3940256099942544/9257395921',
              MyAdIdName.bannerSplash:
                  'ca-app-pub-3940256099942544/6300978111',
              MyAdIdName.interSplashHigh:
                  'ca-app-pub-3940256099942544/1033173712',
              MyAdIdName.interSplash:
                  'ca-app-pub-3940256099942544/1033173712',
              MyAdIdName.nativeLanguageHigh:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeLanguage:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeLanguageClick:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeLanguageClickHigh:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeOnboard1Ad:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeOnboardFull1Ad:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeOnboardFull2Ad:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeOnboard4Ad:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.interOnboard:
                  'ca-app-pub-3940256099942544/1033173712',
              MyAdIdName.nativeHome:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeAll:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeDramaPopup:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeCollap:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.bannerAll:
                  'ca-app-pub-3940256099942544/6300978111',
              MyAdIdName.nativePip:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.interAll: 'ca-app-pub-3940256099942544/1033173712',
              MyAdIdName.rewardedAd:
                  'ca-app-pub-3940256099942544/5224354917',
              MyAdIdName.nativeBanner:
                  'ca-app-pub-3940256099942544/2247696110',
              MyAdIdName.nativeFull:
                  'ca-app-pub-3940256099942544/2247696110',
            },
    };
