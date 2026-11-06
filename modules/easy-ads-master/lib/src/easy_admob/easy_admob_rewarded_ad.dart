import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../easy_ad_base.dart';
import '../enums/ad_network.dart';
import '../enums/ad_unit_type.dart';

class EasyAdmobRewardedAd extends EasyAdBase {
  final AdRequest _adRequest;
  final bool _immersiveModeEnabled;

  EasyAdmobRewardedAd(
    String adUnitId,
    this._adRequest,
    this._immersiveModeEnabled, {
    String? adIdName,
  }) : super(adUnitId, adIdName: adIdName);

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  bool _isAdLoadedFailed = false;

  @override
  AdNetwork get adNetwork => AdNetwork.admob;

  @override
  AdUnitType get adUnitType => AdUnitType.rewarded;

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
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  @override
  Future<void> load() async {
    if (_isAdLoaded) {
      return;
    }
    _isAdLoading = true;
    await RewardedAd.load(
        adUnitId: adUnitId,
        request: _adRequest,
        rewardedAdLoadCallback:
            RewardedAdLoadCallback(onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _rewardedAd?.onPaidEvent =
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
          _isAdLoadedFailed = false;
          _isAdLoading = false;
          onAdLoaded?.call(adNetwork, adUnitType, ad);
        }, onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isAdLoaded = false;
          _isAdLoadedFailed = true;
          _isAdLoading = false;
          onAdFailedToLoad?.call(
              adNetwork, adUnitType, error, error.toString());
        }));
  }

  @override
  dynamic show() {
    final ad = _rewardedAd;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        onAdShowed?.call(adNetwork, adUnitType, ad);
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        onAdDismissed?.call(adNetwork, adUnitType, ad);

        ad.dispose();
        // load();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        onAdFailedToShow?.call(adNetwork, adUnitType, ad, error.toString());

        ad.dispose();
        // load();
      },
      onAdImpression: (RewardedAd ad) {
        onLogAdImpression?.call(adNetwork, adUnitType, ad, '', 0.0, adIdName: adIdName);
      },
    );

    ad.setImmersiveMode(_immersiveModeEnabled);
    ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      onEarnedReward?.call(adNetwork, adUnitType, reward.type, reward.amount);
    });
    _rewardedAd = null;
    _isAdLoaded = false;
  }
}
