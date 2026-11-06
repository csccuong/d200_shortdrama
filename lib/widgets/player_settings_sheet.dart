import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/screen_utils.dart';
import '../providers/app_providers.dart';
import '../services/app_strings.dart';

class PlayerSettingsSheet extends ConsumerWidget {
  const PlayerSettingsSheet({super.key});

  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PlayerSettingsSheet(),
    );
  }

  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) {
      return '${speed.toStringAsFixed(1)}x';
    }
    return '${speed}x';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final localeNotifier = ref.read(localeProvider.notifier);
    final wallet = ref.watch(userWalletProvider);
    final walletNotifier = ref.read(userWalletProvider.notifier);
    final bottomInset = AppScreenUtils.bottomSafeInset(context);

    return Material(
      color: AppColors.surfaceSheet,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h + bottomInset),
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
                Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 21.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    locale.tr('player_settings'),
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
            SizedBox(height: 8.h),

            // 1. Show Subtitles Toggle + Subtitle Language Picker
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.profileTileBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        locale.subtitlesEnabled
                            ? Icons.subtitles_rounded
                            : Icons.subtitles_off_outlined,
                        color: AppColors.primary,
                        size: 21.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          locale.tr('show_subtitles'),
                          style: AppTextStyles.profileMenuTitle,
                        ),
                      ),
                      Switch.adaptive(
                        value: locale.subtitlesEnabled,
                        activeThumbColor: AppColors.primary,
                        activeTrackColor:
                            AppColors.primary.withValues(alpha: 0.35),
                        onChanged: (val) =>
                            localeNotifier.toggleSubtitlesEnabled(val),
                      ),
                    ],
                  ),
                  if (locale.subtitlesEnabled) ...[
                    Divider(color: AppColors.divider, height: 14.h),
                    Text(
                      locale.tr('subtitle_language'),
                      style: AppTextStyles.caption,
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      height: 34.h,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: AppScreenUtils.adaptiveScrollPhysics,
                        itemCount: AppStrings.supportedLanguages.length,
                        separatorBuilder: (_, _) => SizedBox(width: 8.w),
                        itemBuilder: (context, idx) {
                          final opt = AppStrings.supportedLanguages[idx];
                          final isSelected =
                              opt.code == locale.subtitleLanguage;
                          return GestureDetector(
                            onTap: () =>
                                localeNotifier.setSubtitleLanguage(opt.code),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 11.w),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? null : AppColors.glassFill,
                                gradient: isSelected
                                    ? AppColors.primaryGradient
                                    : null,
                                borderRadius: BorderRadius.circular(18.r),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.transparent
                                      : AppColors.divider,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(opt.flag, style: AppTextStyles.bodyMedium),
                                  SizedBox(width: 5.w),
                                  Text(
                                    opt.name,
                                    style: AppTextStyles.chipLabel(
                                      isSelected: isSelected,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 4.h),
                  ],
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // 2. Auto-Play Next Episode Toggle
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: AppColors.profileTileBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_play_rounded,
                    color: AppColors.primary,
                    size: 23.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      locale.tr('auto_play_next'),
                      style: AppTextStyles.profileMenuTitle,
                    ),
                  ),
                  Switch.adaptive(
                    value: wallet.autoPlayNext,
                    activeThumbColor: AppColors.primary,
                    activeTrackColor:
                        AppColors.primary.withValues(alpha: 0.35),
                    onChanged: (val) => walletNotifier.setAutoPlayNext(val),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // 3. Playback Speed Selector
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.profileTileBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        color: AppColors.primary,
                        size: 21.sp,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        locale.tr('playback_speed'),
                        style: AppTextStyles.profileMenuTitle,
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: List.generate(_speeds.length, (idx) {
                      final spd = _speeds[idx];
                      final isSelected = wallet.playbackSpeed == spd;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: idx < _speeds.length - 1 ? 6.w : 0,
                          ),
                          child: GestureDetector(
                            onTap: () => walletNotifier.setPlaybackSpeed(spd),
                            child: Container(
                              height: 34.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? null : AppColors.glassFill,
                                gradient: isSelected
                                    ? AppColors.primaryGradient
                                    : null,
                                borderRadius: BorderRadius.circular(18.r),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.transparent
                                      : AppColors.divider,
                                ),
                              ),
                              child: Text(
                                _formatSpeed(spd),
                                style: AppTextStyles.chipLabel(
                                  isSelected: isSelected,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
