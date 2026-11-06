// ignore_for_file: avoid_print

import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:collection/collection.dart';
import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:easy_ads_flutter/src/easy_admob/easy_admob_interstitial_ad.dart';
import 'package:easy_ads_flutter/src/easy_admob/easy_admob_rewarded_ad.dart';
import 'package:easy_ads_flutter/src/services/easy_firebase_service.dart';
import 'package:easy_ads_flutter/src/services/easy_shared_pref_service.dart';
import 'package:easy_ads_flutter/src/utils/easy_app_open_ad_with_2_id.dart';
import 'package:easy_ads_flutter/src/utils/easy_app_open_ad_with_id.dart';
import 'package:easy_ads_flutter/src/utils/easy_event_controller.dart';
import 'package:easy_ads_flutter/src/utils/easy_interstitial_ad_splash.dart';
import 'package:easy_ads_flutter/src/utils/easy_interstitial_ad_splash_with_2_id.dart';
import 'package:easy_ads_flutter/src/utils/easy_logger.dart';
import 'package:easy_ads_flutter/src/utils/extensions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:easy_ads_flutter/src/easy_admob/easy_admob_native_ad.dart';
import 'services/easy_adjust_service.dart';
import 'services/easy_gsm_service.dart';
import 'utils/easy_app_open_ad.dart';
import 'utils/easy_interstitial_ad_splash_with_3_id.dart';
import 'utils/easy_splash_ad_with_interstitial_and_app_open.dart';

class EasyAds {
  static const String _keyIntervalInterAd = 'interval_inter_ad';
  static const String _keyLastInterstitialShowTimePref =
      'easy_ads_last_interstitial_show_time';

  DateTime? _lastInterstitialAdShowTime;
  int? _customInterstitialInterval;

  EasyAds._easyAds() {
    _eventController.onEvent.listen((event) {
      if (event.adUnitType == AdUnitType.interstitial &&
          event.type == AdEventType.adShowed) {
        recordInterstitialAdShowTime();
      }
    });
  }

  static final EasyAds instance = EasyAds._easyAds();

  AppLifecycleReactor? appLifecycleReactor;

  // SharedPreferences singleton
  static SharedPreferences? _sharedPreferences;

  // Getter for SharedPreferences
  static SharedPreferences? get sharedPreferences => _sharedPreferences;

  /// Google admob's ad request
  AdRequest _adRequest = const AdRequest();
  late final IAdIdManager adIdManager;
  static Widget? _loadingSplashWidget;
  static String _defaultLoadingMessage = 'Loading Ads';

  // Expose configured loading splash/message to module widgets
  static Widget? get configuredLoadingSplash => _loadingSplashWidget;

  static String get configuredLoadingMessage => _defaultLoadingMessage;

  static String Function(String adId)? adIdResolver;

  /// True value when there is exist an Ad and false otherwise.
  bool _isFullscreenAdShowing = false;

  /// Flag to disable app open ad from lifecycle when showing manually
  bool _isManualAppOpenAdShowing = false;

  /// True value when user has purchased Premium / No Ads
  bool _isPremiumUser = false;

  bool get isPremiumUser => _isPremiumUser;

  void setPremiumUser(bool value) {
    _isPremiumUser = value;
    _logger.logInfo('EasyAds: setPremiumUser = $value');
    if (value) {
      for (final ad in _nativeAdCache.values) {
        ad.dispose();
      }
      _nativeAdCache.clear();

      for (final ad in _interstitialAdCache.values) {
        ad.dispose();
      }
      _interstitialAdCache.clear();

      for (final ad in _rewardAdCache.values) {
        ad.dispose();
      }
      _rewardAdCache.clear();

      _eventController.fireEvent(
        AdEvent(
          type: AdEventType.adFailedToLoad,
          adNetwork: AdNetwork.admob,
          adUnitType: AdUnitType.banner,
        ),
      );
    }
  }

  void setManualAppOpenAdShowing(bool value) =>
      _isManualAppOpenAdShowing = value;

  bool get isManualAppOpenAdShowing => _isManualAppOpenAdShowing;

  void setFullscreenAdShowing(bool value) => _isFullscreenAdShowing = value;

  bool get isFullscreenAdShowing => _isFullscreenAdShowing;

  final _eventController = EasyEventController();

  Stream<AdEvent> get onEvent => _eventController.onEvent;

  List<EasyAdBase> get _allAds => [..._interstitialAds, ..._rewardedAds];

  /// All the interstitial ads will be stored in it
  final List<EasyAdBase> _appOpenAds = [];

  /// All the interstitial ads will be stored in it
  final List<EasyAdBase> _interstitialAds = [];

  /// All the rewarded ads will be stored in it
  final List<EasyAdBase> _rewardedAds = [];

  /// Cache pool for preloaded Native Ads
  final Map<String, EasyAdBase> _nativeAdCache = {};

