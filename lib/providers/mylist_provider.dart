import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/di/injection.dart';
import '../models/drama_card.dart';
import '../models/pagination.dart';
import '../services/api/drama_api_service.dart';
import '../services/api/mylist_api_service.dart';

/// Shared state for Favorites (`My List`), `Watch Later`, `History`, and local `Liked` flags.
class MyListState {
  final List<DramaCard> favorites;
  final List<DramaCard> watchLater;
  final List<DramaCard> history;
  final Pagination? favoritesPagination;
  final Pagination? watchLaterPagination;
  final Pagination? historyPagination;
  final bool isLoadingFavorites;
  final bool isLoadingWatchLater;
  final bool isLoadingHistory;
  final Set<String> favoriteIds;
  final Set<String> watchLaterIds;
  final Set<String> likedIds;

  const MyListState({
    this.favorites = const [],
    this.watchLater = const [],
    this.history = const [],
    this.favoritesPagination,
    this.watchLaterPagination,
    this.historyPagination,
    this.isLoadingFavorites = false,
    this.isLoadingWatchLater = false,
    this.isLoadingHistory = false,
    this.favoriteIds = const {},
    this.watchLaterIds = const {},
    this.likedIds = const {},
  });

  bool isFavorited(String dramaId) => favoriteIds.contains(dramaId);
  bool isInWatchLater(String dramaId) => watchLaterIds.contains(dramaId);
  bool isLiked(String dramaId) => likedIds.contains(dramaId);

  MyListState copyWith({
    List<DramaCard>? favorites,
    List<DramaCard>? watchLater,
    List<DramaCard>? history,
    Pagination? favoritesPagination,
    Pagination? watchLaterPagination,
    Pagination? historyPagination,
    bool? isLoadingFavorites,
    bool? isLoadingWatchLater,
    bool? isLoadingHistory,
    Set<String>? favoriteIds,
    Set<String>? watchLaterIds,
    Set<String>? likedIds,
  }) {
    return MyListState(
      favorites: favorites ?? this.favorites,
      watchLater: watchLater ?? this.watchLater,
      history: history ?? this.history,
      favoritesPagination: favoritesPagination ?? this.favoritesPagination,
      watchLaterPagination: watchLaterPagination ?? this.watchLaterPagination,
      historyPagination: historyPagination ?? this.historyPagination,
      isLoadingFavorites: isLoadingFavorites ?? this.isLoadingFavorites,
      isLoadingWatchLater: isLoadingWatchLater ?? this.isLoadingWatchLater,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      watchLaterIds: watchLaterIds ?? this.watchLaterIds,
      likedIds: likedIds ?? this.likedIds,
    );
  }
}

class MyListNotifier extends Notifier<MyListState> {
  MyListApiService get _service => inject<MyListApiService>();
  DramaApiService get _dramaService => inject<DramaApiService>();

  @override
  MyListState build() => const MyListState();

  /// Absorbs boolean interaction flags coming from Home / ForYou / Detail API responses.
  void syncCards(Iterable<DramaCard> cards) {
    final favs = {...state.favoriteIds};
    final watchLater = {...state.watchLaterIds};
    final liked = {...state.likedIds};
    var changed = false;

    for (final c in cards) {
      if (c.isFavorited && !favs.contains(c.dramaId)) {
        favs.add(c.dramaId);
        changed = true;
      }
      if (c.isInWatchLater && !watchLater.contains(c.dramaId)) {
        watchLater.add(c.dramaId);
        changed = true;
      }
      if (c.isLiked && !liked.contains(c.dramaId)) {
        liked.add(c.dramaId);
        changed = true;
      }
    }

    if (changed) {
      state = state.copyWith(
        favoriteIds: favs,
        watchLaterIds: watchLater,
        likedIds: liked,
      );
    }
  }

  Future<void> fetchFavorites({String? lang, bool refresh = true}) async {
    state = state.copyWith(isLoadingFavorites: true);
    try {
      final res = await _service.fetchFavorites(
        page: 1,
        pageSize: 20,
        lang: lang ?? AppConstants.selectedLanguageCode,
      );
      final ids = {...res.items.map((e) => e.dramaId)};
      final wlIds = {
        ...state.watchLaterIds,
        ...res.items.where((e) => e.isInWatchLater).map((e) => e.dramaId),
      };
      state = state.copyWith(
        favorites: res.items,
        favoritesPagination: res.pagination,
        isLoadingFavorites: false,
        favoriteIds: ids,
        watchLaterIds: wlIds,
      );
    } catch (e) {
      debugPrint('MyListNotifier.fetchFavorites error: $e');
      state = state.copyWith(isLoadingFavorites: false);
    }
  }

