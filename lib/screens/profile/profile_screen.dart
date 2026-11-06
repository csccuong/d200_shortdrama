import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/screen_utils.dart';
import '../../fo/language/language_activity.dart';
import '../../providers/app_providers.dart';
import '../../widgets/bottom_native_all_ad.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const String _imgGuest = 'assets/images/img_guest.png';
  static const String _icLanguage = 'assets/icons/ic_language.png';
  static const String _icRateApp = 'assets/icons/ic_rateapp.png';
  static const String _icTerms = 'assets/icons/ic_terms.png';
  static const String _icPolicy = 'assets/icons/ic_policy.png';

  void _copyGuestId(BuildContext context, LocaleState locale, String guestId) {
    Clipboard.setData(ClipboardData(text: guestId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${locale.tr('id_copied_toast')}: $guestId'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showRateAppDialog(BuildContext context, LocaleState locale) {
    int selectedStars = 5;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: AppColors.surfaceSheet,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18.r),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              _icRateApp,
                              width: 22.w,
                              height: 22.w,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              locale.tr('menu_rate_app'),
                              style: AppTextStyles.h3,
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(dialogCtx),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.textMuted,
                            size: 20.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      locale.tr('rate_dialog_desc'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall,
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (idx) {
                        final filled = idx < selectedStars;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedStars = idx + 1),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5.w),
                            child: Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppColors.gold,
                              size: 34.sp,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 20.h),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(locale.tr('rate_thanks_toast')),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 42.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(22.r),
                        ),
                        child: Text(
                          locale.tr('rate_submit_btn'),
                          style: AppTextStyles.exploreButtonText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLegalSheet(
    BuildContext context, {
    required String title,
    required String content,
    required String iconAsset,
  }) {
    final bottomInset = AppScreenUtils.bottomSafeInset(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(maxHeight: 0.72.sh),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h + bottomInset),
          decoration: BoxDecoration(
            color: AppColors.surfaceSheet,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  Image.asset(
                    iconAsset,
                    width: 22.w,
                    height: 22.w,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(title, style: AppTextStyles.h3),
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
              Divider(color: AppColors.borderLight, height: 16.h),
              Flexible(
                child: SingleChildScrollView(
                  physics: AppScreenUtils.adaptiveScrollPhysics,
                  child: Text(
                    content,
                    style: AppTextStyles.bodyRegular.copyWith(height: 1.55),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final wallet = ref.watch(userWalletProvider);
    final guest = ref.watch(guestIdentityProvider);

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
          physics: AppScreenUtils.adaptiveScrollPhysics,
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
          children: [
            // 1. Top "Profile" Header
            Text(
              locale.tr('nav_profile'),
              style: AppTextStyles.h1,
            ),

            SizedBox(height: 22.h),

            // 2. Guest Avatar + Guest Name & Copyable ID
            Row(
              children: [
                Image.asset(
                  _imgGuest,
                  width: 72.w,
                  height: 72.w,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${locale.tr('guest_prefix')}_${guest.guestNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.profileGuestName,
                      ),
                      SizedBox(height: 6.h),
                      GestureDetector(
                        onTap: () =>
                            _copyGuestId(context, locale, guest.guestId),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${locale.tr('id_label')}: ${guest.guestId}',
                              style: AppTextStyles.profileIdLabel,
                            ),
                            SizedBox(width: 8.w),
                            Icon(
                              Icons.bookmarks_outlined,
                              color: AppColors.profileIdText,
                              size: 16.sp,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 22.h),

            // 3. Golden "Unlock VIP" Banner Card
            GestureDetector(
              onTap: () => ref.read(shellTabIndexProvider.notifier).setTab(3),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                decoration: BoxDecoration(
                  gradient: AppColors.profileVipGoldGradient,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    Transform.rotate(
                      angle: -0.14,
                      child: Image.asset(
                        'assets/images/vip_crown.png',
                        width: 50.w,
                        height: 50.w,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wallet.isVip
                                ? locale.tr('vip_activated_title')
                                : locale.tr('unlock_vip_title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.vipBannerTitle,
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            locale.tr('vip_enjoy_benefits'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.vipBannerSubtitle,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      height: 38.h,
                      padding: EdgeInsets.symmetric(horizontal: 22.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.vipActivateBtnBg,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        wallet.isVip
                            ? locale.tr('plan_active')
                            : locale.tr('activate_btn'),
                        style: AppTextStyles.vipActivateButton,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 18.h),

            // 4. Individual Rounded Menu Items
            _ProfileMenuTile(
              iconAsset: _icLanguage,
              title: locale.tr('menu_language'),
              onTap: () => ref
                  .read(navigationServiceProvider)
                  .push(context, const LanguageActivity(isFirstLaunch: false)),
            ),
            SizedBox(height: 12.h),
            _ProfileMenuTile(
              iconAsset: _icRateApp,
              title: locale.tr('menu_rate_app'),
              onTap: () => _showRateAppDialog(context, locale),
            ),
            SizedBox(height: 12.h),
            _ProfileMenuTile(
              iconAsset: _icTerms,
              title: locale.tr('menu_terms'),
              onTap: () => _showLegalSheet(
                context,
                title: locale.tr('menu_terms'),
                content: locale.tr('terms_content'),
                iconAsset: _icTerms,
              ),
            ),
            SizedBox(height: 12.h),
            _ProfileMenuTile(
              iconAsset: _icPolicy,
              title: locale.tr('menu_privacy'),
              onTap: () => _showLegalSheet(
                context,
                title: locale.tr('menu_privacy'),
                content: locale.tr('privacy_content'),
                iconAsset: _icPolicy,
              ),
            ),
          ],
              ),
            ),
            const BottomNativeAllAd(tabIndex: 4),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final String iconAsset;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.iconAsset,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.profileTileBg,
      borderRadius: BorderRadius.circular(12.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            children: [
              Image.asset(
                iconAsset,
                width: 22.w,
                height: 22.w,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.profileMenuTitle,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.profileChevron,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
