import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/screen_utils.dart';
import '../../core/utils/vip_package_helper.dart';
import '../../fo/language/language_activity.dart';
import '../../models/promo_feedback_models.dart';
import '../../providers/app_providers.dart';
import '../../services/api/app_api_service.dart';
import '../../widgets/bottom_native_all_ad.dart';
import '../../widgets/drama_network_image.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const String _imgGuest = 'assets/images/img_guest.png';
  static const String _icLanguage = 'assets/icons/ic_language.png';
  static const String _icRateApp = 'assets/icons/ic_rateapp.png';
  static const String _icTerms = 'assets/icons/ic_terms.png';
  static const String _icPolicy = 'assets/icons/ic_policy.png';

  void _copyGuestId(BuildContext context, LocaleState locale, String guestId) {
    Clipboard.setData(ClipboardData(text: guestId));
    AppToast.show(context, '${locale.tr('id_copied_toast')}: $guestId');
  }

  Future<void> _openRateApp(
    BuildContext context,
    WidgetRef ref,
    LocaleState locale,
  ) async {
    final initData = ref.read(sessionProvider).asData?.value.initData;
    final configuredStoreUrl = initData?.versionGate.storeUrl.trim() ?? '';
    if (configuredStoreUrl.isNotEmpty) {
      final uri = Uri.tryParse(configuredStoreUrl);
      if (uri != null &&
          await _tryLaunch(uri, const [LaunchMode.externalApplication])) {
        return;
      }
    }

    final pkgFromInit = initData?.app.packageName.trim() ?? '';
    final pkg = pkgFromInit.isNotEmpty
        ? pkgFromInit
        : AppConstants.resolvedPackageId;

    if (!kIsWeb && Platform.isAndroid) {
      final marketUri = Uri.parse('market://details?id=$pkg');
      final webStoreUri =
          Uri.parse('https://play.google.com/store/apps/details?id=$pkg');
      if (await _tryLaunch(marketUri, const [LaunchMode.externalApplication]) ||
          await _tryLaunch(
            webStoreUri,
            const [LaunchMode.externalApplication, LaunchMode.inAppBrowserView],
          )) {
        return;
      }
      try {
        await InAppReview.instance.openStoreListing();
        return;
      } catch (e) {
        debugPrint('Android openStoreListing failed: $e');
      }
    } else if (!kIsWeb && Platform.isIOS) {
      try {
        if (await InAppReview.instance.isAvailable()) {
          await InAppReview.instance.requestReview();
          return;
        }
      } catch (e) {
        debugPrint('iOS requestReview failed: $e');
      }
    }

    if (context.mounted) {
      AppToast.show(context, locale.tr('generic_error_toast'));
    }
  }

  Future<bool> _tryLaunch(Uri uri, List<LaunchMode> modes) async {
    for (final mode in modes) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } catch (e) {
        debugPrint('Launch URL ($uri, $mode) failed: $e');
      }
    }
    return false;
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

  Future<void> _openLegalDocument(
    BuildContext context, {
    required String url,
    required String title,
    required String fallbackContent,
    required String iconAsset,
  }) async {
    final uri = Uri.parse(url);
    if (await _tryLaunch(
      uri,
      const [LaunchMode.inAppBrowserView, LaunchMode.externalApplication],
    )) {
      return;
    }
    if (!context.mounted) return;
    _showLegalSheet(
      context,
      title: title,
      content: fallbackContent,
      iconAsset: iconAsset,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final legacyWallet = ref.watch(userWalletProvider);
    final wallet = ref.watch(walletProvider);
    final profile = ref.watch(accountProvider).profile;
    final guest = ref.watch(guestIdentityProvider);
    final isVip =
        wallet.isVip || (profile?.isVip ?? false) || legacyWallet.isVip;

    final uid = (profile != null && profile.userUid.isNotEmpty)
        ? profile.userUid
        : guest.guestId;
    final displayName = (profile?.displayName != null &&
            profile!.displayName!.trim().isNotEmpty)
        ? profile.displayName!.trim()
        : (profile?.email?.isNotEmpty == true
            ? profile!.email!
            : '${locale.tr('guest_prefix')}_${guest.guestNumber}');

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

                  // 2. Guest / User Avatar + Display Name & Copyable ID
                  Row(
                    children: [
                      if (profile?.avatarUrl != null &&
                          profile!.avatarUrl!.trim().isNotEmpty)
                        ClipOval(
                          child: DramaNetworkImage(
                            imageUrl: profile.avatarUrl!,
                            width: 72.w,
                            height: 72.w,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
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
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.profileGuestName,
                            ),
                            SizedBox(height: 6.h),
                            GestureDetector(
                              onTap: () => _copyGuestId(context, locale, uid),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${locale.tr('id_label')}: $uid',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.profileIdLabel,
                                    ),
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
                    onTap: () =>
                        ref.read(shellTabIndexProvider.notifier).setTab(3),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
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
                              width: 44.w,
                              height: 44.w,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isVip
                                      ? locale.tr('vip_activated_title')
                                      : locale.tr('unlock_vip_title'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.vipBannerTitle,
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  locale.tr('vip_enjoy_benefits'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.vipBannerSubtitle,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            height: 34.h,
                            padding: EdgeInsets.symmetric(horizontal: 18.w),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.vipActivateBtnBg,
                              borderRadius: BorderRadius.circular(18.r),
                            ),
                            child: Text(
                              isVip
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
                    key: const ValueKey('profile_promotion_code_tile'),
                    leading: Container(
                      width: 26.w,
                      height: 26.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.gold.withValues(alpha: 0.28),
                            AppColors.primaryBright.withValues(alpha: 0.24),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.55),
                          width: 0.9,
                        ),
                      ),
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.gold,
                            AppColors.secondaryOrange,
                            AppColors.primaryBright,
                          ],
                        ).createShader(bounds),
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          size: 17.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: locale.tr('menu_promotion_code'),
                    onTap: () =>
                        _showPromotionCodeSheet(context, ref, locale),
                  ),
                  SizedBox(height: 12.h),
                  _ProfileMenuTile(
                    iconAsset: _icLanguage,
                    title: locale.tr('menu_language'),
                    onTap: () => ref.read(navigationServiceProvider).push(
                          context,
                          const LanguageActivity(isFirstLaunch: false),
                        ),
                  ),
                  SizedBox(height: 12.h),
                  _ProfileMenuTile(
                    iconAsset: _icRateApp,
                    title: locale.tr('menu_rate_app'),
                    onTap: () => unawaited(_openRateApp(context, ref, locale)),
                  ),
                  SizedBox(height: 12.h),
                  _ProfileMenuTile(
                    key: const ValueKey('profile_feedback_tile'),
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: AppColors.primaryBright,
                    title: locale.tr('menu_feedback'),
                    onTap: () => _showFeedbackSheet(context, ref, locale),
                  ),
                  SizedBox(height: 12.h),
                  _ProfileMenuTile(
                    iconAsset: _icTerms,
                    title: locale.tr('menu_terms'),
                    onTap: () => unawaited(
                      _openLegalDocument(
                        context,
                        url: AppConstants.termsOfServiceUrl,
                        title: locale.tr('menu_terms'),
                        fallbackContent: locale.tr('terms_content'),
                        iconAsset: _icTerms,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _ProfileMenuTile(
                    iconAsset: _icPolicy,
                    title: locale.tr('menu_privacy'),
                    onTap: () => unawaited(
                      _openLegalDocument(
                        context,
                        url: AppConstants.privacyPolicyUrl,
                        title: locale.tr('menu_privacy'),
                        fallbackContent: locale.tr('privacy_content'),
                        iconAsset: _icPolicy,
                      ),
                    ),
                  ),
                  if (isVip) ...[
                    SizedBox(height: 12.h),
                    _ProfileMenuTile(
                      icon: Icons.subscriptions_outlined,
                      title: locale.tr('menu_manage_subscription'),
                      onTap: () => _showManageSubscriptionSheet(
                        context,
                        ref,
                        locale,
                        isVip: isVip,
                        vipSubtitle: locale.tr('vip_enjoy_benefits'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const BottomNativeAllAd(tabIndex: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _openStoreSubscriptions(
    BuildContext context,
    WidgetRef ref,
    LocaleState locale,
  ) async {
    final initPkg =
        ref.read(sessionProvider).asData?.value.initData?.app.packageName.trim() ??
            '';
    final pkg = initPkg.isNotEmpty ? initPkg : AppConstants.resolvedPackageId;

    final uris = (!kIsWeb && Platform.isIOS)
        ? <Uri>[Uri.parse('https://apps.apple.com/account/subscriptions')]
        : <Uri>[
            if (pkg.isNotEmpty)
              Uri.parse(
                'https://play.google.com/store/account/subscriptions?package=$pkg',
              ),
            Uri.parse('https://play.google.com/store/account/subscriptions'),
          ];

    final releaseAdGuard = suppressAppOpenAdsOnResume(excludeNextResume: true);
    try {
      for (final uri in uris) {
        if (await _tryLaunch(uri, const [LaunchMode.externalApplication])) {
          return;
        }
      }
    } finally {
      releaseAdGuard();
    }

    if (context.mounted) {
      AppToast.show(context, locale.tr('generic_error_toast'));
    }
  }

  void _showPromotionCodeSheet(
    BuildContext context,
    WidgetRef ref,
    LocaleState locale,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _TextSubmitSheet(
        sheetKey: const ValueKey('promo_code_sheet'),
        inputKey: const ValueKey('promo_code_input'),
        submitKey: const ValueKey('promo_code_submit_btn'),
        icon: Icons.card_giftcard_rounded,
        iconColor: AppColors.gold,
        title: locale.tr('promo_code_title'),
        description: locale.tr('promo_code_desc'),
        hintText: locale.tr('promo_code_hint'),
        submitLabel: locale.tr('promo_apply_btn'),
        emptyErrorMessage: locale.tr('promo_empty_error'),
        maxLines: 1,
        onSubmit: (rawText) async {
          final ready = await ensureSessionForUserAction(ref);
          if (!ready) {
            return (
              closeSheet: false,
              inlineError: locale.tr('generic_error_toast'),
              toastMessage: null,
            );
          }
          try {
            final PromoFeedbackResult res = await ref
                .read(accountProvider.notifier)
                .redeemPromoCode(rawText);
            return (
              closeSheet: true,
              inlineError: null,
              toastMessage: res.message.isNotEmpty
                  ? res.message
                  : locale.tr('vip_activated_title'),
            );
          } on PromoRedeemException catch (e) {
            return (
              closeSheet: false,
              inlineError: e.message.isNotEmpty
                  ? e.message
                  : locale.tr('promo_invalid_code'),
              toastMessage: null,
            );
          } catch (_) {
            return (
              closeSheet: false,
              inlineError: locale.tr('generic_error_toast'),
              toastMessage: null,
            );
          }
        },
      ),
    );
  }

  void _showFeedbackSheet(
    BuildContext context,
    WidgetRef ref,
    LocaleState locale,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _TextSubmitSheet(
        sheetKey: const ValueKey('feedback_sheet'),
        inputKey: const ValueKey('feedback_input'),
        submitKey: const ValueKey('feedback_submit_btn'),
        icon: Icons.chat_bubble_outline_rounded,
        iconColor: AppColors.primaryBright,
        title: locale.tr('feedback_title'),
        description: locale.tr('feedback_desc'),
        hintText: locale.tr('feedback_hint'),
        submitLabel: locale.tr('feedback_submit_btn'),
        emptyErrorMessage: locale.tr('feedback_empty_error'),
        maxLines: 4,
        onSubmit: (rawText) async {
          final ready = await ensureSessionForUserAction(ref);
          if (!ready) {
            return (
              closeSheet: false,
              inlineError: locale.tr('generic_error_toast'),
              toastMessage: null,
            );
          }
          try {
            final PromoFeedbackResult res = await ref
                .read(accountProvider.notifier)
                .submitFeedback(rawText);
            final fallbackToast = res.vipActivated
                ? locale.tr('vip_activated_title')
                : locale.tr('feedback_thanks_toast');
            return (
              closeSheet: true,
              inlineError: null,
              toastMessage:
                  res.message.isNotEmpty ? res.message : fallbackToast,
            );
          } catch (_) {
            return (
              closeSheet: false,
              inlineError: locale.tr('generic_error_toast'),
              toastMessage: null,
            );
          }
        },
      ),
    );
  }

  void _showManageSubscriptionSheet(
    BuildContext context,
    WidgetRef ref,
    LocaleState locale, {
    required bool isVip,
    required String vipSubtitle,
  }) {
    final bottomInset = AppScreenUtils.bottomSafeInset(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetCtx) {
        return Container(
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
                    'assets/images/vip_crown.png',
                    width: 28.w,
                    height: 28.w,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      locale.tr('menu_manage_subscription'),
                      style: AppTextStyles.h3,
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
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.profileTileBg,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isVip
                        ? AppColors.gold.withValues(alpha: 0.45)
                        : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVip
                                ? locale.tr('vip_activated_title')
                                : locale.tr('free_badge'),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isVip
                                  ? AppColors.gold
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            vipSubtitle,
                            style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.textWhite60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isVip)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.vipActivateBtnBg,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          locale.tr('plan_active'),
                          style: AppTextStyles.vipActivateButton,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                locale.tr('manage_sub_desc'),
                style: AppTextStyles.bodyRegular.copyWith(
                  color: AppColors.textWhite70,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 18.h),
              GestureDetector(
                onTap: () {
                  Navigator.pop(sheetCtx);
                  unawaited(_openStoreSubscriptions(context, ref, locale));
                },
                child: Container(
                  width: double.infinity,
                  height: 48.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Text(
                    locale.tr('manage_sub_open_store'),
                    style: AppTextStyles.rewardContinueBtn,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    unawaited(
                      VipPackageHelper.restorePurchasesWithFeedback(
                        context: context,
                        ref: ref,
                        locale: locale,
                      ),
                    );
                  },
                  child: Text(
                    locale.tr('iap_restore_purchases'),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textWhite70,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final String? iconAsset;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    super.key,
    this.iconAsset,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    required this.onTap,
  }) : assert(iconAsset != null || icon != null || leading != null);

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
              if (leading != null)
                leading!
              else if (iconAsset != null)
                Image.asset(
                  iconAsset!,
                  width: 22.w,
                  height: 22.w,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                )
              else
                Icon(
                  icon,
                  color: iconColor ?? AppColors.textPrimary,
                  size: 22.sp,
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

typedef _SheetSubmitOutcome = ({
  bool closeSheet,
  String? inlineError,
  String? toastMessage,
});

class _TextSubmitSheet extends StatefulWidget {
  final Key? sheetKey;
  final Key? inputKey;
  final Key? submitKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String hintText;
  final String submitLabel;
  final String emptyErrorMessage;
  final int maxLines;
  final Future<_SheetSubmitOutcome> Function(String trimmedText) onSubmit;

  const _TextSubmitSheet({
    this.sheetKey,
    this.inputKey,
    this.submitKey,
    required this.icon,
    this.iconColor = AppColors.gold,
    required this.title,
    required this.description,
    required this.hintText,
    required this.submitLabel,
    required this.emptyErrorMessage,
    required this.maxLines,
    required this.onSubmit,
  });

  @override
  State<_TextSubmitSheet> createState() => _TextSubmitSheetState();
}

class _TextSubmitSheetState extends State<_TextSubmitSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _inlineError = widget.emptyErrorMessage);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    final outcome = await widget.onSubmit(trimmed);
    if (!mounted) return;

    if (outcome.closeSheet) {
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      final toastCtx = rootNavigator.overlay?.context ?? rootNavigator.context;
      final toastMsg = outcome.toastMessage;
      Navigator.of(context).pop();
      if (toastMsg != null && toastMsg.isNotEmpty && toastCtx.mounted) {
        AppToast.show(toastCtx, toastMsg);
      }
      return;
    }

    setState(() {
      _isSubmitting = false;
      _inlineError = outcome.inlineError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = AppScreenUtils.bottomSafeInset(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      key: widget.sheetKey,
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        20.h + bottomInset + keyboardInset,
      ),
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
              Icon(widget.icon, color: widget.iconColor, size: 22.sp),
              SizedBox(width: 10.w),
              Expanded(child: Text(widget.title, style: AppTextStyles.h3)),
              IconButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.textWhite60,
                  size: 20.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            widget.description,
            style: AppTextStyles.caption.copyWith(color: AppColors.textWhite70),
          ),
          SizedBox(height: 14.h),
          TextField(
            key: widget.inputKey,
            controller: _controller,
            enabled: !_isSubmitting,
            maxLines: widget.maxLines,
            minLines: widget.maxLines > 1 ? 3 : 1,
            textInputAction: widget.maxLines == 1
                ? TextInputAction.done
                : TextInputAction.newline,
            onChanged: (_) {
              if (_inlineError != null) {
                setState(() => _inlineError = null);
              }
            },
            onSubmitted: widget.maxLines == 1 ? (_) => _handleSubmit() : null,
            style: AppTextStyles.bodyRegular.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: AppTextStyles.bodyRegular.copyWith(
                color: AppColors.textWhite38,
              ),
              filled: true,
              fillColor: AppColors.profileTileBg,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 12.h,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: _inlineError != null
                      ? AppColors.primaryBright
                      : AppColors.borderLight,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: _inlineError != null
                      ? AppColors.primaryBright
                      : AppColors.gold,
                ),
              ),
            ),
          ),
          if (_inlineError != null) ...[
            SizedBox(height: 8.h),
            Text(
              _inlineError!,
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.primaryBright,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: 16.h),
          GestureDetector(
            key: widget.submitKey,
            onTap: _isSubmitting ? null : _handleSubmit,
            child: Container(
              width: double.infinity,
              height: 48.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    )
                  : Text(
                      widget.submitLabel,
                      style: AppTextStyles.rewardContinueBtn,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
