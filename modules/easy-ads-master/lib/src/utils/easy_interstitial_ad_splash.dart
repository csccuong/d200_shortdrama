import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';

import 'easy_fullscreen_ad_loading_box.dart';

class EasyInterstitialAdSplash extends StatefulWidget {
  final AdNetwork adNetwork;
  final String adId;
  final void Function()? onShowed;
  final void Function()? onFailed;
  final void Function()? adDismissed;
  final void Function()? onAdImpression;

  const EasyInterstitialAdSplash({
    super.key,
    this.adNetwork = AdNetwork.admob,
    required this.adId,
    this.onShowed,
    this.adDismissed,
    this.onFailed,
    this.onAdImpression,
  });

  @override
  State<EasyInterstitialAdSplash> createState() =>
      _EasyInterstitialAdSplashState();
}

class _EasyInterstitialAdSplashState extends State<EasyInterstitialAdSplash>
    with WidgetsBindingObserver {
  late final String _resolvedId = EasyAds.instance.resolveAdUnitId(widget.adId);
  late final EasyAdBase? _interstitialAd = EasyAds.instance.isAdUnitValid(
    widget.adId,
  )
      ? EasyAds.instance.createInterstitial(
          adNetwork: widget.adNetwork,
          adId: widget.adId,
          immersiveModeEnabled: true,
        )
      : null;

  StreamSubscription? _streamSubscription;
  Timer? _timeoutTimer;
  bool _terminalHandled = false;

  Future<void> _showAd() => Future.delayed(
        const Duration(milliseconds: 50),
        () {
          if (_appLifecycleState == AppLifecycleState.resumed) {
            if (mounted && !_terminalHandled) {
              _interstitialAd?.show();
            }
          } else {
            _adFailedToShow = true;
          }
        },
      );

  void _completeTerminal({required bool dismissed}) {
    if (_terminalHandled) return;
    _terminalHandled = true;
    _timeoutTimer?.cancel();
    _streamSubscription?.cancel();
    EasyAds.instance.setFullscreenAdShowing(false);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (dismissed) {
      widget.adDismissed?.call();
    } else {
      widget.onFailed?.call();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EasyAds.instance.setFullscreenAdShowing(true);

    final ad = _interstitialAd;
    if (ad == null || ad.isAdLoadedFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeTerminal(dismissed: false);
      });
      return;
    }

    _timeoutTimer = Timer(
      const Duration(seconds: 7),
      () => _completeTerminal(dismissed: false),
    );

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (_terminalHandled) return;
      if (isMatchingFullscreenAdEvent(
        event,
        expectedType: AdUnitType.interstitial,
        rawAdId: widget.adId,
        resolvedId: _resolvedId,
        currentAdUnitId: ad.adUnitId,
      )) {
        switch (event.type) {
          case AdEventType.adLoaded:
            if (_appLifecycleState == AppLifecycleState.resumed) {
              _showAd();
            } else {
              _adFailedToShow = true;
            }
            break;
          case AdEventType.adShowed:
            _timeoutTimer?.cancel();
            widget.onShowed?.call();
            break;
          case AdEventType.onAdImpression:
            widget.onAdImpression?.call();
            break;
          case AdEventType.adFailedToLoad:
            _completeTerminal(dismissed: false);
            break;
          case AdEventType.adDismissed:
            _completeTerminal(dismissed: true);
            break;
          case AdEventType.adFailedToShow:
            if (_appLifecycleState != AppLifecycleState.resumed) {
              _adFailedToShow = true;
            } else {
              _completeTerminal(dismissed: false);
            }
            break;
          default:
            break;
        }
      }
    });

    if (ad.isAdLoaded) {
      if (_appLifecycleState == AppLifecycleState.resumed) {
        _showAd();
      } else {
        _adFailedToShow = true;
      }
    } else {
      ad.load().then((_) {
        if (mounted && ad.isAdLoadedFailed && !_terminalHandled) {
          _completeTerminal(dismissed: false);
        }
      });
    }
  }

  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  bool _adFailedToShow = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed && _adFailedToShow) {
      _adFailedToShow = false;
      _showAd();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _streamSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _interstitialAd?.dispose();
    if (!_terminalHandled) {
      EasyAds.instance.setFullscreenAdShowing(false);
    }
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
