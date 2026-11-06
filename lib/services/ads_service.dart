import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdsService {
  AdsService._();

  static const String keyIsOrganic = 'is_organic';
  static final ValueNotifier<bool> isOrganic = ValueNotifier<bool>(false);

  static Future<void> initOrganic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(keyIsOrganic) ?? false;
      isOrganic.value = value;
    } catch (_) {
      isOrganic.value = false;
    }
  }

  static Future<void> setIsOrganic(bool value) async {
    try {
      isOrganic.value = value;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyIsOrganic, value);
    } catch (e) {
      debugPrint('Error setting isOrganic in AdsService: $e');
    }
  }

  static Future<bool> isOrganicAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(keyIsOrganic) ?? false;
      isOrganic.value = value;
      return value;
    } catch (_) {
      return false;
    }
  }
}
