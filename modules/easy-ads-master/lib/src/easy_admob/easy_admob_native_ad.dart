import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../easy_ad_base.dart';
import '../enums/ad_network.dart';
import '../enums/ad_unit_type.dart';
import '../utils/easy_loading_ad.dart';

class EasyAdmobNativeAd extends EasyAdBase {
  final AdRequest _adRequest;
  final String _factoryId;
  final double _height;

  EasyAdmobNativeAd(
    String adUnitId,
    String factoryId,
    double height, {
    String? adIdName,
    AdRequest? adRequest,
  })  : _adRequest = adRequest ?? const AdRequest(),
        _factoryId = factoryId,
        _height = height,
        super(adUnitId, adIdName: adIdName);

  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  bool _isAdLoadedFailed = false;

  @override
  AdUnitType get adUnitType => AdUnitType.native;

  @override
  AdNetwork get adNetwork => AdNetwork.admob;

  @override
  void dispose() {
    _isAdLoaded = false;
    _isAdLoadedFailed = false;
    _nativeAd?.dispose();
    _nativeAd = null;
  }

  @override
  bool get isAdLoaded => _isAdLoaded;

  @override
  bool get isAdLoadedFailed => _isAdLoadedFailed;

  @override
  Future<void> load() async {
    if (_isAdLoaded) {
      return;
    }

    print('load native ad $adUnitId');

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: _factoryId,
      request: _adRequest,
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          _nativeAd = ad as NativeAd?;
          _isAdLoaded = true;
          _isAdLoadedFailed = false;
          _isAdLoading = false;
          onAdLoaded?.call(adNetwork, adUnitType, ad);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          _nativeAd = null;
          _isAdLoaded = false;
          _isAdLoading = false;
          _isAdLoadedFailed = true;
          onAdFailedToLoad?.call(adNetwork, adUnitType, ad, error.toString());
          ad.dispose();
        },
        onAdOpened: (Ad ad) => onAdClicked?.call(adNetwork, adUnitType, ad),
        onAdClicked: (Ad ad) => onAdClicked?.call(adNetwork, adUnitType, ad),
        onAdClosed: (Ad ad) => onAdDismissed?.call(adNetwork, adUnitType, ad),
        onAdImpression: (Ad ad) {
          onAdShowed?.call(adNetwork, adUnitType, ad);
          onLogAdImpression?.call(adNetwork, adUnitType, ad, '', 0.0, adIdName: adIdName);
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          try {
            onPaidEvent?.call(
              adNetwork,
              adUnitType,
              ad,
              valueMicros,
              precision,
              currencyCode,
            );
          } catch (e) {
            print('Error in onPaidEvent callback: $e');
          }
        },
      ),
    );
    _nativeAd?.load();
    _isAdLoading = true;
  }

  @override
  dynamic show() {
    final ad = _nativeAd;
    if (_isAdLoading) {
      return EasyLoadingAd(height: _height);
    }
    if (ad == null || !_isAdLoaded) {
      return const SizedBox();
    }

    return SizedBox(
      height: _height,
      child: AdWidget(ad: ad),
    );
  }

  @override
  bool get isAdLoading => _isAdLoading;
}
