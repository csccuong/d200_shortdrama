import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/placement/show_placement_ad.dart';
import '../core/utils/screen_utils.dart';
import '../core/utils/vip_package_helper.dart';
import '../providers/app_providers.dart';
import '../services/firebase_remote_config_service.dart';
import 'iap_subscription_footer.dart';
import 'vip_package_card.dart';

/// Full-featured VIP / Premium upsell popup shown on entering Home.
class PremiumUpgradeDialog extends ConsumerStatefulWidget {
  final int closeDelaySeconds;
  final String sourceScreen;

  const PremiumUpgradeDialog({
    super.key,
    required this.closeDelaySeconds,
    this.sourceScreen = 'home_popup',
  });

  static Future<bool> show(
    BuildContext context, {
    int? closeDelaySeconds,
    String sourceScreen = 'home_popup',
  }) async {
    final delaySec = (closeDelaySeconds ??
            FirebaseRemoteConfigService.getIntConfigByKey(
              FirebaseRemoteConfigService.time_delay_close_premium,
              defaultValue: 0,
            ))
        .clamp(0, 15);

    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'PremiumUpgrade',
      barrierColor: AppColors.overlayHeavy,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, _) => PremiumUpgradeDialog(
        closeDelaySeconds: delaySec,
        sourceScreen: sourceScreen,
      ),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  ConsumerState<PremiumUpgradeDialog> createState() =>
      _PremiumUpgradeDialogState();
}

class _PremiumUpgradeDialogState extends ConsumerState<PremiumUpgradeDialog> {
  int _selectedPlanIndex = 1; // Default: Monthly VIP
  late int _remainingCloseSec;
  Timer? _closeTimer;
  VoidCallback? _releaseOpenAdSuppression;

