import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'easy_loading_ad.dart';

class EasyNativeAd extends StatefulWidget {
  final AdNetwork adNetwork;
  final String factoryId;
  final String adId;
  final String? adIdName;
  final double height;
  final VoidCallback? onLoaded;
  final VoidCallback? onFailedToLoad;
  final VoidCallback? onImpression;
  const EasyNativeAd({
    this.adNetwork = AdNetwork.admob,
    required this.factoryId,
    required this.adId,
    this.adIdName,
    required this.height,
    this.onLoaded,
    this.onFailedToLoad,
    this.onImpression,
    Key? key,
  }) : super(key: key);

  @override
  State<EasyNativeAd> createState() => _EasyNativeAdState();
}

class _EasyNativeAdState extends State<EasyNativeAd> {
  late final String _cacheKey =
      '${widget.adIdName ?? (widget.adId.startsWith('ca-app-pub-') ? widget.adId : widget.adId)}_${identityHashCode(this)}';
  EasyAdBase? _nativeAd;
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    if (EasyAds.instance.isPremiumUser) return;

    _nativeAd = EasyAds.instance.getCachedNativeAd(_cacheKey);

    if (_nativeAd == null || _nativeAd!.isAdLoadedFailed) {
      EasyAds.instance.preloadNativeAd(
        adId: widget.adId,
        adIdName: widget.adIdName,
        factoryId: widget.factoryId,
        height: widget.height,
        cacheKey: _cacheKey,
        adNetwork: widget.adNetwork,
      );
      _nativeAd = EasyAds.instance.getCachedNativeAd(_cacheKey);
    }

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (EasyAds.instance.isPremiumUser) {
        _nativeAd = null;
        if (mounted) setState(() {});
        return;
      }

      final resolvedId = EasyAds.instance.resolveAdUnitId(widget.adId);
      if (event.adUnitType == AdUnitType.native &&
          (event.adUnitId == widget.adId || event.adUnitId == resolvedId)) {
        switch (event.type) {
          case AdEventType.adLoaded:
            widget.onLoaded?.call();
            if (mounted) {
              setState(() {
                _nativeAd = EasyAds.instance.getCachedNativeAd(_cacheKey);
              });
            }
            break;
          case AdEventType.adFailedToLoad:
            widget.onFailedToLoad?.call();
            if (mounted) {
              setState(() {
                _nativeAd = EasyAds.instance.getCachedNativeAd(_cacheKey);
              });
            }
            break;
          case AdEventType.onAdImpression:
            widget.onImpression?.call();
            break;
          default:
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (EasyAds.instance.isPremiumUser) return const SizedBox();

    final ad = _nativeAd ?? EasyAds.instance.getCachedNativeAd(_cacheKey);
    if (ad == null || ad.isAdLoading) {
      return EasyLoadingAd(height: widget.height);
    }
    if (ad.isAdLoadedFailed) {
      return const SizedBox();
    }
    return ad.show() ?? const SizedBox();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    EasyAds.instance.disposeCachedNativeAd(_cacheKey);
    super.dispose();
  }
}
