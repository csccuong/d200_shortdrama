import 'package:dio/dio.dart';
import 'package:dxx_shortdrama/core/network/api_endpoints.dart';
import 'package:dxx_shortdrama/models/feed_response.dart';

/// Group C + doc 02 §6 `DramaFeedRepository`: For You feed, Recommended
/// pagination, Browse filtered dramas, and feed events.
///
/// Doc 02 Section 6 defines a single `DramaFeedRepository` class with 4 methods:
///   1. fetchForYouFeed       — Tab For You (cursor-based, 20/page)
///   2. fetchRecommendedPage  — Kệ "Recommended for You" (page-based)
///   3. browseFilteredDramas  — "All Dramas" multi-filter browse
///   4. flushForYouEvents     — Batch interest signals
class FeedApiService {
  final Dio _dio;

  FeedApiService(this._dio);

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Tab For You: cursor-based vertical feed (doc 02 §6.1)
  // ──────────────────────────────────────────────────────────────────────────

  /// C1. GET /v1/feed/for-you — TikTok-style vertical feed.
  ///
  /// First call: `cursor = '0'`.
  /// Subsequent pages: pass `nextCursor` from the previous response verbatim.
  /// Default returns 20 items per page.
  Future<FeedResponse> fetchForYouFeed({
    String cursor = '0',
    int count = 20,
    bool refresh = false,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.feedForYou,
      queryParameters: {
        'cursor': cursor,
        'count': count,
        if (refresh) 'refresh': true,
        'lang': lang,
      },
    );
    return FeedResponse.fromJson(resp.data['data'] as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Kệ "Recommended for You" — page-based (doc 02 §6.2)
  // ──────────────────────────────────────────────────────────────────────────

  /// GET /v1/dramas/recommend — paginated recommended dramas.
  ///
  /// Page 1 is already embedded in `GET /v1/home` response; call this for
  /// subsequent pages when user scrolls to the bottom of the home screen.
  Future<Map<String, dynamic>> fetchRecommendedPage({
    required int page,
    int pageSize = 20,
    bool refresh = false,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.recommend,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (refresh) 'refresh': true,
        'lang': lang,
      },
    );
    return resp.data['data'] as Map<String, dynamic>;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. "All Dramas" multi-filter browse (doc 02 §6.3)
  // ──────────────────────────────────────────────────────────────────────────

  /// GET /v1/dramas — browse with multi-dimensional filters.
  ///
  /// Supports filtering by country, region, audioMode, category, tags, and sort.
  Future<Map<String, dynamic>> browseFilteredDramas({
    int page = 1,
    int pageSize = 20,
    String country = 'all',
    String region = 'all',
    String audioMode = 'all',
    String category = 'all',
    String tags = '',
    String sort = 'popular',
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.dramas,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'country': country,
        'region': region,
        'audio_mode': audioMode,
        'category': category,
        if (tags.isNotEmpty) 'tag': tags,
        'sort': sort,
        'lang': lang,
      },
    );
    return resp.data['data'] as Map<String, dynamic>;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Batch interest signals (doc 02 §6.4)
  // ──────────────────────────────────────────────────────────────────────────

  /// C2. POST /v1/feed/events — batch-send interest signals (max 25/call).
  ///
  /// Each event: `{ "drama_id": "...", "action": "watch_3s" | "skip_fast" | ... }`
  Future<void> sendFeedEvents(List<Map<String, String>> events) async {
    if (events.isEmpty) return;
    await _dio.post(
      ApiEndpoints.feedEvents,
      data: {'events': events},
    );
  }
}
