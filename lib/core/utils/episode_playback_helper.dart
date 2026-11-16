import 'package:flutter/services.dart';

import '../../models/stream_bundle.dart';
import '../../services/api/drama_api_service.dart';

/// Helper for proactively renewing expired episode stream tokens via `/play`
/// and detecting HTTP 403 playback errors for single-retry recovery.
class EpisodePlaybackHelper {
  final DramaApiService _api;

  const EpisodePlaybackHelper(this._api);

  /// Returns [cachedBundle] if still valid, otherwise fetches a fresh token via
  /// `GET /v1/dramas/{dramaId}/episodes/{episodeNumber}/play` without re-charging.
  Future<StreamBundle> ensureFreshEpisodeStream({
    required String dramaId,
    required int episodeNumber,
    StreamBundle? cachedBundle,
    String lang = 'en',
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        cachedBundle != null &&
        !cachedBundle.isExpired &&
        cachedBundle.videoUrl.isNotEmpty) {
      return cachedBundle;
    }

    final playResp = await _api.playEpisode(
      dramaId,
      episodeNumber,
      lang: lang,
    );
    return playResp.toStreamBundle();
  }

  /// Checks whether a player error (PlatformException or errorDescription)
  /// indicates an HTTP 403 Forbidden response from CDN/stream edge.
  static bool isHttp403Error(Object? error) {
    if (error == null) return false;
    final buffer = StringBuffer();
    if (error is PlatformException) {
      buffer
        ..write(error.code)
        ..write(' ')
        ..write(error.message ?? '')
        ..write(' ')
        ..write(error.details ?? '');
    } else {
      buffer.write(error.toString());
    }
    final text = buffer.toString().toLowerCase();
    return RegExp(r'\b403\b').hasMatch(text) ||
        text.contains('response code: 403') ||
        text.contains('http 403') ||
        text.contains('forbidden');
  }
}
