/// Subtitle track info for video playback.
class SubtitleTrack {
  final String language;
  final String label;
  final String format;
  final bool isDefault;
  final String url;

  SubtitleTrack({
    required this.language,
    this.label = '',
    this.format = 'vtt',
    this.isDefault = false,
    this.url = '',
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    return SubtitleTrack(
      language: json['language'] as String? ?? '',
      label: json['label'] as String? ?? '',
      format: json['format'] as String? ?? 'vtt',
      isDefault: json['is_default'] as bool? ?? false,
      url: json['url'] as String? ?? '',
    );
  }
}

/// Info about the next episode after the current one.
class NextEpisodeInfo {
  final int episodeNumber;
  final bool isLocked;
  final int unlockCoinCost;

  NextEpisodeInfo({
    required this.episodeNumber,
    this.isLocked = false,
    this.unlockCoinCost = 0,
  });

  factory NextEpisodeInfo.fromJson(Map<String, dynamic> json) {
    return NextEpisodeInfo(
      episodeNumber: json['episode_number'] as int? ?? 0,
      isLocked: json['is_locked'] as bool? ?? false,
      unlockCoinCost: json['unlock_coin_cost'] as int? ?? 0,
    );
  }
}

/// Successful play response (HTTP 200).
class PlayResponse {
  final String dramaId;
  final int episodeNumber;
  final int durationSec;
  final String accessReason;
  final String videoUrl;
  final int streamExpiresIn;
  final List<SubtitleTrack> subtitles;
  final NextEpisodeInfo? nextEpisode;

  PlayResponse({
    required this.dramaId,
    required this.episodeNumber,
    this.durationSec = 0,
    this.accessReason = '',
    this.videoUrl = '',
    this.streamExpiresIn = 900,
    this.subtitles = const [],
    this.nextEpisode,
  });

  factory PlayResponse.fromJson(Map<String, dynamic> json) {
    return PlayResponse(
      dramaId: json['drama_id']?.toString() ?? '',
      episodeNumber: json['episode_number'] as int? ?? 0,
      durationSec: json['duration_sec'] as int? ?? 0,
      accessReason: json['access_reason'] as String? ?? '',
      videoUrl: json['video_url'] as String? ?? '',
      streamExpiresIn: json['stream_expires_in'] as int? ?? 900,
      subtitles: (json['subtitles'] as List<dynamic>?)
              ?.map(
                  (e) => SubtitleTrack.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      nextEpisode: json['next_episode'] != null
          ? NextEpisodeInfo.fromJson(
              json['next_episode'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Options presented when an episode is locked (HTTP 402 paywall).
class UnlockOptions {
  final bool allowAdUnlock;
  final int adUnlocksRemainingToday;
  final int adUnlockDailyLimit;
  final int coinCost;
  final int fullDramaRemainingEpisodes;
  final int fullDramaCoinCost;
  final int fullDramaDiscountPct;
  final int userCoinBalance;
  final int userBonusCoinBalance;
  final int userTotalCoins;
  final bool canAffordSingle;
  final bool canAffordFullDrama;

  UnlockOptions({
    this.allowAdUnlock = false,
    this.adUnlocksRemainingToday = 0,
    this.adUnlockDailyLimit = 10,
    this.coinCost = 0,
    this.fullDramaRemainingEpisodes = 0,
    this.fullDramaCoinCost = 0,
    this.fullDramaDiscountPct = 0,
    this.userCoinBalance = 0,
    this.userBonusCoinBalance = 0,
    this.userTotalCoins = 0,
    this.canAffordSingle = false,
    this.canAffordFullDrama = false,
  });

  factory UnlockOptions.fromJson(Map<String, dynamic> json) {
    return UnlockOptions(
      allowAdUnlock: json['allow_ad_unlock'] as bool? ?? false,
      adUnlocksRemainingToday:
          json['ad_unlocks_remaining_today'] as int? ?? 0,
      adUnlockDailyLimit: json['ad_unlock_daily_limit'] as int? ?? 10,
      coinCost: json['coin_cost'] as int? ?? 0,
      fullDramaRemainingEpisodes:
          json['full_drama_remaining_episodes'] as int? ?? 0,
      fullDramaCoinCost: json['full_drama_coin_cost'] as int? ?? 0,
      fullDramaDiscountPct:
          json['full_drama_discount_pct'] as int? ?? 0,
      userCoinBalance: json['user_coin_balance'] as int? ?? 0,
      userBonusCoinBalance:
          json['user_bonus_coin_balance'] as int? ?? 0,
      userTotalCoins: json['user_total_coins'] as int? ?? 0,
      canAffordSingle: json['can_afford_single'] as bool? ?? false,
      canAffordFullDrama: json['can_afford_full_drama'] as bool? ?? false,
    );
  }
}

/// Paywall response body when an episode is locked (HTTP 402).
class PaywallResponse {
  final String dramaId;
  final int episodeNumber;
  final bool isLocked;
  final UnlockOptions unlockOptions;

  PaywallResponse({
    required this.dramaId,
    required this.episodeNumber,
    this.isLocked = true,
    required this.unlockOptions,
  });

  factory PaywallResponse.fromJson(Map<String, dynamic> json) {
    return PaywallResponse(
      dramaId: json['drama_id']?.toString() ?? '',
      episodeNumber: json['episode_number'] as int? ?? 0,
      isLocked: json['is_locked'] as bool? ?? true,
      unlockOptions: UnlockOptions.fromJson(
          json['unlock_options'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Response after successfully unlocking an episode.
class UnlockResponse {
  final int coinBalance;
  final int bonusCoinBalance;
  final int totalCoins;
  final int adUnlocksRemainingToday;
  final String videoUrl;
  final List<SubtitleTrack> subtitles;

  UnlockResponse({
    this.coinBalance = 0,
    this.bonusCoinBalance = 0,
    this.totalCoins = 0,
    this.adUnlocksRemainingToday = 0,
    this.videoUrl = '',
    this.subtitles = const [],
  });

  factory UnlockResponse.fromJson(Map<String, dynamic> json) {
    return UnlockResponse(
      coinBalance: json['coin_balance'] as int? ?? 0,
      bonusCoinBalance: json['bonus_coin_balance'] as int? ?? 0,
      totalCoins: json['total_coins'] as int? ?? 0,
      adUnlocksRemainingToday:
          json['ad_unlocks_remaining_today'] as int? ?? 0,
      videoUrl: json['video_url'] as String? ?? '',
      subtitles: (json['subtitles'] as List<dynamic>?)
              ?.map(
                  (e) => SubtitleTrack.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
