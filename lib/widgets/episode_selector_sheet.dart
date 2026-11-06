import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/screen_utils.dart';
import '../models/drama_models.dart';
import '../providers/app_providers.dart';

class EpisodeSelectorSheet extends ConsumerStatefulWidget {
  final Drama drama;
  final int currentEpisode;
  final ValueChanged<int> onSelectEpisode;

  const EpisodeSelectorSheet({
    super.key,
    required this.drama,
    required this.currentEpisode,
    required this.onSelectEpisode,
  });

  @override
  ConsumerState<EpisodeSelectorSheet> createState() =>
      _EpisodeSelectorSheetState();
}

class _EpisodeSelectorSheetState extends ConsumerState<EpisodeSelectorSheet> {
  static const int _chunkSize = 30;
  late int _selectedChunk;

  @override
  void initState() {
    super.initState();
    _selectedChunk = (widget.currentEpisode - 1) ~/ _chunkSize;
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(userWalletProvider);
    final locale = ref.watch(localeProvider);
    final total = widget.drama.totalEpisodes;
    final chunkCount = (total / _chunkSize).ceil();

    final startEp = _selectedChunk * _chunkSize + 1;
    final endEp = ((_selectedChunk + 1) * _chunkSize).clamp(1, total);
    final epsInChunk = List.generate(endEp - startEp + 1, (i) => startEp + i);
    final bottomInset = AppScreenUtils.bottomSafeInset(context);

    return Container(
      height: 0.68.sh,
      decoration: BoxDecoration(
        color: AppColors.surfaceSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.textWhite24,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.asset(
                    widget.drama.posterAssetPath,
                    width: 54.w,
                    height: 74.h,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale.dramaTitle(widget.drama),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${locale.tr('full_series')} $total ${locale.tr('episodes_suffix')} • ${locale.tr('currently_playing')} ${widget.currentEpisode}',
                        style: AppTextStyles.caption,
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 4.h,
                        children: widget.drama.tags.take(3).map((tag) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.borderSubtle,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              locale.trTag(tag),
                              style: AppTextStyles.captionSmall,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textWhite70,
                    size: 20.sp,
                  ),
                ),
              ],
            ),
          ),
          if (chunkCount > 1)
            SizedBox(
              height: 38.h,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                scrollDirection: Axis.horizontal,
                physics: AppScreenUtils.adaptiveScrollPhysics,
                itemCount: chunkCount,
                separatorBuilder: (_, _) => SizedBox(width: 8.w),
                itemBuilder: (context, idx) {
                  final s = idx * _chunkSize + 1;
                  final e = ((idx + 1) * _chunkSize).clamp(1, total);
                  final isSelected = idx == _selectedChunk;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedChunk = idx),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? null : AppColors.borderSubtle,
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Text(
                        '$s - $e',
                        style: AppTextStyles.chipLabel(
                          isSelected: isSelected,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: 12.h),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h + bottomInset),
              physics: AppScreenUtils.adaptiveScrollPhysics,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppScreenUtils.episodeGridColumns(context),
                mainAxisSpacing: 10.h,
                crossAxisSpacing: 10.w,
                childAspectRatio: 1.25,
              ),
              itemCount: epsInChunk.length,
              itemBuilder: (context, index) {
                final epNo = epsInChunk[index];
                final isCurrent = epNo == widget.currentEpisode;
                final isUnlocked =
                    wallet.isEpisodeUnlocked(widget.drama, epNo);

                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelectEpisode(epNo);
                  },
                  borderRadius: BorderRadius.circular(8.r),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent ? null : AppColors.borderSubtle,
                      gradient:
                          isCurrent ? AppColors.badgePrimaryGradient : null,
                      borderRadius: BorderRadius.circular(8.r),
                      border: isCurrent
                          ? Border.all(
                              color: AppColors.textPrimary,
                              width: 1.2,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrent) ...[
                                Icon(
                                  Icons.equalizer_rounded,
                                  color: AppColors.textPrimary,
                                  size: 14.sp,
                                ),
                                SizedBox(width: 2.w),
                              ],
                              Text(
                                '$epNo',
                                style: isCurrent
                                    ? AppTextStyles.bodyMedium
                                    : AppTextStyles.bodyRegular,
                              ),
                            ],
                          ),
                        ),
                        if (!isUnlocked)
                          Positioned(
                            top: 4.h,
                            right: 4.w,
                            child: Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                gradient: AppColors.badgePrimaryGradient,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Icon(
                                Icons.lock_rounded,
                                color: AppColors.textPrimary,
                                size: 10.sp,
                              ),
                            ),
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
    );
  }
}
