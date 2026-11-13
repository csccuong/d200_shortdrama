import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/di/injection.dart';
import '../models/drama_card.dart';
import '../models/home_response.dart';
import '../models/pagination.dart';
import '../services/api/home_api_service.dart';

// ============================================================================
// HOME STATE
// ============================================================================

class HomeState {
  final HomeResponse? homeData;
  final List<DramaCard> recommendedDramas;
  final Pagination? recommendedPagination;
  final bool isLoadingMore;

  const HomeState({
    this.homeData,
    this.recommendedDramas = const [],
    this.recommendedPagination,
    this.isLoadingMore = false,
  });

  HomeState copyWith({
    HomeResponse? homeData,
    List<DramaCard>? recommendedDramas,
    Pagination? recommendedPagination,
    bool? isLoadingMore,
  }) {
    return HomeState(
      homeData: homeData ?? this.homeData,
      recommendedDramas: recommendedDramas ?? this.recommendedDramas,
      recommendedPagination:
          recommendedPagination ?? this.recommendedPagination,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

// ============================================================================
// HOME NOTIFIER
// ============================================================================

class HomeNotifier extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    return const HomeState();
  }

  HomeApiService get _service => inject<HomeApiService>();

  /// Fetches the home screen data: banners, sections, and page-1 recommended.
  Future<void> fetchHome(String lang) async {
    state = const AsyncValue.loading();
    try {
      final homeResponse = await _service.fetchHome(lang: lang);

      state = AsyncValue.data(HomeState(
        homeData: homeResponse,
        recommendedDramas: homeResponse.recommended,
        recommendedPagination: homeResponse.recommendedPagination,
      ));
    } catch (e, st) {
      debugPrint('HomeNotifier.fetchHome error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Loads the next page of recommended dramas and appends to existing list.
  Future<void> loadMoreRecommended({String? lang}) async {
    final current = state.value;
    if (current == null) return;
    if (current.isLoadingMore) return;
    if (current.recommendedPagination?.hasMore != true) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final nextPage = (current.recommendedPagination!.page) + 1;
      final result = await _service.fetchRecommended(
        page: nextPage,
        pageSize: current.recommendedPagination!.pageSize,
        lang: lang ?? AppConstants.selectedLanguageCode,
      );

      // result is a named record with .items, .cohort, .pagination
      final newItems = result.items;
      final newPagination = result.pagination;

      state = AsyncValue.data(current.copyWith(
        recommendedDramas: [...current.recommendedDramas, ...newItems],
        recommendedPagination: newPagination,
        isLoadingMore: false,
      ));
    } catch (e) {
      debugPrint('HomeNotifier.loadMoreRecommended error: $e');
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
      // Don't replace whole state with error for pagination failures
    }
  }

  /// Re-fetches home data from scratch.
  Future<void> refresh(String lang) async {
    await fetchHome(lang);
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final homeProvider = AsyncNotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
