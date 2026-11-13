import 'package:dio/dio.dart';
import 'package:dxx_shortdrama/core/network/api_endpoints.dart';
import 'package:dxx_shortdrama/models/drama_card.dart';
import 'package:dxx_shortdrama/models/pagination.dart';

/// Group E: Favorites, Watch Later & History APIs (9 endpoints).
class MyListApiService {
  final Dio _dio;

  MyListApiService(this._dio);

  /// E1 (legacy alias). GET /v1/me/my-list — paginated saved dramas.
  Future<({List<DramaCard> items, Pagination pagination})> fetchMyList({
    int page = 1,
    int pageSize = 20,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.myList,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'lang': lang,
      },
    );
    final data = resp.data['data'] as Map<String, dynamic>;
    return (
      items: (data['items'] as List<dynamic>?)
              ?.map((e) => DramaCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination:
          Pagination.fromJson(data['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// E2 (legacy alias). POST /v1/me/my-list — save or toggle a drama.
  Future<void> addToMyList(
    String dramaId, {
    int episodeNumber = 1,
    String action = 'toggle',
  }) async {
    await _dio.post(
      ApiEndpoints.myList,
      data: {
        'drama_id': dramaId,
        'episode_number': episodeNumber,
        'action': action,
      },
    );
  }

  /// E3 (legacy alias). DELETE /v1/me/my-list/{drama_id} — remove one drama.
  Future<void> removeFromMyList(String dramaId) async {
    await _dio.delete(ApiEndpoints.myListRemove(dramaId));
  }

  /// E3 (legacy batch). DELETE /v1/me/my-list — remove multiple dramas.
  Future<void> batchRemoveFromMyList(List<String> dramaIds) async {
    await _dio.delete(
      ApiEndpoints.myList,
      data: {'drama_ids': dramaIds},
    );
  }

  /// E1. GET /v1/me/favorites — paginated favorite dramas (v4.5).
  Future<({List<DramaCard> items, Pagination pagination})> fetchFavorites({
    int page = 1,
    int pageSize = 20,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.favorites,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'lang': lang,
      },
    );
    final data = resp.data['data'] as Map<String, dynamic>;
    return (
      items: (data['items'] as List<dynamic>?)
              ?.map((e) => DramaCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination:
          Pagination.fromJson(data['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// E2. POST /v1/me/favorites — add / remove / toggle favorite drama.
  Future<({bool isFavorited, int favoriteCount})> toggleFavorite(
    String dramaId, {
    String action = 'toggle',
    int episodeNumber = 1,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.favorites,
      data: {
        'drama_id': dramaId,
        'action': action,
        'episode_number': episodeNumber,
      },
    );
    final data = resp.data['data'] as Map<String, dynamic>? ?? {};
    return (
      isFavorited: data['is_favorited'] as bool? ?? false,
      favoriteCount: (data['favorite_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// E3. DELETE /v1/me/favorites — delete favorite items or clear all.
  Future<void> deleteFavorites({
    List<String>? dramaIds,
    bool clearAll = false,
  }) async {
    final body = <String, dynamic>{};
    if (clearAll) {
      body['clear_all'] = true;
    } else if (dramaIds != null && dramaIds.isNotEmpty) {
      body['drama_ids'] = dramaIds;
    }
    await _dio.delete(ApiEndpoints.favorites, data: body);
  }

  /// E4. GET /v1/me/watch-later — paginated Watch Later list.
  Future<({List<DramaCard> items, Pagination pagination})> fetchWatchLater({
    int page = 1,
    int pageSize = 20,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.watchLater,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'lang': lang,
      },
    );
    final data = resp.data['data'] as Map<String, dynamic>;
    return (
      items: (data['items'] as List<dynamic>?)
              ?.map((e) => DramaCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination:
          Pagination.fromJson(data['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// E5. POST /v1/me/watch-later — add / remove / toggle Watch Later drama.
  Future<({bool isInWatchLater, int watchLaterCount})> toggleWatchLater(
    String dramaId, {
    String action = 'toggle',
    int episodeNumber = 1,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'drama_id': dramaId,
      'action': action,
      'episode_number': episodeNumber,
    };
    if (note != null) body['note'] = note;

    final resp = await _dio.post(
      ApiEndpoints.watchLater,
      data: body,
    );
    final data = resp.data['data'] as Map<String, dynamic>? ?? {};
    return (
      isInWatchLater: data['is_in_watch_later'] as bool? ?? false,
      watchLaterCount: (data['watch_later_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// E6. DELETE /v1/me/watch-later — delete Watch Later items or clear all.
  Future<void> deleteWatchLater({
    List<String>? dramaIds,
    bool clearAll = false,
  }) async {
    final body = <String, dynamic>{};
    if (clearAll) {
      body['clear_all'] = true;
    } else if (dramaIds != null && dramaIds.isNotEmpty) {
      body['drama_ids'] = dramaIds;
    }
    await _dio.delete(ApiEndpoints.watchLater, data: body);
  }

  /// E7. GET /v1/me/history — paginated watch history.
  Future<({List<DramaCard> items, Pagination pagination})> fetchHistory({
    int page = 1,
    int pageSize = 20,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.history,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'lang': lang,
      },
    );
    final data = resp.data['data'] as Map<String, dynamic>;
    return (
      items: (data['items'] as List<dynamic>?)
              ?.map((e) => DramaCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination:
          Pagination.fromJson(data['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// E8. POST /v1/me/history — save playback progress.
  Future<void> saveHistory({
    required String dramaId,
    required int episodeNumber,
    required int positionSec,
    required int durationSec,
    int watchedDeltaSec = 0,
  }) async {
    await _dio.post(
      ApiEndpoints.history,
      data: {
        'drama_id': dramaId,
        'episode_number': episodeNumber,
        'position_sec': positionSec,
        'duration_sec': durationSec,
        'watched_delta_sec': watchedDeltaSec,
      },
    );
  }

  /// E6. DELETE /v1/me/history — delete history items or clear all.
  Future<void> deleteHistory({
    List<String>? dramaIds,
    bool clearAll = false,
  }) async {
    final body = <String, dynamic>{};
    if (clearAll) {
      body['clear_all'] = true;
    } else if (dramaIds != null && dramaIds.isNotEmpty) {
      body['drama_ids'] = dramaIds;
    }
    await _dio.delete(ApiEndpoints.history, data: body);
  }
}
