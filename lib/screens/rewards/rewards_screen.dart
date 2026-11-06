import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/utils/screen_utils.dart';
import '../../models/drama_models.dart';
import '../../providers/app_providers.dart';
import '../player/drama_player_screen.dart';

/// Configuration model for the 3 VIP subscription packages on the Rewards tab.
/// Update [price] or [productId] here later when integrating real In-App Purchases.
class RewardVipPackage {
  final String productId;
  final String planKey;
  final String titleKey;
  final String price;
  final String? discountBadgeKey;

  const RewardVipPackage({
    required this.productId,
    required this.planKey,
    required this.titleKey,
    required this.price,
    this.discountBadgeKey,
  });
}

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  /// 3 VIP packages (placeholder prices — replace with real store prices/IDs later).
  static const List<RewardVipPackage> vipPackages = [
    RewardVipPackage(
      productId: 'dxx_vip_weekly',
      planKey: 'vip_weekly_name',
      titleKey: 'reward_plan_weekly',
      price: '4.99\$',
    ),
    RewardVipPackage(
      productId: 'dxx_vip_monthly',
      planKey: 'vip_monthly_name',
      titleKey: 'reward_plan_monthly',
      price: '9.99\$',
      discountBadgeKey: 'reward_save_30',
    ),
    RewardVipPackage(
      productId: 'dxx_vip_yearly',
      planKey: 'vip_annual_name',
      titleKey: 'reward_plan_yearly',
      price: '29.99\$',
    ),
  ];

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  static const String _icAllContent = 'assets/icons/ic_reward_all_content.png';
  static const String _icNoAds = 'assets/icons/ic_reward_no_ads.png';
  static const String _icVipExclusive =
      'assets/icons/ic_reward_vip_exclusive.png';

  int _selectedPlanIndex = 1; // Default selected: Monthly VIP (Save 30%)

  void _openDrama(Drama drama) {
    final lastEp =
        ref.read(watchlistProvider).getLastWatchedEpisode(drama.slug);
    showInterAllThen(context, ref, () {
      ref.read(navigationServiceProvider).push(
            context,
            DramaPlayerScreen(
              drama: drama,
              initialEpisode: lastEp,
            ),
          );
    });
  }

  void _handleContinuePurchase(LocaleState locale) {
    final pkg = RewardsScreen.vipPackages[_selectedPlanIndex];
    ref.read(userWalletProvider.notifier).subscribeVip(pkg.planKey);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${locale.tr('activated_vip_toast')}: ${locale.tr(pkg.titleKey)} (${pkg.price})',
        ),
      ),
    );
  }

  void _showAllVipDramasSheet(List<Drama> dramas, LocaleState locale) {
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

  List<Drama> _prioritizeVipDramas(List<Drama> allDramas) {
    if (allDramas.isEmpty) return const [];
    final ordered = [...allDramas];
    ordered.sort((a, b) {
      final aFeatured = a.slug.contains('fake_romance') ? 0 : 1;
      final bFeatured = b.slug.contains('fake_romance') ? 0 : 1;
      if (aFeatured != bFeatured) return aFeatured.compareTo(bFeatured);
      return b.score.compareTo(a.score);
    });
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final catalogAsync = ref.watch(catalogProvider);
    final topInset = AppScreenUtils.topSafeInset(context);
    final vipDramas = _prioritizeVipDramas(catalogAsync.asData?.value ?? []);
    final previewDramas = vipDramas.take(6).toList();

    return ColoredBox(
      color: AppColors.background,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: SingleChildScrollView(
          physics: AppScreenUtils.adaptiveScrollPhysics,
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
                        Text(
                          locale.tr('reward_hero_line1'),
                          style: AppTextStyles.rewardHeroUnlock,
                        ),
                        Text(
                          locale.tr('reward_hero_line2'),
                          style: AppTextStyles.rewardHeroHighlight,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          locale.tr('reward_hero_sub'),
                          style: AppTextStyles.rewardHeroSubtitle,
                        ),
                        SizedBox(height: 24.h),
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

              SizedBox(height: 22.h),

              // 2. 3 Selectable VIP Package Cards
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: List.generate(
                    RewardsScreen.vipPackages.length,
                    (idx) {
                      final pkg = RewardsScreen.vipPackages[idx];
                      final isSelected = idx == _selectedPlanIndex;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: idx < RewardsScreen.vipPackages.length - 1
                                ? 10.w
                                : 0,
                          ),
                          child: _VipPackageCard(
                            package: pkg,
                            locale: locale,
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

              SizedBox(height: 18.h),

              // 3. Full-Width Red Gradient "Continue" Pill CTA Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: GestureDetector(
                  onTap: () => _handleContinuePurchase(locale),
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
                    child: Text(
                      locale.tr('reward_continue_btn'),
                      style: AppTextStyles.rewardContinueBtn,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // 4. "VIP Exclusive" Header + "See All >"
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
                        onTap: () => _showAllVipDramasSheet(vipDramas, locale),
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

              // 5. 3-Column VIP Exclusive Drama Grid
              if (previewDramas.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: AppScreenUtils.posterGridColumns(context),
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
  final LocaleState locale;
  final bool isSelected;
  final VoidCallback onTap;

  const _VipPackageCard({
    required this.package,
    required this.locale,
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
                locale.tr(package.titleKey),
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
              if (package.discountBadgeKey != null)
                Container(
                  height: 21.h,
                  padding: EdgeInsets.symmetric(horizontal: 9.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Text(
                    locale.tr(package.discountBadgeKey!),
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

    // 1. Base solid dark fill (#131416)
    final basePaint = Paint()
      ..color = AppColors.rewardPlanCardBg
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRRect(outerRRect, basePaint);

    // 2. Selected Radial Gradient overlay (0% center -> #F61B29 angled ellipse edge glow)
    if (selectionProgress > 0.001) {
      final glowPaint = Paint()
        ..shader = AppColors.rewardSelectedPlanGradient.createShader(rect)
        ..color = AppColors.textPrimary.withValues(alpha: selectionProgress)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawRRect(outerRRect, glowPaint);
    }

    // 3. 1px Inner-aligned border: subtle unselected border + Figma linear gradient border
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
  final Drama drama;
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
                  Image.asset(
                    drama.posterAssetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.rewardPlanCardBg,
                    ),
                  ),
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
              locale.dramaTitle(drama),
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