  /// Cache pool for preloaded Interstitial Ads
  final Map<String, EasyAdBase> _interstitialAdCache = {};

  /// Cache pool for preloaded Rewarded Ads
  final Map<String, EasyAdBase> _rewardAdCache = {};

  /// Returns the required interval in seconds between interstitial ad shows.
  /// First checks if a custom interval was set, otherwise fetches from [FirebaseRemoteConfig] key 'interval_inter_ad',
  /// falling back to 30 seconds default.
  int get interstitialInterval {
    if (_customInterstitialInterval != null) {
      return _customInterstitialInterval!;
    }
    try {
      final value = FirebaseRemoteConfig.instance.getInt(_keyIntervalInterAd);
      if (value > 0) return value;
    } catch (e) {
      // RemoteConfig not initialized or failed
    }
    return 30;
  }

  void setCustomInterstitialInterval(int seconds) {
    _customInterstitialInterval = seconds;
  }

  DateTime? get lastInterstitialAdShowTime {
    if (_lastInterstitialAdShowTime == null && _sharedPreferences != null) {
      final ts = _sharedPreferences!.getInt(_keyLastInterstitialShowTimePref);
      if (ts != null && ts > 0) {
        _lastInterstitialAdShowTime = DateTime.fromMillisecondsSinceEpoch(ts);
      }
    }
    return _lastInterstitialAdShowTime;
  }

  void recordInterstitialAdShowTime() {
    _lastInterstitialAdShowTime = DateTime.now();
    _sharedPreferences?.setInt(_keyLastInterstitialShowTimePref,
        _lastInterstitialAdShowTime!.millisecondsSinceEpoch);
    _logger.logInfo(
        'EasyAds: Recorded interstitial ad show time at $_lastInterstitialAdShowTime');
  }

  /// Checks if minimum interval between interstitial ads has passed.
  bool canShowInterstitialAd() {
    if (_isPremiumUser) return false;
    if (_isFullscreenAdShowing) return false;

    final lastShow = lastInterstitialAdShowTime;
    if (lastShow != null) {
      final elapsedSeconds = DateTime.now().difference(lastShow).inSeconds;
      final requiredInterval = interstitialInterval;
      if (elapsedSeconds < requiredInterval) {
        _logger.logInfo(
            'EasyAds: Interstitial ad skipped. Elapsed: ${elapsedSeconds}s, Required: ${requiredInterval}s (Key: $_keyIntervalInterAd)');
        return false;
      }
    }
    return true;
  }

  /// [_logger] is used to show Ad logs in the console
  final EasyLogger _logger = EasyLogger();
  AdSize? adSize;
  bool _initialized = false;

  /// Initializes the Google Mobile Ads SDK.
  ///
  /// Call this method as early as possible after the app launches
  /// [adMobAdRequest] will be used in all the admob requests. By default empty request will be used if nothing passed here.
  /// [fbTestingId] can be obtained by running the app once without the testingId.
  Future<void> initialize(
    IAdIdManager manager, {
    bool unityTestMode = false,
    AdRequest? adMobAdRequest,
    RequestConfiguration? admobConfiguration,
    bool enableLogger = true,
    String? fbTestingId,
    bool fbiOSAdvertiserTrackingEnabled = false,
    GlobalKey<NavigatorState>? navigatorKey,
    Widget? loadingSplash,
    String? loadingMessage,
  }) async {
    // If already initialized, allow updating optional UI configs and return
    if (_initialized) {
      _loadingSplashWidget = loadingSplash ?? _loadingSplashWidget;
      if (loadingMessage != null && loadingMessage.isNotEmpty) {
        _defaultLoadingMessage = loadingMessage;
      }
      return;
    }
    // Initialize SharedPreferences if not already initialized
    _sharedPreferences ??= await SharedPreferences.getInstance();
    if (enableLogger) _logger.enable(enableLogger);
    adIdManager = manager;
    if (adMobAdRequest != null) {
      _adRequest = adMobAdRequest;
    }

    if (manager.admobAdIds?.appId != null) {
      final response = await MobileAds.instance.initialize();
      final status = response.adapterStatuses.values.firstOrNull?.state;
      if (admobConfiguration != null) {
        await MobileAds.instance.updateRequestConfiguration(admobConfiguration);
      }

      _eventController.fireNetworkInitializedEvent(
          AdNetwork.admob, status == AdapterInitializationState.ready);
      if (navigatorKey != null) {
        appLifecycleReactor = AppLifecycleReactor(navigatorKey: navigatorKey);
        appLifecycleReactor!.listenToAppStateChanges();
      }

      if (navigatorKey?.currentContext != null) {
        adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            MediaQuery.of(navigatorKey!.currentContext!).size.width.round());
      }
    }

