import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/utils/screen_utils.dart';
import '../../models/drama_card.dart';
import '../../providers/app_providers.dart';
import '../../widgets/bottom_native_all_ad.dart';
import '../../widgets/drama_network_image.dart';
import '../player/drama_player_screen.dart';

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  final PageController _pageController = PageController();
  final ScrollController _favScrollCtrl = ScrollController();
  final ScrollController _historyScrollCtrl = ScrollController();
  int _selectedTab = 0; // 0: My List (Favorites) | 1: Watch Later | 2: History
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _favScrollCtrl.addListener(_onFavScroll);
    _historyScrollCtrl.addListener(_onHistoryScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didInitialLoad) return;
      _didInitialLoad = true;
      _refreshAllListsIfSessionReady();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _favScrollCtrl.dispose();
    _historyScrollCtrl.dispose();
    super.dispose();
  }

  void _refreshAllListsIfSessionReady() {
    final ready =
        ref.read(sessionProvider).asData?.value.isInitialized ?? false;
    if (!ready) return;
    final lang = ref.read(localeProvider).appLanguage;
    final notifier = ref.read(mylistProvider.notifier);
    unawaited(notifier.fetchFavorites(lang: lang));
    unawaited(notifier.fetchWatchLater(lang: lang));
    unawaited(notifier.fetchHistory(lang: lang));
  }

  void _onFavScroll() {
    if (!_favScrollCtrl.hasClients) return;
    if (_favScrollCtrl.position.pixels >=
        _favScrollCtrl.position.maxScrollExtent - 260) {
      unawaited(
        ref
            .read(mylistProvider.notifier)
            .loadMoreFavorites(lang: ref.read(localeProvider).appLanguage),
      );
    }
  }

  void _onHistoryScroll() {
    if (!_historyScrollCtrl.hasClients) return;
    if (_historyScrollCtrl.position.pixels >=
        _historyScrollCtrl.position.maxScrollExtent - 260) {
      unawaited(
        ref
            .read(mylistProvider.notifier)
            .loadMoreHistory(lang: ref.read(localeProvider).appLanguage),
      );
    }
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

  void _openDrama(DramaCard drama, {int? episodeNo, int? positionSec}) {
    final cw = drama.continueWatching;
    final ep = episodeNo ?? ((cw?.episodeNumber ?? 0) > 0 ? cw!.episodeNumber : 1);
    final pos = positionSec ?? (cw?.positionSec ?? 0);

    showInterAllThen(context, ref, () {
      ref.read(navigationServiceProvider).push(
            context,
            DramaPlayerScreen(
              dramaCard: drama,
              dramaId: drama.dramaId,
              initialEpisode: ep,
              initialPositionSec: pos,
              sourceScreen: _selectedTab == 2
                  ? 'history'
                  : (_selectedTab == 1 ? 'watch_later' : 'my_list'),
            ),
          );
    });
  }

  void _exploreDramas() {
    ref.read(shellTabIndexProvider.notifier).setTab(0);
  }

  @override
  Widget build(BuildContext context) {
    final mylist = ref.watch(mylistProvider);
    final locale = ref.watch(localeProvider);
    final lang = locale.appLanguage;

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top 3-Column Tab Bar: "My List" | "Watch Later" | "History"
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
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
                      label: locale.tr('saved'),
                      isSelected: _selectedTab == 1,
                      onTap: () => _selectTab(1),
                    ),
                  ),
                  Expanded(
                    child: _WatchlistTopTab(
                      label: locale.tr('tab_history'),
                      isSelected: _selectedTab == 2,
                      onTap: () => _selectTab(2),
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
                  // Page 0: Favorites (My List)
                  _buildFavoritesPage(mylist, locale, lang),
                  // Page 1: Watch Later
                  _buildWatchLaterPage(mylist, locale, lang),
                  // Page 2: Watch History
                  _buildHistoryPage(mylist, locale, lang),
                ],
              ),
            ),
            const BottomNativeAllAd(tabIndex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesPage(
    MyListState mylist,
    LocaleState locale,
    String lang,
  ) {
    if (mylist.favorites.isEmpty && mylist.isLoadingFavorites) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      onRefresh: () =>
          ref.read(mylistProvider.notifier).fetchFavorites(lang: lang),
      child: mylist.favorites.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 0.6.sh,
                  child: _WatchlistEmptyView(
                    imageAsset: 'assets/images/empty_mylist.png',
                    title: locale.tr('empty_mylist_title'),
                    subtitle: locale.tr('empty_mylist_desc'),
                    ctaLabel: locale.tr('explore_dramas_btn'),
                    onExplore: _exploreDramas,
                  ),
                ),
              ],
            )
          : GridView.builder(
              controller: _favScrollCtrl,
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
              physics: AlwaysScrollableScrollPhysics(
                parent: AppScreenUtils.adaptiveScrollPhysics,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppScreenUtils.watchlistGridColumns(context),
                mainAxisSpacing: 14.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 0.58,
              ),
              itemCount: mylist.favorites.length,
              itemBuilder: (context, idx) {
                final d = mylist.favorites[idx];
                final epNo = (d.continueWatching?.episodeNumber ?? 0) > 0
                    ? d.continueWatching!.episodeNumber
                    : 1;
                return _SavedPosterCard(
                  drama: d,
                  episodeLabel:
                      '${locale.tr('episode_prefix')} $epNo / ${d.totalEpisodes > 0 ? d.totalEpisodes : epNo}',
                  badgeIcon: Icons.bookmark_rounded,
                  onTap: () => _openDrama(d),
                  onRemove: () => unawaited(
                    ref.read(mylistProvider.notifier).toggleFavorite(d),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildWatchLaterPage(
    MyListState mylist,
    LocaleState locale,
    String lang,
  ) {
    if (mylist.watchLater.isEmpty && mylist.isLoadingWatchLater) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      onRefresh: () =>
          ref.read(mylistProvider.notifier).fetchWatchLater(lang: lang),
      child: mylist.watchLater.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 0.6.sh,
                  child: _WatchlistEmptyView(
                    imageAsset: 'assets/images/empty_mylist.png',
                    title: locale.tr('empty_mylist_title'),
                    subtitle: locale.tr('empty_mylist_desc'),
                    ctaLabel: locale.tr('explore_dramas_btn'),
                    onExplore: _exploreDramas,
                  ),
                ),
              ],
            )
          : GridView.builder(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
              physics: AlwaysScrollableScrollPhysics(
                parent: AppScreenUtils.adaptiveScrollPhysics,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppScreenUtils.watchlistGridColumns(context),
                mainAxisSpacing: 14.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 0.58,
              ),
              itemCount: mylist.watchLater.length,
              itemBuilder: (context, idx) {
                final d = mylist.watchLater[idx];
                final epNo = (d.continueWatching?.episodeNumber ?? 0) > 0
                    ? d.continueWatching!.episodeNumber
                    : 1;
                return _SavedPosterCard(
                  drama: d,
                  episodeLabel:
                      '${locale.tr('episode_prefix')} $epNo / ${d.totalEpisodes > 0 ? d.totalEpisodes : epNo}',
                  badgeIcon: Icons.watch_later_rounded,
                  onTap: () => _openDrama(d),
                  onRemove: () => unawaited(
                    ref.read(mylistProvider.notifier).toggleWatchLater(d),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHistoryPage(
    MyListState mylist,
    LocaleState locale,
    String lang,
  ) {
    if (mylist.history.isEmpty && mylist.isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      onRefresh: () =>
          ref.read(mylistProvider.notifier).fetchHistory(lang: lang),
      child: mylist.history.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 0.6.sh,
                  child: _WatchlistEmptyView(
                    imageAsset: 'assets/images/empty_history.png',
                    title: locale.tr('empty_history_title'),
                    subtitle: locale.tr('empty_history_desc'),
                    ctaLabel: locale.tr('explore_dramas_btn'),
                    onExplore: _exploreDramas,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 12.w, 0.h),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => unawaited(
                        ref
                            .read(mylistProvider.notifier)
                            .deleteHistory(clearAll: true),
                      ),
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
                    controller: _historyScrollCtrl,
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                    physics: AlwaysScrollableScrollPhysics(
                      parent: AppScreenUtils.adaptiveScrollPhysics,
                    ),
                    itemCount: mylist.history.length,
                    separatorBuilder: (_, _) => SizedBox(height: 12.h),
                    itemBuilder: (context, idx) {
                      final d = mylist.history[idx];
                      final cw = d.continueWatching;
                      final ep = (cw?.episodeNumber ?? 0) > 0
                          ? cw!.episodeNumber
                          : 1;
                      final totalEps = d.totalEpisodes > 0 ? d.totalEpisodes : ep;
                      final progress = (cw != null && cw.percentWatched > 0)
                          ? (cw.percentWatched / 100.0).clamp(0.05, 1.0)
                          : (ep / totalEps).clamp(0.05, 1.0);

                      return Dismissible(
                        key: ValueKey('history_${d.dramaId}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 20.w),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                            size: 24.sp,
                          ),
                        ),
                        onDismissed: (_) => unawaited(
                          ref
                              .read(mylistProvider.notifier)
                              .deleteHistory(dramaIds: [d.dramaId]),
                        ),
                        child: InkWell(
                          onTap: () => _openDrama(
                            d,
                            episodeNo: ep,
                            positionSec: cw?.positionSec ?? 0,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: AppColors.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: [
                                DramaNetworkImage(
                                  imageUrl: d.coverUrl,
                                  width: 56.w,
                                  height: 76.h,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.cardTitle,
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        '${locale.tr('continue_ep')} $ep / $totalEps',
                                        style: AppTextStyles.captionAccent,
                                      ),
                                      SizedBox(height: 8.h),
                                      LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: AppColors.borderLight,
                                        color: AppColors.primaryBright,
                                        minHeight: 4.h,
                                        borderRadius:
                                            BorderRadius.circular(2.r),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: AppColors.primaryBright,
                                  size: 30.sp,
                                ),
                              ],
                            ),
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

class _SavedPosterCard extends StatelessWidget {
  final DramaCard drama;
  final String episodeLabel;
  final IconData badgeIcon;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedPosterCard({
    required this.drama,
    required this.episodeLabel,
    required this.badgeIcon,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DramaNetworkImage(imageUrl: drama.coverUrl, fit: BoxFit.cover),
                  Positioned(
                    top: 5.h,
                    right: 5.w,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: EdgeInsets.all(5.w),
                        decoration: const BoxDecoration(
                          color: AppColors.overlayDark,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          badgeIcon,
                          color: AppColors.primaryBright,
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
            drama.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.continueCardTitle,
          ),
          SizedBox(height: 2.h),
          Text(
            episodeLabel,
            style: AppTextStyles.continueEpisodeText,
          ),
        ],
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
