import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/screen_utils.dart';
import '../providers/app_providers.dart';
import '../services/app_strings.dart';

class LanguagePickerSheet extends ConsumerWidget {
  const LanguagePickerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LanguagePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final localeNotifier = ref.read(localeProvider.notifier);
    final bottomInset = AppScreenUtils.bottomSafeInset(context);

    return Material(
      color: AppColors.surfaceSheet,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 18.h + bottomInset),
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
                  'assets/icons/ic_language.png',
                  width: 22.w,
                  height: 22.w,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    locale.tr('menu_language'),
                    style: AppTextStyles.h3,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textWhite60,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
            Text(
              locale.tr('app_language_only_desc'),
              style: AppTextStyles.caption,
            ),
            SizedBox(height: 14.h),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppScreenUtils.isTablet(context) ? 3 : 2,
                  mainAxisSpacing: 8.h,
                  crossAxisSpacing: 8.w,
                  childAspectRatio: 3.2,
                ),
                itemCount: AppStrings.supportedLanguages.length,
                itemBuilder: (context, idx) {
                  final opt = AppStrings.supportedLanguages[idx];
                  final isSelected = opt.code == locale.appLanguage;
                  return InkWell(
                    onTap: () {
                      localeNotifier.setAppLanguage(opt.code);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(10.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.glassFill,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(opt.flag, style: AppTextStyles.h3),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              opt.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.chipLabel(
                                isSelected: isSelected,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 16.sp,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
