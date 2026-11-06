import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';

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
  late final EasyAdBase? _interstitialAd = EasyAds.instance.createInterstitial(
    adNetwork: widget.adNetwork,
    adId: widget.adId,
    immersiveModeEnabled: true,
  );

  StreamSubscription? _streamSubscription;

  Future<void> _showAd() => Future.delayed(
        const Duration(seconds: 1),
        () {
          if (_appLifecycleState == AppLifecycleState.resumed) {
            if (mounted) {
              _interstitialAd?.show();
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
    
    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      final resolvedId = EasyAds.instance.resolveAdUnitId(widget.adId);
      if (event.adUnitType == AdUnitType.interstitial &&
          (event.adUnitId == widget.adId || event.adUnitId == resolvedId)) {
        switch (event.type) {
          case AdEventType.adLoaded:
            if (_appLifecycleState == AppLifecycleState.resumed) {
              _showAd();
            } else {
              _adFailedToShow = true;
            }
            break;
          case AdEventType.adShowed:
            widget.onShowed?.call();
            break;
          case AdEventType.onAdImpression:
            widget.onAdImpression?.call();
            break;
          case AdEventType.adFailedToLoad:
            EasyAds.instance.setFullscreenAdShowing(false);
            _streamSubscription?.cancel();
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            widget.onFailed?.call();
            break;
          case AdEventType.adDismissed:
            EasyAds.instance.setFullscreenAdShowing(false);
            _streamSubscription?.cancel();
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            widget.adDismissed?.call();
            break;
          case AdEventType.adFailedToShow:
            if (_appLifecycleState != AppLifecycleState.resumed) {
              _adFailedToShow = true;
            } else {
              EasyAds.instance.setFullscreenAdShowing(false);
              _streamSubscription?.cancel();
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              widget.onFailed?.call();
            }
            break;
          default:
            break;
        }
      }
    });

    if (_interstitialAd?.isAdLoaded == true) {
      if (_appLifecycleState == AppLifecycleState.resumed) {
        _showAd();
      } else {
        _adFailedToShow = true;
      }
    } else {
      _interstitialAd?.load();
    }

    super.initState();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _interstitialAd?.dispose();
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
