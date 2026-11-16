import '../../easy_ads_flutter.dart';

class EasyAdmobAppOpenAd extends EasyAdBase {
  final AdRequest _adRequest;

  EasyAdmobAppOpenAd(
    super.adUnitId,
    this._adRequest, {
    String? adIdName,
  }) : super(adIdName: adIdName);

  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;
  bool _isAdLoadedFailed = false;
  DateTime? _loadTime;

  @override
  AdNetwork get adNetwork => AdNetwork.admob;

  @override
  AdUnitType get adUnitType => AdUnitType.appOpen;

  @override
  bool get isAdLoaded => _isAdLoaded;

  @override
  bool get isAdLoading => _isAdLoading;

  @override
  bool get isAdLoadedFailed => _isAdLoadedFailed;

  @override
  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _isAdLoadedFailed = false;
    _isAdLoaded = false;
    _isAdLoading = false;
  }

  @override
  Future<void> load() async {
    // Check if ad is expired (App Open Ads expire after 4 hours)
    if (_loadTime != null &&
        DateTime.now().difference(_loadTime!).inHours >= 4) {
      dispose();
    }

    if (isAdLoaded || isAdLoading) {
      return;
    }
    final sanitizedId = adUnitId.trim();
    if (sanitizedId.isEmpty || sanitizedId == 'null') {
      _appOpenAd = null;
      _isAdLoaded = false;
      _isAdLoading = false;
      _isAdLoadedFailed = true;
      onAdFailedToLoad?.call(
          adNetwork, adUnitType, null, 'Empty or invalid adUnitId');
      return;
    }

    _isAdLoading = true;
    _isAdLoadedFailed = false;
    _loadTime = DateTime.now(); // Track load time

    try {
      await AppOpenAd.load(
        adUnitId: sanitizedId,
        request: _adRequest,
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (AppOpenAd ad) {
            _appOpenAd = ad;
            _appOpenAd?.onPaidEvent =
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
            _appOpenAd = null;
            _isAdLoaded = false;
            _isAdLoading = false;
            _isAdLoadedFailed = true;
            _loadTime = null;
            onAdFailedToLoad?.call(
                adNetwork, adUnitType, error, error.toString());
          },
        ),
      );
    } catch (e) {
      _appOpenAd = null;
      _isAdLoaded = false;
      _isAdLoading = false;
      _isAdLoadedFailed = true;
      _loadTime = null;
      onAdFailedToLoad?.call(adNetwork, adUnitType, null, e.toString());
    }
  }

  @override
  show() async {
    if (!isAdLoaded) {
      onAdFailedToShow?.call(adNetwork, adUnitType, null, 'Ad not loaded');
      return;
    }

    if (_isShowingAd) {
      onAdFailedToShow?.call(adNetwork, adUnitType, null,
          'Tried to show ad while already showing an ad.');
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (AppOpenAd ad) {
        _isShowingAd = true;
        onAdShowed?.call(adNetwork, adUnitType, ad);
      },
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        _isShowingAd = false;
        onAdDismissed?.call(adNetwork, adUnitType, ad);
        ad.dispose();
        _appOpenAd = null;
        _isAdLoaded = false;
        _loadTime = null;
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
        _isShowingAd = false;
        onAdFailedToShow?.call(adNetwork, adUnitType, ad, error.toString());
        ad.dispose();
        _appOpenAd = null;
        _isAdLoaded = false;
        _loadTime = null;
      },
      onAdImpression: (AppOpenAd ad) {
        onLogAdImpression?.call(adNetwork, adUnitType, ad, '', 0.0, adIdName: adIdName);
      },
    );

    _appOpenAd!.show();
  }
}
