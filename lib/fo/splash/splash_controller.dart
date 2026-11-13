import 'dart:async';
import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/const/ad_id_extension.dart';
import '../../ads/const/ad_id_name.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/injection.dart';
import '../../core/router/app_route_observer.dart';
import '../../core/utils/screen_utils.dart';
import '../../providers/app_providers.dart';
import '../../screens/main_shell/main_shell_screen.dart';
import '../../services/api/event_tracker_service.dart';
import '../../services/firebase_remote_config_service.dart';
import '../../services/shared_preference_service.dart';
import '../language/language_activity.dart';

class SplashController extends ChangeNotifier {
  double percentLoading = 0.0;
  Timer? _timer;
  int _value = 0;
  bool _isDisposed = false;
  bool isNoFirstOpenApp = false;

  /// Tracks whether the API session was successfully initialized.
  bool _apiInitialized = false;
  bool get isApiInitialized => _apiInitialized;

  /// Holds maintenance message if the server is in maintenance mode.
  String? _maintenanceMessage;

  /// Holds force-update store URL if a mandatory update is required.
  String? _forceUpdateUrl;

  Future<void> init(
    BuildContext context, {
    required WidgetRef ref,
    VoidCallback? onFinished,
  }) async {
    if (AppConstants.isMobilePlatform) {
      EasyAds.instance.appLifecycleReactor?.setOnSplashScreen(true);
    }
    AppRouteObserver.logScreen('SplashActivity');

    isNoFirstOpenApp = await SharedPreferenceService.getIsNoFirstOpenApp();
    await SharedPreferenceService.initFirstAppOpenTimeIfNeeded();

    final savedLang = await SharedPreferenceService.getSavedLanguageCodeOrNull();
    if (savedLang != null && !_isDisposed) {
      AppConstants.selectedLanguageCode = savedLang;
      ref.read(localeProvider.notifier).setAppLanguage(savedLang);
    }

    if (!context.mounted || _isDisposed) return;
    _startProgress(context, ref: ref, onFinished: onFinished);
  }

