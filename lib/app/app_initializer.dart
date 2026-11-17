import 'dart:async';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';

import '../ads/const/ad_id_extension.dart';
import '../ads/const/ad_id_name.dart';
import '../ads/loading/ad_loading_page.dart';
import '../ads/manager/my_ad_id_manager.dart';
import '../ads/placement/show_placement_ad.dart';
import '../core/constants/app_constants.dart';
import '../core/helper/firebase_helper.dart';
import '../core/utils/screen_utils.dart';
import '../main.dart' as app_main;
import '../services/ads_service.dart';
import '../services/firebase_remote_config_service.dart';
import '../services/shared_preference_service.dart';

class AppInitializer {
  AppInitializer._();

  static bool _initialized = false;
  static _RemoteConfigLifecycleObserver? _rcObserver;

  static Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_initialized) return;
    _initialized = true;

    if (!AppConstants.isFlutterTest && _rcObserver == null) {
      _rcObserver = _RemoteConfigLifecycleObserver();
      WidgetsBinding.instance.addObserver(_rcObserver!);
    }

    // Load package info and shared preferences in parallel to minimize cold-start delay
    final results = await Future.wait([
      AppConstants.loadPackageInfo(),
      AdsService.initOrganic(),
      SharedPreferenceService.getIsPremiumUser(),
      SharedPreferenceService.getSavedLanguageCodeOrNull(),
    ]);

    final savedPremium = results[2] as bool;
    AppConstants.isPremiumUser.value = savedPremium;

    final savedLang = results[3] as String?;
    if (savedLang != null) {
      AppConstants.selectedLanguageCode = savedLang;
    }

    if (!AppConstants.isMobilePlatform) return;

    unawaited(_initAdjustAndGsm());
    unawaited(initializeAds(navigatorKey: navigatorKey));
  }

  static Future<void> _initAdjustAndGsm() async {
    final isProd = app_main.env == Environment.prod;
    try {
      if (AppConstants.adjustToken.isNotEmpty) {
        AdjustHelper.init(
          token: AppConstants.adjustToken,
          iapToken: AppConstants.adjustIapToken,
          isProd: isProd,
        );

        final config = AdjustConfig(
          AdjustHelper.adjustToken,
          isProd
              ? AdjustEnvironment.production
              : AdjustEnvironment.sandbox,
        );

        await EasyAds.instance.initAdjust(
          config,
          onOrganicChanged: (isOrganic) => AdsService.setIsOrganic(isOrganic),
        );
      }

      if (AppConstants.gsmAppId.isNotEmpty) {
        Future.delayed(const Duration(seconds: 5), () async {
          try {
            final token = await EasyAds.instance.loginGSM(
              gsmAppId: AppConstants.gsmAppId,
              isProd: isProd,
            );
            if (token != null) {
              AppConstants.gsmAccessToken = token;
            }
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('AppInitializer _initAdjustAndGsm error: $e');
    }
  }

  static Future<void> initializeAds({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (!AppConstants.isMobilePlatform) return;
    try {
      debugPrint('Starting EasyAds initialization...');

      final analytics = FirebaseHelper.analyticsOrNull;
      if (analytics != null) {
        await EasyAds.instance.initFirebaseAnalytics(analytics);
      }
      EasyAds.adIdResolver = (adId) => adId.getId;
      EasyAds.adEnabledChecker =
          (adUnitType, adIdName, adId) =>
              FirebaseRemoteConfigService.isAdPlacementEnabled(
                adUnitType: adUnitType,
                adIdName: adIdName,
                adId: adId,
              );

      await EasyAds.instance.initConsent().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Consent initialization timed out after 4s');
        },
      );

      final IAdIdManager adIdManager = MyAdIdManager();

      final isProd = app_main.env == Environment.prod;
      await EasyAds.instance
          .initialize(
            adIdManager,
            navigatorKey: navigatorKey,
            unityTestMode: !isProd,
            adMobAdRequest: const AdRequest(httpTimeoutMillis: 6000),
            admobConfiguration: RequestConfiguration(testDeviceIds: const []),
            loadingSplash: const AdLoadingPage(),
          )
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              debugPrint('EasyAds initialization timed out after 6s');
            },
          );

      await EasyAds.instance.initAdmob(
        appOpenAdUnitId: MyAdIdName.appOpenResume.getId,
        appOpenAdIdName: MyAdIdName.appOpenResume,
      );
      if (AppConstants.isPremiumUser.value) {
        EasyAds.instance.setPremiumUser(true);
      }
      EasyAds.instance.appLifecycleReactor
          ?.setAllowAppOpenAd(!isAppOpenAdSuppressed);
      if (!AppConstants.isPremiumUser.value &&
          FirebaseRemoteConfigService.appOpenResumeEnabled) {
        EasyAds.instance.loadAppOpenAd();
      }

      EasyAds.instance.onEvent.listen((event) {
        Ad? adObj;
        if (event.ad is Ad) {
          adObj = event.ad as Ad;
        } else if (event.data is Ad) {
          adObj = event.data as Ad;
        }
        final adIdName = event.data is String ? event.data as String : null;
        if (event.type == AdEventType.onAdImpression && adObj != null) {
          FirebaseHelper.logAdmobAdImpression(
            ad: adObj,
            adIdName: adIdName,
            adUnitType: event.adUnitType,
          );
        }
      });

      debugPrint('EasyAds & AdMob initialized successfully.');
    } catch (e) {
      debugPrint('EasyAds initialization error: $e');
    }
  }
}

class _RemoteConfigLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppScreenUtils.applyImmersiveMode());
      unawaited(FirebaseRemoteConfigService.refreshInBackground());
    }
  }
}
