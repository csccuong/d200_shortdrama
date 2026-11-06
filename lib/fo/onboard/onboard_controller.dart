import 'dart:async';
import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';

import '../../ads/const/ad_id_extension.dart';
import '../../ads/const/ad_id_factory.dart';
import '../../ads/const/ad_id_name.dart';
import '../../core/constants/app_constants.dart';
import '../../core/helper/firebase_helper.dart';
import '../../core/router/app_route_observer.dart';
import '../../core/utils/screen_utils.dart';
import '../../screens/main_shell/main_shell_screen.dart';
import '../../services/ads_service.dart';
import '../../services/firebase_remote_config_service.dart';
import '../../services/shared_preference_service.dart';

class OnboardStep {
  final String titleKey;
  final String descKey;
  final String image;
  final String fallbackPoster;
  final String adId;
  final String? adIdName;
  final String factoryId;
  final EasyAdBase? fullAd;
  final BoxFit fit;

  const OnboardStep({
    this.titleKey = '',
    this.descKey = '',
    this.image = '',
    this.fallbackPoster = '',
    this.adId = '',
    this.adIdName,
    this.factoryId = '',
    this.fullAd,
    this.fit = BoxFit.cover,
  });

  bool get isFullAd => fullAd != null;
  bool get hasAd =>
      AppConstants.isMobilePlatform &&
      adId.isNotEmpty &&
      !AppConstants.isPremiumUser.value;
}

class OnboardController extends ChangeNotifier {
  final PageController pageController = PageController();

  int currentIndex = 0;
  int currentTabOnboard = 0;
  final int totalPage = 4;
  bool _isDisposed = false;

  EasyAdBase? nativeOnboardFull1;
  EasyAdBase? nativeOnboardFull2;
  bool shouldShowAdsFull1 = false;
  bool shouldShowAdsFull2 = false;

  bool isIntro1AdLoading = false;
  bool isIntro4AdLoading = false;
  bool isIntro4AdReady = false;
  bool isFullAdNextButtonVisible = false;

  StreamSubscription<AdEvent>? _adEventSubscription;
  Timer? _fullAdTimer;
  Timer? _intro1TimeoutTimer;
  Timer? _intro4TimeoutTimer;
  Timer? _intro1SuccessTimer;
  Timer? _intro4SuccessTimer;

  void init() {
    AppRouteObserver.logScreen('OnboardActivity');
    FirebaseHelper.logEventName(FirebaseHelper.onboard1View);
    unawaited(reloadAds());
  }

  Future<void> reloadAds() async {
    if (!AppConstants.isMobilePlatform || AppConstants.isPremiumUser.value) {
      isIntro1AdLoading = false;
      isIntro4AdLoading = false;
      isIntro4AdReady = false;
      _notify();
      return;
    }

    await AdsService.initOrganic();

    isIntro4AdReady = false;
    _initIntro1AdState();
    await _initFullAds();
    _listenAdEvents();
  }

  void _initIntro1AdState() {
    final showAdOnboard1 = FirebaseRemoteConfigService.getBoolConfigByKey(
      FirebaseRemoteConfigService.native_onboarding_1,
    );

    if (showAdOnboard1) {
      final ad = EasyAds.instance.getCachedNativeAd(
        MyAdIdName.nativeOnboard1Ad,
      );
      final isLoaded = ad != null && ad.isAdLoaded;

      isIntro1AdLoading = true;
      if (isLoaded) {
        _intro1SuccessTimer?.cancel();
        _intro1SuccessTimer = Timer(const Duration(milliseconds: 500), () {
          isIntro1AdLoading = false;
          _notify();
        });
      } else {
        _intro1TimeoutTimer?.cancel();
        _intro1TimeoutTimer = Timer(const Duration(seconds: 4), () {
          if (isIntro1AdLoading) {
            isIntro1AdLoading = false;
            _notify();
          }
        });
      }
    } else {
      isIntro1AdLoading = false;
    }
    isIntro4AdLoading = false;
    _notify();
  }

