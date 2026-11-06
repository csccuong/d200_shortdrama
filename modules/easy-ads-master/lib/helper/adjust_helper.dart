import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_ad_revenue.dart';
import 'package:adjust_sdk/adjust_event.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class AdjustHelper {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  static String adjustToken = '';
  static String adjustEventTokenIAP = '';
  static bool isProduction = false;

  static void init({
    required String token,
    required String iapToken,
    required bool isProd,
  }) {
    adjustToken = token;
    adjustEventTokenIAP = iapToken;
    isProduction = isProd;
  }

  static Future<void> saveAttributionNetwork(String? network) async {
    print('====================================================');
    print('[ADJUST ATTRIBUTION LOG]');
    print('👉 User Network Source: ${network ?? "Unknown/Null"}');

    if (network == null || network.isEmpty) {
      print('====================================================');
      return;
    }

    bool isOrganicUser = network.toLowerCase().contains('organic');
    print('👉 Is Organic User: $isOrganicUser');
    print('====================================================');
  }

  static String adjustEventTokenBuyWeeklySuccess = '';
  static String adjustEventTokenBuyMonthlySuccess = '';
  static String adjustEventTokenBuyYearlySuccess = '';
  static String adjustEventTokenBuyYearlySaleSuccess = '';
  static String adjustEventTokenBuyLifetimeSuccess = '';
  static String adjustEventTokenBuy3MonthsSuccess = '';
  static String adjustEventTokenBuyRemoveAdsSuccess = '';

  static String adjustEventTokenUserDay1Retention = '';
  static String adjustEventTokenUserDay3Retention = '';
  static String adjustEventTokenUserDay7Retention = '';
  static String adjustEventTokenUserDay14Retention = '';
  static String adjustEventTokenUserDay20Retention = '';
  static String adjustEventTokenUserDay30Retention = '';

  static String adjustEventTokenWatch5AdFull = '';
  static String adjustEventTokenWatch10AdFull = '';

  static String adjustEventTokenWatch5AdReward = '';
  static String adjustEventTokenWatch10AdReward = '';

  static String adjustEventTokenTestWork = '';

  trackEventTestWork() {
    AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenTestWork);
    Adjust.trackEvent(adjustEvent);
  }

  trackEventBuyMonthlySuccess({
    required PurchaseDetails purchase,
    required ProductDetails productDetail,
  }) {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (isProduction) {
        AdjustEvent adjustEventMonthly =
        AdjustEvent(adjustEventTokenBuyMonthlySuccess);
        if (kDebugMode) {
          print('AdjustHelper trackEventBuyMonthlySuccess');
        }
        Adjust.trackEvent(adjustEventMonthly);
      }
    });
  }

  trackEventBuyWeeklySuccess({
    required PurchaseDetails purchase,
    required ProductDetails productDetail,
  }) {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (isProduction) {
        AdjustEvent adjustEventWeekly =
        AdjustEvent(adjustEventTokenBuyWeeklySuccess);
        if (kDebugMode) {
          print('AdjustHelper trackEventBuyWeeklySuccess');
        }
        Adjust.trackEvent(adjustEventWeekly);
      }
    });
  }

  trackEventBuyYearlySuccess({
    required PurchaseDetails purchase,
    required ProductDetails productDetail,
  }) {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (isProduction) {
        AdjustEvent adjustEventYearly =
        AdjustEvent(adjustEventTokenBuyYearlySuccess);
        if (kDebugMode) {
          print('AdjustHelper trackEventBuyYearlySuccess');
        }
        Adjust.trackEvent(adjustEventYearly);
      }
    });
  }

  trackEventInAppPurchase({
    required PurchaseDetails purchase,
    required ProductDetails productDetail,
  }) {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenIAP);
      adjustEvent.transactionId = purchase.purchaseID;
      adjustEvent.setRevenue(
          productDetail.rawPrice, productDetail.currencyCode);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventBuyYearlySaleSuccess({
    required PurchaseDetails purchase,
    required ProductDetails productDetail,
  }) {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (isProduction) {
        AdjustEvent adjustEventYearly =
        AdjustEvent(adjustEventTokenBuyYearlySaleSuccess);
        if (kDebugMode) {
          print('AdjustHelper trackEventBuyYearlySaleSuccess');
        }
        Adjust.trackEvent(adjustEventYearly);
      }
    });
  }

  trackEventBuyLifetimeSuccess({
    required PurchaseDetails purchase,
    required ProductDetails productDetail,
  }) {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (isProduction) {
        AdjustEvent adjustEventLifetime =
        AdjustEvent(adjustEventTokenBuyLifetimeSuccess);
        if (kDebugMode) {
          print('AdjustHelper trackEventBuyYearlySuccess');
        }
        Adjust.trackEvent(adjustEventLifetime);
      }
    });
  }

  trackEventBuy3MonthsSuccess({
    required PurchaseDetails purchase,
    required ProductDetails productDetail,
  }) {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (isProduction) {
        AdjustEvent adjustEvent3Months =
        AdjustEvent(adjustEventTokenBuy3MonthsSuccess);
        if (kDebugMode) {
          print('AdjustHelper adjustEventTokenBuy3MonthsSuccess');
        }
        Adjust.trackEvent(adjustEvent3Months);
      }
    });
  }

  trackEventBuyRemoveAdsSuccess({
    required PurchaseDetails purchase,
    required ProductDetails productDetail,
  }) {
    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (isProduction) {
        AdjustEvent adjustEventRemoveAds =
        AdjustEvent(adjustEventTokenBuyRemoveAdsSuccess);
        if (kDebugMode) {
          print('AdjustHelper adjustEventTokenBuyRemoveAdsSuccess');
        }
        Adjust.trackEvent(adjustEventRemoveAds);
      }
    });
  }

  trackEventWatch5AdFull() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenWatch5AdFull);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventWatch10AdFull() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenWatch10AdFull);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventWatch5AdReward() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenWatch5AdReward);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventWatch10AdReward() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenWatch10AdReward);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventUserRetentionDay1() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenUserDay1Retention);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventUserRetentionDay3() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenUserDay3Retention);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventUserRetentionDay7() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenUserDay7Retention);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventUserRetentionDay14() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenUserDay14Retention);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventUserRetentionDay20() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenUserDay20Retention);
      Adjust.trackEvent(adjustEvent);
    }
  }

  trackEventUserRetentionDay30() {
    if (isProduction) {
      AdjustEvent adjustEvent = AdjustEvent(adjustEventTokenUserDay30Retention);
      Adjust.trackEvent(adjustEvent);
    }
  }

  static adjustTrackAdRevenue({
    required Ad ad,
    required double valueMicros,
    required PrecisionType precision,
    required String currencyCode,
    required String adOnScreen,
    required String adUnit,
    required int adImpressionsCount,
  }) {
    if (kDebugMode) {
      print('adjustTrackAdRevenue currentRoute: $adOnScreen');
    }
    Future.delayed(const Duration(milliseconds: 500), () async {
      AdjustAdRevenue adjustAdRevenue = AdjustAdRevenue("admob_sdk");
      adjustAdRevenue.setRevenue(valueMicros / 1000000, currencyCode);
      adjustAdRevenue.adRevenueUnit = adUnit;
      adjustAdRevenue.adImpressionsCount = adImpressionsCount;
      if (ad.responseInfo != null) {
        AdapterResponseInfo? loadedAdapterResponseInfo = ad.responseInfo!.loadedAdapterResponseInfo;
        if (loadedAdapterResponseInfo != null) {
          adjustAdRevenue.adRevenueUnit = loadedAdapterResponseInfo.adSourceId;
          adjustAdRevenue.adRevenueNetwork = loadedAdapterResponseInfo.adSourceName;
        }
      }
      if (kDebugMode) {
        print(
            'Adjust.trackAdRevenue adUnit: $adUnit, adSourceName: ${adjustAdRevenue.adRevenueNetwork}, value: ${valueMicros / 1000000}, currency: $currencyCode');
      }
      Adjust.trackAdRevenue(adjustAdRevenue);
    });
  }

  static adjustTrackRevenueMAXEmptyTest({
    required String adUnit,
    required int adImpressionsCount,
  }) {
    AdjustAdRevenue adjustAdRevenue = AdjustAdRevenue("applovin_max_sdk");
    adjustAdRevenue.setRevenue(0, 'USD');
    adjustAdRevenue.adRevenuePlacement = '';
    adjustAdRevenue.adRevenueUnit = '';
    adjustAdRevenue.adImpressionsCount = 0;
    adjustAdRevenue.adRevenueUnit = adUnit;
    adjustAdRevenue.adRevenueNetwork = '';
    Adjust.trackAdRevenue(adjustAdRevenue);
  }
}
