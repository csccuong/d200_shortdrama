import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';

class EasyInterstitialAdSplashWith3Id extends StatefulWidget {
  final AdNetwork adNetwork;
  final String adIdHigh;
  final String adIdMedium;
  final String adIdAll;
  final void Function()? onShowed;
  final void Function()? onFailed;
  final void Function()? adDismissed;
  final void Function()? onAdImpression;

  const EasyInterstitialAdSplashWith3Id({
    super.key,
    this.adNetwork = AdNetwork.admob,
    required this.adIdHigh,
    required this.adIdMedium,
    required this.adIdAll,
    this.onShowed,
    this.adDismissed,
    this.onFailed,
    this.onAdImpression,
  });

  @override
  State<EasyInterstitialAdSplashWith3Id> createState() =>
      _EasyInterstitialAdSplashWith3IdState();
}

class _EasyInterstitialAdSplashWith3IdState
    extends State<EasyInterstitialAdSplashWith3Id> with WidgetsBindingObserver {
  EasyAdBase? _currentAd;
  StreamSubscription? _streamSubscription;
  bool _isLoading = true;
  bool _adShown = false;
  int _currentAdIndex = 0;

  final List<String> _adIds = [];
  bool _currentLoadFailed = false;
  bool _currentLoadSucceeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EasyAds.instance.setFullscreenAdShowing(true);

    // Initialize ad IDs in priority order
    _adIds.addAll([widget.adIdHigh, widget.adIdMedium, widget.adIdAll]);

    // Start loading process
    _loadAdsSequentially();

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (event.adUnitType == AdUnitType.interstitial) {
        switch (event.type) {
          case AdEventType.adLoaded:
            if (_isLoading && !_adShown) {
              _currentLoadSucceeded = true;
              _onAdLoaded();
            }
            break;
          case AdEventType.adShowed:
            _adShown = true;
            _isLoading = false;
            widget.onShowed?.call();
            break;
          case AdEventType.onAdImpression:
            widget.onAdImpression?.call();
            break;
          case AdEventType.adFailedToLoad:
            _currentLoadFailed = true;
            _onAdFailedToLoad();
            break;
          case AdEventType.adDismissed:
            EasyAds.instance.setFullscreenAdShowing(false);
            widget.adDismissed?.call();
            _streamSubscription?.cancel();
            break;
          case AdEventType.adFailedToShow:
            _onAdFailedToShow();
            break;
          default:
            break;
        }
      }
    });
  }

  Future<void> _loadAdsSequentially() async {
    for (int i = 0; i < _adIds.length; i++) {
      if (!mounted || _adShown) break;

      _currentAdIndex = i;
      // Dispose previous ad if any
      _currentAd?.dispose();
      // Create only the current ad we are trying to load
      _currentAd = EasyAds.instance.createInterstitial(
        adNetwork: widget.adNetwork,
        adId: _adIds[i],
        immersiveModeEnabled: true,
      );

      print(
          '[EasyInterstitialAdSplashWith3Id] Loading ad ${i + 1}/${_adIds.length} with ID: ${_adIds[i]}');

      // Load the current ad
      _currentLoadFailed = false;
      _currentLoadSucceeded = false;
      _currentAd?.load();

      // Wait for ad to load or fail
      await _waitForAdResult();

      // If ad loaded successfully, show it and break
      if (_currentAd?.isAdLoaded == true || _currentLoadSucceeded) {
        print(
            '[EasyInterstitialAdSplashWith3Id] Ad ${i + 1} loaded successfully, showing...');
        _showAd();
        break;
      }

      // If this is the last ad and it failed, call onFailed
      if (i == _adIds.length - 1) {
        print('[EasyInterstitialAdSplashWith3Id] All ads failed to load');
        _onAllAdsFailed();
        break;
      }
    }
  }

  Future<void> _waitForAdResult() async {
    int attempts = 0;
    const int maxAttempts = 300; // 15 seconds max (50ms * 300)

    while (attempts < maxAttempts && mounted && !_adShown) {
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;

      if (_currentAd?.isAdLoaded == true || _currentLoadSucceeded) {
        break;
      }
      if (_currentLoadFailed) {
        break;
      }
    }
  }

  void _onAdLoaded() {
    if (_currentAd?.isAdLoaded == true && !_adShown) {
      _showAd();
    }
  }

  void _onAdFailedToLoad() {
    print(
        '[EasyInterstitialAdSplashWith3Id] Ad ${_currentAdIndex + 1} failed to load');
    // Continue to next ad in sequence
  }

  void _onAdFailedToShow() {
    print(
        '[EasyInterstitialAdSplashWith3Id] Ad ${_currentAdIndex + 1} failed to show');
    // Continue to next ad in sequence
  }

  void _onAllAdsFailed() {
    _isLoading = false;
    widget.onFailed?.call();
    EasyAds.instance.setFullscreenAdShowing(false);
    _streamSubscription?.cancel();
  }

  Future<void> _showAd() => Future.delayed(
        const Duration(seconds: 1),
        () {
          if (_appLifecycleState == AppLifecycleState.resumed) {
            if (mounted && _currentAd?.isAdLoaded == true) {
              _currentAd?.show();
            }
          } else {
            _adFailedToShow = true;
          }
        },
      );

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  bool _adFailedToShow = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed && _adFailedToShow) {
      _showAd();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _currentAd?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.shrink(),
      ),
    );
  }
}
