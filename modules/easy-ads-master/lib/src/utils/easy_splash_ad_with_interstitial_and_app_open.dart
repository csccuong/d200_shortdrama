import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'easy_loading_splash.dart';

class EasySplashAdWithInterstitialAndAppOpen extends StatefulWidget {
  final AdNetwork adNetwork;
  final String interstitialSplashAdId;
  final String appOpenAdId;
  final void Function()? onShowed;
  final void Function()? onDismissed;
  final void Function()? onFailedToLoad;

  const EasySplashAdWithInterstitialAndAppOpen({
    Key? key,
    this.adNetwork = AdNetwork.admob,
    required this.interstitialSplashAdId,
    required this.appOpenAdId,
    this.onShowed,
    this.onDismissed,
    this.onFailedToLoad,
  }) : super(key: key);

  @override
  State<EasySplashAdWithInterstitialAndAppOpen> createState() =>
      _EasySplashAdWithInterstitialAndAppOpenState();
}

class _EasySplashAdWithInterstitialAndAppOpenState
    extends State<EasySplashAdWithInterstitialAndAppOpen>
    with WidgetsBindingObserver {
  //
  EasyAdBase? _ads;
  late final EasyAdBase? _interstitialAd = EasyAds.instance.createInterstitial(
    adNetwork: widget.adNetwork,
    adId: widget.interstitialSplashAdId,
    immersiveModeEnabled: true,
  );

  late final EasyAdBase? _appOpenAd = EasyAds.instance.createAppOpenAd(
    adNetwork: widget.adNetwork,
    adId: widget.appOpenAdId,
  );

  StreamSubscription? _streamSubscription;
  Timer? _timer;

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  bool _adFailedToShow = false;
  bool _isAdShowed = false;

  Future<void> _showAd() => Future.delayed(
        const Duration(seconds: 1),
        () {
          if (_appLifecycleState == AppLifecycleState.resumed && !_isAdShowed) {
            if (_ads != null) {
              _ads!.show();
              _isAdShowed = true;
            }
          } else {
            _adFailedToShow = true;
          }
        },
      );

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    EasyAds.instance.setFullscreenAdShowing(true);
    _appOpenAd?.load();
    if (EasyAds.instance.canShowInterstitialAd()) {
      _interstitialAd?.load();
    }
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_ads != null) {
        _timer?.cancel();
        _timer = null;
      }
      if (_appOpenAd?.isAdLoaded == true) {
        _timer?.cancel();
        _timer = null;
        _ads = _appOpenAd;
      } else if (_interstitialAd?.isAdLoaded == true &&
          _appOpenAd?.isAdLoadedFailed == true &&
          EasyAds.instance.canShowInterstitialAd()) {
        _timer?.cancel();
        _timer = null;
        _ads = _interstitialAd;
      } else if (_appOpenAd?.isAdLoadedFailed == true &&
          _interstitialAd?.isAdLoadedFailed == true) {
        _timer?.cancel();
        _timer = null;
        widget.onFailedToLoad?.call();
        EasyAds.instance.setFullscreenAdShowing(false);
        _streamSubscription?.cancel();
      }

      if (_ads != null) {
        _showAd();
      }
    });
    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (event.adUnitType == AdUnitType.interstitial ||
          event.adUnitType == AdUnitType.appOpen) {
        switch (event.type) {
          case AdEventType.adShowed:
            widget.onShowed?.call();
            break;
          case AdEventType.adFailedToShow:
            if (_appLifecycleState != AppLifecycleState.resumed) {
              _adFailedToShow = true;
            }
            break;
          case AdEventType.adDismissed:
            widget.onDismissed?.call();
            EasyAds.instance.setFullscreenAdShowing(false);
            _streamSubscription?.cancel();
            break;
          default:
            break;
        }
      }
    });
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed && _adFailedToShow && !_isAdShowed) {
      _showAd();
    } else if (state == AppLifecycleState.paused) {}
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _interstitialAd?.dispose();
    _appOpenAd?.dispose();
    // _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EasyLoadingSplash(
      customSplash: EasyAds.configuredLoadingSplash,
      message: EasyAds.configuredLoadingMessage,
    );
  }
}
