import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_ad_revenue.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:easy_ads_flutter/easy_ads_flutter.dart';

class EasyAdjustService {
  factory EasyAdjustService() {
    return _instance;
  }
  EasyAdjustService._internal();

  static final EasyAdjustService _instance = EasyAdjustService._internal();

  Future<void> initAdjust(
    AdjustConfig config, {
    Function(bool isOrganic)? onOrganicChanged,
  }) async {
    config.logLevel = AdjustLogLevel.verbose;

    config.attributionCallback = (attributionChangedData) {
      print('[Adjust]: Attribution changed!');
      AdjustHelper.saveAttributionNetwork(attributionChangedData.network);
      if (attributionChangedData.network != null &&
          attributionChangedData.network!.isNotEmpty) {
        bool isOrganic =
            attributionChangedData.network!.toLowerCase().contains('organic');
        onOrganicChanged?.call(isOrganic);
      }
      if (attributionChangedData.trackerToken != null) {
        print('[Adjust]: Tracker token: ' + attributionChangedData.trackerToken!);
      }
      if (attributionChangedData.trackerName != null) {
        print('[Adjust]: Tracker name: ' + attributionChangedData.trackerName!);
      }
      if (attributionChangedData.campaign != null) {
        print('[Adjust]: Campaign: ' + attributionChangedData.campaign!);
      }
      if (attributionChangedData.network != null) {
        print('[Adjust]: Network: ' + attributionChangedData.network!);
      }
      if (attributionChangedData.creative != null) {
        print('[Adjust]: Creative: ' + attributionChangedData.creative!);
      }
      if (attributionChangedData.adgroup != null) {
        print('[Adjust]: Adgroup: ' + attributionChangedData.adgroup!);
      }
      if (attributionChangedData.clickLabel != null) {
        print('[Adjust]: Click label: ' + attributionChangedData.clickLabel!);
      }
      if (attributionChangedData.costType != null) {
        print('[Adjust]: Cost type: ' + attributionChangedData.costType!);
      }
      if (attributionChangedData.costAmount != null) {
        print('[Adjust]: Cost amount: ' + attributionChangedData.costAmount!.toString());
      }
      if (attributionChangedData.costCurrency != null) {
        print('[Adjust]: Cost currency: ' + attributionChangedData.costCurrency!);
      }
    };

    config.sessionSuccessCallback = (sessionSuccessData) {
      print('[Adjust]: Session tracking success!');
      if (sessionSuccessData.message != null) {
        print('[Adjust]: Message: ' + sessionSuccessData.message!);
      }
      if (sessionSuccessData.timestamp != null) {
        print('[Adjust]: Timestamp: ' + sessionSuccessData.timestamp!);
      }
      if (sessionSuccessData.adid != null) {
        print('[Adjust]: Adid: ' + sessionSuccessData.adid!);
      }
      if (sessionSuccessData.jsonResponse != null) {
        print('[Adjust]: JSON response: ' + sessionSuccessData.jsonResponse!);
      }
    };

    config.sessionFailureCallback = (sessionFailureData) {
      print('[Adjust]: Session tracking failure!');
      if (sessionFailureData.message != null) {
        print('[Adjust]: Message: ' + sessionFailureData.message!);
      }
      if (sessionFailureData.timestamp != null) {
        print('[Adjust]: Timestamp: ' + sessionFailureData.timestamp!);
      }
      if (sessionFailureData.adid != null) {
        print('[Adjust]: Adid: ' + sessionFailureData.adid!);
      }
      if (sessionFailureData.willRetry != null) {
        print('[Adjust]: Will retry: ' + sessionFailureData.willRetry.toString());
      }
      if (sessionFailureData.jsonResponse != null) {
        print('[Adjust]: JSON response: ' + sessionFailureData.jsonResponse!);
      }
    };

    config.eventSuccessCallback = (eventSuccessData) {
      print('[Adjust]: Event tracking success!');
      if (eventSuccessData.eventToken != null) {
        print('[Adjust]: Event token: ' + eventSuccessData.eventToken!);
      }
      if (eventSuccessData.message != null) {
        print('[Adjust]: Message: ' + eventSuccessData.message!);
      }
      if (eventSuccessData.timestamp != null) {
        print('[Adjust]: Timestamp: ' + eventSuccessData.timestamp!);
      }
      if (eventSuccessData.adid != null) {
        print('[Adjust]: Adid: ' + eventSuccessData.adid!);
      }
      if (eventSuccessData.callbackId != null) {
        print('[Adjust]: Callback ID: ' + eventSuccessData.callbackId!);
      }
      if (eventSuccessData.jsonResponse != null) {
        print('[Adjust]: JSON response: ' + eventSuccessData.jsonResponse!);
      }
    };

    config.eventFailureCallback = (eventFailureData) {
      print('[Adjust]: Event tracking failure!');
      if (eventFailureData.eventToken != null) {
        print('[Adjust]: Event token: ' + eventFailureData.eventToken!);
      }
      if (eventFailureData.message != null) {
        print('[Adjust]: Message: ' + eventFailureData.message!);
      }
      if (eventFailureData.timestamp != null) {
        print('[Adjust]: Timestamp: ' + eventFailureData.timestamp!);
      }
      if (eventFailureData.adid != null) {
        print('[Adjust]: Adid: ' + eventFailureData.adid!);
      }
      if (eventFailureData.callbackId != null) {
        print('[Adjust]: Callback ID: ' + eventFailureData.callbackId!);
      }
      if (eventFailureData.willRetry != null) {
        print('[Adjust]: Will retry: ' + eventFailureData.willRetry.toString());
      }
      if (eventFailureData.jsonResponse != null) {
        print('[Adjust]: JSON response: ' + eventFailureData.jsonResponse!);
      }
    };

    config.deferredDeeplinkCallback = (uri) {
      print('[Adjust]: Received deferred deeplink: ' + (uri ?? ""));
    };

    config.skanUpdatedCallback = (skanUpdateData) {
      print('[Adjust]: Received SKAN update data: ' + skanUpdateData.toString());
    };

    // Add session callback parameters.
    Adjust.addGlobalCallbackParameter('scp_foo_1', 'scp_bar');
    Adjust.addGlobalCallbackParameter('scp_foo_2', 'scp_value');

    // Add session Partner parameters.
    Adjust.addGlobalPartnerParameter('spp_foo_1', 'spp_bar');
    Adjust.addGlobalPartnerParameter('spp_foo_2', 'spp_value');

    // Remove session callback parameters.
    Adjust.removeGlobalCallbackParameter('scp_foo_1');
    Adjust.removeGlobalPartnerParameter('spp_foo_1');

    // Clear all session callback parameters.
    Adjust.removeGlobalCallbackParameters();

    // Clear all session partner parameters.
    Adjust.removeGlobalPartnerParameters();

    try {
      // Ask for tracking consent.
      Adjust.requestAppTrackingAuthorization().then((status) {
        print('[Adjust]: Authorization status update: $status');
      });
    } catch (_) {}

    print('[Adjust]: init SDK from easy_ads');
    Adjust.initSdk(config);

    Adjust.getAttribution().then((attribution) {
      if (attribution.network != null && attribution.network!.isNotEmpty) {
        AdjustHelper.saveAttributionNetwork(attribution.network);
        bool isOrganic =
            attribution.network!.toLowerCase().contains('organic');
        onOrganicChanged?.call(isOrganic);
      }
    });
  }