    _loadingSplashWidget = loadingSplash;
    if (loadingMessage != null && loadingMessage.isNotEmpty) {
      _defaultLoadingMessage = loadingMessage;
    }
    _initialized = true;
  }

  /// Initializes App Tracking Transparency (iOS ATT) and Google UMP GDPR Consent Form.
  Future<void> initConsent({bool isDebugGeographyEEA = true}) async {
    // 1. App Tracking Transparency for iOS
    try {
      final TrackingStatus status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future.delayed(const Duration(milliseconds: 200));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      _logger.logInfo('Tracking transparency status error: $e');
    }

    // 2. Google UMP GDPR Consent Form
    try {
      final params = ConsentRequestParameters(
        consentDebugSettings: isDebugGeographyEEA
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
              )
            : null,
      );

      final consentCompleter = Completer<void>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            if (await ConsentInformation.instance.isConsentFormAvailable()) {
              await _loadConsentForm();
            }
            _logger.logInfo('Consent completed');
          } catch (e) {
            _logger.logInfo('Consent form error: $e');
          }
          consentCompleter.complete();
        },
        (error) {
          _logger.logInfo('Consent error: ${error.message}');
          consentCompleter.complete();
        },
      );

      await consentCompleter.future;
    } catch (e) {
      _logger.logInfo('Consent request error: $e');
    }
  }

  Future<void> _loadConsentForm() async {
    final completer = Completer<void>();

    ConsentForm.loadConsentForm(
      (consentForm) async {
        final status = await ConsentInformation.instance.getConsentStatus();

        if (status == ConsentStatus.required) {
          consentForm.show((formError) async {
            if (formError != null) {
              _logger.logInfo('Consent form show error: ${formError.message}');
              completer.complete();
              return;
            }
            await _loadConsentForm();
            completer.complete();
          });
        } else {
          completer.complete();
        }
      },
      (formError) {
        _logger.logInfo('Consent form load error: ${formError.message}');
        completer.complete();
      },
    );

    await completer.future;
  }

  Future<void> initAdjust(
    AdjustConfig config, {
    Function(bool isOrganic)? onOrganicChanged,
  }) async {
    await EasyAdjustService().initAdjust(
      config,
      onOrganicChanged: onOrganicChanged,
    );
  }

  Future<void> initFirebaseAnalytics(FirebaseAnalytics analytics) async {
    EasyFirebaseService().init(analytics);
  }

  Future<String?> loginGSM({
    required String gsmAppId,
    required bool isProd,
    String? deviceId,
  }) async {
    return await EasyGsmService().loginGSM(
      gsmAppId: gsmAppId,
      isProd: isProd,
      deviceId: deviceId,
    );
  }

  String? get gsmAccessToken => EasyGsmService().gsmAccessToken;

  String resolveAdUnitId(String adId) {
    if (adId.startsWith('ca-app-pub-')) return adId;
    final resolved = adIdResolver?.call(adId);
    if (resolved != null && resolved != 'null' && resolved.isNotEmpty) {
      return resolved;
    }
    return adId;
  }

  /// Returns [EasyAdBase] if ad is created successfully. It assumes that you have already assigned banner id in Ad Id Manager
  ///
  /// if [adNetwork] is provided, only that network's ad would be created. For now, only unity and admob banner is supported
  /// [adSize] is used to provide ad banner size
  EasyAdBase? createBanner({
    required AdNetwork adNetwork,
    required AdSize? adSize,
    required String adId,
    String? adIdName,
    required bool isCollapsible,
  }) {
    EasyAdBase? ad;
    final realAdUnitId = resolveAdUnitId(adId);

    switch (adNetwork) {
      case AdNetwork.admob:
        ad = EasyAdmobBannerAd(
          realAdUnitId,
          adSize: adSize,
          adIdName: adIdName ?? adId,
          adRequest: isCollapsible
              ? AdRequest(
                  httpTimeoutMillis: _adRequest.httpTimeoutMillis,
                  extras: {'collapsible': 'bottom'},
                )
              : _adRequest,
        );
        _eventController.setupEvents(ad);
        break;
      default:
        ad = null;
    }
    return ad;
  }

  EasyAdBase? createNative({
    required AdNetwork adNetwork,
    required String factoryId,
    required String adId,
    String? adIdName,
    required double height,
  }) {
    EasyAdBase? ad;
    final realAdUnitId = resolveAdUnitId(adId);
    ad = EasyAdmobNativeAd(
      realAdUnitId,
      factoryId,
      height,
      adIdName: adIdName ?? adId,
      adRequest: _adRequest,
    );
    if (ad != null) _eventController.setupEvents(ad);
    return ad;
  }

  EasyAdBase? createInterstitial({
    required AdNetwork adNetwork,
    required String adId,
    String? adIdName,
    bool immersiveModeEnabled = true,
  }) {
    EasyAdBase? ad;
    final realAdUnitId = resolveAdUnitId(adId);
    ad = EasyAdmobInterstitialAd(realAdUnitId, _adRequest, immersiveModeEnabled, adIdName: adIdName ?? adId);
    _eventController.setupEvents(ad);
    return ad;
  }

  EasyAdBase? createReward({
    required AdNetwork adNetwork,
    required String adId,
    String? adIdName,
    bool immersiveModeEnabled = true,
  }) {
    EasyAdBase? ad;
    final realAdUnitId = resolveAdUnitId(adId);
    ad = EasyAdmobRewardedAd(realAdUnitId, _adRequest, immersiveModeEnabled, adIdName: adIdName ?? adId);
    _eventController.setupEvents(ad);
    return ad;
  }

  EasyAdBase? createAppOpenAd({
    required AdNetwork adNetwork,
    required String adId,
    String? adIdName,
    // int orientation = AppOpenAd.orientationPortrait,
  }) {
    EasyAdBase? ad;
    final realAdUnitId = resolveAdUnitId(adId);
    ad = EasyAdmobAppOpenAd(realAdUnitId, _adRequest, adIdName: adIdName ?? adId);
    _eventController.setupEvents(ad);
    return ad;
  }

  /// Preloads a native ad with a specific ID, factory ID, and height, and stores it in the cache under a unique cacheKey.
  Future<void> preloadNativeAd({
    required String adId,
    String? adIdName,
    required String factoryId,
    required double height,
    required String cacheKey,
    AdNetwork adNetwork = AdNetwork.admob,
  }) async {
    if (adId.isEmpty || cacheKey.isEmpty) return;

    // If already preloading or loaded, don't load again
    if (_nativeAdCache.containsKey(cacheKey)) {
      final cachedAd = _nativeAdCache[cacheKey]!;
      if (cachedAd.isAdLoaded || cachedAd.isAdLoading) {
        _logger.logInfo('Native Ad with cacheKey $cacheKey is already loaded or loading.');
        return;
      }
    }

    _logger.logInfo('Preloading Native Ad for cacheKey $cacheKey with adId $adId and height: $height');
    final ad = createNative(
      adNetwork: adNetwork,
      factoryId: factoryId,
      adId: adId,
      adIdName: adIdName,
      height: height,
    );

    if (ad != null) {
      _nativeAdCache[cacheKey] = ad;
      await ad.load();
    }
  }

  /// Retrieves a cached native ad by its cache key.
  EasyAdBase? getCachedNativeAd(String cacheKey) {
    return _nativeAdCache[cacheKey];
  }

  /// Disposes and removes a specific cached native ad.
  void disposeCachedNativeAd(String cacheKey) {
    if (_nativeAdCache.containsKey(cacheKey)) {
      _logger.logInfo('Disposing cached Native Ad for cacheKey: $cacheKey');
      _nativeAdCache[cacheKey]?.dispose();
      _nativeAdCache.remove(cacheKey);
    }
  }

  /// Disposes and clears all cached native ads.
  void clearNativeAdCache() {
    _logger.logInfo('Clearing all cached Native Ads');
    for (final ad in _nativeAdCache.values) {
      ad.dispose();
    }
    _nativeAdCache.clear();
  }

  /// Preloads an interstitial ad for a specific adId / adIdName and stores it in cache.
  Future<void> preloadInterstitialAd({
    required String adId,
    String? adIdName,
    AdNetwork adNetwork = AdNetwork.admob,
    bool immersiveModeEnabled = true,
  }) async {
    if (_isPremiumUser || adId.isEmpty) return;
    final key = adIdName ?? (adId.startsWith('ca-app-pub-') ? adId : adId);

    if (_interstitialAdCache.containsKey(key)) {
      final cachedAd = _interstitialAdCache[key]!;
      if (cachedAd.isAdLoaded || cachedAd.isAdLoading) {
        _logger.logInfo('Interstitial Ad with key $key is already loaded or loading.');
        return;
      }
    }

    _logger.logInfo('Preloading Interstitial Ad for key $key with adId $adId');
    final ad = createInterstitial(
      adNetwork: adNetwork,
      adId: adId,
      adIdName: adIdName,
      immersiveModeEnabled: immersiveModeEnabled,
    );

    if (ad != null) {
      _interstitialAdCache[key] = ad;
      await ad.load();
    }
  }

  /// Gets an existing cached interstitial ad or creates and caches a new one.
  EasyAdBase? getOrCreateCachedInterstitialAd({
    required String adId,
    String? adIdName,
    AdNetwork adNetwork = AdNetwork.admob,
    bool immersiveModeEnabled = true,
  }) {
    if (adId.isEmpty) return null;
    final key = adIdName ?? (adId.startsWith('ca-app-pub-') ? adId : adId);

    if (_interstitialAdCache.containsKey(key)) {
      final existingAd = _interstitialAdCache[key]!;
      if (existingAd.isAdLoaded || existingAd.isAdLoading) {
        return existingAd;
      }
      existingAd.dispose();
      _interstitialAdCache.remove(key);
    }

    final ad = createInterstitial(
      adNetwork: adNetwork,
      adId: adId,
      adIdName: adIdName,
      immersiveModeEnabled: immersiveModeEnabled,
    );

    if (ad != null) {
      _interstitialAdCache[key] = ad;
    }
    return ad;
  }

  /// Retrieves a cached interstitial ad by key.
  EasyAdBase? getCachedInterstitialAd(String key) {
    return _interstitialAdCache[key];
  }

  /// Disposes and removes a specific cached interstitial ad.
  void disposeCachedInterstitialAd(String key) {
    if (_interstitialAdCache.containsKey(key)) {
      _logger.logInfo('Disposing cached Interstitial Ad for key: $key');
      _interstitialAdCache[key]?.dispose();
      _interstitialAdCache.remove(key);
    }
  }

  /// Disposes and clears all cached interstitial ads.
  void clearInterstitialAdCache() {
    _logger.logInfo('Clearing all cached Interstitial Ads');
    for (final ad in _interstitialAdCache.values) {
      ad.dispose();
    }
    _interstitialAdCache.clear();
  }

  /// Preloads a Reward Ad and caches it.
  Future<void> preloadRewardAd({
    required String adId,
    String? adIdName,
    AdNetwork adNetwork = AdNetwork.admob,
    bool immersiveModeEnabled = true,
  }) async {
    if (_isPremiumUser || adId.isEmpty) return;
    final key = adIdName ?? (adId.startsWith('ca-app-pub-') ? adId : adId);

    if (_rewardAdCache.containsKey(key)) {
      final cachedAd = _rewardAdCache[key]!;
      if (cachedAd.isAdLoaded || cachedAd.isAdLoading) {
        _logger.logInfo('Reward Ad with key $key is already loaded or loading.');
        return;
      }
    }

    _logger.logInfo('Preloading Reward Ad for key $key with adId $adId');
    final ad = createReward(
      adNetwork: adNetwork,
      adId: adId,
      adIdName: adIdName,
      immersiveModeEnabled: immersiveModeEnabled,
    );

    if (ad != null) {
      _rewardAdCache[key] = ad;
      await ad.load();
    }
  }

  /// Gets an existing cached reward ad or creates and caches a new one.
  EasyAdBase? getOrCreateCachedRewardAd({
    required String adId,
    String? adIdName,
    AdNetwork adNetwork = AdNetwork.admob,
    bool immersiveModeEnabled = true,
  }) {
    if (adId.isEmpty) return null;
    final key = adIdName ?? (adId.startsWith('ca-app-pub-') ? adId : adId);

    if (_rewardAdCache.containsKey(key)) {
      final existingAd = _rewardAdCache[key]!;
      if (existingAd.isAdLoaded || existingAd.isAdLoading) {
        return existingAd;
      }
      existingAd.dispose();
      _rewardAdCache.remove(key);
    }

    final ad = createReward(
      adNetwork: adNetwork,
      adId: adId,
      adIdName: adIdName,
      immersiveModeEnabled: immersiveModeEnabled,
    );

    if (ad != null) {
      _rewardAdCache[key] = ad;
    }
    return ad;
  }

  /// Retrieves a cached reward ad by key.
  EasyAdBase? getCachedRewardAd(String key) {
    return _rewardAdCache[key];
  }

  /// Disposes and removes a specific cached reward ad.
  void disposeCachedRewardAd(String key) {
    if (_rewardAdCache.containsKey(key)) {
      _logger.logInfo('Disposing cached Reward Ad for key: $key');
      _rewardAdCache[key]?.dispose();
      _rewardAdCache.remove(key);
    }
  }

  /// Disposes and clears all cached reward ads.
  void clearRewardAdCache() {
    _logger.logInfo('Clearing all cached Reward Ads');
    for (final ad in _rewardAdCache.values) {
      ad.dispose();
    }
    _rewardAdCache.clear();
  }

  Future<void> initAdmob({
    String? appOpenAdUnitId,
    String? appOpenAdIdName,
    // int appOpenAdOrientation = AppOpenAd.orientationPortrait,
  }) async {
    if (appOpenAdUnitId != null &&
        _appOpenAds.doesNotContain(AdNetwork.admob, AdUnitType.appOpen)) {
      final appOpenAdManager = EasyAdmobAppOpenAd(
        appOpenAdUnitId,
        _adRequest,
        adIdName: appOpenAdIdName ?? (appOpenAdUnitId.startsWith('ca-app-pub-') ? null : appOpenAdUnitId),
      );
      _appOpenAds.add(appOpenAdManager);
      _eventController.setupEvents(appOpenAdManager);
      try {
        // ignore: empty_catches
      } catch (e) {}
    }
  }

  /// Displays random ad network [adUnitType] ad.
  /// It will randomly display one network and if that network's ad is not loaded, it will try second and so on until it exhaust all the network ads.
  /// Returns bool indicating whether ad has been successfully displayed or not
  ///
  /// [adUnitType] should be mentioned here, only interstitial or rewarded should be mentioned here
  bool showRandomAd(AdUnitType adUnitType) {
    if (_isPremiumUser) return false;
    if (adUnitType == AdUnitType.interstitial && !canShowInterstitialAd()) {
      return false;
    }
    assert(
        adUnitType == AdUnitType.interstitial ||
            adUnitType == AdUnitType.rewarded,
        'Only interstitial and rewarded types should be passed to this method');

    final List<EasyAdBase> ads = (adUnitType == AdUnitType.rewarded
            ? _rewardedAds
            : _interstitialAds)
        .toList(growable: false)
      ..shuffle();

    for (final ad in ads) {
      if (ad.isAdLoaded) {
        ad.show();
        return true;
      } else {
        _logger.logInfo(
            '${ad.adNetwork} ${ad.adUnitType} was not loaded, so called loading');
        ad.load();
      }
    }

    return false;
  }

  /// Show app open ad with a specific ad ID
  /// This is used when you want to show app open ad with a custom ID (not from app lifecycle)
  void showAppOpenAdWithId(
    BuildContext context, {
    AdNetwork adNetwork = AdNetwork.admob,
    required String adId,
    Function()? onShowed,
    Function()? adDissmissed,
    Function()? onFailed,
    Function()? callback,
  }) {
    if (_isPremiumUser) {
      adDissmissed?.call();
      callback?.call();
      return;
    }
    if (_isFullscreenAdShowing || _isManualAppOpenAdShowing) {
      return;
    }
    _isManualAppOpenAdShowing = true;
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) =>
            EasyAppOpenAdWithId(
          adNetwork: adNetwork,
          adId: adId,
          onShowed: onShowed,
          adDismissed: adDissmissed,
          onFailed: () {
            _isManualAppOpenAdShowing = false;
            onFailed?.call();
          },
          callback: () {
            _isManualAppOpenAdShowing = false;
            callback?.call();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  /// Show app open ad with 2 IDs (high priority and all users)
  /// This is used to replace showInterstitialAdSplashWith2Id at Splash screen
  /// It will try to show the high priority ad first, then fallback to all users ad
  void showAppOpenAdWith2Id(
    BuildContext context, {
    AdNetwork adNetwork = AdNetwork.admob,
    required String appOpenHigh,
    required String appOpenAll,
    Function()? onShowed,
    Function()? adDissmissed,
    Function()? onFailed,
    Function()? callback,
  }) {
    if (_isPremiumUser) {
      adDissmissed?.call();
      callback?.call();
      return;
    }
    if (_isFullscreenAdShowing || _isManualAppOpenAdShowing) {
      return;
    }
    _isManualAppOpenAdShowing = true;
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) =>
            EasyAppOpenAdWith2Id(
          adNetwork: adNetwork,
          appOpenHigh: appOpenHigh,
          appOpenAll: appOpenAll,
          onShowed: onShowed,
          adDismissed: () {
            _isManualAppOpenAdShowing = false;
            adDissmissed?.call();
          },
          onFailed: () {
            _isManualAppOpenAdShowing = false;
            onFailed?.call();
          },
          callback: () {
            _isManualAppOpenAdShowing = false;
            callback?.call();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  /// Displays [adUnitType] ad from [adNetwork]. It will check if first ad it found from list is loaded,
  /// it will be displayed if [adNetwork] is not mentioned otherwise it will load the ad.
  ///
  /// Returns bool indicating whether ad has been successfully displayed or not
  ///
  /// [adUnitType] should be mentioned here, only interstitial or rewarded should be mentioned here
  /// if [adNetwork] is provided, only that network's ad would be displayed
  /// if [random] is true, any random loaded ad would be displayed
  Future<bool> showAd(AdUnitType adUnitType,
      {AdNetwork adNetwork = AdNetwork.any}) async {
    if (_isPremiumUser) return false;
    if (adUnitType == AdUnitType.interstitial && !canShowInterstitialAd()) {
      return false;
    }
    List<EasyAdBase> ads = [];
    if (adUnitType == AdUnitType.rewarded) {
      ads = _rewardedAds;
    } else if (adUnitType == AdUnitType.interstitial) {
      ads = _interstitialAds;
    } else if (adUnitType == AdUnitType.appOpen) {
      ads = _appOpenAds;
    }

    // Simple logic: Show if loaded, otherwise try to load once (but not for app open ads)
    for (final ad in ads) {
      if (ad.isAdLoaded) {
        if (adNetwork == AdNetwork.any || adNetwork == ad.adNetwork) {
          ad.show();
          return true;
        }
      } else if (adUnitType != AdUnitType.appOpen) {
        // Only auto-load for non-app-open ads (app open ads use loadAndShowAppOpenAd)
        _logger.logInfo(
            '${ad.adNetwork} ${ad.adUnitType} was not loaded, trying to load');
        await ad.load();
        // Give it a moment to load
        await Future.delayed(const Duration(seconds: 1));
        if (ad.isAdLoaded) {
          if (adNetwork == AdNetwork.any || adNetwork == ad.adNetwork) {
            ad.show();
            return true;
          }
        }
      } else {
        // For app open ads, don't auto-load here - use loadAndShowAppOpenAd instead
        _logger.logInfo(
            '${ad.adNetwork} ${ad.adUnitType} not loaded, skipping auto-load (use loadAndShowAppOpenAd)');
      }
    }

    _logger.logInfo('Failed to show ${adUnitType.name} ad');
    return false;
  }

  /// This will load both rewarded and interstitial ads.
  /// If a particular ad is already loaded, it will not load it again.
  /// Also you do not have to call this method everytime. Ad is automatically loaded after being displayed.
  ///
  /// if [adNetwork] is provided, only that network's ad would be loaded
  void loadAd({AdNetwork adNetwork = AdNetwork.any}) {
    if (_isPremiumUser) return;
    for (final e in _rewardedAds) {
      if (adNetwork == AdNetwork.any || adNetwork == e.adNetwork) {
        e.load();
      }
    }

    for (final e in _interstitialAds) {
      if (adNetwork == AdNetwork.any || adNetwork == e.adNetwork) {
        e.load();
      }
    }
  }

  /// Returns bool indicating whether ad has been loaded
  ///
  /// if [adNetwork] is provided, only that network's ad would be checked
  bool isRewardedAdLoaded({AdNetwork adNetwork = AdNetwork.any}) {
    if (_isPremiumUser) return false;
    final ad = _rewardedAds.firstWhereOrNull((e) =>
        (adNetwork == AdNetwork.any || adNetwork == e.adNetwork) &&
        e.isAdLoaded);
    return ad?.isAdLoaded ?? false;
  }

  /// Returns bool indicating whether ad has been loaded
  ///
  /// if [adNetwork] is provided, only that network's ad would be checked
  bool isInterstitialAdLoaded({AdNetwork adNetwork = AdNetwork.any}) {
    if (_isPremiumUser) return false;
    final ad = _interstitialAds.firstWhereOrNull((e) =>
        (adNetwork == AdNetwork.any || adNetwork == e.adNetwork) &&
        e.isAdLoaded);
    return ad?.isAdLoaded ?? false;
  }

  /// Returns bool indicating whether ad has been loaded
  ///
  /// if [adNetwork] is provided, only that network's ad would be checked
  bool isAppOpenAdLoaded({AdNetwork adNetwork = AdNetwork.any}) {
    if (_isPremiumUser) return false;
    final ad = _appOpenAds.firstWhereOrNull((e) =>
        (adNetwork == AdNetwork.any || adNetwork == e.adNetwork) &&
        e.isAdLoaded);
    bool isLoaded = ad?.isAdLoaded ?? false;
    return isLoaded;
  }

  /// This will load app open ads.
  /// If a particular ad is already loaded, it will not load it again.
  /// Also you do not have to call this method everytime. Ad is automatically loaded after being displayed.
  ///
  /// if [adNetwork] is provided, only that network's ad would be loaded
  void loadAppOpenAd({AdNetwork adNetwork = AdNetwork.any}) {
    if (_isPremiumUser) return;
    for (final e in _appOpenAds) {
      if (adNetwork == AdNetwork.any || adNetwork == e.adNetwork) {
        e.load();
      }
    }
  }

  /// Do not call this method until unless you want to remove ads entirely from the app.
  /// Best user case for this method could be removeAds In app purchase.
  ///
  /// After this, ads would stop loading. You would have to call initialize again.
  ///
  /// if [adNetwork] is provided only that network's ads will be disposed otherwise it will be ignored
  /// if [adUnitType] is provided only that ad unit type will be disposed, otherwise it will be ignored
  void destroyAds(
      {AdNetwork adNetwork = AdNetwork.any, AdUnitType? adUnitType}) {
    for (final e in _allAds) {
      if ((adNetwork == AdNetwork.any || adNetwork == e.adNetwork) &&
          (adUnitType == null || adUnitType == e.adUnitType)) {
        e.dispose();
      }
    }
  }

  void showInterstitialAd(
    BuildContext context, {
    AdNetwork adNetwork = AdNetwork.admob,
    required String adId,
    String? adIdName,
    Function()? onShowed,
    Function()? adDissmissed,
    Function()? onFailed,
  }) {
    if (_isPremiumUser) {
      adDissmissed?.call();
      return;
    }
    if (_isFullscreenAdShowing) {
      return;
    }
    if (!canShowInterstitialAd()) {
      adDissmissed?.call();
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) => EasyInterstitialAd(
          adNetwork: adNetwork,
          adId: adId,
          adIdName: adIdName ?? (adId.startsWith('ca-app-pub-') ? null : adId),
          onShowed: onShowed,
          onFailed: onFailed,
          adDismissed: adDissmissed,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void showInterstitialAdSplash(
    BuildContext context, {
    AdNetwork adNetwork = AdNetwork.admob,
    required String adId,
    Function()? onShowed,
    Function()? adDissmissed,
    Function()? onFailed,
  }) {
    if (_isPremiumUser) {
      adDissmissed?.call();
      return;
    }
    if (_isFullscreenAdShowing) {
      return;
    }
    if (!canShowInterstitialAd()) {
      adDissmissed?.call();
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => EasyInterstitialAdSplash(
          adNetwork: adNetwork,
          adId: adId,
          onShowed: onShowed,
          onFailed: onFailed,
          adDismissed: adDissmissed,
        ),
      ),
    );
  }

  void showInterstitialAdSplashWith3Id(
    BuildContext context, {
    AdNetwork adNetwork = AdNetwork.admob,
    required String interSplashHigh,
    required String interSplashMedium,
    required String interSplashAll,
    Function()? onShowed,
    Function()? adDissmissed,
    Function()? onFailed,
  }) {
    if (_isPremiumUser) {
      adDissmissed?.call();
      return;
    }
    if (_isFullscreenAdShowing) {
      return;
    }
    if (!canShowInterstitialAd()) {
      adDissmissed?.call();
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => EasyInterstitialAdSplashWith3Id(
          adNetwork: adNetwork,
          adIdHigh: interSplashHigh,
          adIdMedium: interSplashMedium,
          adIdAll: interSplashAll,
          onShowed: onShowed,
          onFailed: onFailed,
          adDismissed: adDissmissed,
        ),
      ),
    );
  }

  void showInterstitialAdSplashWith2Id(
    BuildContext context, {
    AdNetwork adNetwork = AdNetwork.admob,
    required String interSplashHigh,
    required String interSplashAll,
    String? interSplashHighName,
    String? interSplashAllName,
    Function()? onShowed,
    Function()? adDissmissed,
    Function()? onFailed,
  }) {
    if (_isPremiumUser) {
      adDissmissed?.call();
      return;
    }
    if (_isFullscreenAdShowing) {
      return;
    }
    if (!canShowInterstitialAd()) {
      adDissmissed?.call();
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => EasyInterstitialAdSplashWith2Id(
          adNetwork: adNetwork,
          adIdHigh: interSplashHigh,
          adIdAll: interSplashAll,
          adIdNameHigh: interSplashHighName ?? (interSplashHigh.startsWith('ca-app-pub-') ? null : interSplashHigh),
          adIdNameAll: interSplashAllName ?? (interSplashAll.startsWith('ca-app-pub-') ? null : interSplashAll),
          onShowed: onShowed,
          onFailed: onFailed,
          adDismissed: adDissmissed,
        ),
      ),
    );
  }

  void showRewardAd(
    BuildContext context, {
    AdNetwork adNetwork = AdNetwork.admob,
    required String adId,
    Function()? onShowed,
    Function()? adDissmissed,
    Function()? onFailed,
  }) {
    if (_isPremiumUser) {
      adDissmissed?.call();
      return;
    }
    if (_isFullscreenAdShowing) {
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (context, animation, secondaryAnimation) => EasyRewardAd(
          adNetwork: adNetwork,
          adId: adId,
          onShowed: onShowed,
          onFailed: onFailed,
          adDismissed: adDissmissed,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void showSplashAdWithInterstitialAndAppOpen(
    BuildContext context, {
    AdNetwork adNetwork = AdNetwork.admob,
    required String interstitialSplashAdId,
    required String appOpenAdId,
    Function()? onShowed,
    Function()? onDismissed,
    Function()? onFailedToLoad,
  }) {
    if (_isPremiumUser) {
      onDismissed?.call();
      return;
    }
    if (_isFullscreenAdShowing) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EasySplashAdWithInterstitialAndAppOpen(
          adNetwork: adNetwork,
          interstitialSplashAdId: interstitialSplashAdId,
          appOpenAdId: appOpenAdId,
          onShowed: onShowed,
          onDismissed: onDismissed,
          onFailedToLoad: onFailedToLoad,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void showAppOpenAd(
    BuildContext context, {
    AdNetwork adNetwork = AdNetwork.admob,
    Function()? callback,
  }) {
    if (_isPremiumUser) {
      callback?.call();
      return;
    }
    if (_isFullscreenAdShowing) {
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: false,
        // cho phÃƒÂ©p nÃ¡Â»Ân sau hiÃ¡Â»Æ’n thÃ¡Â»â€¹ mÃ¡Â»Â
        barrierColor: Colors.black54,
        // mÃƒÂ u nÃ¡Â»Ân mÃ¡Â»Â
        pageBuilder: (context, animation, secondaryAnimation) =>
            EasyAppOpenAd(adNetwork: adNetwork),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }
}
