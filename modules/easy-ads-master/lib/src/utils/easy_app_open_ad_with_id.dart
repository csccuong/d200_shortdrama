import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:easy_ads_flutter/src/utils/easy_loading_splash.dart';
import 'package:flutter/material.dart';

class EasyAppOpenAdWithId extends StatefulWidget {
  final AdNetwork adNetwork;
  final String adId;
  final void Function()? onShowed;
  final void Function()? onFailed;
  final void Function()? adDismissed;
  final void Function()? callback;

  const EasyAppOpenAdWithId({
    Key? key,
    this.adNetwork = AdNetwork.admob,
    required this.adId,
    this.onShowed,
    this.onFailed,
    this.adDismissed,
    this.callback,
  }) : super(key: key);

  @override
  State<EasyAppOpenAdWithId> createState() => _EasyAppOpenAdWithIdState();
}

class _EasyAppOpenAdWithIdState extends State<EasyAppOpenAdWithId>
    with WidgetsBindingObserver {
  StreamSubscription? _streamSubscription;
  EasyAdBase? _currentAd;
  bool _adShown = false;
  bool _isLoading = true;
  bool _showInitiated = false; // Prevent multiple show calls

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EasyAds.instance.setFullscreenAdShowing(true);

    // Create and load app open ad with specific ID
    _loadAndShowAppOpenAd();

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      final resolvedId = EasyAds.instance.resolveAdUnitId(widget.adId);
      if (event.adUnitType == AdUnitType.appOpen &&
          (event.adUnitId == widget.adId || event.adUnitId == resolvedId)) {
        switch (event.type) {
          case AdEventType.adLoaded:
            // Only process if ad hasn't been shown yet
            if (!_adShown && _isLoading && !_showInitiated) {
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
          case AdEventType.adDismissed:
            // adDismissed should always be processed, even after adShown
            EasyAds.instance.setFullscreenAdShowing(false);
            _streamSubscription?.cancel();
            widget.adDismissed?.call();
            widget.callback?.call();
            break;
          case AdEventType.adFailedToLoad:
          case AdEventType.adFailedToShow:
            // Only call onFailed if ad hasn't been shown yet
            if (!_adShown) {
              _onAdFailed();
            }
            break;
          default:
            break;
        }
      }
    });
  }

  Future<void> _loadAndShowAppOpenAd() async {
    if (EasyAds.instance.isFullscreenAdShowing && _adShown) {
      return;
    }

    // Dispose previous ad if exists
    _currentAd?.dispose();
    _showInitiated = false;

    // Create app open ad with specific ID
    _currentAd = EasyAds.instance.createAppOpenAd(
      adNetwork: widget.adNetwork,
      adId: widget.adId,
    );

    // Load the ad
    _currentAd?.load();

    // Wait for ad to load and show
    await _waitForAdAndShow();
  }

  Future<void> _waitForAdAndShow() async {
    int attempts = 0;
    const int maxAttempts = 100; // 5 seconds max (50ms * 100)

    while (attempts < maxAttempts && mounted && !_adShown) {
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;

      if (_currentAd?.isAdLoaded == true) {
        _onAdLoaded();
        break;
      }
    }

    // If timeout and ad not shown
    if (!_adShown && mounted && !_showInitiated) {
      _onAdFailed();
    }
  }

  void _onAdLoaded() {
    // Prevent multiple show calls
    if (_showInitiated || _adShown) {
      return;
    }

    if (_currentAd?.isAdLoaded == true && !_adShown && mounted) {
      _showInitiated = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _currentAd?.isAdLoaded == true && !_adShown) {
          _currentAd?.show();
        } else {
          _showInitiated = false; // Reset if show failed
        }
      });
    }
  }

  void _onAdFailed() {
    // Don't call onFailed if ad has already been shown
    if (_adShown) {
      return;
    }

    _isLoading = false;
    _showInitiated = false; // Reset on failure
    EasyAds.instance.setFullscreenAdShowing(false);
    widget.onFailed?.call();
    // Use SchedulerBinding to ensure safe navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
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
