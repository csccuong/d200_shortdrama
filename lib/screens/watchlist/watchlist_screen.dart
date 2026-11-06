import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/utils/screen_utils.dart';
import '../../widgets/bottom_native_all_ad.dart';
import '../../models/drama_models.dart';
import '../../providers/app_providers.dart';
import '../player/drama_player_screen.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  final PageController _pageController = PageController();
  int _selectedTab = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _openDrama(Drama drama, int epNo) {
    showInterAllThen(context, ref, () {
      ref.read(navigationServiceProvider).push(
            context,
            DramaPlayerScreen(
              drama: drama,
              initialEpisode: epNo,
            ),
          );
    });
  }

  void _exploreDramas() {
    ref.read(shellTabIndexProvider.notifier).setTab(0);
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final watchlist = ref.watch(watchlistProvider);
    final locale = ref.watch(localeProvider);
    final allDramas = catalogAsync.asData?.value ?? [];

    final favorites =
        allDramas.where((d) => watchlist.isFavorite(d.slug)).toList();
    final history = <MapEntry<Drama, int>>[];
    for (final entry in watchlist.watchHistory.entries) {
      final match = allDramas.where((d) => d.slug == entry.key);
      if (match.isNotEmpty) {
        history.add(MapEntry(match.first, entry.value));
      }
    }

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Minimalist 2-Column Tab Bar: "My List" | "History"
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: _WatchlistTopTab(
                      label: locale.tr('tab_following'),
                      isSelected: _selectedTab == 0,
                      onTap: () => _selectTab(0),
                    ),
                  ),
                  Expanded(
                    child: _WatchlistTopTab(
                      label: locale.tr('tab_history'),
                      isSelected: _selectedTab == 1,
                      onTap: () => _selectTab(1),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: AppScreenUtils.adaptiveScrollPhysics,
                onPageChanged: (idx) {
                  if (_selectedTab != idx) {
                    setState(() => _selectedTab = idx);
                  }
                },
                children: [
                  // Page 0: My List
                  favorites.isEmpty
                      ? _WatchlistEmptyView(
                          imageAsset: 'assets/images/empty_mylist.png',
                          title: locale.tr('empty_mylist_title'),
                          subtitle: locale.tr('empty_mylist_desc'),
                          ctaLabel: locale.tr('explore_dramas_btn'),
                          onExplore: _exploreDramas,
                        )
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
                          physics: AppScreenUtils.adaptiveScrollPhysics,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                AppScreenUtils.watchlistGridColumns(context),
                            mainAxisSpacing: 14.h,
                            crossAxisSpacing: 12.w,
                            childAspectRatio: 0.58,
                          ),
                          itemCount: favorites.length,
                          itemBuilder: (context, idx) {
                            final d = favorites[idx];
                            final lastEp =
                                watchlist.getLastWatchedEpisode(d.slug);
                            return GestureDetector(
                              onTap: () => _openDrama(d, lastEp),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10.r),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.asset(
                                            d.posterAssetPath,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned(
                                            top: 5.h,
                                            right: 5.w,
                                            child: GestureDetector(
                                              onTap: () => ref
                                                  .read(watchlistProvider
                                                      .notifier)
                                                  .toggleFavorite(d.slug),
                                              child: Container(
                                                padding: EdgeInsets.all(5.w),
                                                decoration: const BoxDecoration(
                                                  color: AppColors.overlayDark,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.bookmark_rounded,
                                                  color:
                                                      AppColors.primaryBright,
                                                  size: 15.sp,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    locale.dramaTitle(d),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.continueCardTitle,
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '${locale.tr('episode_prefix')} $lastEp / ${d.totalEpisodes}',
                                    style: AppTextStyles.continueEpisodeText,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                  // Page 1: History
                  history.isEmpty
                      ? _WatchlistEmptyView(
                          imageAsset: 'assets/images/empty_history.png',
                          title: locale.tr('empty_history_title'),
                          subtitle: locale.tr('empty_history_desc'),
                          ctaLabel: locale.tr('explore_dramas_btn'),
                          onExplore: _exploreDramas,
                        )
                      : Column(
                          children: [
                            Padding(
                              padding:
                                  EdgeInsets.fromLTRB(16.w, 4.h, 12.w, 0.h),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => ref
                                      .read(watchlistProvider.notifier)
                                      .clearHistory(),
                                  icon: Icon(
                                    Icons.delete_sweep_outlined,
                                    color: AppColors.textMuted,
                                    size: 17.sp,
                                  ),
                                  label: Text(
                                    locale.tr('clear_history'),
                                    style: AppTextStyles.caption,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding:
                                    EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                                physics: AppScreenUtils.adaptiveScrollPhysics,
                                itemCount: history.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: 12.h),
                                itemBuilder: (context, idx) {
                                  final entry = history[idx];
                                  final d = entry.key;
                                  final ep = entry.value;
                                  final progress = (ep / d.totalEpisodes)
                                      .clamp(0.05, 1.0);
                                  return InkWell(
                                    onTap: () => _openDrama(d, ep),
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius:
                                            BorderRadius.circular(12.r),
                                        border: Border.all(
                                          color: AppColors.borderSubtle,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8.r),
                                            child: Image.asset(
                                              d.posterAssetPath,
                                              width: 56.w,
                                              height: 76.h,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  locale.dramaTitle(d),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      AppTextStyles.cardTitle,
                                                ),
                                                SizedBox(height: 4.h),
                                                Text(
                                                  '${locale.tr('continue_ep')} $ep / ${d.totalEpisodes}',
                                                  style: AppTextStyles
                                                      .captionAccent,
                                                ),
                                                SizedBox(height: 8.h),
                                                LinearProgressIndicator(
                                                  value: progress,
                                                  backgroundColor:
                                                      AppColors.borderLight,
                                                  color:
                                                      AppColors.primaryBright,
                                                  minHeight: 4.h,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          2.r),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Icon(
                                            Icons.play_circle_fill_rounded,
                                            color: AppColors.primaryBright,
                                            size: 32.sp,
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
                ],
              ),
            ),
            const BottomNativeAllAd(tabIndex: 2),
          ],
        ),
      ),
    );
  }
}

class _WatchlistTopTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WatchlistTopTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.w),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: isSelected
                      ? AppTextStyles.watchlistHeaderTabActive
                      : AppTextStyles.watchlistHeaderTabInactive,
                ),
              ),
              SizedBox(height: 7.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2.5.h,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.transparent,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchlistEmptyView extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onExplore;

  const _WatchlistEmptyView({
    required this.imageAsset,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: AppScreenUtils.adaptiveScrollPhysics,
        padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Neon Illustration blended seamlessly onto pure black
            SizedBox(
              width: 248.w,
              height: 248.w,
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                color: AppColors.background,
                colorBlendMode: BlendMode.lighten,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.emptyStateTitle,
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.emptyStateSubtitle,
            ),
            SizedBox(height: 24.h),
            GestureDetector(
              onTap: onExplore,
              child: Container(
                height: 44.h,
                constraints: BoxConstraints(minWidth: 216.w),
                padding: EdgeInsets.symmetric(horizontal: 28.w),
                decoration: BoxDecoration(
                  gradient: AppColors.exploreCtaGradient,
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ctaLabel,
                      style: AppTextStyles.exploreButtonText,
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.textPrimary,
                      size: 18.sp,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