  Future<void> _initFullAds() async {
    final isOrganic = await AdsService.isOrganicAsync();
    final showFull1 = FirebaseRemoteConfigService.getBoolConfigByKey(
          FirebaseRemoteConfigService.native_onboarding_full_1,
        ) &&
        !isOrganic;
    final showFull2 = FirebaseRemoteConfigService.getBoolConfigByKey(
          FirebaseRemoteConfigService.native_onboarding_full_2,
        ) &&
        !isOrganic;

    if (showFull1) {
      nativeOnboardFull1 = EasyAds.instance.createNative(
        adNetwork: AdNetwork.admob,
        factoryId: NativeFactoryId.nativeFull,
        adId: MyAdIdName.nativeOnboardFull1Ad.getId,
        adIdName: MyAdIdName.nativeOnboardFull1Ad,
        height: 1.sh,
      );
      final originalLoaded = nativeOnboardFull1?.onAdLoaded;
      nativeOnboardFull1?.onAdLoaded = (adNetwork, adUnitType, data) {
        originalLoaded?.call(adNetwork, adUnitType, data);
        shouldShowAdsFull1 = true;
        _notify();
      };
      nativeOnboardFull1?.load();
    }

    if (showFull2) {
      nativeOnboardFull2 = EasyAds.instance.createNative(
        adNetwork: AdNetwork.admob,
        factoryId: NativeFactoryId.nativeFull,
        adId: MyAdIdName.nativeOnboardFull2Ad.getId,
        adIdName: MyAdIdName.nativeOnboardFull2Ad,
        height: 1.sh,
      );
      final originalLoaded = nativeOnboardFull2?.onAdLoaded;
      nativeOnboardFull2?.onAdLoaded = (adNetwork, adUnitType, data) {
        originalLoaded?.call(adNetwork, adUnitType, data);
        shouldShowAdsFull2 = true;
        _notify();
      };
      nativeOnboardFull2?.load();
    }
  }

  void _listenAdEvents() {
    if (!AppConstants.isMobilePlatform) return;
    _adEventSubscription?.cancel();
    _adEventSubscription = EasyAds.instance.onEvent.listen((event) {
      if (event.adUnitId == MyAdIdName.nativeOnboard1Ad.getId) {
        if (event.type == AdEventType.adLoaded ||
            event.type == AdEventType.adFailedToLoad) {
          _intro1SuccessTimer?.cancel();
          _intro1SuccessTimer = Timer(const Duration(milliseconds: 500), () {
            isIntro1AdLoading = false;
            _intro1TimeoutTimer?.cancel();
            _notify();
          });
        }
      } else if (event.adUnitId == MyAdIdName.nativeOnboard4Ad.getId) {
        if (event.type == AdEventType.adLoaded ||
            event.type == AdEventType.adFailedToLoad) {
          isIntro4AdReady = true;
          _intro4SuccessTimer?.cancel();
          _intro4SuccessTimer = Timer(const Duration(milliseconds: 500), () {
            isIntro4AdLoading = false;
            _intro4TimeoutTimer?.cancel();
            _notify();
          });
        }
      } else if (event.adUnitId == MyAdIdName.nativeOnboardFull1Ad.getId) {
        if (event.type == AdEventType.adLoaded) {
          shouldShowAdsFull1 = true;
          _notify();
        }
      } else if (event.adUnitId == MyAdIdName.nativeOnboardFull2Ad.getId) {
        if (event.type == AdEventType.adLoaded) {
          shouldShowAdsFull2 = true;
          _notify();
        }
      }
    });
  }

  List<OnboardStep> getSteps() {
    final canShowAds =
        AppConstants.isMobilePlatform && !AppConstants.isPremiumUser.value;
    final showAdOnboard1 = canShowAds &&
        FirebaseRemoteConfigService.getBoolConfigByKey(
          FirebaseRemoteConfigService.native_onboarding_1,
        );
    final showAdOnboard4 = canShowAds &&
        FirebaseRemoteConfigService.getBoolConfigByKey(
          FirebaseRemoteConfigService.native_onboarding_4,
        );

    final steps = <OnboardStep>[
      OnboardStep(
        titleKey: 'onboard_title_1',
        descKey: 'onboard_desc_1',
        image: 'assets/images/onboard1.webp',
        fallbackPoster: 'assets/dramas/01_a_billionaires_love/poster.jpg',
        adId: showAdOnboard1 ? MyAdIdName.nativeOnboard1Ad.getId : '',
        adIdName: showAdOnboard1 ? MyAdIdName.nativeOnboard1Ad : null,
        factoryId: showAdOnboard1 ? NativeFactoryId.nativeMedia : '',
      ),
      const OnboardStep(
        titleKey: 'onboard_title_2',
        descKey: 'onboard_desc_2',
        image: 'assets/images/onboard2.webp',
        fallbackPoster: 'assets/dramas/02_the_tyrants_thoughts/poster.jpg',
      ),
    ];

    if (canShowAds && shouldShowAdsFull1 && nativeOnboardFull1 != null) {
      steps.add(OnboardStep(fullAd: nativeOnboardFull1));
    }

    steps.add(
      const OnboardStep(
        titleKey: 'onboard_title_3',
        descKey: 'onboard_desc_3',
        image: 'assets/images/onboard3.webp',
        fallbackPoster: 'assets/dramas/04_fortune_brides_revenge/poster.jpg',
      ),
    );

    if (canShowAds && shouldShowAdsFull2 && nativeOnboardFull2 != null) {
      steps.add(OnboardStep(fullAd: nativeOnboardFull2));
    }

    steps.add(
      OnboardStep(
        titleKey: 'onboard_title_4',
        descKey: 'onboard_desc_4',
        image: 'assets/images/onboard4.webp',
        fallbackPoster: 'assets/dramas/10_fake_romance_turns_real/poster.jpg',
        adId: showAdOnboard4 ? MyAdIdName.nativeOnboard4Ad.getId : '',
        adIdName: showAdOnboard4 ? MyAdIdName.nativeOnboard4Ad : null,
        factoryId: showAdOnboard4 ? NativeFactoryId.nativeMedia : '',
      ),
    );

    return steps;
  }

