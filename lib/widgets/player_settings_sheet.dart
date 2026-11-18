import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/screen_utils.dart';
import '../providers/app_providers.dart';
import '../services/app_strings.dart';

class PlayerSettingsSheet extends ConsumerWidget {
  final List<String>? availableSubLangs;
  final bool subtitlesOnly;
  final bool speedOnly;

  const PlayerSettingsSheet({
    super.key,
    this.availableSubLangs,
    this.subtitlesOnly = false,
    this.speedOnly = false,
  }) : assert(!(subtitlesOnly && speedOnly));

  static const List<double> speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  static Future<void> show(
    BuildContext context, {
    List<String>? availableSubLangs,
    bool subtitlesOnly = false,
    bool speedOnly = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlayerSettingsSheet(
        availableSubLangs: availableSubLangs,
        subtitlesOnly: subtitlesOnly,
        speedOnly: speedOnly,
      ),
    );
  }

  static String formatSpeed(double speed) {
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
    final rawSubLangs = availableSubLangs;
    final seenSubCodes = <String>{};
    final displaySubOptions = <LanguageOption>[];
    if (rawSubLangs != null) {
      for (final raw in rawSubLangs) {
        final code = AppStrings.normalizeLangCode(raw);
        if (code.isEmpty || code == 'off' || !seenSubCodes.add(code)) continue;
        final opt = AppStrings.getLanguageOption(code);
        displaySubOptions.add(
          LanguageOption(
            code: code,
            name: opt.name,
            flag: opt.flag,
          ),
        );
      }
    } else {
      displaySubOptions.addAll(AppStrings.supportedLanguages);
    }
    final activeSubOption = AppStrings.resolveSubtitleCandidate<LanguageOption>(
      displaySubOptions,
      (o) => o.code,
      locale.subtitleLanguage,
    );

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
                  subtitlesOnly
                      ? Icons.subtitles_rounded
                      : (speedOnly ? Icons.speed_rounded : Icons.tune_rounded),
                  color: AppColors.primary,
                  size: 21.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    subtitlesOnly
                        ? locale.tr('subtitle_language')
                        : (speedOnly
                            ? locale.tr('playback_speed')
                            : locale.tr('player_settings')),
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

            if (speedOnly)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.profileTileBg,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(speeds.length, (idx) {
                    final spd = speeds[idx];
                    final isSelected = wallet.playbackSpeed == spd;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (idx > 0)
                          Divider(color: AppColors.divider, height: 1.h),
                        InkWell(
                          key: ValueKey('speed_option_$spd'),
                          onTap: () {
                            walletNotifier.setPlaybackSpeed(spd);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 13.h,
                            ),
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : AppColors.transparent,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    formatSpeed(spd),
                                    style: AppTextStyles.profileMenuTitle.copyWith(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                    size: 20.sp,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),

            if (!speedOnly) ...[
              // 1. Show Subtitles Toggle + Subtitle Language Picker
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.profileTileBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: displaySubOptions.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      child: Row(
                        children: [
                          Icon(
                            Icons.subtitles_off_outlined,
                            color: AppColors.textWhite60,
                            size: 21.sp,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              locale.tr('no_subtitles_available'),
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
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
                              onChanged: (val) {
                                localeNotifier.toggleSubtitlesEnabled(val);
                                unawaited(
                                  ref
                                      .read(accountProvider.notifier)
                                      .updateSettings(
                                        subtitleLanguage:
                                            val ? locale.subtitleLanguage : 'off',
                                      ),
                                );
                              },
                            ),
                          ],
                        ),
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
                            itemCount: displaySubOptions.length,
                            separatorBuilder: (_, _) => SizedBox(width: 8.w),
                            itemBuilder: (context, idx) {
                              final opt = displaySubOptions[idx];
                              final isSelected = locale.subtitlesEnabled &&
                                  opt.code == activeSubOption?.code;
                              return GestureDetector(
                                onTap: () {
                                  localeNotifier.setSubtitleLanguage(opt.code);
                                  unawaited(
                                    ref
                                        .read(accountProvider.notifier)
                                        .updateSettings(
                                          subtitleLanguage: opt.code,
                                        ),
                                  );
                                },
                                child: Container(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 11.w),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected ? null : AppColors.glassFill,
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
                                      Text(opt.flag,
                                          style: AppTextStyles.bodyMedium),
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
                    ),
              ),
            ],

            if (!subtitlesOnly && !speedOnly) ...[
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
                    onChanged: (val) {
                      walletNotifier.setAutoPlayNext(val);
                      unawaited(
                        ref.read(accountProvider.notifier).updateSettings(
                              autoPlayNext: val,
                            ),
                      );
                    },
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
                    children: List.generate(speeds.length, (idx) {
                      final spd = speeds[idx];
                      final isSelected = wallet.playbackSpeed == spd;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: idx < speeds.length - 1 ? 6.w : 0,
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
                                formatSpeed(spd),
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
          ],
        ),
      ),
    );
  }
}
