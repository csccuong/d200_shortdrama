import 'package:dio/dio.dart';
import 'package:dxx_shortdrama/core/network/api_endpoints.dart';
import 'package:dxx_shortdrama/models/drama_card.dart';
import 'package:dxx_shortdrama/models/home_response.dart';
import 'package:dxx_shortdrama/models/pagination.dart';

/// Group B: Home, browse, filter & search APIs (10 endpoints).
class HomeApiService {
  final Dio _dio;

  HomeApiService(this._dio);

  /// B1. GET /v1/home — aggregated home screen data.
  Future<HomeResponse> fetchHome({String lang = 'en'}) async {
    final resp = await _dio.get(
      ApiEndpoints.home,
      queryParameters: {'lang': lang},
    );
    return HomeResponse.fromJson(resp.data['data'] as Map<String, dynamic>);
  }

  /// B2. GET /v1/dramas/recommend — paginated "Recommended for You".
  Future<({List<DramaCard> items, String? cohort, Pagination pagination})>
      fetchRecommended({
    int page = 1,
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
    final data = resp.data['data'] as Map<String, dynamic>;
    return (
      items: (data['items'] as List<dynamic>?)
              ?.map((e) => DramaCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      cohort: data['cohort'] as String?,
      pagination:
          Pagination.fromJson(data['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// B3. GET /v1/dramas/filters — dynamic filter facets with counts.
  Future<Map<String, dynamic>> fetchFilters({String lang = 'en'}) async {
    final resp = await _dio.get(
      ApiEndpoints.filters,
      queryParameters: {'lang': lang},
    );
    return resp.data['data'] as Map<String, dynamic>;
  }

  /// B4. GET /v1/dramas — browse with multi-dimensional filters.
  Future<({List<DramaCard> items, Pagination pagination})> browseDramas({
    int page = 1,
    int pageSize = 20,
    String country = 'all',
    String region = 'all',
    String audioMode = 'all',
    String? subLang,
    bool? hasSubLang,
    String audience = 'all',
    String category = 'all',
    String tags = '',
    String status = 'all',
    String epLength = 'all',
    String isVip = 'all',
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
        if (subLang != null && subLang.isNotEmpty) 'sub_lang': subLang,
        'has_sub_lang': ?hasSubLang,
        if (audience != 'all') 'audience': audience,
        'category': category,
        if (tags.isNotEmpty) 'tag': tags,
        if (status != 'all') 'status': status,
        if (epLength != 'all') 'ep_length': epLength,
        if (isVip != 'all') 'is_vip': isVip,
        'sort': sort,
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

  /// B5. GET /v1/dramas/new — new releases.
  Future<({List<DramaCard> items, Pagination pagination})> fetchNewDramas({
    int page = 1,
    int pageSize = 20,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.dramasNew,
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

  /// B6. GET /v1/dramas/trending — trending leaderboard.
  Future<({List<DramaCard> items, Pagination pagination})>
      fetchTrendingDramas({
    int page = 1,
    int pageSize = 20,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.dramasTrending,
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

  /// B7. GET /v1/search — full-text multi-language search.
  Future<({List<DramaCard> items, Pagination pagination})> search({
    required String query,
    int page = 1,
    int pageSize = 20,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.search,
      queryParameters: {
        'q': query,
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

  /// B8. GET /v1/search/hot — hot keywords + trending dramas.
  Future<Map<String, dynamic>> searchHot({String lang = 'en'}) async {
    final resp = await _dio.get(
      ApiEndpoints.searchHot,
      queryParameters: {'lang': lang},
    );
    return resp.data['data'] as Map<String, dynamic>;
  }

  /// B9. GET /v1/categories — full category list with optional tags & facets.
  Future<Map<String, dynamic>> fetchCategories({String lang = 'en'}) async {
    final resp = await _dio.get(
      ApiEndpoints.categories,
      queryParameters: {'lang': lang, 'include_tags': true},
    );
    return resp.data['data'] as Map<String, dynamic>;
  }

  /// B10. GET /v1/languages — supported UI & subtitle languages.
  Future<List<Map<String, dynamic>>> fetchLanguages() async {
    final resp = await _dio.get(ApiEndpoints.languages);
    final data = resp.data['data'] as Map<String, dynamic>;
    return (data['languages'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
  }

  /// B11. GET /v1/dramas/ranking — top drama leaderboard (v4.5).
  Future<({List<DramaCard> items, Pagination pagination})> fetchRanking({
    String type = 'most_viewed',
    String period = 'week',
    String? country,
    String? region,
    String? category,
    int page = 1,
    int pageSize = 20,
    String lang = 'en',
  }) async {
    final resp = await _dio.get(
      ApiEndpoints.ranking,
      queryParameters: {
        'type': type,
        'period': period,
        if (country != null && country.isNotEmpty) 'country': country,
        if (region != null && region.isNotEmpty) 'region': region,
        if (category != null && category.isNotEmpty) 'category': category,
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
}
