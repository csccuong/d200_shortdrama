import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/utils/screen_utils.dart';
import '../../models/drama_models.dart';
import '../../providers/app_providers.dart';
import '../player/drama_player_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final PageController _bannerController = PageController();

  static const List<String> _topTabKeys = [
    'tab_discover',
    'tab_new',
    'tab_categories',
    'tab_vip',
    'tab_filter',
    'tab_new_release',
    'tab_ranking',
  ];

  int _selectedTopTab = 0;
  String _selectedCategory = 'ALL';
  String _sortBy = 'popular';
  String _searchQuery = '';
  int _bannerIndex = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  List<String> _extractCategories(List<Drama> dramas) {
    final set = <String>{'ALL'};
    for (final d in dramas) {
      for (final t in d.tags) {
        if (t.trim().isNotEmpty) set.add(t.trim());
      }
    }
    return set.take(10).toList();
  }

  List<Drama> _filterAndSortDramas(List<Drama> dramas, LocaleState locale) {
    final filtered = dramas.where((d) {
      final matchesCategory = _selectedCategory == 'ALL' ||
          d.tags.any((t) => t.toLowerCase() == _selectedCategory.toLowerCase());
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          d.title.toLowerCase().contains(q) ||
          locale.dramaTitle(d).toLowerCase().contains(q) ||
          d.slug.toLowerCase().contains(q) ||
          d.description.toLowerCase().contains(q) ||
          locale.dramaDescription(d).toLowerCase().contains(q) ||
          d.tags.any(
            (t) =>
                t.toLowerCase().contains(q) ||
                locale.trTag(t).toLowerCase().contains(q),
          );
      return matchesCategory && matchesSearch;
    }).toList();

    if (_sortBy == 'rating') {
      filtered.sort((a, b) => b.score.compareTo(a.score));
    } else if (_sortBy == 'episodes') {
      filtered.sort((a, b) => b.totalEpisodes.compareTo(a.totalEpisodes));
    } else {
      filtered.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    }
    return filtered;
  }

  void _openDrama(Drama drama, {int? episodeNo}) {
    final ep = episodeNo ??
        ref.read(watchlistProvider).getLastWatchedEpisode(drama.slug);
    showInterAllThen(context, ref, () {
      ref.read(navigationServiceProvider).push(
            context,
            DramaPlayerScreen(
              drama: drama,
              initialEpisode: ep,
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final watchlist = ref.watch(watchlistProvider);
    final locale = ref.watch(localeProvider);

    return ColoredBox(
      color: AppColors.background,
      child: catalogAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        error: (err, _) => Center(
          child: Text('$err', style: AppTextStyles.bodySmall),
        ),
        data: (allDramas) {
          final categories = _extractCategories(allDramas);
          final filtered = _filterAndSortDramas(allDramas, locale);
          final featured = allDramas.take(4).toList();
          final trending = [...allDramas]
            ..sort((a, b) => b.viewCount.compareTo(a.viewCount));

          final continueItems = <MapEntry<Drama, int>>[];
          for (final entry in watchlist.watchHistory.entries) {
            final match = allDramas.where((d) => d.slug == entry.key);
            if (match.isNotEmpty) {
              continueItems.add(MapEntry(match.first, entry.value));
            }
          }
          for (final d in allDramas) {
            if (continueItems.length >= 4) break;
            if (!continueItems.any((e) => e.key.slug == d.slug)) {
              continueItems.add(MapEntry(d, 4));
            }
          }

          return SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: AppScreenUtils.adaptiveScrollPhysics,
              slivers: [
                // 1. TOP HEADER: "Drama" Logo + Pill Search Input
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 8.h),
                    child: Row(
                      children: [
                        const _DramaBrandLogo(),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Container(
                            height: 38.h,
                            decoration: BoxDecoration(
                              color: AppColors.searchBarBg,
                              borderRadius: BorderRadius.circular(22.r),
                              border: Border.all(
                                color: AppColors.borderSubtle,
                              ),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: AppTextStyles.bodyMedium,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: locale.tr('search_hint'),
                                hintStyle: AppTextStyles.searchHint,
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: AppColors.textWhite70,
                                  size: 20.sp,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchCtrl.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: AppColors.textWhite54,
                                          size: 17.sp,
                                        ),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(right: 12.w),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. TOP SUB-NAVIGATION TAB BAR
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 36.h,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      scrollDirection: Axis.horizontal,
                      physics: AppScreenUtils.adaptiveScrollPhysics,
                      itemCount: _topTabKeys.length,
                      separatorBuilder: (_, _) => SizedBox(width: 20.w),
                      itemBuilder: (context, idx) {
                        final isSelected = _selectedTopTab == idx;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTopTab = idx),
                          behavior: HitTestBehavior.opaque,
                          child: IntrinsicWidth(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  locale.tr(_topTabKeys[idx]),
                                  style: isSelected
                                      ? AppTextStyles.topTabActive
                                      : AppTextStyles.topTabInactive,
                                ),
                                SizedBox(height: 6.h),
                                Container(
                                  height: 2.5.h,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.transparent,
                                    borderRadius: BorderRadius.circular(2.r),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Optional Filter Drawer when "Categories" (2) or "Filter" (4) is active
                if (_selectedTopTab == 2 || _selectedTopTab == 4)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 2.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 32.h,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: AppScreenUtils.adaptiveScrollPhysics,
                              itemCount: categories.length,
                              separatorBuilder: (_, _) => SizedBox(width: 8.w),
                              itemBuilder: (context, idx) {
                                final cat = categories[idx];
                                final active = cat == _selectedCategory;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedCategory = cat),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? null
                                          : AppColors.searchBarBg,
                                      gradient: active
                                          ? AppColors.primaryGradient
                                          : null,
                                      borderRadius: BorderRadius.circular(16.r),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      cat == 'ALL'
                                          ? locale.tr('all_categories')
                                          : locale.trTag(cat),
                                      style: AppTextStyles.chipLabel(
                                        isSelected: active,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_selectedTopTab == 4) ...[
                            SizedBox(height: 8.h),
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
                                    onTap: () =>
                                        setState(() => _sortBy = opt.$1),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 11.w,
                                        vertical: 5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? AppColors.borderLight
                                            : AppColors.searchBarBg,
                                        borderRadius:
                                            BorderRadius.circular(14.r),
                                        border: Border.all(
                                          color: active
                                              ? AppColors.primary
                                              : AppColors.transparent,
                                        ),
                                      ),
                                      child: Text(
                                        opt.$2,
                                        style: AppTextStyles.chipLabel(
                                          isSelected: active,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // 3. HERO BANNER CAROUSEL
                if (_searchQuery.isEmpty && featured.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 6.h),
                      child: SizedBox(
                        height: 176.h,
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _bannerController,
                              physics: AppScreenUtils.adaptiveScrollPhysics,
                              itemCount: featured.length,
                              onPageChanged: (i) =>
                                  setState(() => _bannerIndex = i),
                              itemBuilder: (context, idx) {
                                final d = featured[idx];
                                return _HeroBannerItem(
                                  drama: d,
                                  locale: locale,
                                  isFirstSlide: idx == 0,
                                  onWatchNow: () => _openDrama(d),
                                );
                              },
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 8.h,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children:
                                    List.generate(featured.length, (idx) {
                                  final active = idx == _bannerIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin:
                                        EdgeInsets.symmetric(horizontal: 2.5.w),
                                    width: active ? 12.w : 8.w,
                                    height: 2.5.h,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? AppColors.primary
                                          : AppColors.textWhite38,
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // 4. CONTINUE WATCHING + "See All >"
                if (_searchQuery.isEmpty &&
                    (_selectedTopTab == 0 || _selectedTopTab == 3))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 14.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            child: _SectionHeader(
                              title: locale.tr('continue_watching'),
                              seeAllLabel: locale.tr('see_all'),
                              onSeeAll: () => ref
                                  .read(shellTabIndexProvider.notifier)
                                  .setTab(2),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          SizedBox(
                            height: 132.h,
                            child: ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              scrollDirection: Axis.horizontal,
                              physics: AppScreenUtils.adaptiveScrollPhysics,
                              itemCount: continueItems.length,
                              separatorBuilder: (_, _) => SizedBox(width: 10.w),
                              itemBuilder: (context, idx) {
                                final item = continueItems[idx];
                                return _ContinueWatchingCard(
                                  drama: item.key,
                                  locale: locale,
                                  episodeNo: item.value,
                                  onTap: () => _openDrama(
                                    item.key,
                                    episodeNo: item.value,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. TRENDING NOW (3 Cards with TOP 1, TOP 2, TOP 3 Ribbons)
                if (_searchQuery.isEmpty &&
                    (_selectedTopTab == 0 || _selectedTopTab == 6))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 14.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            child: _SectionHeader(
                              title: locale.tr('trending_now'),
                              seeAllLabel: locale.tr('see_all'),
                              onSeeAll: () =>
                                  setState(() => _selectedTopTab = 6),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(
                                trending.take(3).length,
                                (idx) {
                                  final d = trending[idx];
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: idx == 0 ? 0 : 5.w,
                                        right: idx == 2 ? 0 : 5.w,
                                      ),
                                      child: _PosterGridItem(
                                        drama: d,
                                        locale: locale,
                                        rankNumber: idx + 1,
                                        onTap: () => _openDrama(d),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 6. RECOMMENDED FOR YOU (3-Column Vertical Grid)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 18.h, 14.w, 10.h),
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? '${locale.tr('search_results')} (${filtered.length})'
                          : _selectedTopTab == 1 || _selectedTopTab == 5
                              ? locale.tr('new_releases')
                              : _selectedTopTab == 3
                                  ? locale.tr('vip_exclusive')
                                  : _selectedTopTab == 6
                                      ? locale.tr('top_ranking_dramas')
                                      : locale.tr('recommended_for_you'),
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ),

                SliverPadding(
                  padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 24.h),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: AppScreenUtils.posterGridColumns(context),
                      crossAxisSpacing: 10.w,
                      mainAxisSpacing: 14.h,
                      childAspectRatio: 0.62,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final listToUse =
                            (_selectedTopTab == 1 || _selectedTopTab == 5)
                                ? filtered.reversed.toList()
                                : filtered;
                        final d = listToUse[idx];
                        return _PosterGridItem(
                          drama: d,
                          locale: locale,
                          rankNumber: _selectedTopTab == 6 ? idx + 1 : null,
                          showNewBadge:
                              _selectedTopTab == 1 || _selectedTopTab == 5,
                          onTap: () => _openDrama(d),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DramaBrandLogo extends StatelessWidget {
  const _DramaBrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Text('D', style: AppTextStyles.brandLogoD),
            Positioned(
              left: 0,
              top: 3.h,
              bottom: 3.h,
              child: Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1.5.r),
                ),
              ),
            ),
          ],
        ),
        Text('rama', style: AppTextStyles.brandLogoRest),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String seeAllLabel;
  final VoidCallback onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.seeAllLabel,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionTitle,
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: onSeeAll,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(seeAllLabel, style: AppTextStyles.seeAll),
              SizedBox(width: 2.w),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 16.sp,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroBannerItem extends StatelessWidget {
  final Drama drama;
  final LocaleState locale;
  final bool isFirstSlide;
  final VoidCallback onWatchNow;

  const _HeroBannerItem({
    required this.drama,
    required this.locale,
    required this.isFirstSlide,
    required this.onWatchNow,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = isFirstSlide
        ? locale.tr('hero_banner_title')
        : locale.dramaTitle(drama);
    final displaySub = isFirstSlide
        ? locale.tr('hero_banner_subtitle')
        : locale.dramaDescription(drama);

    return GestureDetector(
      onTap: onWatchNow,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: AppColors.surfaceBannerFallback,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                drama.posterAssetPath,
                fit: BoxFit.cover,
                alignment: const Alignment(0.4, -0.35),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.heroBannerGradient,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 18.h, 130.w, 18.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heroSerifItalic,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    displaySub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                  SizedBox(height: 14.h),
                  Container(
                    height: 33.h,
                    padding: EdgeInsets.symmetric(horizontal: 18.w),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.textPrimary,
                          size: 18.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          locale.tr('watch_now'),
                          style: AppTextStyles.buttonMedium,
                        ),
                      ],
                    ),
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

class _ContinueWatchingCard extends StatelessWidget {
  final Drama drama;
  final LocaleState locale;
  final int episodeNo;
  final VoidCallback onTap;

  const _ContinueWatchingCard({
    required this.drama,
    required this.locale,
    required this.episodeNo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (episodeNo / drama.totalEpisodes).clamp(0.32, 0.85);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 148.w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 82.h,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 0.8,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: 0.22,
                    child: Image.asset(
                      drama.posterAssetPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: AppColors.overlayMedium,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.textPrimary,
                        size: 20.sp,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8.w,
                    right: 8.w,
                    bottom: 7.h,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2.r),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2.5.h,
                        backgroundColor: AppColors.borderLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 7.h),
            Text(
              locale.dramaTitle(drama),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.continueCardTitle,
            ),
            SizedBox(height: 2.h),
            Text(
              '${locale.tr('episode_prefix')} $episodeNo',
              style: AppTextStyles.continueEpisodeText,
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterGridItem extends StatelessWidget {
  final Drama drama;
  final LocaleState locale;
  final int? rankNumber;
  final bool showNewBadge;
  final VoidCallback onTap;

  const _PosterGridItem({
    required this.drama,
    required this.locale,
    this.rankNumber,
    this.showNewBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.78,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 0.8,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    drama.posterAssetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.surface),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.posterBottomGradient,
                      ),
                    ),
                  ),
                  if (rankNumber != null)
                    Positioned(
                      top: 0,
                      right: 6.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.5.w,
                          vertical: 4.5.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.badgePrimaryGradient,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(5.r),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              locale.tr('badge_top'),
                              style: AppTextStyles.rankTopLabel,
                            ),
                            SizedBox(height: 1.5.h),
                            Text(
                              '$rankNumber',
                              style: AppTextStyles.rankNumberLabel,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (showNewBadge)
                    Positioned(
                      top: 6.h,
                      right: 6.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.5.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.badgePrimaryGradient,
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                        child: Text(
                          locale.tr('badge_new'),
                          style: AppTextStyles.hotBadgeText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            locale.dramaTitle(drama),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.posterTitle,
          ),
        ],
      ),
    );
  }
}
