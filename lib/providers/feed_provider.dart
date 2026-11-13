import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../models/feed_response.dart';
import '../services/api/feed_api_service.dart';

// ============================================================================
// FEED STATE — For You vertical swipe feed (cursor-based pagination)
// ============================================================================

class FeedState {
  final List<ForYouItem> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final String cohort;
  final List<Map<String, String>> pendingEvents;

  const FeedState({
    this.items = const [],
    this.nextCursor,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.cohort = '',
    this.pendingEvents = const [],
  });

  FeedState copyWith({
    List<ForYouItem>? items,
    String? nextCursor,
    bool? hasMore,
    bool? isLoadingMore,
    String? cohort,
    List<Map<String, String>>? pendingEvents,
  }) {
    return FeedState(
      items: items ?? this.items,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      cohort: cohort ?? this.cohort,
      pendingEvents: pendingEvents ?? this.pendingEvents,
    );
  }
}

// ============================================================================
// FEED NOTIFIER — Cursor-based "For You" feed with event batching
// ============================================================================

class FeedNotifier extends Notifier<FeedState> {
  static const int _defaultCount = 20;
  static const int _eventFlushThreshold = 15;

  @override
  FeedState build() => const FeedState();

  FeedApiService get _service => inject<FeedApiService>();

  /// Fetches the initial page with cursor='0', count=20.
  Future<void> fetchInitialFeed(String lang) async {
    state = state.copyWith(isLoadingMore: true);
    try {
      final response = await _service.fetchForYouFeed(
        cursor: '0',
        count: _defaultCount,
        lang: lang,
      );

      state = FeedState(
        items: response.items,
        nextCursor: response.nextCursor,
        hasMore: response.hasMore,
        cohort: response.cohort,
        isLoadingMore: false,
      );
    } catch (e) {
      debugPrint('FeedNotifier.fetchInitialFeed error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Loads the next page using the current cursor.
  Future<void> loadMore(String lang) async {
    if (state.isLoadingMore || !state.hasMore) return;
    final cursor = state.nextCursor;
    if (cursor == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final response = await _service.fetchForYouFeed(
        cursor: cursor,
        count: _defaultCount,
        lang: lang,
      );

      state = state.copyWith(
        items: [...state.items, ...response.items],
        nextCursor: response.nextCursor,
        hasMore: response.hasMore,
        cohort: response.cohort,
        isLoadingMore: false,
      );
    } catch (e) {
      debugPrint('FeedNotifier.loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Refreshes the feed with cursor='0' and refresh=true (new seed).
  Future<void> refresh(String lang) async {
    state = state.copyWith(isLoadingMore: true);
    try {
      final response = await _service.fetchForYouFeed(
        cursor: '0',
        count: _defaultCount,
        refresh: true,
        lang: lang,
      );

      state = FeedState(
        items: response.items,
        nextCursor: response.nextCursor,
        hasMore: response.hasMore,
        cohort: response.cohort,
        isLoadingMore: false,
        pendingEvents: state.pendingEvents, // preserve pending events
      );
    } catch (e) {
      debugPrint('FeedNotifier.refresh error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Buffers a user interaction event; flushes when buffer ≥ 15 events.
  void trackEvent(String dramaId, String action) {
    final event = {'drama_id': dramaId, 'action': action};
    final updatedEvents = [...state.pendingEvents, event];

    state = state.copyWith(pendingEvents: updatedEvents);

    if (updatedEvents.length >= _eventFlushThreshold) {
      flushEvents();
    }
  }

  /// Sends the buffered events batch to POST /v1/feed/events.
  Future<void> flushEvents() async {
    if (state.pendingEvents.isEmpty) return;

    final eventsToSend = List<Map<String, String>>.from(state.pendingEvents);
    state = state.copyWith(pendingEvents: const []);

    try {
      await _service.sendFeedEvents(eventsToSend);
    } catch (e) {
      debugPrint('FeedNotifier.flushEvents error: $e');
      // Put events back so they can be retried
      state = state.copyWith(
        pendingEvents: [...eventsToSend, ...state.pendingEvents],
      );
    }
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
