import 'dart:io' show Platform;
import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract class Environment {
  static const String dev = 'dev';
  static const String prod = 'prod';
  static const String test = 'test';
}

class AppConstants {
  AppConstants._();

  static bool get isFlutterTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static bool get isMobilePlatform =>
      !kIsWeb && !isFlutterTest && (Platform.isAndroid || Platform.isIOS);

  static String packageName = '';
  static String version = '';
  static String buildNumber = '';

  static Future<void> loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      packageName = info.packageName;
      version = info.version;
      buildNumber = info.buildNumber;
    } catch (e) {
      debugPrint('Error fetching PackageInfo: $e');
    }
  }

  // GSM & Adjust Constants (replace with project-specific tokens in production)
  static const String gsmAppId = '6af6905edfe0a3aefe4cb0e7';
  static const String adjustToken = 'den3ocinh4ao';
  static const String adjustIapToken = 'ua8nmv';
  static const String privacyPolicyUrl = 'https://dramota.com/privacy';

  static final ValueNotifier<bool> isPremiumUser = ValueNotifier<bool>(false)
    ..addListener(() {
      if (isMobilePlatform) {
        EasyAds.instance.setPremiumUser(isPremiumUser.value);
      }
    });

  static bool appInBackground = false;
  static int intervalInterAd = 35;
  static int adImpressionCount = 0;
  static String selectedLanguageCode = 'vi';
  static String gsmAccessToken = '';

  /// Controls reopen navigation flow from 2nd launch onward:
  /// - `true`: 2nd+ launch -> Splash -> MainShellScreen directly
  /// - `false`: Every launch -> Splash -> Language -> Onboard -> MainShellScreen
  static bool skipLangOnboardOnReopen = true;
}
