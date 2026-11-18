import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// Reads per-install Google Play Install Referrer and Adjust attribution state
/// using [SharedPreferences] so uninstalling or clearing app data resets the
/// install attribution cleanly (never persisted in Keychain/SecureStorage).
class AttributionHelper {
  AttributionHelper._();

  static const String _kInstallReferrerCheckedKey =
      'install_referrer_checked_v1';
  static const String _kInstallReferrerValueKey = 'install_referrer_value_v1';
  static const String _kTrafficTypeKey = 'attribution_traffic_type_v1';
  static const String _kPaidSyncedKey = 'attribution_paid_synced_v1';

  /// Registered by [SessionNotifier] to forward late Adjust `Non-organic`
  /// callbacks to `POST /v1/app/attribution` and refresh Home / For You feeds.
  static Future<void> Function()? onLatePaidAttribution;

  /// Reads the Google Play Install Referrer for the current app installation.
  ///
  /// - On Android: queries Google Play once (~30 ms) and caches in
  ///   [SharedPreferences] for this install.
  /// - On non-Android / Web / test without override: returns `''`.
  static Future<String> getAndroidInstallReferrer({
    Future<String?> Function()? referrerReaderOverride,
    bool? isAndroidOverride,
  }) async {
    final isAndroid = isAndroidOverride ??
        (!kIsWeb && !AppConstants.isFlutterTest && Platform.isAndroid);
    if (!isAndroid) return '';

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kInstallReferrerCheckedKey) == true) {
        return prefs.getString(_kInstallReferrerValueKey) ?? '';
      }

      final raw = referrerReaderOverride != null
          ? await referrerReaderOverride()
          : (await PlayInstallReferrer.installReferrer
                  .timeout(const Duration(seconds: 3)))
              .installReferrer;
      final ref = (raw ?? '').trim();
      await prefs.setString(_kInstallReferrerValueKey, ref);
      await prefs.setBool(_kInstallReferrerCheckedKey, true);
      return ref;
    } catch (e) {
      debugPrint('AttributionHelper.getAndroidInstallReferrer error: $e');
      return '';
    }
  }

  /// Returns the cached MMP traffic type (`'paid'` or `'organic'`) for the
  /// current install if known, or `null` if not yet resolved.
  static Future<String?> getCachedTrafficType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_kTrafficTypeKey)?.trim();
      if (val == 'paid' || val == 'organic') return val;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveTrafficType({required bool isOrganic}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTrafficTypeKey, isOrganic ? 'organic' : 'paid');
    } catch (e) {
      debugPrint('AttributionHelper.saveTrafficType error: $e');
    }
  }

  static Future<bool> hasSyncedPaidAttribution() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kPaidSyncedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markPaidAttributionSynced() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPaidSyncedKey, true);
    } catch (e) {
      debugPrint('AttributionHelper.markPaidAttributionSynced error: $e');
    }
  }

  /// Handles Adjust `onOrganicChanged(isOrganic)` callback.
  ///
  /// Persists the current install's `traffic_type` in [SharedPreferences] and,
  /// when attributed as `Non-organic` (`paid`), triggers [onLatePaidAttribution]
  /// if not already synced for this install.
  static Future<void> handleAdjustAttribution({
    required bool isOrganic,
  }) async {
    await saveTrafficType(isOrganic: isOrganic);
    if (isOrganic) return;

    if (await hasSyncedPaidAttribution()) return;
    final callback = onLatePaidAttribution;
    if (callback != null) {
      await callback();
    }
  }
}
