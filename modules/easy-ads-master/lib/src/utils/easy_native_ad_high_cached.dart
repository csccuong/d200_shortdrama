import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'easy_loading_ad.dart';

class EasyNativeAdHighCached extends StatefulWidget {
  final AdNetwork adNetwork;
  final String factoryId;
  final String adId;
  final String cacheKey;
  final String adIdHigh;
  final String cacheKeyHigh;
  final double height;
  final Widget? loadingWidget;
  final Widget? fallbackWidget;

  const EasyNativeAdHighCached({
    this.adNetwork = AdNetwork.admob,
    required this.factoryId,
    required this.adId,
    required this.cacheKey,
    required this.adIdHigh,
    required this.cacheKeyHigh,
    required this.height,
    this.loadingWidget,
    this.fallbackWidget,
    super.key,
  });

  @override
  State<EasyNativeAdHighCached> createState() => _EasyNativeAdHighCachedState();
}

class _EasyNativeAdHighCachedState extends State<EasyNativeAdHighCached> {
  EasyAdBase? _nativeAdHigh;
  EasyAdBase? _nativeAdFallback;
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    if (EasyAds.instance.isPremiumUser) return;

    _updateAdInstances();

    // If High is not in cache/loading, start preloading it automatically
    if (_nativeAdHigh == null) {
      EasyAds.instance.preloadNativeAd(
        adId: widget.adIdHigh,
        factoryId: widget.factoryId,
        cacheKey: widget.cacheKeyHigh,
        height: widget.height,
        adNetwork: widget.adNetwork,
      );
    }

    // If Fallback is not in cache/loading, start preloading it as well
    if (_nativeAdFallback == null) {
      EasyAds.instance.preloadNativeAd(
        adId: widget.adId,
        factoryId: widget.factoryId,
        cacheKey: widget.cacheKey,
        height: widget.height,
        adNetwork: widget.adNetwork,
      );
    }

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (EasyAds.instance.isPremiumUser) {
        _nativeAdHigh = null;
        _nativeAdFallback = null;
        if (mounted) setState(() {});
        return;
      }
      if ((event.adUnitId == widget.adIdHigh || event.adUnitId == widget.adId) &&
          (event.type == AdEventType.adLoaded || event.type == AdEventType.adFailedToLoad)) {
        if (mounted) {
          setState(() {
            _updateAdInstances();
          });
        }
      }
    });
  }

  void _updateAdInstances() {
    if (EasyAds.instance.isPremiumUser) {
      _nativeAdHigh = null;
      _nativeAdFallback = null;
      return;
    }
    _nativeAdHigh = EasyAds.instance.getCachedNativeAd(widget.cacheKeyHigh);
    _nativeAdFallback = EasyAds.instance.getCachedNativeAd(widget.cacheKey);
  }

  @override
  Widget build(BuildContext context) {
    if (EasyAds.instance.isPremiumUser) return const SizedBox();
    // 1. If High is loaded, show it
    if (_nativeAdHigh != null && _nativeAdHigh!.isAdLoaded) {
      return _nativeAdHigh!.show() ?? const SizedBox();
    }

    // 2. If Fallback is loaded, show it to avoid empty layout
    if (_nativeAdFallback != null && _nativeAdFallback!.isAdLoaded) {
      return _nativeAdFallback!.show() ?? const SizedBox();
    }

    // 3. If High is loading, show loading
    if (_nativeAdHigh != null && _nativeAdHigh!.isAdLoading) {
      return widget.loadingWidget ?? EasyLoadingAd(height: widget.height);
    }

    // 4. If Fallback is loading, show loading
    if (_nativeAdFallback != null && _nativeAdFallback!.isAdLoading) {
      return widget.loadingWidget ?? EasyLoadingAd(height: widget.height);
    }

    // 5. Both failed to load
    if ((_nativeAdHigh == null || _nativeAdHigh!.isAdLoadedFailed) &&
        (_nativeAdFallback == null || _nativeAdFallback!.isAdLoadedFailed)) {
      return widget.fallbackWidget ?? const SizedBox();
    }

    return widget.loadingWidget ?? EasyLoadingAd(height: widget.height);
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
