/// A VIP subscription product from the IAP catalog.
class VipSubscription {
  final String code;
  final String productId;
  final String name;
  final String nameEn;
  final String nameVi;
  final String priceDisplay;
  final int durationDays;
  final double price;
  final String currency;
  final bool isPopular;
  final String benefitsEn;
  final List<String> features;

  const VipSubscription({
    this.code = '',
    required this.productId,
    this.name = '',
    this.nameEn = '',
    this.nameVi = '',
    this.priceDisplay = '',
    this.durationDays = 30,
    this.price = 0.0,
    this.currency = 'USD',
    this.isPopular = false,
    this.benefitsEn = '',
    this.features = const [],
  });

  factory VipSubscription.fromJson(Map<String, dynamic> json) {
    final rawNameEn = json['name_en']?.toString().trim() ?? '';
    final rawNameVi = json['name_vi']?.toString().trim() ?? '';
    final rawName = json['name']?.toString().trim() ?? '';
    final benefits = json['benefits_en']?.toString().trim() ?? '';
    final parsedFeatures = (json['features'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        (benefits.isNotEmpty
            ? benefits
                .split('•')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : const <String>[]);
    return VipSubscription(
      code: json['code']?.toString().trim() ?? '',
      productId: json['product_id'] as String? ?? '',
      name: rawName.isNotEmpty ? rawName : rawNameEn,
      nameEn: rawNameEn,
      nameVi: rawNameVi,
      priceDisplay: json['price_display']?.toString().trim() ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      price: (json['price'] as num?)?.toDouble() ??
          (json['price_usd'] as num?)?.toDouble() ??
          0.0,
      currency: json['currency'] as String? ?? 'USD',
      isPopular: json['is_popular'] as bool? ?? false,
      benefitsEn: benefits,
      features: parsedFeatures,
    );
  }
}

/// A coin package product from the IAP catalog.
class CoinPackage {
  final String productId;
  final String name;
  final int coins;
  final int bonusCoins;
  final double price;
  final String currency;
  final bool isPopular;

  CoinPackage({
    required this.productId,
    this.name = '',
    this.coins = 0,
    this.bonusCoins = 0,
    this.price = 0.0,
    this.currency = 'USD',
    this.isPopular = false,
  });

  factory CoinPackage.fromJson(Map<String, dynamic> json) {
    return CoinPackage(
      productId: json['product_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      coins: json['coins'] as int? ?? 0,
      bonusCoins: json['bonus_coins'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      isPopular: json['is_popular'] as bool? ?? false,
    );
  }
}

/// Full IAP catalog from GET /v1/iap/catalog.
class IapCatalog {
  static const String weeklyProductId = 'com.reels.shortdrama.weekly';
  static const String monthlyProductId = 'com.reels.shortdrama.monthly';
  static const String yearlyProductId = 'com.reels.shortdrama.yearly';

  static const List<VipSubscription> defaultVipSubscriptions = [
    VipSubscription(
      productId: weeklyProductId,
      name: 'weekly',
      durationDays: 7,
      price: 5.0,
      currency: 'USD',
      features: ['unlock all', 'no ads', 'full features'],
    ),
    VipSubscription(
      productId: monthlyProductId,
      name: 'monthly',
      durationDays: 30,
      price: 12.0,
      currency: 'USD',
      features: ['unlock all', 'no ads', 'full features'],
    ),
    VipSubscription(
      productId: yearlyProductId,
      name: 'yearly',
      durationDays: 365,
      price: 67.0,
      currency: 'USD',
      features: ['unlock all', 'no ads', 'full features'],
    ),
  ];

  final List<VipSubscription> subscriptions;
  final List<CoinPackage> coinPackages;

  const IapCatalog({
    this.subscriptions = const [],
    this.coinPackages = const [],
  });

  factory IapCatalog.fromJson(Map<String, dynamic> json) {
    return IapCatalog(
      subscriptions: (json['subscriptions'] as List<dynamic>?)
              ?.map((e) =>
                  VipSubscription.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      coinPackages: (json['coin_packages'] as List<dynamic>?)
              ?.map((e) =>
                  CoinPackage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
