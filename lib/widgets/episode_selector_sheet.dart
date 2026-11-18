import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_toast.dart';
import '../core/utils/episode_unlock_helper.dart';
import '../core/utils/screen_utils.dart';
import '../models/drama_card.dart';
import '../models/episode_detail.dart';
import '../providers/app_providers.dart';
import '../screens/player/drama_player_screen.dart';
import 'drama_network_image.dart';
import 'inline_more_text.dart';

/// Combined Drama Overview ("Giới thiệu") and Episode Selector ("Chọn tập") sheet.
class EpisodeSelectorSheet extends ConsumerStatefulWidget {
  final DramaCard drama;
  final int currentEpisode;
  final List<EpisodeItem> episodes;
  final List<DramaCard> relatedDramas;
  final bool isVipUser;
  final Set<int> locallyUnlockedEpisodes;
  final bool fullDramaUnlocked;
  final int initialTab;
  final ValueChanged<int> onSelectEpisode;
  final ValueChanged<DramaCard>? onSelectRelatedDrama;

  const EpisodeSelectorSheet({
    super.key,
    required this.drama,
    required this.currentEpisode,
    this.episodes = const [],
    this.relatedDramas = const [],
    this.isVipUser = false,
    this.locallyUnlockedEpisodes = const {},
    this.fullDramaUnlocked = false,
    this.initialTab = 1,
    required this.onSelectEpisode,
    this.onSelectRelatedDrama,
  });

  @override
  ConsumerState<EpisodeSelectorSheet> createState() =>
      _EpisodeSelectorSheetState();
}

