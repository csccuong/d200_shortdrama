import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/placement/show_placement_ad.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/screen_utils.dart';
import '../providers/app_providers.dart';

/// Subscription policy disclosure ("Cancel anytime on Google Play") +
/// clickable Restore Purchases, Terms of Service, and Privacy Policy links.
class IapSubscriptionFooter extends StatelessWidget {
  final LocaleState locale;
  final bool isPurchasing;
  final VoidCallback onRestore;

  const IapSubscriptionFooter({
    super.key,
    required this.locale,
    required this.isPurchasing,
    required this.onRestore,
  });

  Future<void> _openLegalDocument(
    BuildContext context, {
    required String url,
    required String title,
    required String fallbackContent,
  }) async {
    final uri = Uri.parse(url);
    final releaseAdGuard = suppressAppOpenAdsOnResume(excludeNextResume: true);
    try {
      for (final mode in const [
        LaunchMode.inAppBrowserView,
        LaunchMode.externalApplication,
      ]) {
        try {
          if (await launchUrl(uri, mode: mode)) return;
        } catch (e) {
          debugPrint('IapSubscriptionFooter launch ($uri, $mode) error: $e');
        }
      }
    } finally {
      releaseAdGuard();
    }
    if (!context.mounted) return;

    final bottomInset = AppScreenUtils.bottomSafeInset(context);
    await showModalBottomSheet<void>(
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
                  Expanded(child: Text(title, style: AppTextStyles.h3)),
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
                    fallbackContent,
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
  Widget build(BuildContext context) {
    final linkStyle = AppTextStyles.captionSmall.copyWith(
      color: AppColors.textWhite70,
      decoration: TextDecoration.underline,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          locale.tr('iap_cancel_anytime'),
          textAlign: TextAlign.center,
          style: AppTextStyles.captionSmall.copyWith(
            color: AppColors.textWhite54,
            height: 1.35,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10.w,
          runSpacing: 4.h,
          children: [
            GestureDetector(
              onTap: isPurchasing ? null : onRestore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                child: Text(
                  locale.tr('iap_restore_purchases'),
                  style: linkStyle,
                ),
              ),
            ),
            Text(
              '•',
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textWhite38,
              ),
            ),
            GestureDetector(
              onTap: () => unawaited(
                _openLegalDocument(
                  context,
                  url: AppConstants.termsOfServiceUrl,
                  title: locale.tr('menu_terms'),
                  fallbackContent: locale.tr('terms_content'),
                ),
              ),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                child: Text(locale.tr('menu_terms'), style: linkStyle),
              ),
            ),
            Text(
              '•',
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textWhite38,
              ),
            ),
            GestureDetector(
              onTap: () => unawaited(
                _openLegalDocument(
                  context,
                  url: AppConstants.privacyPolicyUrl,
                  title: locale.tr('menu_privacy'),
                  fallbackContent: locale.tr('privacy_content'),
                ),
              ),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                child: Text(locale.tr('menu_privacy'), style: linkStyle),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
