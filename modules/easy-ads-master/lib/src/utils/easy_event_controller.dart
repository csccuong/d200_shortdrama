import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';

import '../services/easy_adjust_service.dart';
import '../services/easy_firebase_service.dart';
import '../services/easy_shared_pref_service.dart';

/// Easy Event controller manages events received from all type of ad units
class EasyEventController {
  Stream<AdEvent> get onEvent => _onEventController.stream;
  final _onEventController = StreamController<AdEvent>.broadcast();

  void fireEvent(AdEvent event) => _onEventController.add(event);

  void fireNetworkInitializedEvent(AdNetwork adNetwork, bool status) {
    _onEventController.add(AdEvent(
      type: AdEventType.adNetworkInitialized,
      adNetwork: adNetwork,
      data: status,
    ));
  }

  void setupEvents(EasyAdBase ad) {
    ad.onAdLoaded = (adNetwork, adUnitType, data) => _onAdLoadedMethod(
          adNetwork,
          adUnitType,
          data,
          adUnitId: ad.adUnitId,
        );
    ad.onAdFailedToLoad = (adNetwork, adUnitType, data, errorMessage) =>
        _onAdFailedToLoadMethod(
          adNetwork,
          adUnitType,
          data,
          errorMessage,
          adUnitId: ad.adUnitId,
        );
    ad.onAdShowed = (adNetwork, adUnitType, data) => _onAdShowedMethod(
          adNetwork,
          adUnitType,
          data,
          adUnitId: ad.adUnitId,
        );
    ad.onAdFailedToShow = (adNetwork, adUnitType, data, errorMessage) =>
        _onAdFailedToShowMethod(
          adNetwork,
          adUnitType,
          data,
          errorMessage,
          adUnitId: ad.adUnitId,
        );
    ad.onAdDismissed = (adNetwork, adUnitType, data) => _onAdDismissedMethod(
          adNetwork,
          adUnitType,
          data,
          adUnitId: ad.adUnitId,
        );
    ad.onEarnedReward = (adNetwork, adUnitType, rewardType, rewardAmount) =>
        _onEarnedRewardMethod(
          adNetwork,
          adUnitType,
          rewardType,
          rewardAmount,
          adUnitId: ad.adUnitId,
        );
    ad.onPaidEvent = _onPaidEventMethod;
    ad.onLogAdImpression = _onAdImpressionEventMethod;
  }

  void _onAdLoadedMethod(
      AdNetwork adNetwork, AdUnitType adUnitType, Object? data,
      {String? adUnitId}) {
    _onEventController.add(AdEvent(
      type: AdEventType.adLoaded,
      adNetwork: adNetwork,
      adUnitType: adUnitType,
      adUnitId: adUnitId,
      data: data,
    ));
  }

  void _onAdShowedMethod(
      AdNetwork adNetwork, AdUnitType adUnitType, Object? data,
      {String? adUnitId}) {
    _onEventController.add(AdEvent(
      type: AdEventType.adShowed,
      adNetwork: adNetwork,
      adUnitType: adUnitType,
      adUnitId: adUnitId,
      data: data,
    ));
  }

  void _onAdFailedToLoadMethod(AdNetwork adNetwork, AdUnitType adUnitType,
      Object? data, String errorMessage,
      {String? adUnitId}) {
    _onEventController.add(AdEvent(
      type: AdEventType.adFailedToLoad,
      adNetwork: adNetwork,
      adUnitType: adUnitType,
      adUnitId: adUnitId,
      data: data,
      error: errorMessage,
    ));
  }

  void _onAdFailedToShowMethod(AdNetwork adNetwork, AdUnitType adUnitType,
      Object? data, String errorMessage,
      {String? adUnitId}) {
    _onEventController.add(AdEvent(
      type: AdEventType.adFailedToShow,
      adNetwork: adNetwork,
      adUnitType: adUnitType,
      adUnitId: adUnitId,
      data: data,
      error: errorMessage,
    ));
  }

  void _onAdDismissedMethod(
      AdNetwork adNetwork, AdUnitType adUnitType, Object? data,
      {String? adUnitId}) {
    _onEventController.add(AdEvent(
      type: AdEventType.adDismissed,
      adNetwork: adNetwork,
      adUnitType: adUnitType,
      adUnitId: adUnitId,
      data: data,
    ));
  }

  void _onEarnedRewardMethod(AdNetwork adNetwork, AdUnitType adUnitType,
      String? rewardType, num? rewardAmount,
      {String? adUnitId}) {
    _onEventController.add(AdEvent(
      type: AdEventType.earnedReward,
      adNetwork: adNetwork,
      adUnitType: adUnitType,
      adUnitId: adUnitId,
      data: {'rewardType': rewardType, 'rewardAmount': rewardAmount},
    ));
  }

  void _onPaidEventMethod(
      AdNetwork adNetwork,
      AdUnitType adUnitType,
      Ad ad,
      double valueMicros,
      PrecisionType precision,
      String currencyCode,
      ) {
    EasyAdjustService().logAdRevenue(
      adNetwork,
      ad,
      valueMicros,
      currencyCode,
    );



    if (valueMicros > 0) {
      EasySharedPrefService().setFullAdsValue();
    }

    _onEventController.add(AdEvent(
      type: AdEventType.onPaidEvent,
      adNetwork: adNetwork,
      adUnitType: adUnitType,
      ad: ad,
      valueMicros: valueMicros,
      precision: precision,
      currencyCode: currencyCode,
      data: {'valueMicros': valueMicros, 'currencyCode': currencyCode},
    ));
  }

  void _onAdImpressionEventMethod(
      AdNetwork adNetwork,
      AdUnitType adUnitType,
      Ad ad,
      String currencyCode,
      double valueMicros, {
      String? adIdName,
      }) {
    EasyFirebaseService().logAdImpression(
      adNetwork: adNetwork,
      ad: ad,
      valueMicros: valueMicros,
      currencyCode: currencyCode,
    );

    _onEventController.add(AdEvent(
      type: AdEventType.onAdImpression,
      adNetwork: adNetwork,
      adUnitType: adUnitType,
      ad: ad,
      data: adIdName,
    ));
  }
}
