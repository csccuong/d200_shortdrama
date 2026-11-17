import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../models/iap_models.dart';
import '../../providers/app_providers.dart';
import '../../services/iap_service.dart';
import 'app_toast.dart';

/// UI view model for a VIP subscription plan card.
class RewardVipPackage {
  final String productId;
  final String planKey;
  final String title;
  final String price;
  final String? discountBadge;

  const RewardVipPackage({
    required this.productId,
    required this.planKey,
    required this.title,
    required this.price,
    this.discountBadge,
  });
}

/// Shared resolver and purchase outcome handler for VIP subscription packages.
class VipPackageHelper {
  VipPackageHelper._();

  static List<RewardVipPackage> resolvePackages({
    required IapCatalog? catalog,
    required Map<String, ProductDetails> storeProducts,
    required bool isLoadingCatalog,
    required LocaleState locale,
  }) {
    final subs = (catalog != null && catalog.subscriptions.isNotEmpty)
        ? catalog.subscriptions
        : IapCatalog.defaultVipSubscriptions;

    return subs.asMap().entries.map((e) {
      final sub = e.value;
      final storePrice = storeProducts[sub.productId]?.price;
      final priceStr = (storePrice != null && storePrice.isNotEmpty)
          ? storePrice
          : (isLoadingCatalog
              ? '...'
              : formatFallbackPrice(sub.price, sub.currency));
      return RewardVipPackage(
        productId: sub.productId,
        planKey: sub.productId,
        title: resolvePlanTitle(sub, locale),
        price: priceStr,
        discountBadge: resolvePlanBadge(sub, e.key, locale),
      );
    }).toList();
  }

  static String formatFallbackPrice(double price, String currency) {
    final formatted = price == price.roundToDouble()
        ? '${price.toInt()}'
        : price.toStringAsFixed(2);
    if (currency.toUpperCase() == 'USD') return '\$$formatted';
    return '$formatted $currency'.trim();
  }

  static String resolvePlanTitle(VipSubscription sub, LocaleState locale) {
    final normalized = sub.name.trim().toLowerCase();
    if (sub.productId == IapCatalog.weeklyProductId ||
        normalized == 'weekly') {
      return locale.tr('reward_plan_weekly');
    }
    if (sub.productId == IapCatalog.monthlyProductId ||
        normalized == 'monthly') {
      return locale.tr('reward_plan_monthly');
    }
    if (sub.productId == IapCatalog.yearlyProductId ||
        normalized == 'yearly') {
      return locale.tr('reward_plan_yearly');
    }
    return sub.name.isNotEmpty ? sub.name : '${sub.durationDays}d VIP';
  }

  static String? resolvePlanBadge(
    VipSubscription sub,
    int index,
    LocaleState locale,
  ) {
    if (sub.productId == IapCatalog.monthlyProductId || index == 1) {
      return locale.tr('reward_save_30');
    }
    return null;
  }

  /// Launches Google Play subscription purchase and handles feedback/tracking.
  static Future<bool> purchaseSubscription({
    required BuildContext context,
    required WidgetRef ref,
    required RewardVipPackage package,
    required LocaleState locale,
    required String sourceScreen,
  }) async {
    final result = await ref.read(accountProvider.notifier).purchaseProduct(
          productId: package.productId,
          isConsumable: false,
        );
    debugPrint(
      'VipPackageHelper.purchaseSubscription: product=${package.productId} '
      'outcome=${result.outcome.name} msg=${result.message}',
    );
    if (!context.mounted) return false;

    switch (result.outcome) {
      case IapPurchaseOutcome.success:
        ref.read(eventTrackerProvider).track(
          'iap_purchase',
          sourceScreen: sourceScreen,
          props: {'product_id': package.productId},
        );
        AppToast.show(
          context,
          '${locale.tr('activated_vip_toast')}: ${package.title} (${package.price})',
        );
        return true;
      case IapPurchaseOutcome.pending:
        AppToast.show(
          context,
          result.message ?? 'Payment is pending confirmation on Google Play',
        );
        return false;
      case IapPurchaseOutcome.canceled:
        return false;
      case IapPurchaseOutcome.storeUnavailable:
        AppToast.show(context, 'Google Play Billing is currently unavailable');
        return false;
      case IapPurchaseOutcome.productNotFound:
        AppToast.show(
          context,
          'Product ${package.productId} is not configured on Google Play',
        );
        return false;
      case IapPurchaseOutcome.verificationFailed:
      case IapPurchaseOutcome.error:
        AppToast.show(context, locale.tr('generic_error_toast'));
        return false;
    }
  }
}
