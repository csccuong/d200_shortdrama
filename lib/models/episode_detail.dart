import 'pagination.dart';

/// A single episode in the episode grid.
class EpisodeItem {
  final int episodeNumber;
  final String title;
  final int durationSec;
  final bool isReady;
  final bool isFreeTier;
  final bool isUnlocked;
  final bool isLocked;
  final int unlockCoinCost;
  final List<String> subtitleLanguages;

  EpisodeItem({
    required this.episodeNumber,
    this.title = '',
    this.durationSec = 0,
    this.isReady = true,
    this.isFreeTier = false,
    this.isUnlocked = false,
    this.isLocked = false,
    this.unlockCoinCost = 0,
    this.subtitleLanguages = const [],
  });

  factory EpisodeItem.fromJson(Map<String, dynamic> json) {
    return EpisodeItem(
      episodeNumber: json['episode_number'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      durationSec: json['duration_sec'] as int? ?? 0,
      isReady: json['is_ready'] as bool? ?? true,
      isFreeTier: json['is_free_tier'] as bool? ?? false,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      unlockCoinCost: json['unlock_coin_cost'] as int? ?? 0,
      subtitleLanguages: (json['subtitle_languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Full response for GET /v1/dramas/{drama_id}/episodes.
class EpisodesListResponse {
  final String dramaId;
  final int freeEpisodesCount;
  final int unlockCoinCost;
  final bool isUserVip;
  final List<EpisodeItem> items;
  final Pagination pagination;

  EpisodesListResponse({
    required this.dramaId,
    this.freeEpisodesCount = 0,
    this.unlockCoinCost = 0,
    this.isUserVip = false,
    this.items = const [],
    required this.pagination,
  });

  factory EpisodesListResponse.fromJson(Map<String, dynamic> json) {
    return EpisodesListResponse(
      dramaId: json['drama_id']?.toString() ?? '',
      freeEpisodesCount: json['free_episodes_count'] as int? ?? 0,
      unlockCoinCost: json['unlock_coin_cost'] as int? ?? 0,
      isUserVip: json['is_user_vip'] as bool? ?? false,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) =>
                  EpisodeItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      pagination: Pagination.fromJson(
          json['pagination'] as Map<String, dynamic>? ?? {}),
    );
  }
}
