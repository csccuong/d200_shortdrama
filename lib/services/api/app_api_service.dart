import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dxx_shortdrama/core/network/api_endpoints.dart';
import 'package:dxx_shortdrama/models/init_response.dart';
import 'package:dxx_shortdrama/models/promo_feedback_models.dart';

/// Exception carrying the server validation message for failed promo code redemptions.
class PromoRedeemException implements Exception {
  final String message;

  const PromoRedeemException(this.message);

  @override
  String toString() => message;
}

/// Group A: App lifecycle APIs.
///
/// - POST /v1/app/init
/// - POST /v1/app/attribution
/// - POST /v1/promo/redeem
/// - POST /v1/feedback
/// - POST /v1/app/push-token
/// - POST /v1/app/heartbeat
class AppApiService {
  final Dio _dio;

  AppApiService(this._dio);

  /// A1. Initialize app session — must be called first at splash.
  ///
  /// Returns the full [InitResponse] containing session tokens,
  /// user profile, taxonomy and app config.
  Future<InitResponse> appInit({
    String? appLanguage,
    String? subtitleLanguage,
    String? deviceModel,
    String? osVersion,
  }) async {
    final body = <String, dynamic>{};
    if (appLanguage != null) body['app_language'] = appLanguage;
    if (subtitleLanguage != null) body['subtitle_language'] = subtitleLanguage;
    if (deviceModel != null) body['device_model'] = deviceModel;
    if (osVersion != null) body['os_version'] = osVersion;

    final resp = await _dio.post(
      ApiEndpoints.appInit,
      data: body.isNotEmpty ? body : null,
    );
    final data = resp.data['data'] as Map<String, dynamic>;
    return InitResponse.fromJson(data);
  }

  /// Reports late MMP attribution (e.g. Adjust `Non-organic`) for the current install.
  Future<void> reportAttribution({
    required String deviceId,
    required String trafficType,
    required String installReferrer,
  }) async {
    await _dio.post(
      ApiEndpoints.appAttribution,
      data: {
        'device_id': deviceId,
        'traffic_type': trafficType,
        'install_referrer': installReferrer,
      },
    );
  }

  /// Redeems a promotion / store reviewer code via `POST /v1/promo/redeem`.
  Future<PromoFeedbackResult> redeemPromoCode(String code) async {
    try {
      final resp = await _dio.post(
        ApiEndpoints.promoRedeem,
        data: {'code': code.trim()},
      );
      return _parsePromoFeedbackResponse(resp.data);
    } on DioException catch (e) {
      throw PromoRedeemException(extractServerErrorMessage(e));
    }
  }

  /// Submits user feedback (or reviewer code fallback) via `POST /v1/feedback`.
  Future<PromoFeedbackResult> submitFeedback({
    required String content,
    String category = 'general',
    String contact = '',
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.feedback,
      data: {
        'content': content.trim(),
        'category': category,
        'contact': contact.trim(),
      },
    );
    return _parsePromoFeedbackResponse(resp.data);
  }

  static PromoFeedbackResult _parsePromoFeedbackResponse(dynamic rawBody) {
    final root = rawBody is Map<String, dynamic>
        ? rawBody
        : (rawBody is Map
            ? Map<String, dynamic>.from(rawBody)
            : <String, dynamic>{});
    final rawData = root['data'];
    final data = rawData is Map<String, dynamic>
        ? rawData
        : (rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : <String, dynamic>{});
    return PromoFeedbackResult.fromJson(
      data,
      fallbackMessage: root['message']?.toString().trim() ?? '',
    );
  }

  static String extractServerErrorMessage(DioException error) {
    final raw = error.response?.data;
    Map<String, dynamic>? map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    final fromBody = map?['message']?.toString().trim();
    if (fromBody != null && fromBody.isNotEmpty) return fromBody;

    final errMsg = error.message?.trim() ?? '';
    final prefixMatch = RegExp(r'^HTTP \d+:\s*(.+)$').firstMatch(errMsg);
    if (prefixMatch != null) {
      final extracted = prefixMatch.group(1)?.trim() ?? '';
      if (extracted.isNotEmpty) return extracted;
    }
    return '';
  }

  /// A2. Register / update FCM push token.
  Future<void> pushToken(
    String fcmToken, {
    bool pushEnabled = true,
  }) async {
    await _dio.post(
      ApiEndpoints.pushToken,
      data: {
        'fcm_token': fcmToken,
        'push_enabled': pushEnabled,
      },
    );
  }

  /// A3. Heartbeat — send every 30 s while playing.
  ///
  /// Returns server-side watch stats and any claimable reward tasks.
  Future<Map<String, dynamic>> heartbeat({
    required int watchSecondsDelta,
    required String dramaId,
    required int episodeNumber,
    required int positionSec,
    required int durationSec,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.heartbeat,
      data: {
        'watch_seconds_delta': watchSecondsDelta,
        'drama_id': dramaId,
        'episode_number': episodeNumber,
        'position_sec': positionSec,
        'duration_sec': durationSec,
      },
    );
    return resp.data['data'] as Map<String, dynamic>;
  }
}