  Future<void> loadMoreFavorites({String? lang}) async {
    final pg = state.favoritesPagination;
    if (state.isLoadingFavorites || pg == null || !pg.hasMore) return;
    state = state.copyWith(isLoadingFavorites: true);
    try {
      final res = await _service.fetchFavorites(
        page: pg.page + 1,
        pageSize: 20,
        lang: lang ?? AppConstants.selectedLanguageCode,
      );
      final merged = [...state.favorites, ...res.items];
      state = state.copyWith(
        favorites: merged,
        favoritesPagination: res.pagination,
        isLoadingFavorites: false,
        favoriteIds: {...state.favoriteIds, ...res.items.map((e) => e.dramaId)},
      );
    } catch (e) {
      debugPrint('MyListNotifier.loadMoreFavorites error: $e');
      state = state.copyWith(isLoadingFavorites: false);
    }
  }

  Future<bool> toggleFavorite(
    DramaCard drama, {
    int episodeNumber = 1,
  }) async {
    final wasFav = state.favoriteIds.contains(drama.dramaId) || drama.isFavorited;
    final nextFavs = {...state.favoriteIds};
    if (wasFav) {
      nextFavs.remove(drama.dramaId);
    } else {
      nextFavs.add(drama.dramaId);
    }
    state = state.copyWith(
      favoriteIds: nextFavs,
      favorites: wasFav
          ? state.favorites.where((e) => e.dramaId != drama.dramaId).toList()
          : [
              drama.copyWith(isFavorited: true),
              ...state.favorites.where((e) => e.dramaId != drama.dramaId),
            ],
    );

    try {
      final result = await _service.toggleFavorite(
        drama.dramaId,
        action: 'toggle',
        episodeNumber: episodeNumber,
      );
      final serverFav = result.isFavorited;
      final confirmed = {...state.favoriteIds};
      if (serverFav) {
        confirmed.add(drama.dramaId);
      } else {
        confirmed.remove(drama.dramaId);
      }
      state = state.copyWith(favoriteIds: confirmed);
      return serverFav;
    } catch (e) {
      debugPrint('MyListNotifier.toggleFavorite error: $e');
      return !wasFav;
    }
  }

  Future<void> deleteFavorites({
    List<String>? dramaIds,
    bool clearAll = false,
  }) async {
    try {
      await _service.deleteFavorites(dramaIds: dramaIds, clearAll: clearAll);
      if (clearAll) {
        state = state.copyWith(favorites: const [], favoriteIds: const {});
      } else if (dramaIds != null) {
        final removeSet = dramaIds.toSet();
        state = state.copyWith(
          favorites:
              state.favorites.where((e) => !removeSet.contains(e.dramaId)).toList(),
          favoriteIds:
              state.favoriteIds.where((id) => !removeSet.contains(id)).toSet(),
        );
      }
    } catch (e) {
      debugPrint('MyListNotifier.deleteFavorites error: $e');
    }
  }

  Future<void> fetchWatchLater({String? lang}) async {
    state = state.copyWith(isLoadingWatchLater: true);
    try {
      final res = await _service.fetchWatchLater(
        page: 1,
        pageSize: 20,
        lang: lang ?? AppConstants.selectedLanguageCode,
      );
      state = state.copyWith(
        watchLater: res.items,
        watchLaterPagination: res.pagination,
        isLoadingWatchLater: false,
        watchLaterIds: {...res.items.map((e) => e.dramaId)},
      );
    } catch (e) {
      debugPrint('MyListNotifier.fetchWatchLater error: $e');
      state = state.copyWith(isLoadingWatchLater: false);
    }
  }

  Future<bool> toggleWatchLater(
    DramaCard drama, {
    int episodeNumber = 1,
    String? note,
  }) async {
    final wasSaved =
        state.watchLaterIds.contains(drama.dramaId) || drama.isInWatchLater;
    final nextSet = {...state.watchLaterIds};
    if (wasSaved) {
      nextSet.remove(drama.dramaId);
    } else {
      nextSet.add(drama.dramaId);
    }
    state = state.copyWith(
      watchLaterIds: nextSet,
      watchLater: wasSaved
          ? state.watchLater.where((e) => e.dramaId != drama.dramaId).toList()
          : [
              drama.copyWith(isInWatchLater: true),
              ...state.watchLater.where((e) => e.dramaId != drama.dramaId),
            ],
    );

    try {
      final result = await _service.toggleWatchLater(
        drama.dramaId,
        action: 'toggle',
        episodeNumber: episodeNumber,
        note: note,
      );
      final serverSaved = result.isInWatchLater;
      final confirmed = {...state.watchLaterIds};
      if (serverSaved) {
        confirmed.add(drama.dramaId);
      } else {
        confirmed.remove(drama.dramaId);
      }
      state = state.copyWith(watchLaterIds: confirmed);
      return serverSaved;
    } catch (e) {
      debugPrint('MyListNotifier.toggleWatchLater error: $e');
      return !wasSaved;
    }
  }

