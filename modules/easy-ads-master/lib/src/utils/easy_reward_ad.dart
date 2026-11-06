import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../easy_ads.dart';

class EasyRewardAd extends StatefulWidget {
  final AdNetwork adNetwork;
  final String adId;
  final void Function()? onShowed;
  final void Function()? onFailed;
  final void Function()? adDismissed;
  const EasyRewardAd({
    Key? key,
    this.adNetwork = AdNetwork.admob,
    required this.adId,
    this.onShowed,
    this.adDismissed,
    this.onFailed,
  }) : super(key: key);

  @override
  State<EasyRewardAd> createState() => _EasyRewardAdState();
}

class _EasyRewardAdState extends State<EasyRewardAd>
    with WidgetsBindingObserver {
  late final EasyAdBase? _rewardAd =
      EasyAds.instance.getOrCreateCachedRewardAd(
    adNetwork: widget.adNetwork,
    adId: widget.adId,
    immersiveModeEnabled: true,
  );

  StreamSubscription? _streamSubscription;
  Timer? _timeoutTimer;

  void _handleTimeout() {
    _timeoutTimer?.cancel();
    if (mounted) {
      EasyAds.instance.setFullscreenAdShowing(false);
      _streamSubscription?.cancel();
      if (_rewardAd?.isAdLoaded != true && _rewardAd?.isAdLoading != true) {
        EasyAds.instance.disposeCachedRewardAd(widget.adId);
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      widget.onFailed?.call();
    }
  }

  Future<void> _showAd([Duration delay = const Duration(seconds: 1)]) =>
      Future.delayed(
        delay,
        () {
          if (_appLifecycleState == AppLifecycleState.resumed) {
            if (mounted) {
              _rewardAd?.show();
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

    _timeoutTimer = Timer(const Duration(seconds: 10), _handleTimeout);

    if (_rewardAd?.isAdLoaded == true) {
      _showAd(const Duration(milliseconds: 100));
    } else {
      if (_rewardAd?.isAdLoading != true) {
        _rewardAd?.load();
      }
    }

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      final resolvedId = EasyAds.instance.resolveAdUnitId(widget.adId);
      if (event.adUnitType == AdUnitType.rewarded &&
          (event.adUnitId == widget.adId ||
              event.adUnitId == resolvedId ||
              event.adUnitId == _rewardAd?.adUnitId)) {
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
          case AdEventType.adFailedToLoad:
            _timeoutTimer?.cancel();
            EasyAds.instance.setFullscreenAdShowing(false);
            EasyAds.instance.disposeCachedRewardAd(widget.adId);
            _streamSubscription?.cancel();
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            widget.onFailed?.call();
            break;
          case AdEventType.adDismissed:
            _timeoutTimer?.cancel();
            EasyAds.instance.setFullscreenAdShowing(false);
            EasyAds.instance.disposeCachedRewardAd(widget.adId);
            _streamSubscription?.cancel();
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            widget.adDismissed?.call();
            break;
          case AdEventType.adFailedToShow:
            _timeoutTimer?.cancel();
            if (_appLifecycleState != AppLifecycleState.resumed) {
              _adFailedToShow = true;
            } else {
              EasyAds.instance.setFullscreenAdShowing(false);
              EasyAds.instance.disposeCachedRewardAd(widget.adId);
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
    _timeoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _streamSubscription?.cancel();
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
