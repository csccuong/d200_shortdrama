import 'package:easy_ads_flutter/easy_ads_flutter.dart';

import '../const/ad_id_extension.dart';
import '../const/ad_id_name.dart';

class MyAdIdManager extends IAdIdManager {
  @override
  AppAdIds? get admobAdIds => AppAdIds(
        appId: MyAdIdName.appID,
        appOpenId: MyAdIdName.appOpenResume.getId,
      );
}
