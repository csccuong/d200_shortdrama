import 'package:flutter/foundation.dart';

enum AdNetwork { any, admob }

extension AdNetworkExtension on AdNetwork {
  String get value => describeEnum(this);
}
