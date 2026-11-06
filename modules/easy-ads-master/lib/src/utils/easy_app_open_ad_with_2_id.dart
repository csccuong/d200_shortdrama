import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:easy_ads_flutter/src/utils/easy_loading_splash.dart';
import 'package:flutter/material.dart';

class EasyAppOpenAdWith2Id extends StatefulWidget {
  final AdNetwork adNetwork;
  final String appOpenHigh;
  final String appOpenAll;
  final void Function()? onShowed;
  final void Function()? onFailed;
  final void Function()? adDismissed;
  final void Function()? callback;

  const EasyAppOpenAdWith2Id({
    Key? key,
    this.adNetwork = AdNetwork.admob,
    required this.appOpenHigh,
    required this.appOpenAll,
    this.onShowed,
    this.onFailed,
    this.adDismissed,
    this.callback,
  }) : super(key: key);

  @override
  State<EasyAppOpenAdWith2Id> createState() => _EasyAppOpenAdWith2IdState();
}

class _EasyAppOpenAdWith2IdState extends State<EasyAppOpenAdWith2Id>
    with WidgetsBindingObserver {
  EasyAdBase? _currentAd;
  StreamSubscription? _streamSubscription;
  bool _isLoading = true;
  bool _adShown = false;
  int _currentAdIndex = 0;

  final List<String> _adIds = [];
  bool _currentLoadFailed = false;
  bool _currentLoadSucceeded = false;
  bool _showInitiated = false;
  bool _adFailedToShow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EasyAds.instance.setFullscreenAdShowing(true);

    // Initialize ad IDs in priority order
    _adIds.addAll([widget.appOpenHigh, widget.appOpenAll]);

    // Start loading process
    _loadAdsSequentially();

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (event.adUnitType == AdUnitType.appOpen) {
        switch (event.type) {
          case AdEventType.adLoaded:
            // Only process if ad hasn't been shown yet
            if (!_adShown && _isLoading && !_showInitiated) {
              _currentLoadSucceeded = true;
              _onAdLoaded();
            }
            break;
          case AdEventType.adShowed:
            _adShown = true;
            _isLoading = false;
            _showInitiated = false; // Reset after shown
            widget.onShowed?.call();
            // Don't cancel subscription here - need to wait for adDismissed
            break;
          case AdEventType.adFailedToLoad:
            // Only process failure if ad hasn't been shown yet
            if (!_adShown) {
              _currentLoadFailed = true;
              _onAdFailedToLoad();
            }
            break;
          case AdEventType.adDismissed:
            EasyAds.instance.setFullscreenAdShowing(false);
            widget.adDismissed?.call();
            widget.callback?.call();
            _streamSubscription?.cancel();
            // Use SchedulerBinding to ensure safe navigation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
            break;
          case AdEventType.adFailedToShow:
            // Only process failure if ad hasn't been shown yet
            if (!_adShown) {
              _onAdFailedToShow();
            }
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
      // Create only the current app open ad we are trying to load
      _currentAd = EasyAds.instance.createAppOpenAd(
        adNetwork: widget.adNetwork,
        adId: _adIds[i],
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
    const int maxAttempts = 120; // 6 seconds max (50ms * 120)

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
    // Prevent multiple show calls
    if (_showInitiated || _adShown) {
      return;
    }
    if (_currentAd?.isAdLoaded == true && !_adShown) {
      _tryShowOnce();
    }
  }

  void _onAdFailedToLoad() {
    print('[EasyAppOpenAdWith2Id] Ad ${_currentAdIndex + 1} failed to load');
    // Continue to next ad in sequence
  }

  void _onAdFailedToShow() {
    print('[EasyAppOpenAdWith2Id] Ad ${_currentAdIndex + 1} failed to show');
    // Mark as failed so the loader can proceed to next ad
    _currentLoadFailed = true;
    _showInitiated = false;
  }

  void _onAllAdsFailed() {
    // Don't call onFailed if ad has already been shown
    if (_adShown) {
      return;
    }

    _isLoading = false;
    EasyAds.instance.setFullscreenAdShowing(false);
    _streamSubscription?.cancel();
    widget.onFailed?.call();
    // Use SchedulerBinding to ensure safe navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
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
    EasyAds.instance.setFullscreenAdShowing(false);
    EasyAds.instance.setManualAppOpenAdShowing(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: EasyLoadingSplash(
        customSplash: EasyAds.configuredLoadingSplash,
        message: EasyAds.configuredLoadingMessage,
      ),
    );
  }
}
