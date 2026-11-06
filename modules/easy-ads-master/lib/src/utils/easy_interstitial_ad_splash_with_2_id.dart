import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';

class EasyInterstitialAdSplashWith2Id extends StatefulWidget {
  final AdNetwork adNetwork;
  final String adIdHigh;
  final String adIdAll;
  final String? adIdNameHigh;
  final String? adIdNameAll;
  final void Function()? onShowed;
  final void Function()? onFailed;
  final void Function()? adDismissed;
  final void Function()? onAdImpression;

  const EasyInterstitialAdSplashWith2Id({
    super.key,
    this.adNetwork = AdNetwork.admob,
    required this.adIdHigh,
    required this.adIdAll,
    this.adIdNameHigh,
    this.adIdNameAll,
    this.onShowed,
    this.adDismissed,
    this.onFailed,
    this.onAdImpression,
  });

  @override
  State<EasyInterstitialAdSplashWith2Id> createState() =>
      _EasyInterstitialAdSplashWith2IdState();
}

class _EasyInterstitialAdSplashWith2IdState
    extends State<EasyInterstitialAdSplashWith2Id> with WidgetsBindingObserver {
  EasyAdBase? _currentAd;
  StreamSubscription? _streamSubscription;
  bool _isLoading = true;
  bool _adShown = false;
  int _currentAdIndex = 0;

  final List<String> _adIds = [];
  bool _currentLoadFailed = false;
  bool _currentLoadSucceeded = false;
  bool _showInitiated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EasyAds.instance.setFullscreenAdShowing(true);

    // Initialize ad IDs in priority order
    _adIds.addAll([widget.adIdHigh, widget.adIdAll]);

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
      final adIdName = i == 0 ? widget.adIdNameHigh : widget.adIdNameAll;
      _currentAd = EasyAds.instance.createInterstitial(
        adNetwork: widget.adNetwork,
        adId: _adIds[i],
        adIdName: adIdName,
        immersiveModeEnabled: true,
      );

      // Load the current ad
      _currentLoadFailed = false;
      _currentLoadSucceeded = false;
      _showInitiated = false;
      _adFailedToShow = false;
      _currentAd?.load();

      // Wait for ad to load or fail
      await _waitForAdResult();

      // If ad loaded successfully, try to show it, then wait for result
      if (_currentAd?.isAdLoaded == true || _currentLoadSucceeded) {
        _tryShowOnce();
        await _waitForShowOrFail();
        if (_adShown) {
          break; // stop if showed successfully
        }
      }

      // If this is the last ad and it failed, call onFailed
      if (i == _adIds.length - 1) {
        _onAllAdsFailed();
        break;
      }
    }
  }

  Future<void> _waitForAdResult() async {
    int attempts = 0;
    const int maxAttempts = 400; // 20 seconds max (50ms * 400)

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
      _tryShowOnce();
    }
  }

  void _onAdFailedToLoad() {
    print(
        '[EasyInterstitialAdSplashWith2Id] Ad ${_currentAdIndex + 1} failed to load');
    // Continue to next ad in sequence
  }

  void _onAdFailedToShow() {
    print(
        '[EasyInterstitialAdSplashWith2Id] Ad ${_currentAdIndex + 1} failed to show');
    // Mark as failed so the loader can proceed to next ad
    _currentLoadFailed = true;
    _showInitiated = false;
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

  void _tryShowOnce() {
    if (_showInitiated || _adShown) return;
    _showInitiated = true;
    _showAd();
  }

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

  Future<void> _waitForShowOrFail() async {
    int attempts = 0;
    const int maxAttempts = 120; // 6 seconds max (50ms * 120)

    while (attempts < maxAttempts && mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;

      if (_adShown) {
        break; // showed successfully
      }
      if (_currentLoadFailed) {
        break; // failed to show
      }
    }
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