  void _startProgress(
    BuildContext context, {
    required WidgetRef ref,
    VoidCallback? onFinished,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 22), (timer) {
      _value++;
      percentLoading = (_value / 100).clamp(0.0, 1.0);
      if (!_isDisposed) notifyListeners();

      if (_value >= 100) {
        timer.cancel();
        if (context.mounted && !_isDisposed) {
          _initializeApiThenNavigate(context, ref: ref, onFinished: onFinished);
        }
      }
    });
  }

  /// After progress bar completes, attempts API initialization before navigating.
  /// Implements doc 02 §2 Steps 1-3:
  ///   Step 1: Bootstrap RC keys (done inside coordinator)
  ///   Step 2: Handshake /v1/app/init (done inside coordinator)
  ///   Step 3: Parallel pre-fetch home + feed + push-token (done below)
  Future<void> _initializeApiThenNavigate(
    BuildContext context, {
    required WidgetRef ref,
    VoidCallback? onFinished,
  }) async {
    try {
      final sessionState =
          await ref.read(sessionProvider.notifier).initializeSession();
      final initData = sessionState.initData;

      if (sessionState.isInitialized && initData != null) {
        _apiInitialized = true;

        ref.read(userWalletProvider.notifier).syncFromApi(
              isVip: initData.user.isVip,
              vipPlanName: initData.user.isVip ? 'VIP' : 'FREE',
              autoPlayNext: initData.user.settings.autoPlayNext,
            );

        // Check for force update
        if (initData.versionGate.forceUpdate &&
            initData.versionGate.storeUrl.isNotEmpty) {
          _forceUpdateUrl = initData.versionGate.storeUrl;
          if (context.mounted && !_isDisposed) {
            _showForceUpdateDialog(context);
            return;
          }
        }

        // ── Step 3 (doc 02 §2): Parallel pre-fetch for instant screen display ──
        final lang = AppConstants.selectedLanguageCode;
        _prefetchParallel(ref, lang);
      } else {
        _apiInitialized = false;
      }
    } on StateError catch (e) {
      // StateError is thrown for maintenance mode
      _maintenanceMessage = e.message;
      if (context.mounted && !_isDisposed) {
        _showMaintenanceScreen(context);
        return;
      }
    } catch (e) {
      // Network error or other failure — gracefully fallback to offline mode
      debugPrint('SplashController: API init failed, continuing offline: $e');
      _apiInitialized = false;
    }

    // Proceed with existing navigation flow
    if (context.mounted && !_isDisposed) {
      _showSplashAdThenNavigate(context, onFinished: onFinished);
    }
  }

  /// Doc 02 §2 Step 3: Fire parallel calls that don't block navigation.
  void _prefetchParallel(WidgetRef ref, String lang) {
    unawaited(
      Future(() async {
        try {
          await ref.read(homeProvider.notifier).fetchHome(lang);
        } catch (e) {
          debugPrint('SplashController: Home pre-fetch failed (non-fatal): $e');
        }
      }),
    );

    unawaited(
      Future(() async {
        try {
          await ref.read(feedProvider.notifier).fetchInitialFeed(lang);
        } catch (e) {
          debugPrint('SplashController: Feed pre-fetch failed (non-fatal): $e');
        }
      }),
    );

    unawaited(
      Future(() async {
        try {
          await ref.read(rewardsProvider.notifier).fetchOverview(lang);
        } catch (e) {
          debugPrint(
              'SplashController: Rewards pre-fetch failed (non-fatal): $e');
        }
      }),
    );

    unawaited(
      Future(() async {
        try {
          inject<DramaEventTracker>()
              .track('app_open', sourceScreen: 'splash');
        } catch (e) {
          debugPrint('SplashController: app_open event failed: $e');
        }
      }),
    );

    unawaited(
      Future(() async {
        try {
          // Only send if FCM token is available when FirebaseMessaging is added.
        } catch (e) {
          debugPrint('SplashController: Push token failed (non-fatal): $e');
        }
      }),
    );
  }

  void _showMaintenanceScreen(BuildContext context) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('System Maintenance'),
        content: Text(_maintenanceMessage ?? 'System maintenance in progress.'),
        actions: const [], // No dismiss — user must wait
      ),
    );
  }

  void _showForceUpdateDialog(BuildContext context) {
    if (!context.mounted) return;
    final storeUrl = _forceUpdateUrl ?? '';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Update Required'),
        content: Text(
          storeUrl.isNotEmpty
              ? 'A new version is available. Please update to continue:\n$storeUrl'
              : 'A new version is available. Please update to continue.',
        ),
        actions: [
          if (storeUrl.isNotEmpty)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: storeUrl));
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('Store link copied')),
                );
              },
              child: const Text('Copy Store Link'),
            ),
        ],
      ),
    );
  }

  void _showSplashAdThenNavigate(
    BuildContext context, {
    VoidCallback? onFinished,
  }) {
    final showInterSplash = AppConstants.isMobilePlatform &&
        (FirebaseRemoteConfigService.getBoolConfigByKey(
              FirebaseRemoteConfigService.inter_splash,
            ) ||
            FirebaseRemoteConfigService.getBoolConfigByKey(
              FirebaseRemoteConfigService.inter_splash_high,
            )) &&
        !AppConstants.isPremiumUser.value;

    if (showInterSplash) {
      EasyAds.instance.showInterstitialAdSplashWith2Id(
        context,
        interSplashHigh: MyAdIdName.interSplashHigh.getId,
        interSplashAll: MyAdIdName.interSplash.getId,
        interSplashHighName: MyAdIdName.interSplashHigh,
        interSplashAllName: MyAdIdName.interSplash,
        onShowed: () {},
        adDissmissed: () {
          if (context.mounted) {
            goNextScreen(context, onFinished: onFinished);
          }
        },
        onFailed: () {
          if (context.mounted) {
            goNextScreen(context, onFinished: onFinished);
          }
        },
      );
    } else {
      goNextScreen(context, onFinished: onFinished);
    }
  }

  void goNextScreen(
    BuildContext context, {
    VoidCallback? onFinished,
  }) {
    if (!context.mounted) return;
    if (AppConstants.isMobilePlatform) {
      EasyAds.instance.appLifecycleReactor?.setOnSplashScreen(false);
    }

    if (isNoFirstOpenApp && AppConstants.skipLangOnboardOnReopen) {
      if (onFinished != null) {
        onFinished();
      } else {
        Navigator.of(context).pushReplacement(
          AppScreenUtils.adaptivePageRoute<void>(
            settings: const RouteSettings(name: 'main'),
            builder: (_) => const MainShellScreen(
              key: ValueKey('riverpod_main_shell_5tabs'),
            ),
          ),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        AppScreenUtils.adaptivePageRoute<void>(
          settings: const RouteSettings(name: 'LanguageActivity'),
          builder: (_) => const LanguageActivity(isFirstLaunch: true),
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
