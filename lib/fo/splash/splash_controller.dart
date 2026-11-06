import 'dart:async';
import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/const/ad_id_extension.dart';
import '../../ads/const/ad_id_name.dart';
import '../../core/constants/app_constants.dart';
import '../../core/router/app_route_observer.dart';
import '../../core/utils/screen_utils.dart';
import '../../providers/app_providers.dart';
import '../../screens/main_shell/main_shell_screen.dart';
import '../../services/firebase_remote_config_service.dart';
import '../../services/shared_preference_service.dart';
import '../language/language_activity.dart';

class SplashController extends ChangeNotifier {
  double percentLoading = 0.0;
  Timer? _timer;
  int _value = 0;
  bool _isDisposed = false;
  bool isNoFirstOpenApp = false;

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
    _startProgress(context, onFinished: onFinished);
  }

  void _startProgress(
    BuildContext context, {
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
          _showSplashAdThenNavigate(context, onFinished: onFinished);
        }
      }
    });
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
