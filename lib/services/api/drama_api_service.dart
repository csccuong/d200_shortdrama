import 'package:dio/dio.dart';
import 'package:dxx_shortdrama/core/network/api_endpoints.dart';
import 'package:dxx_shortdrama/models/drama_card.dart';
import 'package:dxx_shortdrama/models/episode_detail.dart';
import 'package:dxx_shortdrama/models/play_response.dart';

/// Group D: Drama detail, episodes, playback & unlock APIs (6 endpoints).
///
/// Note: Stream paths (`/v1/stream/*.mp4`, `/v1/stream/*.vtt`) are direct URLs
/// consumed by the video player — not wrapped API calls — so they are omitted.
class DramaApiService {
  final Dio _dio;

  DramaApiService(this._dio);

  /// D1. GET /v1/dramas/{drama_id} — full drama detail + 12 related dramas.
  Future<({DramaCard drama, List<DramaCard> relatedDramas})> fetchDramaDetail(
    String dramaId, {
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.dramaDetail(dramaId),
      queryParameters: {'lang': lang},
    );
    final data = resp.data['data'] as Map<String, dynamic>;
    final rawRelated = (data['related_dramas'] ?? data['related']) as List<dynamic>?;
    return (
      drama: DramaCard.fromJson(data),
      relatedDramas: rawRelated
              ?.map((e) => DramaCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// D2. GET /v1/dramas/{drama_id}/episodes — episode grid with lock status.
  Future<EpisodesListResponse> fetchEpisodes(
    String dramaId, {
    int page = 1,
    int pageSize = 100,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.dramaEpisodes(dramaId),
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'lang': lang,
      },
    );
    return EpisodesListResponse.fromJson(
        resp.data['data'] as Map<String, dynamic>);
  }

  /// D3. GET /v1/dramas/{drama_id}/episodes/{ep_num}/play — play gatekeeper.
  ///
  /// On HTTP 200: returns a [PlayResponse] with video_url & subtitles.
  /// On HTTP 402: the Dio interceptor throws `DramaPaywallException`
  ///   containing the paywall data — callers should catch it at the UI layer.
  Future<PlayResponse> playEpisode(
    String dramaId,
    int epNum, {
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.episodePlay(dramaId, epNum),
      queryParameters: {'lang': lang},
    );
    return PlayResponse.fromJson(resp.data['data'] as Map<String, dynamic>);
  }

  /// D4. POST /v1/episodes/unlock — unlock via ad / coins / full drama.
  ///
  /// Returns updated wallet balance AND the video_url + subtitles so the
  /// player can start immediately without calling `/play` again.
  Future<UnlockResponse> unlockEpisode(
    String dramaId,
    int epNum,
    String method, {
    bool unlockFullDrama = false,
    String? adNetwork,
    String? adUnitId,
  }) async {
    final body = <String, dynamic>{
      'drama_id': dramaId,
      'episode_number': epNum,
      'method': method,
      'unlock_full_drama': unlockFullDrama,
    };
    if (adNetwork != null) body['ad_network'] = adNetwork;
    if (adUnitId != null) body['ad_unit_id'] = adUnitId;

    final resp = await _dio.post(ApiEndpoints.episodesUnlock, data: body);
    return UnlockResponse.fromJson(resp.data['data'] as Map<String, dynamic>);
  }

  /// D5. POST /v1/dramas/{drama_id}/like — like / unlike a drama.
  Future<({bool isLiked, int likeCount})> likeDrama(
    String dramaId, {
    String action = 'toggle',
    int episodeNumber = 0,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.dramaLike(dramaId),
      data: {
        'action': action,
        'episode_number': episodeNumber,
      },
    );
    final data = resp.data['data'] as Map<String, dynamic>? ?? {};
    return (
      isLiked: data['is_liked'] as bool? ?? false,
      likeCount: (data['like_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// D6. POST /v1/dramas/{drama_id}/share — record a drama share.
  Future<({int shareCount})> shareDrama(
    String dramaId, {
    String channel = 'copy_link',
    int episodeNumber = 1,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.dramaShare(dramaId),
      data: {
        'channel': channel,
        'episode_number': episodeNumber,
      },
    );
    final data = resp.data['data'] as Map<String, dynamic>? ?? {};
    return (
      shareCount: (data['share_count'] as num?)?.toInt() ?? 0,
    );
  }
}
