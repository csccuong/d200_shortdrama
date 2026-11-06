// ignore_for_file: constant_identifier_names

import 'dart:async';

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
  static const String native_full = 'native_full';
  static const String reward_all = 'reward_all';

  static const String time_delay_close_premium = 'time_delay_close_premium';
  static const String show_activity_iap = 'show_activity_iap';

  static const Map<String, Object> _defaults = {
    'show_activity_iap': false,
    'banner_splash': true,
    'native_banner': true,
    'inter_splash_high': true,
    'inter_splash': true,
    'native_language': true,
    'native_language_click': true,
    'native_onboarding_1': true,
    'native_onboarding_full_1': true,
    'native_onboarding_full_2': true,
    'native_onboarding_4': true,
    'inter_onboard': true,
    'inter_all': true,
    'native_all': true,
    'native_home': true,
    'native_drama_popup': true,
    'native_collap': true,
    'banner_all': true,
    'native_pip': true,
    'native_full': true,
    'reward_all': true,
    'interval_inter_ad': 30,
    'time_delay_close_premium': 3,
  };

  static bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  static Future<void> initFirebaseRemoteConfig() async {
    if (!_isFirebaseReady) return;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 3),
          minimumFetchInterval: const Duration(seconds: 60),
        ),
      );
      // Immediately apply in-memory defaults (0ms offline, no network blocking)
      await remoteConfig.setDefaults(_defaults);

      // Fetch and activate latest server values in the background without blocking cold start / runApp()
      unawaited(
        remoteConfig.fetchAndActivate().timeout(
              const Duration(seconds: 3),
              onTimeout: () => false,
            ),
      );
    } catch (_) {}
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
