import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/screen_utils.dart';
import '../providers/app_providers.dart';

class ExitAppDialog extends ConsumerWidget {
  const ExitAppDialog({super.key});

  static bool _isShowing = false;

  /// Shows the synchronized Exit App confirmation popup.
  /// Returns `true` when the user confirms exiting, or `false` to stay.
  static Future<bool> show(BuildContext context) async {
    if (_isShowing) return false;
    _isShowing = true;
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierColor: AppColors.overlayHeavy,
        builder: (_) => const ExitAppDialog(),
      );
      return result ?? false;
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return Dialog(
      backgroundColor: AppColors.surfaceSheet,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.r),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(false),
                child: Padding(
                  padding: EdgeInsets.all(2.w),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                    size: 20.sp,
                  ),
                ),
              ),
            ),
            Container(
              width: 54.w,
              height: 54.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.34),
                ),
              ),
              child: Icon(
                Icons.exit_to_app_rounded,
                color: AppColors.primary,
                size: 26.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              locale.tr('exit_dialog_title'),
              textAlign: TextAlign.center,
              style: AppTextStyles.h2,
            ),
            SizedBox(height: 8.h),
            Text(
              locale.tr('exit_dialog_desc'),
              textAlign: TextAlign.center,
              style: AppTextStyles.dialogBody,
            ),
            SizedBox(height: 22.h),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 42.h,
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.profileTileBg,
                        borderRadius: BorderRadius.circular(22.r),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          locale.tr('exit_confirm_btn'),
                          maxLines: 1,
                          style: AppTextStyles.dialogSecondaryBtn,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 42.h,
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22.r),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          locale.tr('exit_stay_btn'),
                          maxLines: 1,
                          style: AppTextStyles.exploreButtonText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
