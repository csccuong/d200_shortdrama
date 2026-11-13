/// User settings sub-object from profile / app/init.
class UserSettings {
  final String appLanguage;
  final String subtitleLanguage;
  final bool autoPlayNext;
  final String videoQuality;
  final bool wifiOnly;

  UserSettings({
    this.appLanguage = 'en',
    this.subtitleLanguage = 'en',
    this.autoPlayNext = true,
    this.videoQuality = 'auto',
    this.wifiOnly = false,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      appLanguage: json['app_language'] as String? ?? 'en',
      subtitleLanguage: json['subtitle_language'] as String? ?? 'en',
      autoPlayNext: json['auto_play_next'] as bool? ?? true,
      videoQuality: json['video_quality'] as String? ?? 'auto',
      wifiOnly: json['wifi_only'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'app_language': appLanguage,
        'subtitle_language': subtitleLanguage,
        'auto_play_next': autoPlayNext,
        'video_quality': videoQuality,
        'wifi_only': wifiOnly,
      };
}

/// User profile from GET /v1/me/profile and /v1/app/init → user section.
class UserProfile {
  final String userUid;
  final String deviceId;
  final String authProvider;
  final bool isGuest;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final String? gender;
  final int? birthYear;
  final bool isVip;
  final String? vipExpiresAt;
  final int coinBalance;
  final int bonusCoinBalance;
  final int totalCoins;
  final int adUnlocksUsedToday;
  final int adUnlocksRemainingToday;
  final int todayWatchSeconds;
  final int checkinStreak;
  final bool canCheckinToday;
  final int favoritesCount;
  final int watchLaterCount;
  final int watchedDramasCount;
  final UserSettings settings;

  UserProfile({
    this.userUid = '',
    this.deviceId = '',
    this.authProvider = 'guest',
    this.isGuest = true,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.gender,
    this.birthYear,
    this.isVip = false,
    this.vipExpiresAt,
    this.coinBalance = 0,
    this.bonusCoinBalance = 0,
    this.totalCoins = 0,
    this.adUnlocksUsedToday = 0,
    this.adUnlocksRemainingToday = 0,
    this.todayWatchSeconds = 0,
    this.checkinStreak = 0,
    this.canCheckinToday = false,
    this.favoritesCount = 0,
    this.watchLaterCount = 0,
    this.watchedDramasCount = 0,
    UserSettings? settings,
  }) : settings = settings ?? UserSettings();

  UserProfile copyWith({
    UserSettings? settings,
    String? displayName,
    String? avatarUrl,
    String? gender,
    int? birthYear,
  }) {
    return UserProfile(
      userUid: userUid,
      deviceId: deviceId,
      authProvider: authProvider,
      isGuest: isGuest,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      isVip: isVip,
      vipExpiresAt: vipExpiresAt,
      coinBalance: coinBalance,
      bonusCoinBalance: bonusCoinBalance,
      totalCoins: totalCoins,
      adUnlocksUsedToday: adUnlocksUsedToday,
      adUnlocksRemainingToday: adUnlocksRemainingToday,
      todayWatchSeconds: todayWatchSeconds,
      checkinStreak: checkinStreak,
      canCheckinToday: canCheckinToday,
      favoritesCount: favoritesCount,
      watchLaterCount: watchLaterCount,
      watchedDramasCount: watchedDramasCount,
      settings: settings ?? this.settings,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>?;
    return UserProfile(
      userUid: json['user_uid'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      authProvider: json['auth_provider'] as String? ?? 'guest',
      isGuest: json['is_guest'] as bool? ?? true,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as String?,
      birthYear: (json['birth_year'] as num?)?.toInt(),
      isVip: json['is_vip'] as bool? ?? false,
      vipExpiresAt: json['vip_expires_at'] as String?,
      coinBalance: (json['coin_balance'] as num?)?.toInt() ?? 0,
      bonusCoinBalance: (json['bonus_coin_balance'] as num?)?.toInt() ?? 0,
      totalCoins: (json['total_coins'] as num?)?.toInt() ?? 0,
      adUnlocksUsedToday:
          (json['ad_unlocks_used_today'] as num?)?.toInt() ?? 0,
      adUnlocksRemainingToday:
          (json['ad_unlocks_remaining_today'] as num?)?.toInt() ?? 0,
      todayWatchSeconds: (json['today_watch_seconds'] as num?)?.toInt() ?? 0,
      checkinStreak: (json['checkin_streak'] as num?)?.toInt() ?? 0,
      canCheckinToday: json['can_checkin_today'] as bool? ?? false,
      favoritesCount: (json['favorites_count'] as num?)?.toInt() ??
          (stats?['favorites_count'] as num?)?.toInt() ??
          0,
      watchLaterCount: (json['watch_later_count'] as num?)?.toInt() ??
          (stats?['watch_later_count'] as num?)?.toInt() ??
          0,
      watchedDramasCount: (json['watched_dramas_count'] as num?)?.toInt() ??
          (stats?['watched_dramas_count'] as num?)?.toInt() ??
          0,
      settings: json['settings'] != null
          ? UserSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : null,
    );
  }
}
