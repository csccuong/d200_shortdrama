import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:video_player/video_player.dart';
import '../../models/drama_models.dart';
import '../../services/guest_identity_service.dart';
import '../../services/srt_parser.dart';
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

/// Service responsible for loading & caching the drama catalog (`catalog.json`).
class CatalogService {
  List<Drama>? _cachedCatalog;

  Future<List<Drama>> loadCatalog({bool forceRefresh = false}) async {
    if (_cachedCatalog != null && !forceRefresh) {
      return _cachedCatalog!;
    }
    final rawJson = await rootBundle.loadString('assets/dramas/catalog.json');
    final list = json.decode(rawJson) as List<dynamic>;
    _cachedCatalog = list
        .map((item) => Drama.fromJson(item as Map<String, dynamic>))
        .toList();
    return _cachedCatalog!;
  }
}

/// Service responsible for loading, parsing, and caching `.srt` subtitles
/// synchronized with the selected App Language.
class SubtitleService {
  final Map<String, List<SubtitleCue>> _cache = {};

  Future<List<SubtitleCue>> loadSubtitles({
    required String slug,
    required int episodeNo,
    required String langCode,
  }) async {
    final cacheKey = '$slug|$episodeNo|$langCode';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final epPadded = episodeNo.toString().padLeft(3, '0');
    final primaryPath = 'assets/dramas/$slug/sub/$langCode/ep_$epPadded.srt';

    try {
      final srtContent = await rootBundle.loadString(primaryPath);
      final parsed = SrtParser.parse(srtContent);
      if (parsed.isNotEmpty) {
        _cache[cacheKey] = parsed;
        return parsed;
      }
    } catch (_) {}

    if (langCode != 'en') {
      try {
        final fallbackPath = 'assets/dramas/$slug/sub/en/ep_$epPadded.srt';
        final srtContent = await rootBundle.loadString(fallbackPath);
        final parsed = SrtParser.parse(srtContent);
        _cache[cacheKey] = parsed;
        return parsed;
      } catch (_) {}
    }

    return const [];
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

    final epPadded = episodeNo.toString().padLeft(3, '0');

    if (customStreamBaseUrl != null && customStreamBaseUrl.isNotEmpty) {
      final base = customStreamBaseUrl.replaceAll(RegExp(r'/$'), '');
      final url = '$base/${drama.slug}/video/ep_$epPadded.mp4';
      return VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: options,
      );
    }

    final effectiveEp = episodeNo <= drama.bundledEpisodes
        ? episodeNo
        : ((episodeNo - 1) % drama.bundledEpisodes) + 1;
    final assetEpPadded = effectiveEp.toString().padLeft(3, '0');
    final assetPath = 'assets/dramas/${drama.slug}/video/ep_$assetEpPadded.mp4';

    return VideoPlayerController.asset(
      assetPath,
      videoPlayerOptions: options,
    );
  }
}
