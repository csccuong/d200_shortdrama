import '../easy_ads.dart';

class EasySharedPrefService {
  factory EasySharedPrefService() => _instance;

  EasySharedPrefService._internal();

  static final EasySharedPrefService _instance =
      EasySharedPrefService._internal();

  final fullAdsKey = 'FULL_ADS';

  Future<void> setFullAdsValue() async {
    await EasyAds.sharedPreferences?.setBool(fullAdsKey, true);
  }

  bool getFullAdsValue() {
    return EasyAds.sharedPreferences?.getBool(fullAdsKey) ?? false;
  }
}
