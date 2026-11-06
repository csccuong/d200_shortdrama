import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';

import '../../easy_ads_flutter.dart';

class EasyFirebaseService {
  factory EasyFirebaseService() => _instance;

  EasyFirebaseService._internal();

  static final EasyFirebaseService _instance = EasyFirebaseService._internal();

  FirebaseAnalytics? _analytics;

  Future<void> init(FirebaseAnalytics analytics) async {
    _analytics = analytics;
  }

  Future<void> logAdImpression({
    required AdNetwork adNetwork,
    required Ad ad,
    required double valueMicros,
    required String currencyCode,
  }) async {
    if (_analytics == null) {
      return;
    }

    await _analytics!.logEvent(
      name: Platform.isIOS ? 'ad_impression_ios' : 'ad_impression_android',
      parameters: {
        'ad_unit_id': ad.adUnitId,
        'value': valueMicros / 1000000,
        'currency': currencyCode,
      },
    );
  }
}
