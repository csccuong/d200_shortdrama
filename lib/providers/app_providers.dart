import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../core/constants/app_constants.dart';
import '../core/di/injection.dart';
import '../models/drama_models.dart';
import '../services/app_strings.dart';
import '../services/guest_identity_service.dart';
import '../services/shared_preference_service.dart';

// ============================================================================
// 0. DI SERVICE PROVIDERS (Bridging GetIt -> Riverpod)
// ============================================================================

final navigationServiceProvider = Provider<AppNavigationService>((ref) {
  return inject<AppNavigationService>();
});

final guestIdentityServiceProvider = Provider<GuestIdentityService>((ref) {
  return inject<GuestIdentityService>();
});

final guestIdentityProvider = Provider<GuestIdentity>((ref) {
  return ref.watch(guestIdentityServiceProvider).identity;
});

final catalogServiceProvider = Provider<CatalogService>((ref) {
  return inject<CatalogService>();
});

final subtitleServiceProvider = Provider<SubtitleService>((ref) {
  return inject<SubtitleService>();
});

final videoControllerFactoryProvider = Provider<VideoControllerFactory>((ref) {
  return inject<VideoControllerFactory>();
});

// ============================================================================
// 0.5 BOTTOM SHELL TAB NAVIGATION PROVIDER (5 Tabs: 0..4)
// 0: Home | 1: For you | 2: My List | 3: Rewards | 4: Profile
// ============================================================================

class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index.clamp(0, 4);
  }
}

final shellTabIndexProvider = NotifierProvider<ShellTabNotifier, int>(
  ShellTabNotifier.new,
);

// ============================================================================
// 1. LOCALE & SUBTITLE SETTINGS PROVIDER
// ============================================================================

class LocaleState {
  final String appLanguage;
  final String subtitleLanguage;
  final bool subtitlesEnabled;

  const LocaleState({
    this.appLanguage = 'vi',
    this.subtitleLanguage = 'vi',
    this.subtitlesEnabled = true,
  });

  String get subtitleLang => subtitlesEnabled ? subtitleLanguage : 'off';

  String tr(String key) => AppStrings.tr(appLanguage, key);

  String trTag(String rawTag) => AppStrings.trTag(appLanguage, rawTag);

  String dramaTitle(Drama drama) => AppStrings.dramaTitle(appLanguage, drama);

  String dramaDescription(Drama drama) =>
      AppStrings.dramaDescription(appLanguage, drama);

  LocaleState copyWith({
    String? appLanguage,
    String? subtitleLanguage,
    bool? subtitlesEnabled,
  }) {
    return LocaleState(
      appLanguage: appLanguage ?? this.appLanguage,
      subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
    );
  }
}

class LocaleNotifier extends Notifier<LocaleState> {
  @override
  LocaleState build() => LocaleState(
        appLanguage: AppConstants.selectedLanguageCode,
        subtitleLanguage: AppConstants.selectedLanguageCode,
      );

  void setAppLanguage(String langCode) {
    if (langCode == 'off') {
      state = state.copyWith(subtitlesEnabled: false);
    } else {
      AppConstants.selectedLanguageCode = langCode;
      unawaited(SharedPreferenceService.setSelectedLanguageCode(langCode));
      state = state.copyWith(
        appLanguage: langCode,
        subtitleLanguage: langCode,
      );
    }
  }

  void setSubtitleLanguage(String langCode) {
    if (langCode == 'off') {
      state = state.copyWith(subtitlesEnabled: false);
    } else {
      state = state.copyWith(
        subtitleLanguage: langCode,
        subtitlesEnabled: true,
      );
    }
  }