  Future<void> deleteWatchLater({
    List<String>? dramaIds,
    bool clearAll = false,
  }) async {
    try {
      await _service.deleteWatchLater(dramaIds: dramaIds, clearAll: clearAll);
      if (clearAll) {
        state = state.copyWith(watchLater: const [], watchLaterIds: const {});
      } else if (dramaIds != null) {
        final removeSet = dramaIds.toSet();
        state = state.copyWith(
          watchLater:
              state.watchLater.where((e) => !removeSet.contains(e.dramaId)).toList(),
          watchLaterIds:
              state.watchLaterIds.where((id) => !removeSet.contains(id)).toSet(),
        );
      }
    } catch (e) {
      debugPrint('MyListNotifier.deleteWatchLater error: $e');
    }
  }

  Future<void> fetchHistory({String? lang}) async {
    state = state.copyWith(isLoadingHistory: true);
    try {
      final res = await _service.fetchHistory(
        page: 1,
        pageSize: 20,
        lang: lang ?? AppConstants.selectedLanguageCode,
      );
      state = state.copyWith(
        history: res.items,
        historyPagination: res.pagination,
        isLoadingHistory: false,
      );
      syncCards(res.items);
    } catch (e) {
      debugPrint('MyListNotifier.fetchHistory error: $e');
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  Future<void> loadMoreHistory({String? lang}) async {
    final pg = state.historyPagination;
    if (state.isLoadingHistory || pg == null || !pg.hasMore) return;
    state = state.copyWith(isLoadingHistory: true);
    try {
      final res = await _service.fetchHistory(
        page: pg.page + 1,
        pageSize: 20,
        lang: lang ?? AppConstants.selectedLanguageCode,
      );
      state = state.copyWith(
        history: [...state.history, ...res.items],
        historyPagination: res.pagination,
        isLoadingHistory: false,
      );
    } catch (e) {
      debugPrint('MyListNotifier.loadMoreHistory error: $e');
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  Future<void> saveHistory({
    required String dramaId,
    required int episodeNumber,
    required int positionSec,
    required int durationSec,
    int watchedDeltaSec = 0,
  }) async {
    try {
      await _service.saveHistory(
        dramaId: dramaId,
        episodeNumber: episodeNumber,
        positionSec: positionSec,
        durationSec: durationSec,
        watchedDeltaSec: watchedDeltaSec,
      );
    } catch (e) {
      debugPrint('MyListNotifier.saveHistory error: $e');
    }
  }

  Future<void> deleteHistory({
    List<String>? dramaIds,
    bool clearAll = false,
  }) async {
    try {
      await _service.deleteHistory(dramaIds: dramaIds, clearAll: clearAll);
      if (clearAll) {
        state = state.copyWith(history: const []);
      } else if (dramaIds != null) {
        final removeSet = dramaIds.toSet();
        state = state.copyWith(
          history:
              state.history.where((e) => !removeSet.contains(e.dramaId)).toList(),
        );
      }
    } catch (e) {
      debugPrint('MyListNotifier.deleteHistory error: $e');
    }
  }

  Future<({bool isLiked, int likeCount})> toggleLike(
    String dramaId, {
    int episodeNumber = 0,
    int currentLikeCount = 0,
  }) async {
    final wasLiked = state.likedIds.contains(dramaId);
    final nextLiked = {...state.likedIds};
    if (wasLiked) {
      nextLiked.remove(dramaId);
    } else {
      nextLiked.add(dramaId);
    }
    state = state.copyWith(likedIds: nextLiked);

    try {
      final res = await _dramaService.likeDrama(
        dramaId,
        action: 'toggle',
        episodeNumber: episodeNumber,
      );
      final serverLiked = res.isLiked;
      final count = res.likeCount >= 0 ? res.likeCount : currentLikeCount;
      final confirmed = {...state.likedIds};
      if (serverLiked) {
        confirmed.add(dramaId);
      } else {
        confirmed.remove(dramaId);
      }
      state = state.copyWith(likedIds: confirmed);
      return (isLiked: serverLiked, likeCount: count);
    } catch (e) {
      debugPrint('MyListNotifier.toggleLike error: $e');
      return (isLiked: !wasLiked, likeCount: currentLikeCount);
    }
  }
}

final mylistProvider = NotifierProvider<MyListNotifier, MyListState>(
  MyListNotifier.new,
);
