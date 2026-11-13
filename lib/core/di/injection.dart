import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:video_player/video_player.dart';
import '../../models/drama_models.dart';
import '../../services/guest_identity_service.dart';
import '../startup/app_startup_coordinator.dart';
import '../../services/api/app_api_service.dart';
import '../../services/api/home_api_service.dart';
import '../../services/api/feed_api_service.dart';
import '../../services/api/drama_api_service.dart';
import '../../services/api/mylist_api_service.dart';
import '../../services/api/rewards_api_service.dart';
import '../../services/api/account_api_service.dart';
import 'package:dxx_shortdrama/services/api/event_tracker_service.dart';
import '../utils/screen_utils.dart';

/// Global Service Locator instance (GetIt).
final GetIt getIt = GetIt.instance;

/// Initializes Dependency Injection for both Android and iOS platforms.
/// Safe to call multiple times (idempotent for Hot Reload / Hot Restart).
Future<void> setupDependencies() async {
  ensureDependenciesRegistered();
  await getIt<GuestIdentityService>().init();
}

/// Synchronous registration guard so Hot Reload works even if `main()` isn't re-run.
void ensureDependenciesRegistered() {
  if (!getIt.isRegistered<AppNavigationService>()) {
    getIt.registerLazySingleton<AppNavigationService>(
      () => AppNavigationService(),
    );
  }

  if (!getIt.isRegistered<GuestIdentityService>()) {
    getIt.registerLazySingleton<GuestIdentityService>(
      () => GuestIdentityService(),
    );
  }

  if (!getIt.isRegistered<CatalogService>()) {
    getIt.registerLazySingleton<CatalogService>(
      () => CatalogService(),
    );
  }

  if (!getIt.isRegistered<SubtitleService>()) {
    getIt.registerLazySingleton<SubtitleService>(
      () => SubtitleService(),
    );
  }

  if (!getIt.isRegistered<VideoControllerFactory>()) {
    getIt.registerLazySingleton<VideoControllerFactory>(
      () => VideoControllerFactory(),
    );
  }

  // ── API Integration: Startup Coordinator + 7 API Services ──

  if (!getIt.isRegistered<AppStartupCoordinator>()) {
    getIt.registerLazySingleton<AppStartupCoordinator>(
      () => AppStartupCoordinator(),
    );
  }

  if (!getIt.isRegistered<AppApiService>()) {
    getIt.registerLazySingleton<AppApiService>(
      () => AppApiService(getIt<AppStartupCoordinator>().dio),
    );
  }

  if (!getIt.isRegistered<HomeApiService>()) {
    getIt.registerLazySingleton<HomeApiService>(
      () => HomeApiService(getIt<AppStartupCoordinator>().dio),
    );
  }

  if (!getIt.isRegistered<FeedApiService>()) {
    getIt.registerLazySingleton<FeedApiService>(
      () => FeedApiService(getIt<AppStartupCoordinator>().dio),
    );
  }

  if (!getIt.isRegistered<DramaApiService>()) {
    getIt.registerLazySingleton<DramaApiService>(
      () => DramaApiService(getIt<AppStartupCoordinator>().dio),
    );
  }

  if (!getIt.isRegistered<MyListApiService>()) {
    getIt.registerLazySingleton<MyListApiService>(
      () => MyListApiService(getIt<AppStartupCoordinator>().dio),
    );
  }

  if (!getIt.isRegistered<RewardsApiService>()) {
    getIt.registerLazySingleton<RewardsApiService>(
      () => RewardsApiService(getIt<AppStartupCoordinator>().dio),
    );
  }

  if (!getIt.isRegistered<AccountApiService>()) {
    getIt.registerLazySingleton<AccountApiService>(
      () => AccountApiService(getIt<AppStartupCoordinator>().dio),
    );
  }

  if (!getIt.isRegistered<DramaEventTracker>()) {
    getIt.registerLazySingleton<DramaEventTracker>(
      () => DramaEventTracker(getIt<AppStartupCoordinator>().dio),
      dispose: (tracker) => tracker.dispose(),
    );
  }
}

/// Helper to safely resolve a registered dependency from [getIt].
T inject<T extends Object>() {
  ensureDependenciesRegistered();
  return getIt<T>();
}

// ============================================================================
// INJECTABLE SERVICES
// ============================================================================

/// Cross-platform Navigation Service (Cupertino route on iOS, Material on Android).
class AppNavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(
      AppScreenUtils.adaptivePageRoute<T>(builder: (_) => page),
    );
  }
}

/// Service responsible for returning drama catalog entries from the backend.
class CatalogService {
  List<Drama>? _cachedCatalog;

  Future<List<Drama>> loadCatalog({bool forceRefresh = false}) async {
    if (_cachedCatalog != null && !forceRefresh) {
      return _cachedCatalog!;
    }
    _cachedCatalog = const [];
    return _cachedCatalog!;
  }
}

/// Service responsible for caching `.srt` subtitles synchronized with App Language.
class SubtitleService {
  final Map<String, List<SubtitleCue>> _cache = {};

  Future<List<SubtitleCue>> loadSubtitles({
    required String slug,
    required int episodeNo,
    required String langCode,
  }) async {
    final cacheKey = '$slug|$episodeNo|$langCode';
    return _cache[cacheKey] ?? const [];
  }
}

/// Platform-aware factory for creating [VideoPlayerController] instances
/// configured for Android (ExoPlayer) and iOS (AVPlayer).
class VideoControllerFactory {
  VideoPlayerController create({
    required Drama drama,
    required int episodeNo,
    String? customStreamBaseUrl,
  }) {
    final options = VideoPlayerOptions(
      mixWithOthers: false,
      allowBackgroundPlayback: false,
    );

    if (customStreamBaseUrl != null && customStreamBaseUrl.isNotEmpty) {
      final epPadded = episodeNo.toString().padLeft(3, '0');
      final base = customStreamBaseUrl.replaceAll(RegExp(r'/$'), '');
      final url = '$base/${drama.slug}/video/ep_$epPadded.mp4';
      return VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: options,
      );
    }

    return VideoPlayerController.networkUrl(
      Uri(),
      videoPlayerOptions: options,
    );
  }

  /// Creates an unauthenticated network controller for opaque stream URLs
  /// (`/v1/stream/{token}.mp4` or full CDN URLs).
  VideoPlayerController createFromUrl(String rawUrl) {
    final options = VideoPlayerOptions(
      mixWithOthers: false,
      allowBackgroundPlayback: false,
    );
    final resolved = getIt<AppStartupCoordinator>().resolveMediaUrl(rawUrl);
    if (resolved.isEmpty) {
      return VideoPlayerController.networkUrl(
        Uri(),
        videoPlayerOptions: options,
      );
    }
    return VideoPlayerController.networkUrl(
      Uri.parse(resolved),
      videoPlayerOptions: options,
    );
  }
}