class _EpisodeSelectorSheetState extends ConsumerState<EpisodeSelectorSheet> {
  static const int _chunkSize = 30;
  late int _activeTab;
  late int _selectedChunk;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 1);
    final safeEp = widget.currentEpisode < 1 ? 1 : widget.currentEpisode;
    _selectedChunk = (safeEp - 1) ~/ _chunkSize;
  }

  String _formatCompactCount(int count) {
    if (count >= 1000000) {
      final m = count / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1).replaceAll('.0', '')}M';
    }
    if (count >= 1000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1).replaceAll('.0', '')}K';
    }
    return '$count';
  }

  void _openRelatedDrama(DramaCard selected) {
    final nav = Navigator.of(context);
    nav.pop();
    if (widget.onSelectRelatedDrama != null) {
      widget.onSelectRelatedDrama!(selected);
      return;
    }
    nav.push(
      AppScreenUtils.adaptivePageRoute<void>(
        builder: (_) => DramaPlayerScreen(
          dramaCard: selected,
          dramaId: selected.dramaId,
          initialEpisode: 1,
          sourceScreen: 'related_drama',
        ),
      ),
    );
  }

  void _openTagDramas(DramaTag tag) {
    final parentContext = Navigator.of(context).context;
    Navigator.of(context).pop();
    if (!parentContext.mounted) return;
    showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _TagDramasSheet(
        tag: tag,
        onSelectDrama: (selected) {
          if (widget.onSelectRelatedDrama != null) {
            widget.onSelectRelatedDrama!(selected);
            return;
          }
          Navigator.of(parentContext).push(
            AppScreenUtils.adaptivePageRoute<void>(
              builder: (_) => DramaPlayerScreen(
                dramaCard: selected,
                dramaId: selected.dramaId,
                initialEpisode: 1,
                sourceScreen: 'tag_filter',
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final legacyVip = ref.watch(userWalletProvider.select((s) => s.isVip));
    final locale = ref.watch(localeProvider);

    final needRemoteDetail =
        widget.relatedDramas.isEmpty || widget.episodes.isEmpty;
    final detailAsync = needRemoteDetail
        ? ref.watch(dramaDetailProvider(widget.drama.dramaId))
        : null;
    final detailData = detailAsync?.asData?.value;

    final effectiveDrama = detailData?.dramaDetail ?? widget.drama;
    final effectiveEpisodes = widget.episodes.isNotEmpty
        ? widget.episodes
        : (detailData?.episodes.items ?? const <EpisodeItem>[]);
    final effectiveRelated = widget.relatedDramas.isNotEmpty
        ? widget.relatedDramas
        : (detailData?.relatedDramas ?? const <DramaCard>[]);
    final isVip = wallet.isVip ||
        legacyVip ||
        widget.isVipUser ||
        (detailData?.episodes.isUserVip ?? false);

    final total = effectiveDrama.totalEpisodes > 0
        ? effectiveDrama.totalEpisodes
        : (effectiveEpisodes.isNotEmpty ? effectiveEpisodes.length : 1);
    final chunkCount = (total / _chunkSize).ceil().clamp(1, 999);
    if (_selectedChunk >= chunkCount) {
      _selectedChunk = 0;
    }

    final startEp = _selectedChunk * _chunkSize + 1;
    final endEp = ((_selectedChunk + 1) * _chunkSize).clamp(1, total);
    final epsInChunk = List.generate(endEp - startEp + 1, (i) => startEp + i);
    final bottomInset = AppScreenUtils.bottomSafeInset(context);

    final byNum = EpisodeUnlockHelper.indexByNumber(effectiveEpisodes);
    final firstLockedEp = EpisodeUnlockHelper.findFirstLockedEpisode(
      totalEpisodes: total,
      drama: effectiveDrama,
      episodesByNumber: byNum,
      isVip: isVip,
      locallyUnlockedEpisodes: widget.locallyUnlockedEpisodes,
      fullDramaUnlocked: widget.fullDramaUnlocked,
    );

    final displayTags = effectiveDrama.tags.isNotEmpty
        ? effectiveDrama.tags
        : [
            if (effectiveDrama.category.isNotEmpty)
              DramaTag(
                slug: effectiveDrama.categorySlug.isNotEmpty
                    ? effectiveDrama.categorySlug
                    : effectiveDrama.category,
                name: effectiveDrama.category,
              ),
          ];

    final subtitleText = effectiveDrama.viewCount > 0
        ? '${_formatCompactCount(effectiveDrama.viewCount)} ${locale.tr('drama_views_suffix')} • $total ${locale.tr('episodes_suffix')}'
        : '${locale.tr('full_series')} $total ${locale.tr('episodes_suffix')} • ${locale.tr('currently_playing')} ${widget.currentEpisode}';

    return Container(
      key: const ValueKey('drama_detail_sheet'),
      height: 0.74.sh,
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
          // Header: Poster + Full Title + View Count + Close
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 12.w, 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DramaNetworkImage(
                  imageUrl: effectiveDrama.coverUrl,
                  width: 56.w,
                  height: 76.h,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        effectiveDrama.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(height: 1.25),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
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

          // 2 Tabs: Overview ("Giới thiệu") | Episodes ("Chọn tập")
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _SheetTabButton(
                  key: const ValueKey('drama_sheet_tab_intro'),
                  label: locale.tr('drama_tab_intro'),
                  active: _activeTab == 0,
                  onTap: () => setState(() => _activeTab = 0),
                ),
                SizedBox(width: 24.w),
                _SheetTabButton(
                  key: const ValueKey('drama_sheet_tab_episodes'),
                  label: locale.tr('drama_tab_episodes'),
                  active: _activeTab == 1,
                  onTap: () => setState(() => _activeTab = 1),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSubtle),

          // Tab Content
          Expanded(
            child: _activeTab == 0
                ? _buildIntroTab(
                    drama: effectiveDrama,
                    displayTags: displayTags,
                    relatedDramas: effectiveRelated,
                    isLoadingRelated:
                        needRemoteDetail && (detailAsync?.isLoading ?? false),
                    locale: locale,
                    bottomInset: bottomInset,
                  )
                : _buildEpisodesTab(
                    total: total,
                    chunkCount: chunkCount,
                    epsInChunk: epsInChunk,
                    drama: effectiveDrama,
                    byNum: byNum,
                    isVip: isVip,
                    firstLockedEp: firstLockedEp,
                    locale: locale,
                    bottomInset: bottomInset,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroTab({
    required DramaCard drama,
    required List<DramaTag> displayTags,
    required List<DramaCard> relatedDramas,
    required bool isLoadingRelated,
    required LocaleState locale,
    required double bottomInset,
  }) {
    return SingleChildScrollView(
      physics: AppScreenUtils.adaptiveScrollPhysics,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (drama.description.trim().isNotEmpty) ...[
            _ExpandableIntroDescription(
              description: drama.description.trim(),
              expanded: _isDescriptionExpanded,
              moreLabel: locale.tr('player_more_short'),
              lessLabel: locale.tr('player_less_short'),
              onToggle: () => setState(
                () => _isDescriptionExpanded = !_isDescriptionExpanded,
              ),
            ),
            SizedBox(height: 12.h),
          ],
          if (displayTags.isNotEmpty) ...[
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: displayTags.map((tag) {
                return GestureDetector(
                  onTap: () => _openTagDramas(tag),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          locale.trTag(tag.name),
                          style: AppTextStyles.captionSmall.copyWith(
                            color: AppColors.textWhite70,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14.sp,
                          color: AppColors.textWhite54,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20.h),
          ],
          if (isLoadingRelated && relatedDramas.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28.h),
              child: const Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
                ),
              ),
            )
          else if (relatedDramas.isNotEmpty) ...[
            Text(
              locale.tr('drama_more_like_this'),
              style: AppTextStyles.h3,
            ),
            SizedBox(height: 12.h),
            LayoutBuilder(
              builder: (context, constraints) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: _buildRelatedDramaGridDelegate(
                  context,
                  gridWidth: constraints.maxWidth,
                ),
                itemCount: relatedDramas.length,
                itemBuilder: (context, idx) {
                  final item = relatedDramas[idx];
                  return _RelatedDramaCard(
                    drama: item,
                    locale: locale,
                    viewCountText: item.viewCount > 0
                        ? _formatCompactCount(item.viewCount)
                        : null,
                    onTap: () => _openRelatedDrama(item),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEpisodesTab({
    required int total,
    required int chunkCount,
    required List<int> epsInChunk,
    required DramaCard drama,
    required Map<int, EpisodeItem> byNum,
    required bool isVip,
    required int? firstLockedEp,
    required LocaleState locale,
    required double bottomInset,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chunkCount > 1) ...[
          SizedBox(height: 12.h),
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
        ],
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
              final isUnlocked = EpisodeUnlockHelper.isEpisodeUnlocked(
                episodeNo: epNo,
                drama: drama,
                episodesByNumber: byNum,
                isVip: isVip,
                locallyUnlockedEpisodes: widget.locallyUnlockedEpisodes,
                fullDramaUnlocked: widget.fullDramaUnlocked,
              );
              final isOutOfOrder =
                  !isUnlocked && firstLockedEp != null && epNo > firstLockedEp;

              return InkWell(
                onTap: () {
                  if (isOutOfOrder) {
                    AppToast.show(
                      context,
                      locale
                          .tr('unlock_in_order_toast')
                          .replaceAll('{ep}', '$firstLockedEp'),
                    );
                    return;
                  }
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
    );
  }
}

class _SheetTabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SheetTabButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textWhite54,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2.5.h,
            width: active ? 28.w : 0,
            decoration: BoxDecoration(
              color: AppColors.primaryBright,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableIntroDescription extends StatelessWidget {
  final String description;
  final bool expanded;
  final String moreLabel;
  final String lessLabel;
  final VoidCallback onToggle;

  const _ExpandableIntroDescription({
    required this.description,
    required this.expanded,
    required this.moreLabel,
    required this.lessLabel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = AppTextStyles.bodyRegular.copyWith(
      color: AppColors.textWhite70,
      height: 1.45,
    );
    final actionStyle = baseStyle.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );

    if (expanded) {
      return GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$description ', style: baseStyle),
              TextSpan(text: lessLabel, style: actionStyle),
            ],
          ),
        ),
      );
    }

    return InlineMoreText(
      text: description,
      style: baseStyle,
      actionStyle: actionStyle,
      moreSuffix: '... $moreLabel ⌄',
      maxLines: 2,
      onTap: onToggle,
    );
  }
}

class _RelatedDramaCard extends StatelessWidget {
  final DramaCard drama;
  final LocaleState locale;
  final String? viewCountText;
  final VoidCallback onTap;

  const _RelatedDramaCard({
    required this.drama,
    required this.locale,
    this.viewCountText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeLabel = drama.audioMode.toLowerCase() == 'dubbed'
        ? locale.tr('drama_dubbed_badge')
        : (drama.trendingRank != null ? locale.tr('badge_hot') : null);
    final subtitle = drama.tags.isNotEmpty
        ? locale.trTag(drama.tags.first.name)
        : (drama.category.isNotEmpty ? locale.trTag(drama.category) : '');

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.74,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DramaNetworkImage(
                    imageUrl: drama.coverUrl,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.posterBottomGradient,
                      ),
                    ),
                  ),
                  if (badgeLabel != null)
                    Positioned(
                      top: 5.h,
                      right: 5.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: drama.audioMode.toLowerCase() == 'dubbed'
                              ? AppColors.overlayDark
                              : AppColors.primaryBright,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          badgeLabel,
                          style: AppTextStyles.captionSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (viewCountText != null)
                    Positioned(
                      right: 6.w,
                      bottom: 5.h,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.textPrimary,
                            size: 12.sp,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            viewCountText!,
                            style: AppTextStyles.captionSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Flexible(
            child: Text(
              drama.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.posterTitle,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: 3.h),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.captionSmall.copyWith(
                color: AppColors.textWhite54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

SliverGridDelegateWithFixedCrossAxisCount _buildRelatedDramaGridDelegate(
  BuildContext context, {
  required double gridWidth,
}) {
  final columns = AppScreenUtils.posterGridColumns(context);
  final crossAxisSpacing = 10.w;
  final cellWidth = ((gridWidth - crossAxisSpacing * (columns - 1)) / columns)
      .clamp(60.0, double.infinity);
  final posterHeight = cellWidth / 0.74;
  final textScaler = MediaQuery.textScalerOf(context);
  final titleFontSize = AppTextStyles.posterTitle.fontSize ?? 12.sp;
  final titleLineHeight = AppTextStyles.posterTitle.height ?? 1.25;
  final titleHeight =
      textScaler.scale(titleFontSize * titleLineHeight * 2) + 6.h;
  final subtitleFontSize = AppTextStyles.captionSmall.fontSize ?? 10.sp;
  final subtitleHeight = textScaler.scale(subtitleFontSize * 1.4) + 3.h;

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: crossAxisSpacing,
    mainAxisSpacing: 14.h,
    mainAxisExtent: posterHeight + 6.h + titleHeight + subtitleHeight,
  );
}

class _TagDramasSheet extends ConsumerStatefulWidget {
  final DramaTag tag;
  final ValueChanged<DramaCard> onSelectDrama;

  const _TagDramasSheet({
    required this.tag,
    required this.onSelectDrama,
  });

  @override
  ConsumerState<_TagDramasSheet> createState() => _TagDramasSheetState();
}

class _TagDramasSheetState extends ConsumerState<_TagDramasSheet> {
  List<DramaCard> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final lang = ref.read(localeProvider).appLanguage;
      final tagFilter = widget.tag.slug.isNotEmpty
          ? widget.tag.slug
          : widget.tag.name;
      final res = await ref.read(homeApiServiceProvider).browseDramas(
            page: 1,
            pageSize: 24,
            tags: tagFilter,
            lang: lang,
          );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final bottomInset = AppScreenUtils.bottomSafeInset(context);

    return Container(
      height: 0.72.sh,
      decoration: BoxDecoration(
        color: AppColors.surfaceSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 8.w, 10.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    locale.trTag(widget.tag.name),
                    style: AppTextStyles.h3,
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
          Divider(height: 1, color: AppColors.borderSubtle),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBright,
                      ),
                    ),
                  )
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          locale.tr('empty_following'),
                          style: AppTextStyles.caption,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16.w,
                            14.h,
                            16.w,
                            16.h + bottomInset,
                          ),
                          physics: AppScreenUtils.adaptiveScrollPhysics,
                          gridDelegate: _buildRelatedDramaGridDelegate(
                            context,
                            gridWidth: (constraints.maxWidth - 32.w).clamp(
                              60.0,
                              double.infinity,
                            ),
                          ),
                          itemCount: _items.length,
                          itemBuilder: (context, idx) {
                            final item = _items[idx];
                            return _RelatedDramaCard(
                              drama: item,
                              locale: locale,
                              onTap: () {
                                Navigator.pop(context);
                                widget.onSelectDrama(item);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
