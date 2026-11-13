import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/utils/screen_utils.dart';
import '../../models/drama_card.dart';
import '../../models/iap_models.dart';
import '../../models/rewards_models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/drama_network_image.dart';
import '../player/drama_player_screen.dart';

/// Configuration model for fallback VIP subscription packages.
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

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  static const String _icAllContent = 'assets/icons/ic_reward_all_content.png';
  static const String _icNoAds = 'assets/icons/ic_reward_no_ads.png';
  static const String _icVipExclusive =
      'assets/icons/ic_reward_vip_exclusive.png';

  int _selectedPlanIndex = 1;
  bool _didLoad = false;
  List<DramaCard> _vipDramas = [];
  bool _isLoadingVipDramas = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didLoad) return;
      _didLoad = true;
      _bootstrapIfSessionReady();
    });
  }

  void _bootstrapIfSessionReady() {
    if (!ref.read(sessionProvider).isReady) return;
    unawaited(_refreshAll());
  }

  Future<void> _refreshAll() async {
    final ready = await ensureSessionForUserAction(ref);
    if (!ready || !mounted) return;
    final lang = ref.read(localeProvider).appLanguage;
    await Future.wait([
      ref.read(rewardsProvider.notifier).fetchOverview(lang),
      ref.read(accountProvider.notifier).fetchIapCatalog(lang: lang),
      _fetchVipDramas(lang),
    ]);
  }

  Future<void> _fetchVipDramas(String lang) async {
    setState(() => _isLoadingVipDramas = true);
    try {
      final res = await ref.read(homeApiServiceProvider).browseDramas(
            page: 1,
            pageSize: 18,
            isVip: 'vip',
            lang: lang,
          );
      if (!mounted) return;
      setState(() {
        _vipDramas = res.items;
        _isLoadingVipDramas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingVipDramas = false);
    }
  }

  void _openDrama(DramaCard drama) {
    final ep = (drama.continueWatching?.episodeNumber ?? 0) > 0
        ? drama.continueWatching!.episodeNumber
        : 1;
    final pos = drama.continueWatching?.positionSec ?? 0;

    ref.read(eventTrackerProvider).track(
      'drama_click',
      dramaId: drama.dramaId,
      episodeNumber: ep,
      sourceScreen: 'rewards',
    );

    showInterAllThen(context, ref, () {
      ref.read(navigationServiceProvider).push(
            context,
            DramaPlayerScreen(
              dramaCard: drama,
              dramaId: drama.dramaId,
              initialEpisode: ep,
              initialPositionSec: pos,
              sourceScreen: 'rewards',
            ),
          );
    });
  }

  List<RewardVipPackage> _resolveVipPackages(
    IapCatalog? catalog,
    LocaleState locale,
  ) {
    if (catalog != null && catalog.subscriptions.isNotEmpty) {
      return catalog.subscriptions.asMap().entries.map((e) {
        final sub = e.value;
        final priceStr =
            '${sub.price.toStringAsFixed(2)} ${sub.currency}'.trim();
        return RewardVipPackage(
          productId: sub.productId,
          planKey: sub.productId,
          title: sub.name.isNotEmpty ? sub.name : '${sub.durationDays}d VIP',
          price: priceStr,
          discountBadge: sub.features.isNotEmpty
              ? sub.features.first
              : (e.key == 1 ? locale.tr('reward_save_30') : null),
        );
      }).toList();
    }

    return [
      RewardVipPackage(
        productId: 'dxx_vip_weekly',
        planKey: 'vip_weekly_name',
        title: locale.tr('reward_plan_weekly'),
        price: '4.99\$',
      ),
      RewardVipPackage(
        productId: 'dxx_vip_monthly',
        planKey: 'vip_monthly_name',
        title: locale.tr('reward_plan_monthly'),
        price: '9.99\$',
        discountBadge: locale.tr('reward_save_30'),
      ),
      RewardVipPackage(
        productId: 'dxx_vip_yearly',
        planKey: 'vip_annual_name',
        title: locale.tr('reward_plan_yearly'),
        price: '29.99\$',
      ),
    ];
  }

  Future<void> _verifyPurchase({
    required String productId,
    required String title,
    required String priceLabel,
    required LocaleState locale,
  }) async {
    final token =
        'play_${productId}_${DateTime.now().millisecondsSinceEpoch}';
    final ok = await ref.read(accountProvider.notifier).verifyIap(
          productId: productId,
          purchaseToken: token,
        );
    if (!mounted) return;
    if (ok) {
      ref.read(eventTrackerProvider).track(
        'iap_purchase',
        sourceScreen: 'rewards',
        props: {'product_id': productId},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${locale.tr('activated_vip_toast')}: $title ($priceLabel)',
          ),
        ),
      );
    } else {
      final err = ref.read(accountProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Purchase verification pending'),
        ),
      );
    }
  }

  Future<void> _handleCheckIn({bool adBonus = false}) async {
    if (adBonus) {
      final earned = await showRewardUnlock(context, ref);
      if (!mounted) return;
      if (!earned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(localeProvider).tr('reward_ad_failed')),
          ),
        );
        return;
      }
    }
    await ref.read(rewardsProvider.notifier).checkIn(adBonus: adBonus);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ref.read(localeProvider).tr('claimed_toast')),
      ),
    );
  }

  Future<void> _handleTaskAction(RewardTask task) async {
    final locale = ref.read(localeProvider);
    if (task.isCompleted) return;

    if (task.taskCode == 'watch_ad_bonus' && !task.canClaim) {
      final earned = await showRewardUnlock(context, ref);
      if (!mounted) return;
      if (!earned) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(locale.tr('reward_ad_failed'))),
        );
        return;
      }
    } else if (!task.canClaim) {
      return;
    }

    await ref.read(rewardsProvider.notifier).claimTask(task.taskCode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(locale.tr('claimed_toast'))),
    );
  }

  void _showAllVipDramasSheet(List<DramaCard> dramas, LocaleState locale) {
    final bottomInset = AppScreenUtils.bottomSafeInset(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetCtx) {
        return Container(
          height: 0.82.sh,
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h + bottomInset),
          decoration: BoxDecoration(
            color: AppColors.surfaceSheet,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 14.h),
                  decoration: BoxDecoration(
                    color: AppColors.textWhite24,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      locale.tr('reward_vip_section'),
                      style: AppTextStyles.rewardVipSectionTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textWhite60,
                      size: 20.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: GridView.builder(
                  physics: AppScreenUtils.adaptiveScrollPhysics,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: AppScreenUtils.posterGridColumns(context),
                    crossAxisSpacing: 10.w,
                    mainAxisSpacing: 14.h,
                    childAspectRatio: 0.61,
                  ),
                  itemCount: dramas.length,
                  itemBuilder: (ctx, idx) {
                    final drama = dramas[idx];
                    return _VipDramaPosterCard(
                      drama: drama,
                      locale: locale,
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _openDrama(drama);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final wallet = ref.watch(walletProvider);
    final rewardsAsync = ref.watch(rewardsProvider);

    ref.listen<AsyncValue<SessionState>>(sessionProvider, (prev, next) {
      if (!(prev?.isReady ?? false) && next.isReady) {
        unawaited(_refreshAll());
      }
    });
    final accountState = ref.watch(accountProvider);
    final homeVip =
        ref.watch(homeProvider).asData?.value.homeData?.vipExclusive ??
            const <DramaCard>[];

    final rewardsState = rewardsAsync.asData?.value;
    final overview = rewardsState?.overview;
    final vipPackages =
        _resolveVipPackages(accountState.iapCatalog, locale);
    final safePlanIdx =
        _selectedPlanIndex.clamp(0, vipPackages.length - 1);
    final coinPacks = accountState.iapCatalog?.coinPackages ?? const [];

    final vipDramas = _vipDramas.isNotEmpty ? _vipDramas : homeVip;
    final previewDramas = vipDramas.take(6).toList();
    final topInset = AppScreenUtils.topSafeInset(context);

    return ColoredBox(
      color: AppColors.background,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(
              parent: AppScreenUtils.adaptiveScrollPhysics,
            ),
            padding: EdgeInsets.only(bottom: 28.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Full-Bleed Hero Artwork + Headline + 3 VIP Feature Icons
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: topInset + 224.h,
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
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16.w,
                        topInset + 26.h,
                        16.w,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      locale.tr('reward_hero_line1'),
                                      style: AppTextStyles.rewardHeroUnlock,
                                    ),
                                    Text(
                                      locale.tr('reward_hero_line2'),
                                      style: AppTextStyles.rewardHeroHighlight,
                                    ),
                                  ],
                                ),
                              ),
                              // Wallet Coins Pill
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.overlayDark,
                                  borderRadius: BorderRadius.circular(18.r),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.monetization_on_rounded,
                                      color: AppColors.gold,
                                      size: 16.sp,
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      '${wallet.totalCoins}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            wallet.isVip
                                ? locale.tr('vip_activated_title')
                                : locale.tr('reward_hero_sub'),
                            style: AppTextStyles.rewardHeroSubtitle,
                          ),
                          SizedBox(height: 22.h),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _VipFeatureItem(
                                  title: locale.tr('reward_feat_all_title'),
                                  subtitle: locale.tr('reward_feat_all_desc'),
                                  iconAsset: _icAllContent,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _VipFeatureItem(
                                  title: locale.tr('reward_feat_noads_title'),
                                  subtitle: locale.tr('reward_feat_noads_desc'),
                                  iconAsset: _icNoAds,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _VipFeatureItem(
                                  title: locale.tr('reward_feat_vip_title'),
                                  subtitle: locale.tr('reward_feat_vip_desc'),
                                  iconAsset: _icVipExclusive,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),

                // 2. VIP Subscription Package Cards
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: List.generate(
                      vipPackages.length.clamp(0, 3),
                      (idx) {
                        final pkg = vipPackages[idx];
                        final isSelected = idx == safePlanIdx;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: idx <
                                      (vipPackages.length.clamp(0, 3) - 1)
                                  ? 10.w
                                  : 0,
                            ),
                            child: _VipPackageCard(
                              package: pkg,
                              isSelected: isSelected,
                              onTap: () =>
                                  setState(() => _selectedPlanIndex = idx),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // 3. Full-Width Red Gradient "Continue" CTA
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: GestureDetector(
                    onTap: accountState.isPurchasing
                        ? null
                        : () {
                            final pkg = vipPackages[safePlanIdx];
                            unawaited(
                              _verifyPurchase(
                                productId: pkg.productId,
                                title: pkg.title,
                                priceLabel: pkg.price,
                                locale: locale,
                              ),
                            );
                          },
                    child: Container(
                      width: double.infinity,
                      height: 50.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(26.r),
                        border: Border.all(
                          color: AppColors.textPrimary.withValues(alpha: 0.16),
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
                              locale.tr('reward_continue_btn'),
                              style: AppTextStyles.rewardContinueBtn,
                            ),
                    ),
                  ),
                ),

                // 4. Coin Packages Section (if IAP catalog loaded)
                if (coinPacks.isNotEmpty) ...[
                  SizedBox(height: 22.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      locale.tr('coin_packs_title'),
                      style: AppTextStyles.rewardVipSectionTitle,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    height: 106.h,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      scrollDirection: Axis.horizontal,
                      physics: AppScreenUtils.adaptiveScrollPhysics,
                      itemCount: coinPacks.length,
                      separatorBuilder: (_, _) => SizedBox(width: 10.w),
                      itemBuilder: (context, idx) {
                        final cp = coinPacks[idx];
                        return _CoinPackageTile(
                          pack: cp,
                          onTap: () => unawaited(
                            _verifyPurchase(
                              productId: cp.productId,
                              title: cp.name,
                              priceLabel: '${cp.price} ${cp.currency}',
                              locale: locale,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // 5. Daily 7-Day Check-In Streak (Group F)
                if (overview != null) ...[
                  SizedBox(height: 24.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: _DailyCheckInCard(
                      schedule: overview.checkin,
                      isCheckingIn: rewardsState?.isCheckingIn ?? false,
                      locale: locale,
                      onCheckIn: () => _handleCheckIn(adBonus: false),
                      onCheckInAdBonus: () => _handleCheckIn(adBonus: true),
                    ),
                  ),
                ],

                // 6. Daily Bonus Tasks (Group F)
                if (overview != null && overview.tasks.isNotEmpty) ...[
                  SizedBox(height: 22.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      locale.tr('free_tasks_title'),
                      style: AppTextStyles.rewardVipSectionTitle,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: overview.tasks.map((task) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: _RewardTaskTile(
                            task: task,
                            isClaiming: rewardsState?.isClaimingTask ?? false,
                            locale: locale,
                            onTap: () => unawaited(_handleTaskAction(task)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                SizedBox(height: 22.h),

                // 7. "VIP Exclusive" Header + "See All >"
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        locale.tr('reward_vip_section'),
                        style: AppTextStyles.rewardVipSectionTitle,
                      ),
                      if (vipDramas.isNotEmpty)
                        GestureDetector(
                          onTap: () =>
                              _showAllVipDramasSheet(vipDramas, locale),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                locale.tr('see_all'),
                                style: AppTextStyles.seeAll,
                              ),
                              SizedBox(width: 2.w),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textMuted,
                                size: 18.sp,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(height: 12.h),

                // 8. 3-Column VIP Exclusive Drama Grid
                if (_isLoadingVipDramas && previewDramas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: CircularProgressIndicator.adaptive(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBright,
                        ),
                      ),
                    ),
                  )
                else if (previewDramas.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            AppScreenUtils.posterGridColumns(context),
                        crossAxisSpacing: 10.w,
                        mainAxisSpacing: 14.h,
                        childAspectRatio: 0.61,
                      ),
                      itemCount: previewDramas.length,
                      itemBuilder: (context, idx) {
                        final drama = previewDramas[idx];
                        return _VipDramaPosterCard(
                          drama: drama,
                          locale: locale,
                          onTap: () => _openDrama(drama),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinPackageTile extends StatelessWidget {
  final CoinPackage pack;
  final VoidCallback onTap;

  const _CoinPackageTile({required this.pack, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 118.w,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: AppColors.rewardPlanCardBg,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: pack.isPopular ? AppColors.primary : AppColors.borderSubtle,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on_rounded,
                    color: AppColors.gold, size: 16.sp),
                SizedBox(width: 4.w),
                Text(
                  '${pack.coins}',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gold),
                ),
              ],
            ),
            if (pack.bonusCoins > 0) ...[
              SizedBox(height: 2.h),
              Text(
                '+${pack.bonusCoins} Bonus',
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.primaryBright,
                ),
              ),
            ],
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                '${pack.price.toStringAsFixed(2)} ${pack.currency}'.trim(),
                style: AppTextStyles.captionSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyCheckInCard extends StatelessWidget {
  final CheckInSchedule schedule;
  final bool isCheckingIn;
  final LocaleState locale;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckInAdBonus;

  const _DailyCheckInCard({
    required this.schedule,
    required this.isCheckingIn,
    required this.locale,
    required this.onCheckIn,
    required this.onCheckInAdBonus,
  });

  @override
  Widget build(BuildContext context) {
    final days = schedule.schedule;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.rewardPlanCardBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  color: AppColors.gold, size: 20.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  locale.tr('daily_checkin'),
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '${locale.tr('streak_label')}: ${schedule.streak} ${locale.tr('days_label')}',
                  style: AppTextStyles.captionSmall.copyWith(
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          if (days.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Row(
              children: days.take(7).map((d) {
                final active = d.isToday && !d.isClaimed;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 2.5.w),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    decoration: BoxDecoration(
                      color: d.isClaimed
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : (active
                              ? AppColors.gold.withValues(alpha: 0.16)
                              : AppColors.searchBarBg),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: active
                            ? AppColors.gold
                            : (d.isClaimed
                                ? AppColors.primary
                                : AppColors.borderSubtle),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${locale.tr('day_short')}${d.day}',
                          style: AppTextStyles.captionSmall,
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          '+${d.reward}',
                          style: AppTextStyles.captionSmall.copyWith(
                            color: d.isClaimed
                                ? AppColors.primaryBright
                                : AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (!schedule.canCheckinToday || isCheckingIn)
                      ? null
                      : onCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                  child: Text(
                    schedule.canCheckinToday
                        ? locale.tr('checkin_now')
                        : locale.tr('checked_in'),
                    style: AppTextStyles.buttonMedium,
                  ),
                ),
              ),
              if (schedule.canCheckinToday) ...[
                SizedBox(width: 8.w),
                OutlinedButton.icon(
                  onPressed: isCheckingIn ? null : onCheckInAdBonus,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                  icon: Icon(Icons.ondemand_video_rounded, size: 16.sp),
                  label: Text('2x', style: AppTextStyles.buttonMedium),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardTaskTile extends StatelessWidget {
  final RewardTask task;
  final bool isClaiming;
  final LocaleState locale;
  final VoidCallback onTap;

  const _RewardTaskTile({
    required this.task,
    required this.isClaiming,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canAct = !task.isCompleted &&
        (task.canClaim || task.taskCode == 'watch_ad_bonus');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.profileTileBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              '+${task.rewardCoins}',
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (task.description.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    task.description,
                    style: AppTextStyles.captionSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (task.target > 1) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '${task.progress}/${task.target}',
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textWhite54,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: (!canAct || isClaiming) ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: task.isCompleted
                  ? AppColors.borderSubtle
                  : (canAct ? AppColors.primary : AppColors.searchBarBg),
              foregroundColor: AppColors.textPrimary,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Text(
              task.isCompleted
                  ? locale.tr('claimed_btn')
                  : (task.canClaim
                      ? locale.tr('claim_btn')
                      : (task.taskCode == 'watch_ad_bonus'
                          ? locale.tr('watch_now')
                          : '${task.progress}/${task.target}')),
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipFeatureItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconAsset;

  const _VipFeatureItem({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Image.asset(
              iconAsset,
              width: 42.w,
              height: 38.w,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.rewardFeatureTitle,
        ),
        SizedBox(height: 4.h),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.rewardFeatureDesc,
        ),
      ],
    );
  }
}

class _VipPackageCard extends StatelessWidget {
  final RewardVipPackage package;
  final bool isSelected;
  final VoidCallback onTap;

  const _VipPackageCard({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = 8.r;
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: isSelected ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, selectionProgress, child) {
          return CustomPaint(
            painter: _VipPlanCardPainter(
              selectionProgress: selectionProgress,
              radius: radius,
            ),
            child: child,
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 14.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                package.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.rewardPlanTitle,
              ),
              SizedBox(height: 10.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  package.price,
                  style: AppTextStyles.rewardPlanPrice(isSelected: isSelected),
                ),
              ),
              SizedBox(height: 8.h),
              if (package.discountBadge != null)
                Container(
                  height: 21.h,
                  padding: EdgeInsets.symmetric(horizontal: 9.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Text(
                    package.discountBadge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.rewardSaveBadge,
                  ),
                )
              else
                SizedBox(height: 21.h),
              SizedBox(height: 12.h),
              Container(
                width: 20.w,
                height: 20.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.rewardPlanRadioInactive,
                    width: isSelected ? 1.8 : 1.4,
                  ),
                ),
                child: isSelected
                    ? Container(
                        width: 11.w,
                        height: 11.w,
                        decoration: const BoxDecoration(
                          color: AppColors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VipPlanCardPainter extends CustomPainter {
  final double selectionProgress;
  final double radius;

  const _VipPlanCardPainter({
    required this.selectionProgress,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outerRRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final basePaint = Paint()
      ..color = AppColors.rewardPlanCardBg
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRRect(outerRRect, basePaint);

    if (selectionProgress > 0.001) {
      final glowPaint = Paint()
        ..shader = AppColors.rewardSelectedPlanGradient.createShader(rect)
        ..color = AppColors.textPrimary.withValues(alpha: selectionProgress)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawRRect(outerRRect, glowPaint);
    }

    final innerRect = rect.deflate(0.5);
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular((radius - 0.5).clamp(0.0, radius)),
    );

    if (selectionProgress < 0.999) {
      final unselectedBorderPaint = Paint()
        ..color = AppColors.borderSubtle.withValues(
          alpha: AppColors.borderSubtle.a * (1.0 - selectionProgress),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true;
      canvas.drawRRect(innerRRect, unselectedBorderPaint);
    }

    if (selectionProgress > 0.001) {
      final selectedBorderPaint = Paint()
        ..shader = AppColors.rewardSelectedPlanBorderGradient.createShader(rect)
        ..color = AppColors.textPrimary.withValues(alpha: selectionProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true;
      canvas.drawRRect(innerRRect, selectedBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VipPlanCardPainter oldDelegate) {
    return oldDelegate.selectionProgress != selectionProgress ||
        oldDelegate.radius != radius;
  }
}

class _VipDramaPosterCard extends StatelessWidget {
  final DramaCard drama;
  final LocaleState locale;
  final VoidCallback onTap;

  const _VipDramaPosterCard({
    required this.drama,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.rewardPlanCardBg,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DramaNetworkImage(imageUrl: drama.coverUrl, fit: BoxFit.cover),
                  Positioned(
                    top: 6.h,
                    right: 6.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.vipPosterBadgeGradient,
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      child: Text(
                        locale.tr('tab_vip'),
                        style: AppTextStyles.rewardVipBadgeText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            height: 31.h,
            child: Text(
              drama.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.posterTitle,
            ),
          ),
        ],
      ),
    );
  }
}