  @override
  void initState() {
    super.initState();
    _releaseOpenAdSuppression = suppressAppOpenAdsOnResume();
    _remainingCloseSec = widget.closeDelaySeconds;
    if (_remainingCloseSec > 0) {
      _closeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_remainingCloseSec <= 1) {
          timer.cancel();
          setState(() => _remainingCloseSec = 0);
        } else {
          setState(() => _remainingCloseSec--);
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final accState = ref.read(accountProvider);
      if ((accState.iapCatalog == null || accState.storeProducts.isEmpty) &&
          !accState.isLoadingCatalog) {
        unawaited(
          ref
              .read(accountProvider.notifier)
              .fetchIapCatalog(lang: ref.read(localeProvider).appLanguage),
        );
      }
    });
  }

  @override
  void dispose() {
    _releaseOpenAdSuppression?.call();
    _releaseOpenAdSuppression = null;
    _closeTimer?.cancel();
    super.dispose();
  }

  bool _didClose = false;

  void _closeDialog(bool purchased) {
    if (_didClose || !mounted) return;
    _didClose = true;
    if (!purchased && ref.read(accountProvider).isPurchasing) {
      ref.read(accountProvider.notifier).cancelPendingPurchase();
    }
    Navigator.of(context).pop(purchased);
  }

  Future<void> _onContinue(
    RewardVipPackage package,
    LocaleState locale,
  ) async {
    final purchased = await VipPackageHelper.purchaseSubscription(
      context: context,
      ref: ref,
      package: package,
      locale: locale,
      sourceScreen: widget.sourceScreen,
    );
    if (purchased) {
      _closeDialog(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      userWalletProvider.select((s) => s.isVip),
      (prev, isVip) {
        if (isVip && prev != true) {
          _closeDialog(true);
        }
      },
    );

    final locale = ref.watch(localeProvider);
    final accountState = ref.watch(accountProvider);
    final packages = VipPackageHelper.resolvePackages(
      catalog: accountState.iapCatalog,
      storeProducts: accountState.storeProducts,
      isLoadingCatalog: accountState.isLoadingCatalog,
      locale: locale,
    );
    final safeIdx =
        packages.isEmpty ? 0 : _selectedPlanIndex.clamp(0, packages.length - 1);
    final canTapClose = _remainingCloseSec <= 0;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result != true && ref.read(accountProvider).isPurchasing) {
          ref.read(accountProvider.notifier).cancelPendingPurchase();
        }
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 380.w),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSheet,
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBright.withValues(alpha: 0.20),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hero Header with Close Countdown
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(21.r),
                      ),
                      child: SizedBox(
                        height: 158.h,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/images/rewards_hero_banner.jpg',
                              fit: BoxFit.cover,
                              alignment: Alignment.topRight,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: AppColors.surfaceBannerFallback,
                              ),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.rewardHeroLeftScrim,
                              ),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.rewardHeroBottomScrim,
                              ),
                            ),
                            Positioned(
                              top: 10.h,
                              right: 10.w,
                              child: GestureDetector(
                                onTap: canTapClose
                                    ? () => _closeDialog(false)
                                    : null,
                                child: Container(
                                  width: 30.w,
                                  height: 30.w,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.overlayDark,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: canTapClose
                                      ? Icon(
                                          Icons.close_rounded,
                                          color: AppColors.textPrimary,
                                          size: 18.sp,
                                        )
                                      : Text(
                                          '${_remainingCloseSec}s',
                                          style: AppTextStyles.captionSmall
                                              .copyWith(
                                            color: AppColors.textWhite70,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16.w,
                              right: 46.w,
                              bottom: 14.h,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/vip_crown.png',
                                    width: 44.w,
                                    height: 44.w,
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          locale.tr('unlock_vip_title'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.h2.copyWith(
                                            color: AppColors.gold,
                                          ),
                                        ),
                                        SizedBox(height: 3.h),
                                        Text(
                                          locale.tr('vip_enjoy_benefits'),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.textWhite70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 3 VIP Feature Highlights
                          Row(
                            children: [
                              Expanded(
                                child: _PopupFeatureBadge(
                                  iconAsset:
                                      'assets/icons/ic_reward_all_content.png',
                                  title: locale.tr('reward_feat_all_title'),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: _PopupFeatureBadge(
                                  iconAsset: 'assets/icons/ic_reward_no_ads.png',
                                  title: locale.tr('reward_feat_noads_title'),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: _PopupFeatureBadge(
                                  iconAsset:
                                      'assets/icons/ic_reward_vip_exclusive.png',
                                  title: locale.tr('reward_feat_vip_title'),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 16.h),

                          // 3 Subscription Plan Cards
                          Row(
                            children: List.generate(
                              packages.length.clamp(0, 3),
                              (idx) {
                                final pkg = packages[idx];
                                final selected = idx == safeIdx;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: idx <
                                              (packages.length.clamp(0, 3) - 1)
                                          ? 8.w
                                          : 0,
                                    ),
                                    child: VipPackageCard(
                                      package: pkg,
                                      isSelected: selected,
                                      horizontalPadding: 6.w,
                                      onTap: () => setState(
                                        () => _selectedPlanIndex = idx,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          SizedBox(height: 16.h),

                          // Continue / Purchase CTA
                          GestureDetector(
                            onTap: (accountState.isPurchasing || packages.isEmpty)
                                ? null
                                : () => unawaited(
                                      _onContinue(packages[safeIdx], locale),
                                    ),
                            child: Container(
                              width: double.infinity,
                              height: 48.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(24.r),
                                border: Border.all(
                                  color: AppColors.textPrimary
                                      .withValues(alpha: 0.16),
                                  width: 0.8,
                                ),
                              ),
                              child: accountState.isPurchasing
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.textPrimary,
                                      ),
                                    )
                                  : Text(
                                      VipPackageHelper.buildSubscribeButtonLabel(
                                        packages.isEmpty
                                            ? null
                                            : packages[safeIdx],
                                        locale,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.rewardContinueBtn,
                                    ),
                            ),
                          ),

                          SizedBox(height: 12.h),

                          IapSubscriptionFooter(
                            locale: locale,
                            isPurchasing: accountState.isPurchasing,
                            selectedPackage:
                                packages.isEmpty ? null : packages[safeIdx],
                            onRestore: () => unawaited(
                              VipPackageHelper.restorePurchasesWithFeedback(
                                context: context,
                                ref: ref,
                                locale: locale,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopupFeatureBadge extends StatelessWidget {
  final String iconAsset;
  final String title;

  const _PopupFeatureBadge({
    required this.iconAsset,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.rewardPlanCardBg,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            iconAsset,
            width: 24.w,
            height: 24.w,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 5.h),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.captionSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
