import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceService {
  SharedPreferenceService._();

  static SharedPreferences? _prefs;

  static const String keyIsNoFirstOpenApp = 'is_no_first_open_app';
  static const String keySelectedLanguageCode = 'selected_language_code';
  static const String keySelectedLanguageVariant = 'selected_language_variant';
  static const String keyIsPremiumUser = 'IS_PREMIUM_USER';
  static const String keyFirstAppOpenTime = 'FIRST_APP_OPEN_TIME_MS';

  static Future<SharedPreferences> getInstance() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<bool> getIsNoFirstOpenApp() async {
    try {
      return (await getInstance()).getBool(keyIsNoFirstOpenApp) ?? false;
    } catch (e) {
      debugPrint('SharedPreferenceService getIsNoFirstOpenApp error: $e');
      return false;
    }
  }

  static Future<bool> setIsNoFirstOpenApp(bool value) async {
    try {
      return await (await getInstance()).setBool(keyIsNoFirstOpenApp, value);
    } catch (e) {
      debugPrint('SharedPreferenceService setIsNoFirstOpenApp error: $e');
      return false;
    }
  }

  static Future<String?> getSavedLanguageCodeOrNull() async {
    try {
      final raw = (await getInstance()).getString(keySelectedLanguageCode);
      if (raw == null || raw.trim().isEmpty) return null;
      return raw.trim();
    } catch (e) {
      debugPrint('SharedPreferenceService getSavedLanguageCodeOrNull error: $e');
      return null;
    }
  }

  static Future<String> getSelectedLanguageCode({String fallback = 'vi'}) async {
    return (await getSavedLanguageCodeOrNull()) ?? fallback;
  }

  static Future<bool> setSelectedLanguageCode(String code) async {
    try {
      return await (await getInstance())
          .setString(keySelectedLanguageCode, code);
    } catch (e) {
      debugPrint('SharedPreferenceService setSelectedLanguageCode error: $e');
      return false;
    }
  }

  static Future<String?> getSavedLanguageVariantOrNull() async {
    try {
      final raw = (await getInstance()).getString(keySelectedLanguageVariant);
      if (raw == null || raw.trim().isEmpty) return null;
      return raw.trim();
    } catch (e) {
      debugPrint(

        'SharedPreferenceService getSavedLanguageVariantOrNull error: $e',
      );
      return null;
    }
  }

  static Future<bool> setSelectedLanguageVariant(String variantId) async {
    try {
      return await (await getInstance())
          .setString(keySelectedLanguageVariant, variantId);
    } catch (e) {
      debugPrint(
        'SharedPreferenceService setSelectedLanguageVariant error: $e',
      );
      return false;
    }
  }

  static Future<bool> getIsPremiumUser() async {
    try {
      return (await getInstance()).getBool(keyIsPremiumUser) ?? false;
    } catch (e) {
      debugPrint('SharedPreferenceService getIsPremiumUser error: $e');
      return false;
    }
  }

  static Future<bool> setIsPremiumUser(bool value) async {
    try {
      return await (await getInstance()).setBool(keyIsPremiumUser, value);
    } catch (e) {
      debugPrint('SharedPreferenceService setIsPremiumUser error: $e');
      return false;
    }
  }

  static Future<int> initFirstAppOpenTimeIfNeeded() async {
    try {
      final prefs = await getInstance();
      int? time = prefs.getInt(keyFirstAppOpenTime);
      if (time == null) {
        time = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(keyFirstAppOpenTime, time);
      }
      return time;
    } catch (e) {
      debugPrint(
        'SharedPreferenceService initFirstAppOpenTimeIfNeeded error: $e',
      );
      return DateTime.now().millisecondsSinceEpoch;
    }
  }
}

typedef SharedPreferenceUtils = SharedPreferenceService;
