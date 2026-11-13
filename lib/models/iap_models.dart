/// A VIP subscription product from the IAP catalog.
class VipSubscription {
  final String productId;
  final String name;
  final int durationDays;
  final double price;
  final String currency;
  final List<String> features;

  VipSubscription({
    required this.productId,
    this.name = '',
    this.durationDays = 30,
    this.price = 0.0,
    this.currency = 'USD',
    this.features = const [],
  });

  factory VipSubscription.fromJson(Map<String, dynamic> json) {
    return VipSubscription(
      productId: json['product_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      durationDays: json['duration_days'] as int? ?? 30,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
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
  final List<VipSubscription> subscriptions;
  final List<CoinPackage> coinPackages;

  IapCatalog({
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