  void onChangePage(int value) {
    currentIndex = value;
    final steps = getSteps();

    if (value >= 0 && value < steps.length) {
      final step = steps[value];
      if (step.isFullAd) {
        isFullAdNextButtonVisible = false;
        _fullAdTimer?.cancel();
        _fullAdTimer = Timer(const Duration(seconds: 2), () {
          isFullAdNextButtonVisible = true;
          _notify();
        });
      } else {
        isFullAdNextButtonVisible = false;
      }

      if (step.titleKey == 'onboard_title_4') {
        _checkIntro4AdLoadingState();
      }
    }

    int introCount = 0;
    for (int i = 0; i <= value && i < steps.length; i++) {
      if (!steps[i].isFullAd) {
        introCount++;
      }
    }
    currentTabOnboard = (introCount - 1).clamp(0, 3);

    if (value >= 0 && value < steps.length && steps[value].isFullAd) {
      AppRouteObserver.logScreen('OnboardActivity');
    } else {
      final stepNum = currentTabOnboard + 1;
      AppRouteObserver.logScreen('OnboardActivity');
      if (stepNum == 2) {
        FirebaseHelper.logEventName(FirebaseHelper.onboard2View);
      } else if (stepNum == 3) {
        FirebaseHelper.logEventName(FirebaseHelper.onboard3View);
      } else if (stepNum == 4) {
        FirebaseHelper.logEventName(FirebaseHelper.onboard4View);
      }
    }
    _notify();
  }

  void _checkIntro4AdLoadingState() {
    final showAdOnboard4 = AppConstants.isMobilePlatform &&
        !AppConstants.isPremiumUser.value &&
        FirebaseRemoteConfigService.getBoolConfigByKey(
          FirebaseRemoteConfigService.native_onboarding_4,
        );

    if (showAdOnboard4) {
      final ad = EasyAds.instance.getCachedNativeAd(
        MyAdIdName.nativeOnboard4Ad,
      );
      final isLoaded = isIntro4AdReady || (ad != null && ad.isAdLoaded);

      isIntro4AdLoading = true;
      _intro4TimeoutTimer?.cancel();
      _intro4SuccessTimer?.cancel();

      if (isLoaded) {
        _intro4SuccessTimer = Timer(const Duration(milliseconds: 500), () {
          isIntro4AdLoading = false;
          _notify();
        });
      } else {
        _intro4TimeoutTimer = Timer(const Duration(seconds: 4), () {
          if (isIntro4AdLoading) {
            isIntro4AdLoading = false;
            _notify();
          }
        });
      }
    } else {
      isIntro4AdLoading = false;
    }
  }

  void onSelectNext(BuildContext context, List<OnboardStep> steps) {
    if (currentIndex < steps.length - 1) {
      currentIndex++;
      pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      _notify();
    } else {
      unawaited(_finishOnboarding(context));
    }
  }

  Future<void> _finishOnboarding(BuildContext context) async {
    await SharedPreferenceService.setIsNoFirstOpenApp(true);
    if (AppConstants.isMobilePlatform) {
      EasyAds.instance.appLifecycleReactor?.setOnSplashScreen(false);
    }

    void navigateToMain() {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        AppScreenUtils.adaptivePageRoute<void>(
          settings: const RouteSettings(name: 'main'),
          builder: (_) => const MainShellScreen(
            key: ValueKey('riverpod_main_shell_5tabs'),
          ),
        ),
      );
    }

    final isOrganic = await AdsService.isOrganicAsync();
    final showInterOnboard = FirebaseRemoteConfigService.getBoolConfigByKey(
      FirebaseRemoteConfigService.inter_onboard,
    );

    if (AppConstants.isMobilePlatform &&
        !AppConstants.isPremiumUser.value &&
        !isOrganic &&
        showInterOnboard) {
      if (!context.mounted) return;
      EasyAds.instance.showInterstitialAd(
        context,
        adId: MyAdIdName.interOnboard.getId,
        adIdName: MyAdIdName.interOnboard,
        adDissmissed: navigateToMain,
        onFailed: navigateToMain,
      );
    } else {
      navigateToMain();
    }
  }

  void _cancelTimers() {
    _fullAdTimer?.cancel();
    _intro1TimeoutTimer?.cancel();
    _intro4TimeoutTimer?.cancel();
    _intro1SuccessTimer?.cancel();
    _intro4SuccessTimer?.cancel();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelTimers();
    _adEventSubscription?.cancel();
    nativeOnboardFull1?.dispose();
    nativeOnboardFull2?.dispose();
    pageController.dispose();
    super.dispose();
  }
}
