import '../../main.dart' as app_main;
import 'ad_id.dart';

extension AdIdEx on String {
  String get getId {
    final id = myAdsId[app_main.env]?[this];
    return id ?? 'null';
  }
}
