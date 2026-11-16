import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';

import 'easy_fullscreen_ad_loading_box.dart';

class EasyRewardAd extends StatefulWidget {
  final AdNetwork adNetwork;
  final String adId;
  final String? adIdName;
  final void Function()? onShowed;
  final void Function()? onFailed;
  final void Function()? adDismissed;

  const EasyRewardAd({
    Key? key,
    this.adNetwork = AdNetwork.admob,
    required this.adId,
    this.adIdName,
    this.onShowed,
    this.adDismissed,
    this.onFailed,
  }) : super(key: key);

  @override
  State<EasyRewardAd> createState() => _EasyRewardAdState();
}

class _EasyRewardAdState extends State<EasyRewardAd>
    with WidgetsBindingObserver {
  late final String _adKey = widget.adIdName ?? widget.adId;
  late final String _resolvedId = EasyAds.instance.resolveAdUnitId(widget.adId);
  late final EasyAdBase? _rewardAd = EasyAds.instance.isAdEnabled(
    adUnitType: AdUnitType.rewarded,
    adId: widget.adId,
    adIdName: widget.adIdName,
  )
      ? EasyAds.instance.getOrCreateCachedRewardAd(
          adNetwork: widget.adNetwork,
          adId: widget.adId,
          adIdName: widget.adIdName,
          immersiveModeEnabled: true,
        )
      : null;

  StreamSubscription? _streamSubscription;
  Timer? _timeoutTimer;
  bool _terminalHandled = false;
  bool _isShowScheduled = false;

  void _completeTerminal({required bool dismissed}) {
    if (_terminalHandled) return;
    _terminalHandled = true;
    _timeoutTimer?.cancel();
    _streamSubscription?.cancel();
    EasyAds.instance.setFullscreenAdShowing(false);
    if (dismissed ||
        (_rewardAd?.isAdLoaded != true && _rewardAd?.isAdLoading != true)) {
      EasyAds.instance.disposeCachedRewardAd(_adKey);
    }
    if (mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      }
    }
    if (dismissed) {
      widget.adDismissed?.call();
    } else {
      widget.onFailed?.call();
    }
  }

  void _handleTimeout() => _completeTerminal(dismissed: false);

  Future<void> _showAd([
    Duration delay = const Duration(milliseconds: 50),
  ]) {
    if (_isShowScheduled || _terminalHandled) return Future.value();
    _isShowScheduled = true;
    return Future.delayed(
      delay,
      () {
        if (!mounted || _terminalHandled) return;
        if (_appLifecycleState == AppLifecycleState.resumed) {
          _rewardAd?.show();
        } else {
          _adFailedToShow = true;
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EasyAds.instance.setFullscreenAdShowing(true);

    final ad = _rewardAd;
    if (ad == null || ad.isAdLoadedFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeTerminal(dismissed: false);
      });
      return;
    }

    _timeoutTimer = Timer(const Duration(seconds: 7), _handleTimeout);

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (_terminalHandled) return;
      if (isMatchingFullscreenAdEvent(
        event,
        expectedType: AdUnitType.rewarded,
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
      _showAd(const Duration(milliseconds: 50));
    } else if (!ad.isAdLoading) {
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
    WidgetsBinding.instance.removeObserver(this);
    _streamSubscription?.cancel();
    if (!_terminalHandled) {
      EasyAds.instance.setFullscreenAdShowing(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const EasyFullscreenAdLoadingCard();
}
