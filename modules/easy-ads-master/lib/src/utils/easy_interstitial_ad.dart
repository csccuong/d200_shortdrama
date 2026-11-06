import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class EasyInterstitialAd extends StatefulWidget {
  final AdNetwork adNetwork;
  final String adId;
  final String? adIdName;
  final void Function()? onShowed;
  final void Function()? onFailed;
  final void Function()? adDismissed;
  final void Function()? onAdImpression;

  const EasyInterstitialAd({
    super.key,
    this.adNetwork = AdNetwork.admob,
    required this.adId,
    this.adIdName,
    this.onShowed,
    this.adDismissed,
    this.onFailed,
    this.onAdImpression,
  });

  @override
  State<EasyInterstitialAd> createState() => _EasyInterstitialAdState();
}

class _EasyInterstitialAdState extends State<EasyInterstitialAd>
    with WidgetsBindingObserver {
  late final String _adKey = widget.adIdName ?? (widget.adId.startsWith('ca-app-pub-') ? widget.adId : widget.adId);
  late final EasyAdBase? _interstitialAd = EasyAds.instance.getOrCreateCachedInterstitialAd(
    adNetwork: widget.adNetwork,
    adId: widget.adId,
    adIdName: widget.adIdName ?? (widget.adId.startsWith('ca-app-pub-') ? null : widget.adId),
    immersiveModeEnabled: true,
  );

  StreamSubscription? _streamSubscription;
  Timer? _timeoutTimer;

  Future<void> _showAd() => Future.delayed(
        _interstitialAd?.isAdLoaded == true
            ? const Duration(milliseconds: 100)
            : const Duration(seconds: 1),
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

  void _handleTimeout() {
    _timeoutTimer?.cancel();
    if (mounted) {
      EasyAds.instance.setFullscreenAdShowing(false);
      _streamSubscription?.cancel();
      // If ad failed to load completely, dispose it.
      // If it is still loading in background, keep it in cache so it finishes loading for the next click.
      if (_interstitialAd?.isAdLoaded != true && _interstitialAd?.isAdLoading != true) {
        EasyAds.instance.disposeCachedInterstitialAd(_adKey);
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      widget.onFailed?.call();
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    EasyAds.instance.setFullscreenAdShowing(true);
    
    _timeoutTimer = Timer(const Duration(seconds: 12), _handleTimeout);

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
            _timeoutTimer?.cancel();
            widget.onShowed?.call();
            break;
          case AdEventType.onAdImpression:
            widget.onAdImpression?.call();
            break;
          case AdEventType.adFailedToLoad:
            _timeoutTimer?.cancel();
            EasyAds.instance.setFullscreenAdShowing(false);
            _streamSubscription?.cancel();
            EasyAds.instance.disposeCachedInterstitialAd(_adKey);
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            widget.onFailed?.call();
            break;
          case AdEventType.adDismissed:
            _timeoutTimer?.cancel();
            EasyAds.instance.setFullscreenAdShowing(false);
            _streamSubscription?.cancel();
            EasyAds.instance.disposeCachedInterstitialAd(_adKey);
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            widget.adDismissed?.call();
            break;
          case AdEventType.adFailedToShow:
            if (_appLifecycleState != AppLifecycleState.resumed) {
              _adFailedToShow = true;
            } else {
              _timeoutTimer?.cancel();
              EasyAds.instance.setFullscreenAdShowing(false);
              _streamSubscription?.cancel();
              EasyAds.instance.disposeCachedInterstitialAd(_adKey);
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
    } else if (_interstitialAd?.isAdLoading != true) {
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
    _streamSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: const Color(0xE614151C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x1FFFFFFF),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Lottie.asset(
                    'assets/json/loading_ads.json',
                    package: 'easy_ads_flutter',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Lottie.asset(
                        'assets/json/loading_ads.json',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Loading Ads...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
