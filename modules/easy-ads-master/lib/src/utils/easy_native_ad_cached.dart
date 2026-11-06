import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'easy_loading_ad.dart';

class EasyNativeAdCached extends StatefulWidget {
  final AdNetwork adNetwork;
  final String factoryId;
  final String adId;
  final String cacheKey;
  final double height;
  final Widget? loadingWidget;
  final Widget? fallbackWidget;

  const EasyNativeAdCached({
    this.adNetwork = AdNetwork.admob,
    required this.factoryId,
    required this.adId,
    required this.cacheKey,
    required this.height,
    this.loadingWidget,
    this.fallbackWidget,
    Key? key,
  }) : super(key: key);

  @override
  State<EasyNativeAdCached> createState() => _EasyNativeAdCachedState();
}

class _EasyNativeAdCachedState extends State<EasyNativeAdCached> {
  EasyAdBase? _nativeAd;
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    if (EasyAds.instance.isPremiumUser) return;
    _nativeAd = EasyAds.instance.getCachedNativeAd(widget.cacheKey);

    if (_nativeAd == null) {
      // If it is not in the cache, start preloading it automatically
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
        _nativeAd = null;
        if (mounted) setState(() {});
        return;
      }
      if (event.adUnitId == widget.adId && event.type == AdEventType.adLoaded) {
        if (mounted) {
          setState(() {
            _nativeAd = EasyAds.instance.getCachedNativeAd(widget.cacheKey);
          });
        }
      } else if (event.adUnitId == widget.adId && event.type == AdEventType.adFailedToLoad) {
        if (mounted) {
          setState(() {
            _nativeAd = EasyAds.instance.getCachedNativeAd(widget.cacheKey);
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (EasyAds.instance.isPremiumUser) return const SizedBox();
    final ad = _nativeAd;

    if (ad == null || ad.isAdLoading) {
      return widget.loadingWidget ?? EasyLoadingAd(height: widget.height);
    }

    if (ad.isAdLoadedFailed) {
      return widget.fallbackWidget ?? const SizedBox();
    }

    return ad.show() ?? const SizedBox();
  }

  @override
  void dispose() {
    // CRITICAL: DO NOT dispose the cached native ad here, 
    // as its lifecycle is managed globally by the EasyAds cache pool.
    _streamSubscription?.cancel();
    super.dispose();
  }
}
