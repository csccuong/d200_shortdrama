import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/utils/screen_utils.dart';
import '../../models/drama_models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/episode_selector_sheet.dart';
import '../../widgets/short_video_item.dart';
import '../player/drama_player_screen.dart';

class ShortsFeedScreen extends ConsumerStatefulWidget {
  final bool isTabActive;

  const ShortsFeedScreen({
    super.key,
    required this.isTabActive,
  });

  @override
  ConsumerState<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends ConsumerState<ShortsFeedScreen> {
  final PageController _pageController = PageController();
  int _topTab = 0; // 0: For you (Vertical Feed) | 1: All Dramas
  int _currentIndex = 0;
  bool _isPushedRouteActive = false;
  String _selectedGenre = 'ALL';
  String _sortBy = 'popular';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_FeedItem> _buildFeed(List<Drama> dramas) {
    final items = <_FeedItem>[];
    for (int ep = 1; ep <= 3; ep++) {
      for (final d in dramas) {
        if (ep <= d.totalEpisodes) {
          items.add(_FeedItem(drama: d, episodeNo: ep));
        }
      }
    }
    return items;
  }

  Future<void> _openFullDrama(Drama drama, int startEp) async {
    setState(() {
      _isPushedRouteActive = true;
    });
    showInterAllThen(context, ref, () async {
      await _pushFullDrama(drama, startEp);
    });
  }

  Future<void> _pushFullDrama(Drama drama, int startEp) async {
    await ref.read(navigationServiceProvider).push(
          context,
          DramaPlayerScreen(
            drama: drama,
            initialEpisode: startEp,
          ),
        );
    if (mounted) {
      setState(() {
        _isPushedRouteActive = false;
      });
    }
  }

  Future<void> _openEpisodeSheet(Drama drama, int currentEp) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => EpisodeSelectorSheet(
        drama: drama,
        currentEpisode: currentEp,
        onSelectEpisode: (epNo) => _openFullDrama(drama, epNo),
      ),
    );
  }

  void _openFilterSheet(List<String> genres, LocaleState locale) {
    final bottomInset = AppScreenUtils.bottomSafeInset(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                16.w,
                12.h,
                16.w,
                20.h + bottomInset,
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
                      Icon(
                        Icons.tune_rounded,
                        color: AppColors.primary,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          locale.tr('tab_filter'),
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
                  SizedBox(height: 8.h),
                  Text(
                    locale.tr('tab_categories'),
                    style: AppTextStyles.caption,
                  ),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: genres.map((g) {
                      final active = g == _selectedGenre;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedGenre = g);
                          setSheetState(() {});
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 13.w,
                            vertical: 7.h,
                          ),
                          decoration: BoxDecoration(
                            color: active ? null : AppColors.searchBarBg,
                            gradient:
                                active ? AppColors.primaryGradient : null,
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: active
                                  ? AppColors.transparent
                                  : AppColors.borderSubtle,
                            ),
                          ),
                          child: Text(
                            g == 'ALL'
                                ? locale.tr('all_categories')
                                : locale.trTag(g),
                            style: AppTextStyles.chipLabel(isSelected: active),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      ('popular', locale.tr('sort_popular')),
                      ('rating', locale.tr('sort_rating')),
                      ('episodes', locale.tr('sort_episodes')),
                    ].map((opt) {
                      final active = _sortBy == opt.$1;
                      return Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _sortBy = opt.$1);
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 13.w,
                              vertical: 7.h,
                            ),
                            decoration: BoxDecoration(
                              color: active ? null : AppColors.searchBarBg,
                              gradient:
                                  active ? AppColors.primaryGradient : null,
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: active
                                    ? AppColors.transparent
                                    : AppColors.borderSubtle,
                              ),
                            ),
                            child: Text(
                              opt.$2,
                              style:
                                  AppTextStyles.chipLabel(isSelected: active),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSearchSheet(List<Drama> dramas) async {
    setState(() {
      _isPushedRouteActive = true;
    });
    final selectedDrama = await showModalBottomSheet<Drama>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => _ForYouSearchSheet(dramas: dramas),
    );
    if (!mounted) return;
    if (selectedDrama != null) {
      final lastEp = ref
          .read(watchlistProvider)
          .getLastWatchedEpisode(selectedDrama.slug);
      await _openFullDrama(selectedDrama, lastEp);
    } else {
      setState(() {
        _isPushedRouteActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTabActive) {
      return const ColoredBox(color: AppColors.background);
    }

    final catalogAsync = ref.watch(catalogProvider);
    final locale = ref.watch(localeProvider);
    final autoPlayNext =
        ref.watch(userWalletProvider.select((s) => s.autoPlayNext));

    return catalogAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
        ),
      ),
      error: (err, _) => Center(
        child: Text('$err', style: AppTextStyles.bodySmall),
      ),
      data: (dramas) {
        if (dramas.isEmpty) return const SizedBox.shrink();
        final feed = _buildFeed(dramas);

        final genres = <String>{'ALL'};
        for (final d in dramas) {
          genres.addAll(d.tags.take(3));
        }
        final filteredDramas = (_selectedGenre == 'ALL'
                ? [...dramas]
                : dramas
                    .where((d) => d.tags.any((t) =>
                        t.toLowerCase() == _selectedGenre.toLowerCase()))
                    .toList())
          ..sort((a, b) {
            if (_sortBy == 'rating') return b.score.compareTo(a.score);
            if (_sortBy == 'episodes') {
              return b.totalEpisodes.compareTo(a.totalEpisodes);
            }
            return b.viewCount.compareTo(a.viewCount);
          });

        return Stack(
          children: [
            // Sub-tab 0: Vertical Short Video Feed ("For you")
            if (_topTab == 0)
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: AppScreenUtils.adaptiveScrollPhysics,
                itemCount: feed.length,
                onPageChanged: (idx) {
                  setState(() {
                    _currentIndex = idx;
                  });
                },
                itemBuilder: (context, index) {
                  final item = feed[index];
                  final active = widget.isTabActive &&
                      _topTab == 0 &&
                      !_isPushedRouteActive &&
                      _currentIndex == index;
                  return ShortVideoItem(
                    drama: item.drama,
                    episodeNo: item.episodeNo,
                    isActive: active,
                    showFullDramaButton: true,
                    onOpenFullDrama: () =>
                        _openFullDrama(item.drama, item.episodeNo),
                    onOpenEpisodeList: () =>
                        _openEpisodeSheet(item.drama, item.episodeNo),
                    onVideoEnded: () {
                      if (autoPlayNext && _currentIndex < feed.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  );
                },
              )
            // Sub-tab 1: "All Dramas" Browser inside For You Tab (3 Columns + Filter + Hot Gradient Badge)
            else
              Container(
                color: AppColors.background,
                padding: EdgeInsets.only(
                  top: AppScreenUtils.topSafeInset(context) + 48.h,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 6.h),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => _openFilterSheet(genres.toList(), locale),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedGenre == 'ALL'
                                      ? locale.tr('tab_filter')
                                      : '${locale.tr('tab_filter')} • ${locale.trTag(_selectedGenre)}',
                                  style: AppTextStyles.filterButtonLabel,
                                ),
                                SizedBox(width: 6.w),
                                Icon(
                                  Icons.tune_rounded,
                                  color: _selectedGenre == 'ALL'
                                      ? AppColors.profileIdText
                                      : AppColors.primary,
                                  size: 18.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 24.h),
                        physics: AppScreenUtils.adaptiveScrollPhysics,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              AppScreenUtils.posterGridColumns(context),
                          mainAxisSpacing: 14.h,
                          crossAxisSpacing: 10.w,
                          childAspectRatio: 0.61,
                        ),
                        itemCount: filteredDramas.length,
                        itemBuilder: (context, idx) {
                          final d = filteredDramas[idx];
                          final lastEp = ref
                              .watch(watchlistProvider)
                              .getLastWatchedEpisode(d.slug);
                          return _AllDramasPosterCard(
                            drama: d,
                            locale: locale,
                            onTap: () => _openFullDrama(d, lastEp),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Subtle Top Scrim over Video Feed for Crisp Header Legibility
            if (_topTab == 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: AppScreenUtils.topSafeInset(context) + 64.h,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.topHeaderScrimGradient,
                    ),
                  ),
                ),
              ),

            // Floating Minimalist Top Header: "For you" | "All Dramas" + Search Icon
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 48.h,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: _MinimalTopTabText(
                              label: locale.tr('for_you_tab'),
                              active: _topTab == 0,
                              onTap: () => setState(() => _topTab = 0),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: _MinimalTopTabText(
                              label: locale.tr('all_dramas_title'),
                              active: _topTab == 1,
                              onTap: () => setState(() => _topTab = 1),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openSearchSheet(dramas),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: EdgeInsets.all(6.w),
                            child: Icon(
                              Icons.search_rounded,
                              color: AppColors.textPrimary,
                              size: 24.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MinimalTopTabText extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MinimalTopTabText({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: active
              ? AppTextStyles.forYouHeaderTabActive
              : AppTextStyles.forYouHeaderTabInactive,
        ),
      ),
    );
  }
}

class _ForYouSearchSheet extends ConsumerStatefulWidget {
  final List<Drama> dramas;

  const _ForYouSearchSheet({required this.dramas});

  @override
  ConsumerState<_ForYouSearchSheet> createState() => _ForYouSearchSheetState();
}

class _ForYouSearchSheetState extends ConsumerState<_ForYouSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom +
        AppScreenUtils.bottomSafeInset(context);
    final q = _query.trim().toLowerCase();

    final results = q.isEmpty
        ? widget.dramas
        : widget.dramas.where((d) {
            final title = locale.dramaTitle(d).toLowerCase();
            final desc = locale.dramaDescription(d).toLowerCase();
            final tagsMatch = d.tags.any(
              (t) =>
                  t.toLowerCase().contains(q) ||
                  locale.trTag(t).toLowerCase().contains(q),
            );
            return title.contains(q) || desc.contains(q) || tagsMatch;
          }).toList();

    return Container(
      height: 0.85.sh,
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surfaceSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: AppColors.textWhite24,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40.h,
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: AppColors.searchBarBg,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: AppColors.textWhite60,
                        size: 19.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          style: AppTextStyles.bodyRegular,
                          onChanged: (val) => setState(() => _query = val),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: locale.tr('search_hint'),
                            hintStyle: AppTextStyles.searchHint,
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: Icon(
                            Icons.cancel_rounded,
                            color: AppColors.textWhite54,
                            size: 18.sp,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.textWhite60,
                  size: 21.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            _query.trim().isEmpty
                ? locale.tr('trending_now')
                : '${locale.tr('search_results')} (${results.length})',
            style: AppTextStyles.sectionTitle,
          ),
          SizedBox(height: 10.h),
          Expanded(
            child: GridView.builder(
              physics: AppScreenUtils.adaptiveScrollPhysics,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppScreenUtils.posterGridColumns(context),
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 14.h,
                childAspectRatio: 0.61,
              ),
              itemCount: results.length,
              itemBuilder: (ctx, idx) {
                final drama = results[idx];
                return _AllDramasPosterCard(
                  drama: drama,
                  locale: locale,
                  onTap: () => Navigator.pop(context, drama),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDramasPosterCard extends StatelessWidget {
  final Drama drama;
  final LocaleState locale;
  final VoidCallback onTap;

  const _AllDramasPosterCard({
    required this.drama,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.rewardPlanCardBg,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    drama.posterAssetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.rewardPlanCardBg,
                    ),
                  ),
                  Positioned(
                    top: 6.h,
                    right: 6.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 9.w,
                        vertical: 3.5.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.badgePrimaryGradient,
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                      child: Text(
                        locale.tr('badge_hot'),
                        style: AppTextStyles.hotBadgeText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            height: 31.h,
            child: Text(
              locale.dramaTitle(drama),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.posterTitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedItem {
  final Drama drama;
  final int episodeNo;

  const _FeedItem({required this.drama, required this.episodeNo});
}
