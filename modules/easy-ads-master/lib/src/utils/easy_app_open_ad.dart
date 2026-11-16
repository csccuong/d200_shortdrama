import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:easy_ads_flutter/src/utils/easy_loading_splash.dart';
import 'package:flutter/material.dart';

class EasyAppOpenAd extends StatefulWidget {
  final AdNetwork adNetwork;

  const EasyAppOpenAd({
    Key? key,
    this.adNetwork = AdNetwork.admob,
  }) : super(key: key);

  @override
  State<EasyAppOpenAd> createState() => _EasyAppOpenAdState();
}

class _EasyAppOpenAdState extends State<EasyAppOpenAd>
    with WidgetsBindingObserver {
  StreamSubscription? _streamSubscription;
  bool _terminalHandled = false;
  bool _adFailed = false;
  bool _adShown = false;

  void _dismissOverlay({bool reloadAfterDismiss = false}) {
    if (_terminalHandled) return;
    _terminalHandled = true;
    _streamSubscription?.cancel();
    EasyAds.instance.setFullscreenAdShowing(false);
    if (mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      }
    }
    if (reloadAfterDismiss) {
      Future.microtask(
        () => EasyAds.instance.loadAppOpenAd(adNetwork: widget.adNetwork),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    EasyAds.instance.setFullscreenAdShowing(true);

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (_terminalHandled) return;
      if (event.adUnitType == AdUnitType.appOpen) {
        switch (event.type) {
          case AdEventType.adShowed:
            _adShown = true;
            break;
          case AdEventType.adFailedToLoad:
          case AdEventType.adFailedToShow:
            _adFailed = true;
            _dismissOverlay();
            break;
          case AdEventType.adDismissed:
            _dismissOverlay(reloadAfterDismiss: true);
            break;
          default:
            break;
        }
      }
    });

    _loadAndShowAppOpenAd();
  }

  /// Load app open ad if needed, then show it immediately.
  Future<void> _loadAndShowAppOpenAd() async {
    if (!EasyAds.instance.isAppOpenAdLoaded(adNetwork: widget.adNetwork)) {
      EasyAds.instance.loadAppOpenAd(adNetwork: widget.adNetwork);
    }

    int attempts = 0;
    const int maxAttempts = 100; // 5 seconds max (50ms * 100)

    while (!_adShown &&
        !_adFailed &&
        !_terminalHandled &&
        attempts < maxAttempts &&
        mounted) {
      if (EasyAds.instance.isAppOpenAdLoaded(adNetwork: widget.adNetwork)) {
        final success = await EasyAds.instance
            .showAd(AdUnitType.appOpen, adNetwork: widget.adNetwork);
        if (success) {
          _adShown = true;
          break;
        } else {
          _adFailed = true;
          break;
        }
      }
      if (EasyAds.instance.isAppOpenAdLoadFailed(adNetwork: widget.adNetwork)) {
        _adFailed = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
      attempts++;
    }

    if (!_adShown && !_terminalHandled && mounted) {
      _dismissOverlay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamSubscription?.cancel();
    if (!_terminalHandled) {
      EasyAds.instance.setFullscreenAdShowing(false);
    }
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
