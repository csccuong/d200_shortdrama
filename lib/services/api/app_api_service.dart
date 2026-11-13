import 'package:dio/dio.dart';
import 'package:dxx_shortdrama/core/network/api_endpoints.dart';
import 'package:dxx_shortdrama/models/init_response.dart';

/// Group A: App lifecycle APIs (3 endpoints).
///
/// - POST /v1/app/init
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
