import 'package:easy_ads_flutter/src/enums/ad_event_type.dart';
import 'package:easy_ads_flutter/src/enums/ad_network.dart';
import 'package:easy_ads_flutter/src/enums/ad_unit_type.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// [AdEvent] is used to pass data inside event streams in easy ads instance
/// You can use this to distinguish between different event types and each event type has a data attached to it.
class AdEvent {
  final AdEventType type;
  final AdNetwork adNetwork;
  final AdUnitType? adUnitType;
  final Ad? ad;
  final double? valueMicros;
  final PrecisionType? precision;
  final String? currencyCode;

  /// Any custom data along with the event
  final Object? data;

  /// In case of [AdEventType.adFailedToLoad] & [AdEventType.adFailedToShow] or in any error case
  final String? error;

  String? get adUnitId {
    if (ad != null) return ad!.adUnitId;
    if (data is Ad) return (data as Ad).adUnitId;
    return null;
  }

  AdEvent({
    required this.type,
    required this.adNetwork,
    this.adUnitType,
    this.ad,
    this.valueMicros,
    this.precision,
    this.currencyCode,
    this.data,
    this.error,
  });
}
