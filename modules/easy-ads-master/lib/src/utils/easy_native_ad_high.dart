import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:easy_ads_flutter/src/utils/easy_logger.dart';
import 'package:flutter/material.dart';

import 'easy_loading_ad.dart';

class EasyNativeAdHigh extends StatefulWidget {
  final AdNetwork adNetwork;
  final String factoryId;
  final String adId;
  final String adIdHigh;
  final String? adIdName;
  final String? adIdNameHigh;
  final double height;
  final VoidCallback? onLoaded;
  final VoidCallback? onFailedToLoad;
  final VoidCallback? onImpression;
  const EasyNativeAdHigh({
    this.adNetwork = AdNetwork.admob,
    required this.factoryId,
    required this.adId,
    required this.adIdHigh,
    this.adIdName,
    this.adIdNameHigh,
    required this.height,
    this.onLoaded,
    this.onFailedToLoad,
    this.onImpression,
    super.key,
  });

  @override
  State<EasyNativeAdHigh> createState() => _EasyNativeAdHighState();
}

class _EasyNativeAdHighState extends State<EasyNativeAdHigh> {
  late final String _cacheKeyHigh = widget.adIdNameHigh ??
      (widget.adIdHigh.startsWith('ca-app-pub-') ? widget.adIdHigh : widget.adIdHigh);
  late final String _cacheKeyFallback = widget.adIdName ??
      (widget.adId.startsWith('ca-app-pub-') ? widget.adId : widget.adId);

  EasyAdBase? _ad;
  EasyAdBase? _nativeAd; // fallback (all)
  EasyAdBase? _nativeAdHigh; // high priority
  Timer? _timer;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  StreamSubscription? _adEventSubscription;
  bool _finalized = false; // selection between high/fallback is done
  bool _impressionSent = false;

  @override
  void initState() {
    super.initState();
    if (EasyAds.instance.isPremiumUser) {
      _isAdLoading = false;
      return;
    }
    _isAdLoading = true;

    // Check / preload HIGH in cache
    _nativeAdHigh = EasyAds.instance.getCachedNativeAd(_cacheKeyHigh);
    if (_nativeAdHigh == null || _nativeAdHigh!.isAdLoadedFailed) {
      EasyAds.instance.preloadNativeAd(
        adId: widget.adIdHigh,
        adIdName: widget.adIdNameHigh ?? widget.adIdName,
        factoryId: widget.factoryId,
        height: widget.height,
        cacheKey: _cacheKeyHigh,
        adNetwork: widget.adNetwork,
      );
      _nativeAdHigh = EasyAds.instance.getCachedNativeAd(_cacheKeyHigh);
    }

    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (EasyAds.instance.isPremiumUser) {
        _timer?.cancel();
        _timer = null;
        _ad = null;
        _isAdLoading = false;
        if (mounted) setState(() {});
        return;
      }

      // If HIGH loaded -> use it and stop
      if (_nativeAdHigh?.isAdLoaded == true) {
        _timer?.cancel();
        _timer = null;
        _ad = _nativeAdHigh;
        _isAdLoaded = true;
        _finalized = true;
        widget.onLoaded?.call();
        EasyLogger().logInfo('Load native high success');
      }

      // If HIGH failed -> create and load FALLBACK (ALL) once
      if (_nativeAdHigh?.isAdLoadedFailed == true && _nativeAd == null) {
        _nativeAd = EasyAds.instance.getCachedNativeAd(_cacheKeyFallback);
        if (_nativeAd == null || _nativeAd!.isAdLoadedFailed) {
          EasyAds.instance.preloadNativeAd(
            adId: widget.adId,
            adIdName: widget.adIdName,
            factoryId: widget.factoryId,
            height: widget.height,
            cacheKey: _cacheKeyFallback,
            adNetwork: widget.adNetwork,
          );
          _nativeAd = EasyAds.instance.getCachedNativeAd(_cacheKeyFallback);
        }
      }

      // If FALLBACK loaded after HIGH failed -> use it and stop
      if (_nativeAdHigh?.isAdLoadedFailed == true &&
          _nativeAd?.isAdLoaded == true) {
        _timer?.cancel();
        _timer = null;
        _ad = _nativeAd;
        _isAdLoaded = true;
        _finalized = true;
        widget.onLoaded?.call();
        EasyLogger().logInfo('Load native fallback success');
      }

      // Both failed
      if (_nativeAdHigh?.isAdLoadedFailed == true &&
          _nativeAd?.isAdLoadedFailed == true) {
        _timer?.cancel();
        _timer = null;
        _isAdLoaded = false;
        _finalized = true;
        widget.onFailedToLoad?.call();
        EasyLogger().logInfo('Load native ad failed');
      }

      if (_timer == null) {
        _isAdLoading = false;
        if (mounted) setState(() {});
      }
    });

    _adEventSubscription = EasyAds.instance.onEvent.listen((event) {
      if (EasyAds.instance.isPremiumUser) {
        _timer?.cancel();
        _timer = null;
        _ad = null;
        _isAdLoading = false;
        if (mounted) setState(() {});
        return;
      }

      if (event.adUnitType == AdUnitType.native) {
        if (_finalized &&
            !_impressionSent &&
            event.type == AdEventType.onAdImpression) {
          _impressionSent = true;
          widget.onImpression?.call();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _adEventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (EasyAds.instance.isPremiumUser) {
      return const SizedBox();
    }
    if (_isAdLoading) {
      return EasyLoadingAd(height: widget.height);
    }
    if (_ad == null || !_isAdLoaded) {
      return const SizedBox();
    }
    return _ad?.show() ?? const SizedBox();
  }
}
