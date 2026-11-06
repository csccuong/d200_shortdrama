import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';

class EasyBannerAd extends StatefulWidget {
  final AdNetwork adNetwork;
  final AdSize? adSize;
  final String adId;
  final String? adIdName;
  final bool isCollapsible;
  final int? reloadInterval;

  const EasyBannerAd({
    this.adNetwork = AdNetwork.admob,
    this.adSize,
    required this.adId,
    this.adIdName,
    this.isCollapsible = false,
    this.reloadInterval,
    Key? key,
  }) : super(key: key);

  @override
  State<EasyBannerAd> createState() => _EasyBannerAdState();
}

class _EasyBannerAdState extends State<EasyBannerAd> {
  EasyAdBase? _bannerAd;
  StreamSubscription? _streamSubscription;
  Timer? _reloadTimer;

  @override
  Widget build(BuildContext context) {
    if (EasyAds.instance.isPremiumUser) return const SizedBox();
    final adWidget = _bannerAd?.show();
    if (adWidget == null) return const SizedBox();
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: adWidget,
    );
  }

  AdSize? adSize;
  Future<void> _initAd() async {
    if (EasyAds.instance.isPremiumUser) return;
    if (adSize != null) {
      return;
    }
    if (widget.adSize != null) {
      adSize = widget.adSize!;
    } else {
      final currentWidth = MediaQuery.of(context).size.width.round();
      if (currentWidth > 0) {
        adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(currentWidth) ??
            EasyAds.instance.adSize ??
            AdSize.banner;
      } else {
        adSize = EasyAds.instance.adSize ?? AdSize.banner;
      }
    }
    _bannerAd = EasyAds.instance.createBanner(
      adNetwork: widget.adNetwork,
      adSize: adSize,
      adId: widget.adId,
      adIdName: widget.adIdName,
      isCollapsible: widget.isCollapsible,
    );
    _bannerAd?.load();
    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (EasyAds.instance.isPremiumUser) {
        _reloadTimer?.cancel();
        _bannerAd?.dispose();
        _bannerAd = null;
        if (mounted) setState(() {});
        return;
      }
      if (event.adUnitType == AdUnitType.banner) {
        if (mounted) {
          setState(() {});
        }
      }
    });

    _startReloadTimer();
  }

  void _startReloadTimer() {
    _reloadTimer?.cancel();
    if (EasyAds.instance.isPremiumUser) return;
    if (widget.reloadInterval != null && widget.reloadInterval! > 0) {
      _reloadTimer = Timer.periodic(Duration(seconds: widget.reloadInterval!), (timer) {
        _reloadAd();
      });
    }
  }

  void _reloadAd() {
    if (EasyAds.instance.isPremiumUser) {
      _reloadTimer?.cancel();
      _bannerAd?.dispose();
      _bannerAd = null;
      if (mounted) setState(() {});
      return;
    }
    _bannerAd?.dispose();
    _bannerAd = EasyAds.instance.createBanner(
      adNetwork: widget.adNetwork,
      adSize: adSize,
      adId: widget.adId,
      adIdName: widget.adIdName,
      isCollapsible: widget.isCollapsible,
    );
    _bannerAd?.load();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    _initAd();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _bannerAd?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
