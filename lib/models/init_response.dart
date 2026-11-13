import 'taxonomy_models.dart';
import 'user_profile.dart';

/// App info from /v1/app/init → app.
class AppInfo {
  final String appCode;
  final String appName;
  final String packageName;
  final String defaultLanguage;
  final List<String> supportedLanguages;

  AppInfo({
    this.appCode = '',
    this.appName = '',
    this.packageName = '',
    this.defaultLanguage = 'en',
    this.supportedLanguages = const [],
  });

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      appCode: json['app_code'] as String? ?? '',
      appName: json['app_name'] as String? ?? '',
      packageName: json['package_name'] as String? ?? '',
      defaultLanguage: json['default_language'] as String? ?? 'en',
      supportedLanguages: (json['supported_languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Version gate from /v1/app/init → version_gate.
class VersionGate {
  final int currentVersionCode;
  final int minSupportedVersionCode;
  final int latestVersionCode;
  final bool forceUpdate;
  final String storeUrl;

  VersionGate({
    this.currentVersionCode = 0,
    this.minSupportedVersionCode = 0,
    this.latestVersionCode = 0,
    this.forceUpdate = false,
    this.storeUrl = '',
  });

  factory VersionGate.fromJson(Map<String, dynamic> json) {
    return VersionGate(
      currentVersionCode:
          json['current_version_code'] as int? ?? 0,
      minSupportedVersionCode:
          json['min_supported_version_code'] as int? ?? 0,
      latestVersionCode:
          json['latest_version_code'] as int? ?? 0,
      forceUpdate: json['force_update'] as bool? ?? false,
      storeUrl: json['store_url'] as String? ?? '',
    );
  }
}

/// Security info from /v1/app/init → security.
class SecurityInfo {
  final String ephemeralSeed;
  final int seedTtlSeconds;
  final int streamTokenTtlSeconds;
  final String encryptionVersion;

  /// Alias — the interceptor stores this as `sessionToken`.
  /// The actual session_token is returned at the `session` level.
  String sessionToken;

  SecurityInfo({
    this.ephemeralSeed = '',
    this.seedTtlSeconds = 86400,
    this.streamTokenTtlSeconds = 900,
    this.encryptionVersion = 'v2',
    this.sessionToken = '',
  });

  factory SecurityInfo.fromJson(Map<String, dynamic> json) {
    return SecurityInfo(
      ephemeralSeed: json['ephemeral_seed'] as String? ?? '',
      seedTtlSeconds: json['seed_ttl_seconds'] as int? ?? 86400,
      streamTokenTtlSeconds:
          json['stream_token_ttl_seconds'] as int? ?? 900,
      encryptionVersion:
          json['encryption_version'] as String? ?? 'v2',
      sessionToken: json['session_token'] as String? ?? '',
    );
  }
}

/// Ads sub-config inside app_config.
class AdsConfig {
  final bool enableSplashAd;
  final bool enableRewardedUnlock;
  final int interstitialEveryNEpisodes;

  AdsConfig({
    this.enableSplashAd = false,
    this.enableRewardedUnlock = true,
    this.interstitialEveryNEpisodes = 4,
  });

  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    return AdsConfig(
      enableSplashAd: json['enable_splash_ad'] as bool? ?? false,
      enableRewardedUnlock:
          json['enable_rewarded_unlock'] as bool? ?? true,
      interstitialEveryNEpisodes:
          json['interstitial_every_n_episodes'] as int? ?? 4,
    );
  }
}

/// App config from /v1/app/init → app_config.
class AppConfig {
  final bool maintenanceMode;
  final int defaultPageSize;
  final int defaultFreeEpisodes;
  final int adUnlockDailyLimit;
  final int coinCostPerEpisode;
  final int fullDramaDiscountPct;
  final AdsConfig ads;

  AppConfig({
    this.maintenanceMode = false,
    this.defaultPageSize = 20,
    this.defaultFreeEpisodes = 5,
    this.adUnlockDailyLimit = 10,
    this.coinCostPerEpisode = 30,
    this.fullDramaDiscountPct = 25,
    AdsConfig? ads,
  }) : ads = ads ?? AdsConfig();

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      defaultPageSize: json['default_page_size'] as int? ?? 20,
      defaultFreeEpisodes:
          json['default_free_episodes'] as int? ?? 5,
      adUnlockDailyLimit:
          json['ad_unlock_daily_limit'] as int? ?? 10,
      coinCostPerEpisode:
          json['coin_cost_per_episode'] as int? ?? 30,
      fullDramaDiscountPct:
          json['full_drama_discount_pct'] as int? ?? 25,
      ads: json['ads'] != null
          ? AdsConfig.fromJson(json['ads'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Full decrypted response for POST /v1/app/init.
class InitResponse {
  final int serverTime;
  final AppInfo app;
  final VersionGate versionGate;
  final SecurityInfo security;
  final AppConfig appConfig;
  final UserProfile user;
  final Taxonomy taxonomy;

  InitResponse({
    this.serverTime = 0,
    AppInfo? app,
    VersionGate? versionGate,
    SecurityInfo? security,
    AppConfig? appConfig,
    UserProfile? user,
    Taxonomy? taxonomy,
  })  : app = app ?? AppInfo(),
        versionGate = versionGate ?? VersionGate(),
        security = security ?? SecurityInfo(),
        appConfig = appConfig ?? AppConfig(),
        user = user ?? UserProfile(),
        taxonomy = taxonomy ?? Taxonomy();

  factory InitResponse.fromJson(Map<String, dynamic> json) {
    // The session section is a peer of security in the raw JSON.
    final securityJson =
        json['security'] as Map<String, dynamic>? ?? {};
    final sessionJson =
        json['session'] as Map<String, dynamic>? ?? {};
    // Merge session_token from the session block into security.
    final mergedSecurity = <String, dynamic>{
      ...securityJson,
      'session_token': sessionJson['session_token'] ?? '',
      'ephemeral_seed':
          sessionJson['ephemeral_seed'] ?? securityJson['ephemeral_seed'] ?? '',
    };

    return InitResponse(
      serverTime: json['server_time'] as int? ?? 0,
      app: json['app'] != null
          ? AppInfo.fromJson(json['app'] as Map<String, dynamic>)
          : null,
      versionGate: json['version_gate'] != null
          ? VersionGate.fromJson(
              json['version_gate'] as Map<String, dynamic>)
          : null,
      security: SecurityInfo.fromJson(mergedSecurity),
      appConfig: json['app_config'] != null
          ? AppConfig.fromJson(
              json['app_config'] as Map<String, dynamic>)
          : null,
      user: json['user'] != null
          ? UserProfile.fromJson(
              json['user'] as Map<String, dynamic>)
          : null,
      taxonomy: json['taxonomy'] != null
          ? Taxonomy.fromJson(
              json['taxonomy'] as Map<String, dynamic>)
          : null,
    );
  }
}
