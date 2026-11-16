import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../easy_ad_base.dart' show EasyAdBase;
import '../enums/ad_network.dart';
import '../enums/ad_unit_type.dart';

class EasyAdmobInterstitialAd extends EasyAdBase {
  final AdRequest _adRequest;
  final bool _immersiveModeEnabled;

  EasyAdmobInterstitialAd(
    super.adUnitId,
    this._adRequest,
    this._immersiveModeEnabled, {
    String? adIdName,
  }) : super(adIdName: adIdName);

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  bool _isAdLoadedFailed = false;

  @override
  AdNetwork get adNetwork => AdNetwork.admob;

  @override
  AdUnitType get adUnitType => AdUnitType.interstitial;

  @override
  bool get isAdLoaded => _isAdLoaded;

  @override
  bool get isAdLoading => _isAdLoading;

  @override
  bool get isAdLoadedFailed => _isAdLoadedFailed;

  @override
  void dispose() {
    _isAdLoaded = false;
    _isAdLoading = false;
    _isAdLoadedFailed = false;
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  @override
  Future<void> load() async {
    if (_isAdLoaded || _isAdLoading) return;
    final sanitizedId = adUnitId.trim();
    if (sanitizedId.isEmpty || sanitizedId == 'null') {
      _interstitialAd = null;
      _isAdLoaded = false;
      _isAdLoading = false;
      _isAdLoadedFailed = true;
      onAdFailedToLoad?.call(
          adNetwork, adUnitType, null, 'Empty or invalid adUnitId');
      return;
    }

    _isAdLoading = true;
    _isAdLoadedFailed = false;
    try {
      await InterstitialAd.load(
          adUnitId: sanitizedId,
          request: _adRequest,
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (InterstitialAd ad) {
              _interstitialAd = ad;
              _interstitialAd?.onPaidEvent =
                  (ad, valueMicros, precision, currencyCode) {
                onPaidEvent?.call(
                  adNetwork,
                  adUnitType,
                  ad,
                  valueMicros,
                  precision,
                  currencyCode,
                );
              };
              _isAdLoaded = true;
              _isAdLoading = false;
              _isAdLoadedFailed = false;
              onAdLoaded?.call(adNetwork, adUnitType, ad);
            },
            onAdFailedToLoad: (LoadAdError error) {
              _interstitialAd = null;
              _isAdLoaded = false;
              _isAdLoading = false;
              _isAdLoadedFailed = true;
              onAdFailedToLoad?.call(
                  adNetwork, adUnitType, error, error.toString());
            },
          ));
    } catch (e) {
      _interstitialAd = null;
      _isAdLoaded = false;
      _isAdLoading = false;
      _isAdLoadedFailed = true;
      onAdFailedToLoad?.call(adNetwork, adUnitType, null, e.toString());
    }
  }

  @override
  show() {
    final ad = _interstitialAd;
    if (ad == null) {
      onAdFailedToShow?.call(
          adNetwork, adUnitType, null, 'Interstitial ad is not ready');
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        onAdShowed?.call(adNetwork, adUnitType, ad);
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        onAdDismissed?.call(adNetwork, adUnitType, ad);

        ad.dispose();
        // load();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        onAdFailedToShow?.call(adNetwork, adUnitType, ad, error.toString());

        ad.dispose();
        // load();
      },
      onAdImpression: (InterstitialAd ad) {
        onLogAdImpression?.call(adNetwork, adUnitType, ad, '', 0.0, adIdName: adIdName);
      },
    );
    ad.setImmersiveMode(_immersiveModeEnabled);
    ad.show();
    _interstitialAd = null;
    _isAdLoaded = false;
  }
}