  void toggleSubtitlesEnabled([bool? enabled]) {
    state = state.copyWith(
      subtitlesEnabled: enabled ?? !state.subtitlesEnabled,
    );
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, LocaleState>(
  LocaleNotifier.new,
);

// ============================================================================
// 2. USER WALLET, VIP, REWARDS & SETTINGS PROVIDER
// ============================================================================

class UserWalletState {
  final bool isVip;
  final String vipPlanName;
  final Set<String> unlockedEpisodes;
  final Set<String> likedEpisodes;
  final bool autoPlayNext;
  final double playbackSpeed;
  final String videoQuality;
  final String? customStreamBaseUrl;

  const UserWalletState({
    this.isVip = false,
    this.vipPlanName = 'vip_weekly_name',
    this.unlockedEpisodes = const {},
    this.likedEpisodes = const {},
    this.autoPlayNext = true,
    this.playbackSpeed = 1.0,
    this.videoQuality = '1080p HD',
    this.customStreamBaseUrl,
  });

  bool isEpisodeUnlocked(Drama drama, int episodeNo) {
    if (isVip) return true;
    if (unlockedEpisodes.contains('${drama.slug}_$episodeNo')) return true;
    final match = drama.episodes.where((e) => e.episodeNo == episodeNo);
    if (match.isNotEmpty) {
      return !match.first.isLocked;
    }
    return episodeNo <= 10;
  }

  bool isEpisodeLiked(String slug, int episodeNo) =>
      likedEpisodes.contains('${slug}_$episodeNo');

  UserWalletState copyWith({
    bool? isVip,
    String? vipPlanName,
    Set<String>? unlockedEpisodes,
    Set<String>? likedEpisodes,
    bool? autoPlayNext,
    double? playbackSpeed,
    String? videoQuality,
    String? customStreamBaseUrl,
    bool clearCustomUrl = false,
  }) {
    return UserWalletState(
      isVip: isVip ?? this.isVip,
      vipPlanName: vipPlanName ?? this.vipPlanName,
      unlockedEpisodes: unlockedEpisodes ?? this.unlockedEpisodes,
      likedEpisodes: likedEpisodes ?? this.likedEpisodes,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      videoQuality: videoQuality ?? this.videoQuality,
      customStreamBaseUrl: clearCustomUrl
          ? null
          : (customStreamBaseUrl ?? this.customStreamBaseUrl),
    );
  }
}

class UserWalletNotifier extends Notifier<UserWalletState> {
  @override
  UserWalletState build() => UserWalletState(
        isVip: AppConstants.isPremiumUser.value,
      );

  void subscribeVip(String planName) {
    state = state.copyWith(
      isVip: true,
      vipPlanName: planName,
    );
    AppConstants.isPremiumUser.value = true;
    unawaited(SharedPreferenceService.setIsPremiumUser(true));
  }

  void toggleVip() {
    final nextVip = !state.isVip;
    state = state.copyWith(isVip: nextVip);
    AppConstants.isPremiumUser.value = nextVip;
    unawaited(SharedPreferenceService.setIsPremiumUser(nextVip));
  }

  void unlockEpisodeByAd(Drama drama, int episodeNo) {
    final nextUnlocked = {...state.unlockedEpisodes, '${drama.slug}_$episodeNo'};
    state = state.copyWith(unlockedEpisodes: nextUnlocked);
  }

  void toggleEpisodeLike(String slug, int episodeNo) {
    final key = '${slug}_$episodeNo';
    final nextLikes = {...state.likedEpisodes};
    if (nextLikes.contains(key)) {
      nextLikes.remove(key);
    } else {
      nextLikes.add(key);
    }
    state = state.copyWith(likedEpisodes: nextLikes);
  }

  void setAutoPlayNext(bool enabled) {
    state = state.copyWith(autoPlayNext: enabled);
  }

  void toggleAutoPlayNext() {
    state = state.copyWith(autoPlayNext: !state.autoPlayNext);
  }

  void setPlaybackSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed);
  }

  void setVideoQuality(String quality) {
    state = state.copyWith(videoQuality: quality);
  }

  void setCustomStreamBaseUrl(String? url) {
    final clean = url?.trim() ?? '';
    if (clean.isEmpty) {
      state = state.copyWith(clearCustomUrl: true);
    } else {
      state = state.copyWith(customStreamBaseUrl: clean);
    }
  }
}

final userWalletProvider =
    NotifierProvider<UserWalletNotifier, UserWalletState>(
  UserWalletNotifier.new,
);

// ============================================================================
// 3. WATCHLIST (MY LIST) & WATCH HISTORY PROVIDER
// ============================================================================

class WatchlistState {
  final Set<String> favorites;
  final Map<String, int> watchHistory;

  const WatchlistState({
    this.favorites = const {},
    this.watchHistory = const {},
  });

  bool isFavorite(String slug) => favorites.contains(slug);

  int getLastWatchedEpisode(String slug) => watchHistory[slug] ?? 1;

  WatchlistState copyWith({
    Set<String>? favorites,
    Map<String, int>? watchHistory,
  }) {
    return WatchlistState(
      favorites: favorites ?? this.favorites,
      watchHistory: watchHistory ?? this.watchHistory,
    );
  }
}

class WatchlistNotifier extends Notifier<WatchlistState> {
  @override
  WatchlistState build() => const WatchlistState();

  void toggleFavorite(String slug) {
    final nextFavs = {...state.favorites};
    if (nextFavs.contains(slug)) {
      nextFavs.remove(slug);
    } else {
      nextFavs.add(slug);
    }
    state = state.copyWith(favorites: nextFavs);
  }

  void recordWatchHistory(String slug, int episodeNo) {
    if (state.watchHistory[slug] == episodeNo) return;
    final nextHistory = {...state.watchHistory, slug: episodeNo};
    state = state.copyWith(watchHistory: nextHistory);
  }

  void clearHistory() {
    state = state.copyWith(watchHistory: const {});
  }
}

final watchlistProvider = NotifierProvider<WatchlistNotifier, WatchlistState>(
  WatchlistNotifier.new,
);

// ============================================================================
// 4. DRAMA CATALOG & SUBTITLE FUTURE PROVIDERS (Injected via DI)
// ============================================================================

final catalogProvider = FutureProvider<List<Drama>>((ref) async {
  final catalogService = ref.watch(catalogServiceProvider);
  return catalogService.loadCatalog();
});

/// Automatically watches [localeProvider] and loads + parses the `.srt` cues
/// for `(slug, episodeNo)` in the currently selected App Language via [SubtitleService].
final episodeSubtitlesProvider = FutureProvider.autoDispose
    .family<List<SubtitleCue>, ({String slug, int episodeNo})>((ref, args) async {
  final locale = ref.watch(localeProvider);
  if (!locale.subtitlesEnabled) return const [];

  final subtitleService = ref.watch(subtitleServiceProvider);
  return subtitleService.loadSubtitles(
    slug: args.slug,
    episodeNo: args.episodeNo,
    langCode: locale.subtitleLanguage,
  );
});

/// Helper to create a [VideoPlayerController] via the DI-registered [VideoControllerFactory].
VideoPlayerController createDramaVideoController({
  required Drama drama,
  required int episodeNo,
  String? customStreamBaseUrl,
}) {
  return inject<VideoControllerFactory>().create(
    drama: drama,
    episodeNo: episodeNo,
    customStreamBaseUrl: customStreamBaseUrl,
  );
}