  void logAdRevenue(
    AdNetwork adNetwork,
    Ad ad,
    double valueMicros,
    String currencyCode,
  ) {
    final adUnitMapping =
        ad.responseInfo?.adapterResponses?.firstOrNull?.adUnitMapping['pubid'] ??
            'Unknown';

    AdjustAdRevenue adjustAdRevenue = AdjustAdRevenue("admob_sdk");
    adjustAdRevenue.setRevenue(valueMicros / 1000000.0, currencyCode);
    adjustAdRevenue.adRevenueUnit = _extractAdUnitId(adUnitMapping);
    
    if (ad.responseInfo != null) {
      AdapterResponseInfo? loadedAdapterResponseInfo = ad.responseInfo!.loadedAdapterResponseInfo;
      if (loadedAdapterResponseInfo != null) {
        adjustAdRevenue.adRevenueNetwork = loadedAdapterResponseInfo.adSourceName;
      }
    }

    Adjust.trackAdRevenue(adjustAdRevenue);
  }

  void logAdRevenue60Percent(
    AdNetwork adNetwork,
    Ad ad,
    double valueMicros,
    String currencyCode,
  ) {
    final adUnitMapping =
        ad.responseInfo?.adapterResponses?.firstOrNull?.adUnitMapping['pubid'] ??
            'Unknown';

    AdjustAdRevenue adjustAdRevenue60 = AdjustAdRevenue("admob_sdk");
    adjustAdRevenue60.setRevenue((valueMicros * 0.6) / 1000000.0, currencyCode);
    adjustAdRevenue60.adRevenueUnit = _extractAdUnitId(adUnitMapping) + "60%";
    
    if (ad.responseInfo != null) {
      AdapterResponseInfo? loadedAdapterResponseInfo = ad.responseInfo!.loadedAdapterResponseInfo;
      if (loadedAdapterResponseInfo != null) {
        adjustAdRevenue60.adRevenueNetwork = loadedAdapterResponseInfo.adSourceName;
      }
    }

    Adjust.trackAdRevenue(adjustAdRevenue60);
  }

  String _extractAdUnitId(String adUnitMapping) {
    List parts = adUnitMapping.split('/');
    if (parts.length >= 2) {
      return '${parts[0]}/${parts[1]}';
    } else {
      return adUnitMapping;
    }
  }
}
