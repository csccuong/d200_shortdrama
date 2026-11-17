// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class FirebaseRemoteConfigService {
  FirebaseRemoteConfigService._();

  static const String android_app_version = 'android_app_version';

  // Ad placement flags (matching d73piano_app Remote Config convention)
  static const String banner_splash = 'banner_splash';
  static const String native_banner = 'native_banner';
  static const String inter_splash_high = 'inter_splash_high';
  static const String inter_splash = 'inter_splash';
  static const String native_language = 'native_language';
  static const String native_language_click = 'native_language_click';
  static const String native_onboarding_1 = 'native_onboarding_1';
  static const String native_onboarding_full_1 = 'native_onboarding_full_1_2';
  static const String native_onboarding_full_2 = 'native_onboarding_full_2_3';
  static const String native_onboarding_4 = 'native_onboarding_4';

  static const String inter_all = 'inter_all';
  static const String inter_onboard = 'inter_onboard';
  static const String interval_inter_ad = 'interval_inter_ad';
  static const String native_all = 'native_all';
  static const String native_home = 'native_home';
  static const String native_drama_popup = 'native_drama_popup';
  static const String native_collap = 'native_collap';
  static const String banner_all = 'banner_all';
  static const String native_pip = 'native_pip';
  static const String capping_time_pip = 'capping_time_pip';
  static const String native_full = 'native_full';
  static const String reward_all = 'reward_all';
  static const String appopen_resume = 'appopen_resume';

  static const String time_delay_close_premium = 'time_delay_close_premium';
  static const String show_activity_iap = 'show_activity_iap';

  static const Duration fetchTimeout = Duration(seconds: 3);
  static const Duration minimumFetchInterval = Duration(seconds: 60);

  static const Map<String, Object> _defaults = {
    show_activity_iap: true,
    banner_splash: true,
    native_banner: true,
    inter_splash_high: true,
    inter_splash: true,
    native_language: true,
    native_language_click: true,
    native_onboarding_1: true,
    native_onboarding_full_1: true,
    native_onboarding_full_2: true,
    native_onboarding_4: true,
    inter_onboard: true,
    inter_all: true,
    native_all: true,
    native_home: true,
    native_drama_popup: true,
    native_collap: true,
    banner_all: true,
    native_pip: true,
    native_full: true,
    reward_all: true,
    appopen_resume: true,
    interval_inter_ad: 30,
    capping_time_pip: 30,
    time_delay_close_premium: 3,
  };

  /// Exposes ad & UI Remote Config defaults so other startup loaders can merge
  /// defaults instead of replacing them on the shared [FirebaseRemoteConfig] instance.
  static Map<String, Object> get defaultValues => _defaults;

  static const Map<String, String> _adPlacementToRcKey = {
    'interAll': inter_all,
    inter_all: inter_all,
    'interOnboard': inter_onboard,
    inter_onboard: inter_onboard,
    'interSplash': inter_splash,
    inter_splash: inter_splash,
    'interSplashHigh': inter_splash_high,
    inter_splash_high: inter_splash_high,
    'rewardedAd': reward_all,
    reward_all: reward_all,
    'appOpenResume': appopen_resume,
    appopen_resume: appopen_resume,
  };

  static Future<bool>? _inFlightFetch;
  static bool _initialFetchFinished = false;
  static DateTime? _lastBackgroundRefreshAt;

  static bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  static Future<void> initFirebaseRemoteConfig() async {
    if (!_isFirebaseReady) {
      _initialFetchFinished = true;
      return;
    }
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: fetchTimeout,
          minimumFetchInterval: minimumFetchInterval,
        ),
      );
      await remoteConfig.setDefaults(_defaults);

      unawaited(fetchLatest(timeout: fetchTimeout));
    } catch (_) {
      _initialFetchFinished = true;
    }
  }

  /// Fetches and activates Remote Config once at a time (sharing any in-flight call).
  static Future<bool> fetchLatest({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!_isFirebaseReady) {
      _initialFetchFinished = true;
      return false;
    }
    final active = _inFlightFetch;
    if (active != null) {
      try {
        return await active.timeout(timeout, onTimeout: () => false);
      } catch (_) {
        return false;
      }
    }

    final future = () async {
      try {
        _lastBackgroundRefreshAt = DateTime.now();
        return await FirebaseRemoteConfig.instance
            .fetchAndActivate()
            .timeout(timeout, onTimeout: () => false);
      } catch (_) {
        return false;
      } finally {
        _initialFetchFinished = true;
        _inFlightFetch = null;
      }
    }();
    _inFlightFetch = future;
    return future;
  }

  /// Ensures the initial Remote Config fetch has completed (bounded by [timeout])
  /// before gating splash/first-open ad placements.
  static Future<void> waitForInitialFetch({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (_initialFetchFinished || !_isFirebaseReady) return;
    await fetchLatest(timeout: timeout);
  }

  /// Opportunistically refreshes Remote Config on app resume (throttled to [minimumFetchInterval]).
  static Future<void> refreshInBackground() async {
    if (!_isFirebaseReady) return;
    final last = _lastBackgroundRefreshAt;
    if (last != null && DateTime.now().difference(last) < minimumFetchInterval) {
      return;
    }
    await fetchLatest(timeout: fetchTimeout);
  }

  static bool get interAllEnabled => getBoolConfigByKey(inter_all);
  static bool get interOnboardEnabled => getBoolConfigByKey(inter_onboard);
  static bool get interSplashEnabled => getBoolConfigByKey(inter_splash);
  static bool get interSplashHighEnabled =>
      getBoolConfigByKey(inter_splash_high);
  static bool get rewardAllEnabled => getBoolConfigByKey(reward_all);
  static bool get appOpenResumeEnabled => getBoolConfigByKey(appopen_resume);

  /// Placement predicate passed into [EasyAds.adEnabledChecker] so any
  /// Remote-Config-disabled inter, reward, or app-open placement fails fast without
  /// pushing a loading dialog.
  static bool isAdPlacementEnabled({
    required AdUnitType adUnitType,
    String? adIdName,
    String? adId,
  }) {
    final mappedKey = adIdName != null ? _adPlacementToRcKey[adIdName] : null;
    if (mappedKey != null) {
      return getBoolConfigByKey(mappedKey);
    }
    switch (adUnitType) {
      case AdUnitType.rewarded:
        return rewardAllEnabled;
      case AdUnitType.interstitial:
        return interAllEnabled;
      case AdUnitType.appOpen:
        return appOpenResumeEnabled;
      default:
        return true;
    }
  }

  static bool getBoolConfigByKey(String key, {bool? defaultValue}) {
    final fallback = defaultValue ?? (_defaults[key] as bool? ?? true);
    if (!_isFirebaseReady) return fallback;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      final value = remoteConfig.getValue(key);
      if (value.source == ValueSource.valueStatic) {
        return fallback;
      }
      return remoteConfig.getBool(key);
    } catch (_) {
      return fallback;
    }
  }

  static int getIntConfigByKey(String key, {int? defaultValue}) {
    final fallback = defaultValue ?? (_defaults[key] as int? ?? 0);
    if (!_isFirebaseReady) return fallback;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      final value = remoteConfig.getValue(key);
      if (value.source == ValueSource.valueStatic) {
        return fallback;
      }
      return remoteConfig.getInt(key);
    } catch (_) {
      return fallback;
    }
  }
}
