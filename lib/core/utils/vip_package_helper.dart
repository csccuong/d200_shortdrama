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
  final String periodLabel;
  final String? discountBadge;

  const RewardVipPackage({
    required this.productId,
    required this.planKey,
    required this.title,
    required this.price,
    this.periodLabel = '',
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
        periodLabel: resolvePlanPeriod(sub, locale),
        discountBadge: resolvePlanBadge(
          sub,
          subs: subs,
          storeProducts: storeProducts,
          isLoadingCatalog: isLoadingCatalog,
          locale: locale,
        ),
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

  static String resolvePlanPeriod(VipSubscription sub, LocaleState locale) {
    final normalized = sub.name.trim().toLowerCase();
    if (sub.productId == IapCatalog.weeklyProductId ||
        normalized == 'weekly') {
      return locale.tr('vip_weekly_period');
    }
    if (sub.productId == IapCatalog.monthlyProductId ||
        normalized == 'monthly') {
      return locale.tr('vip_monthly_period');
    }
    if (sub.productId == IapCatalog.yearlyProductId ||
        normalized == 'yearly') {
      return locale.tr('vip_annual_period');
    }
    return '/ ${sub.durationDays}d';
  }

  static String buildSubscribeButtonLabel(
    RewardVipPackage? package,
    LocaleState locale,
  ) {
    final base = locale.tr('subscribe_btn');
    if (package == null || package.price.isEmpty || package.price == '...') {
      return base;
    }
    final period = package.periodLabel.trim();
    if (period.isEmpty) return '$base • ${package.price}';
    return '$base • ${package.price} $period';
  }

  /// Computes a factual savings badge from actual store (or fallback) prices.
  /// Returns `null` when prices are loading, missing, or not strictly tiered
  /// (e.g. all plans priced identically at $9.99) to avoid misleading claims.
  static String? resolvePlanBadge(
    VipSubscription sub, {
    required List<VipSubscription> subs,
    required Map<String, ProductDetails> storeProducts,
    required bool isLoadingCatalog,
    required LocaleState locale,
  }) {
    final normalized = sub.name.trim().toLowerCase();
    if (sub.productId == IapCatalog.yearlyProductId ||
        normalized == 'yearly') {
      return null;
    }
    if (isLoadingCatalog && storeProducts.isEmpty) return null;
    if (subs.length < 2 || sub.durationDays <= 0) return null;

    final useStorePrices = storeProducts.isNotEmpty;
    double? effectivePrice(VipSubscription item) {
      if (useStorePrices) {
        final pd = storeProducts[item.productId];
        return (pd != null && pd.rawPrice > 0) ? pd.rawPrice : null;
      }
      return item.price > 0 ? item.price : null;
    }

    final subPrice = effectivePrice(sub);
    if (subPrice == null) return null;

    VipSubscription? baseline;
    for (final candidate in subs) {
      if (candidate.durationDays <= 0) continue;
      if (baseline == null || candidate.durationDays < baseline.durationDays) {
        baseline = candidate;
      }
    }
    if (baseline == null || sub.durationDays <= baseline.durationDays) {
      return null;
    }

    final baselinePrice = effectivePrice(baseline);
    if (baselinePrice == null || baselinePrice <= 0) return null;

    // Require strictly increasing total price as duration increases so flat
    // test/misconfigured prices (e.g. 9.99 / 9.99 / 9.99) never show "Save X%".
    for (final other in subs) {
      if (other.durationDays > 0 && other.durationDays < sub.durationDays) {
        final otherPrice = effectivePrice(other);
        if (otherPrice == null || subPrice <= otherPrice) {
          return null;
        }
      }
    }

    final baselinePerDay = baselinePrice / baseline.durationDays;
    final subPerDay = subPrice / sub.durationDays;
    if (baselinePerDay <= 0 || subPerDay >= baselinePerDay) return null;

    final pct = ((1.0 - (subPerDay / baselinePerDay)) * 100).round();
    if (pct < 5 || pct >= 100) return null;

    return locale.tr('reward_save_pct').replaceAll('{pct}', '$pct');
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
