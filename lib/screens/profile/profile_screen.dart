import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/screen_utils.dart';
import '../../fo/language/language_activity.dart';
import '../../providers/app_providers.dart';
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
    final profile = ref.watch(accountProvider).profile;
    final guest = ref.watch(guestIdentityProvider);

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

                  // TODO(IAP): Re-enable Golden "Unlock VIP" Banner Card when Rewards / IAP is enabled.
                  // SizedBox(height: 22.h),
                  // GestureDetector(
                  //   onTap: () =>
                  //       ref.read(shellTabIndexProvider.notifier).setTab(3),
                  //   child: Container(...),
                  // ),

                  SizedBox(height: 18.h),

                  // 4. Individual Rounded Menu Items
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
