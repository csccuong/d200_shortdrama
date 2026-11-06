import '../easy_ad_base.dart';
import '../enums/ad_network.dart';
import '../enums/ad_unit_type.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../utils/easy_loading_ad.dart';

class EasyAdmobBannerAd extends EasyAdBase {
  final AdRequest _adRequest;
  final AdSize adSize;

  EasyAdmobBannerAd(
    String adUnitId, {
    AdRequest? adRequest,
    required AdSize? adSize,
    String? adIdName,
  })  : _adRequest = adRequest ?? const AdRequest(),
        adSize = adSize ?? AdSize.banner,
        super(adUnitId, adIdName: adIdName);

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  bool _isAdLoadedFailed = false;

  @override
  AdUnitType get adUnitType => AdUnitType.banner;

  @override
  AdNetwork get adNetwork => AdNetwork.admob;

  @override
  void dispose() {
    _isAdLoaded = false;
    _isAdLoading = false;
    _isAdLoadedFailed = false;
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  @override
  bool get isAdLoaded => _isAdLoaded;

  @override
  bool get isAdLoading => _isAdLoading;

  @override
  bool get isAdLoadedFailed => _isAdLoadedFailed;

  @override
  Future<void> load({
    EasyAdCallback? onAdLoaded,
    EasyAdFailedCallback? onAdFailedToLoad,
  }) async {
    if (_isAdLoaded) return;

    _bannerAd = BannerAd(
      size: adSize,
      adUnitId: adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          _bannerAd = ad as BannerAd?;
          _isAdLoaded = true;
          _isAdLoading = false;
          _isAdLoadedFailed = false;
          this.onAdLoaded?.call(adNetwork, adUnitType, ad);
          onAdLoaded?.call(adNetwork, adUnitType, ad);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          _bannerAd = null;
          _isAdLoaded = false;
          _isAdLoading = false;
          _isAdLoadedFailed = true;
          this
              .onAdFailedToLoad
              ?.call(adNetwork, adUnitType, ad, error.toString());
          onAdFailedToLoad?.call(adNetwork, adUnitType, ad, error.toString());
          ad.dispose();
        },
        onAdOpened: (Ad ad) => onAdClicked?.call(adNetwork, adUnitType, ad),
        onAdClosed: (Ad ad) => onAdDismissed?.call(adNetwork, adUnitType, ad),
        onAdImpression: (Ad ad) {
          _isAdLoading = false;
          onAdShowed?.call(adNetwork, adUnitType, ad);
          onLogAdImpression?.call(adNetwork, adUnitType, ad, '', 0.0, adIdName: adIdName);
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          onPaidEvent?.call(
            adNetwork,
            adUnitType,
            ad,
            valueMicros,
            precision,
            currencyCode,
          );
        },
      ),
      request: _adRequest,
    );
    _isAdLoading = true;
    _bannerAd?.load();
  }

  @override
  dynamic show() {
    final ad = _bannerAd;
    if (ad == null && !_isAdLoaded) {
      if (_isAdLoading) {
        return Container(
          height: adSize.height.toDouble(),
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: EasyLoadingAd(height: adSize.height.toDouble()),
        );
      }
      return const SizedBox();
    }
    return Container(
      height: adSize.height.toDouble(),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Stack(
        children: [
          if (ad != null && _isAdLoaded)
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: adSize.width.toDouble(),
                height: adSize.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            ),
          if (_isAdLoading && !_isAdLoaded)
            Container(
              color: Colors.transparent,
              child: EasyLoadingAd(height: adSize.height.toDouble()),
            ),
        ],
      ),
    );
  }
}
