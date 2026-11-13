import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/utils/screen_utils.dart';
import '../../models/drama_card.dart';
import '../../models/home_response.dart';
import '../../models/taxonomy_models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/drama_network_image.dart';
import '../player/drama_player_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final PageController _bannerController = PageController();
  final ScrollController _scrollController = ScrollController();

  Timer? _searchDebounce;
  bool _didBootstrap = false;

  String _selectedCategory = 'all';
  String _selectedTag = '';
  String _sortBy = 'popular';
  String _searchQuery = '';
  int _bannerIndex = 0;

  // Dedicated state for API category / tag browsing (/v1/dramas/browse)
  List<DramaCard> _categoryDramas = [];
  int _categoryPage = 1;
  bool _categoryHasMore = false;
  bool _isLoadingCategory = false;
  String? _categoryError;

  // Dedicated state for Search & Hot keywords
  List<DramaCard> _searchResults = [];
  List<String> _hotKeywords = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && _hotKeywords.isEmpty) {
        unawaited(_loadHotKeywords());
      }
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didBootstrap) return;
      _didBootstrap = true;
      final sessionReady =
          ref.read(sessionProvider).asData?.value.isInitialized ?? false;
      final hasHome =
          ref.read(homeProvider).asData?.value.homeData != null;
      if (sessionReady && !hasHome) {
        unawaited(
          ref
              .read(homeProvider.notifier)
              .fetchHome(ref.read(localeProvider).appLanguage),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _bannerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 320) return;

    if (_searchQuery.trim().isNotEmpty) return;
    if (_selectedCategory == 'all') {
      unawaited(
        ref
            .read(homeProvider.notifier)
            .loadMoreRecommended(lang: ref.read(localeProvider).appLanguage),
      );
    } else if (_categoryHasMore && !_isLoadingCategory) {
      unawaited(_loadCategoryDramas(reset: false));
    }
  }

  Future<void> _loadHotKeywords() async {
    final sessionReady =
        ref.read(sessionProvider).asData?.value.isInitialized ?? false;
    if (!sessionReady) return;
    try {
      final data = await ref
          .read(homeApiServiceProvider)
          .searchHot(lang: ref.read(localeProvider).appLanguage);
      final rawKeywords = data['hot_keywords'] ?? data['keywords'];
      if (rawKeywords is List && mounted) {
        setState(() {
          _hotKeywords = rawKeywords
              .map((e) => e is Map ? (e['keyword'] ?? e['title'] ?? '').toString() : e.toString())
              .where((s) => s.trim().isNotEmpty)
              .take(10)
              .toList();
        });
      }
    } catch (_) {
      // Optional enhancement
    }
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _searchDebounce?.cancel();
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_executeSearch(trimmed));
    });
  }

  Future<void> _executeSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final lang = ref.read(localeProvider).appLanguage;
      final res = await ref.read(homeApiServiceProvider).search(
            query: query,
            lang: lang,
          );
      if (!mounted || _searchQuery.trim() != query) return;
      ref.read(eventTrackerProvider).track(
        'search',
        sourceScreen: 'home',
        props: {'query': query, 'results': res.items.length},
      );
      setState(() {
        _searchResults = res.items;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = e.toString();
      });
    }
  }

  Future<void> _selectCategory(String slug, {String? tag}) async {
    final nextTag = tag ?? (slug == 'all' ? '' : _selectedTag);
    setState(() {
      _selectedCategory = slug;
      _selectedTag = nextTag;
      _categoryError = null;
      if (slug == 'all') {
        _categoryDramas = [];
        _categoryPage = 1;
        _categoryHasMore = false;
      }
    });
    if (slug != 'all') {
      await _loadCategoryDramas(reset: true);
    }
  }

  Future<void> _loadCategoryDramas({required bool reset}) async {
    if (_selectedCategory == 'all') return;
    if (_isLoadingCategory && !reset) return;
    final nextPage = reset ? 1 : (_categoryPage + 1);
    setState(() {
      _isLoadingCategory = true;
      if (reset) {
        _categoryError = null;
      }
    });

    final ready = await ensureSessionForUserAction(ref);
    if (!ready) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategory = false;
        _categoryError = ref.read(sessionProvider).failureText;
      });
      return;
    }

    try {
      final api = ref.read(homeApiServiceProvider);
      final lang = ref.read(localeProvider).appLanguage;
      final res = await api.browseDramas(
        page: nextPage,
        pageSize: 21,
        category: _selectedCategory,
        tags: _selectedTag,
        sort: _sortBy,
        lang: lang,
      );

      if (!mounted) return;
      setState(() {
        _categoryDramas =
            reset ? res.items : [..._categoryDramas, ...res.items];
        _categoryPage = res.pagination.page;
        _categoryHasMore = res.pagination.hasMore;
        _isLoadingCategory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategory = false;
        _categoryError = formatDisplayApiError(e);
      });
    }
  }

  Future<void> _handleRefresh() async {
    final ready = await ensureSessionForUserAction(ref);
    if (!ready || !mounted) return;
    final lang = ref.read(localeProvider).appLanguage;
    await ref.read(homeProvider.notifier).fetchHome(lang);
    if (_selectedCategory != 'all') {
      await _loadCategoryDramas(reset: true);
    }
    if (_searchQuery.trim().isNotEmpty) {
      await _executeSearch(_searchQuery.trim());
    }
  }

  void _openDrama(DramaCard drama, {int? episodeNo, int? positionSec}) {
    final ep = episodeNo ??
        ((drama.continueWatching?.episodeNumber ?? 0) > 0
            ? drama.continueWatching!.episodeNumber
            : 1);
    final pos = positionSec ?? (drama.continueWatching?.positionSec ?? 0);

    ref.read(eventTrackerProvider).track(
      'drama_click',
      dramaId: drama.dramaId,
      episodeNumber: ep,
      sourceScreen: 'home',
      props: {'category': _selectedCategory},
    );

    showInterAllThen(context, ref, () {
      ref.read(navigationServiceProvider).push(
            context,
            DramaPlayerScreen(
              dramaCard: drama,
              dramaId: drama.dramaId,
              initialEpisode: ep,
              initialPositionSec: pos,
              sourceScreen: 'home',
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeProvider);
    final sessionAsync = ref.watch(sessionProvider);
    final mylistState = ref.watch(mylistProvider);
    final locale = ref.watch(localeProvider);

    ref.listen<AsyncValue<SessionState>>(sessionProvider, (prev, next) {
      if (!(prev?.isReady ?? false) && next.isReady) {
        final lang = ref.read(localeProvider).appLanguage;
        if (ref.read(homeProvider).asData?.value.homeData == null) {
          unawaited(ref.read(homeProvider.notifier).fetchHome(lang));
        }
        if (_selectedCategory != 'all' && _categoryDramas.isEmpty) {
          unawaited(_loadCategoryDramas(reset: true));
        }
      }
    });

    ref.listen<LocaleState>(localeProvider, (prev, next) {
      if (prev?.appLanguage != next.appLanguage &&
          sessionAsync.isReady) {
        unawaited(ref.read(homeProvider.notifier).fetchHome(next.appLanguage));
        if (_selectedCategory != 'all') {
          unawaited(_loadCategoryDramas(reset: true));
        }
      }
    });

    final homeState = homeAsync.asData?.value;
    final homeData = homeState?.homeData;
    final taxonomy = sessionAsync.asData?.value.initData?.taxonomy;

    // Derive categories strictly from API taxonomy or homeData
    final rawApiCategories = <({String slug, String name})>[
      if (taxonomy != null && taxonomy.categories.isNotEmpty)
        ...taxonomy.categories.map((c) => (slug: c.slug, name: c.name))
      else if (homeData != null)
        ...homeData.categories.map(
          (c) => (
            slug: (c['slug'] ?? '').toString(),
            name: (c['name'] ?? c['slug'] ?? '').toString(),
          ),
        ),
    ].where((c) => c.slug.trim().isNotEmpty && c.name.trim().isNotEmpty).toList();

    final categories = <({String slug, String name})>[
      if (rawApiCategories.isNotEmpty) ...[
        (slug: 'all', name: locale.tr('all_categories')),
        ...rawApiCategories,
      ] else if (_selectedCategory != 'all') ...[
        (slug: 'all', name: locale.tr('all_categories')),
        (
          slug: _selectedCategory,
          name: _resolveCategoryTitle(_selectedCategory, const [], homeData, locale),
        ),
      ],
    ];

    final sorts = taxonomy?.facets.sorts ?? const <FacetSort>[];

    final banners = homeData?.banners ?? const <DramaCard>[];

    final continueItems = <DramaCard>[
      if (homeData != null && homeData.continueWatching.isNotEmpty)
        ...homeData.continueWatching
      else if (mylistState.history.isNotEmpty)
        ...mylistState.history,
    ];

    final trending = homeData?.trending ?? const <DramaCard>[];
    final newReleases = homeData?.newReleases ?? const <DramaCard>[];

    // Determine primary grid items for active search / category / home feed
    late final List<DramaCard> gridItems;
    if (_searchQuery.trim().isNotEmpty) {
      gridItems = _searchResults;
    } else if (_selectedCategory == 'all') {
      gridItems = homeState?.recommendedDramas ?? const <DramaCard>[];
    } else {
      gridItems = _categoryDramas;
    }

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceCard,
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            physics: AlwaysScrollableScrollPhysics(
              parent: AppScreenUtils.adaptiveScrollPhysics,
            ),
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
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                _searchDebounce?.cancel();
                                unawaited(_executeSearch(v.trim()));
                              }
                            },
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
                                        _searchDebounce?.cancel();
                                        _searchCtrl.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _searchResults = [];
                                          _isSearching = false;
                                          _searchError = null;
                                        });
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

              // 1b. HOT KEYWORDS BAR (when search bar focused & query empty)
              if (_searchFocus.hasFocus &&
                  _searchQuery.trim().isEmpty &&
                  _hotKeywords.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 8.h),
                    child: Wrap(
                      spacing: 8.w,
                      runSpacing: 6.h,
                      children: _hotKeywords.map((kw) {
                        return GestureDetector(
                          onTap: () {
                            _searchCtrl.text = kw;
                            _onSearchChanged(kw);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.searchBarBg,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Text(
                              kw,
                              style: AppTextStyles.caption,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // 2. API CATEGORIES FILTER BAR (only shown when API provides categories or a section filter is active)
              if (_searchQuery.trim().isEmpty && categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildCategoryFilterBar(
                    categories: categories,
                    taxonomy: taxonomy,
                    sorts: sorts,
                    locale: locale,
                  ),
                ),

              // Show top-level loading / error state if Home hasn't loaded yet
              if (_searchQuery.trim().isEmpty &&
                  homeData == null &&
                  (homeAsync.isLoading || sessionAsync.isLoading))
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator.adaptive(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
                    ),
                  ),
                )
              else if (_searchQuery.trim().isEmpty &&
                  homeData == null &&
                  _categoryDramas.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            color: AppColors.textWhite38,
                            size: 42.sp,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            formatDisplayApiError(homeAsync.error) ??
                                sessionAsync.failureText ??
                                locale.tr('empty_following'),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 14.h),
                          ElevatedButton.icon(
                            onPressed: _handleRefresh,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textPrimary,
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(locale.tr('retry_btn')),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // 3. HERO BANNER CAROUSEL (only from /v1/home banners)
                if (_searchQuery.trim().isEmpty &&
                    _selectedCategory == 'all' &&
                    banners.isNotEmpty)
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
                              itemCount: banners.length,
                              onPageChanged: (i) =>
                                  setState(() => _bannerIndex = i),
                              itemBuilder: (context, idx) {
                                final d = banners[idx];
                                return _HeroBannerItem(
                                  drama: d,
                                  locale: locale,
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
                                children: List.generate(banners.length, (idx) {
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

                // 4. CONTINUE WATCHING
                if (_searchQuery.trim().isEmpty &&
                    _selectedCategory == 'all' &&
                    continueItems.isNotEmpty)
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
                                  drama: item,
                                  locale: locale,
                                  onTap: () => _openDrama(item),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. TRENDING NOW (3 Cards with TOP 1..3 Ribbons)
                if (_searchQuery.trim().isEmpty &&
                    _selectedCategory == 'all' &&
                    trending.isNotEmpty)
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
                                        rankNumber: d.trendingRank ?? (idx + 1),
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

                // 5a. NEW RELEASES SHELF (from /v1/home)
                if (_searchQuery.trim().isEmpty &&
                    _selectedCategory == 'all' &&
                    newReleases.isNotEmpty)
                  _buildHorizontalShelfSliver(
                    title: locale.tr('new_releases'),
                    items: newReleases,
                    locale: locale,
                    showNewBadge: true,
                  ),

                // 5b. CATEGORY SECTIONS SHELVES (from /v1/home)
                if (_searchQuery.trim().isEmpty &&
                    _selectedCategory == 'all' &&
                    homeData != null &&
                    homeData.categorySections.isNotEmpty)
                  ...homeData.categorySections.take(3).map(
                        (section) => _buildHorizontalShelfSliver(
                          title: section.title.isNotEmpty
                              ? '${section.icon} ${section.title}'.trim()
                              : locale.trTag(section.slug),
                          items: section.items,
                          locale: locale,
                          seeAllLabel: locale.tr('see_all'),
                          onSeeAll: () => unawaited(
                            _selectCategory(section.slug, tag: ''),
                          ),
                        ),
                      ),

                // 6. MAIN SECTION TITLE
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 18.h, 14.w, 10.h),
                    child: Text(
                      _sectionHeading(
                        locale,
                        gridItems.length,
                        categories,
                        homeData,
                      ),
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ),

                // 7. LOADING / EMPTY / 3-COLUMN GRID
                if ((_isSearching && _searchQuery.trim().isNotEmpty) ||
                    (_selectedCategory != 'all' &&
                        _isLoadingCategory &&
                        gridItems.isEmpty))
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primaryBright,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_searchError != null && _searchQuery.trim().isNotEmpty)
                  SliverToBoxAdapter(
                    child: _InlineRetryBox(
                      message: _searchError!,
                      retryLabel: locale.tr('retry_btn'),
                      onRetry: () =>
                          unawaited(_executeSearch(_searchQuery.trim())),
                    ),
                  )
                else if (_categoryError != null &&
                    _selectedCategory != 'all' &&
                    gridItems.isEmpty)
                  SliverToBoxAdapter(
                    child: _InlineRetryBox(
                      message: _categoryError!,
                      retryLabel: locale.tr('retry_btn'),
                      onRetry: () => unawaited(_loadCategoryDramas(reset: true)),
                    ),
                  )
                else if (gridItems.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 36.h),
                      child: Center(
                        child: Text(
                          locale.tr('empty_following'),
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 16.h),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            AppScreenUtils.posterGridColumns(context),
                        crossAxisSpacing: 10.w,
                        mainAxisSpacing: 14.h,
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                          final d = gridItems[idx];
                          return _PosterGridItem(
                            drama: d,
                            locale: locale,
                            onTap: () => _openDrama(d),
                          );
                        },
                        childCount: gridItems.length,
                      ),
                    ),
                  ),
                  if ((homeState?.isLoadingMore ?? false) ||
                      (_selectedCategory != 'all' && _isLoadingCategory))
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryBright,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _resolveCategoryTitle(
    String slug,
    List<({String slug, String name})> categories,
    HomeResponse? homeData,
    LocaleState locale,
  ) {
    for (final c in categories) {
      if (c.slug == slug) return c.name;
    }
    if (homeData != null) {
      for (final s in homeData.categorySections) {
        if (s.slug == slug && s.title.isNotEmpty) {
          return '${s.icon} ${s.title}'.trim();
        }
      }
    }
    return locale.trTag(slug);
  }

  String _sectionHeading(
    LocaleState locale,
    int count,
    List<({String slug, String name})> categories,
    HomeResponse? homeData,
  ) {
    if (_searchQuery.trim().isNotEmpty) {
      return '${locale.tr('search_results')} ($count)';
    }
    if (_selectedCategory != 'all') {
      return _resolveCategoryTitle(
        _selectedCategory,
        categories,
        homeData,
        locale,
      );
    }
    return locale.tr('recommended_for_you');
  }

  Widget _buildHorizontalShelfSliver({
    required String title,
    required List<DramaCard> items,
    required LocaleState locale,
    String? seeAllLabel,
    VoidCallback? onSeeAll,
    bool showNewBadge = false,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(top: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: _SectionHeader(
                title: title,
                seeAllLabel: seeAllLabel,
                onSeeAll: onSeeAll,
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              height: 186.h,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                scrollDirection: Axis.horizontal,
                physics: AppScreenUtils.adaptiveScrollPhysics,
                itemCount: items.length,
                separatorBuilder: (_, _) => SizedBox(width: 10.w),
                itemBuilder: (context, idx) {
                  final d = items[idx];
                  return SizedBox(
                    width: 108.w,
                    child: _PosterGridItem(
                      drama: d,
                      locale: locale,
                      showNewBadge: showNewBadge,
                      onTap: () => _openDrama(d),
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

  Widget _buildCategoryFilterBar({
    required List<({String slug, String name})> categories,
    required Taxonomy? taxonomy,
    required List<FacetSort> sorts,
    required LocaleState locale,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 2.h),
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
                final active = cat.slug == _selectedCategory;
                return GestureDetector(
                  onTap: () => unawaited(
                    _selectCategory(
                      cat.slug,
                      tag: cat.slug == 'all' ? '' : _selectedTag,
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: active ? null : AppColors.searchBarBg,
                      gradient: active ? AppColors.primaryGradient : null,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat.name,
                      style: AppTextStyles.chipLabel(isSelected: active),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedCategory != 'all' &&
              taxonomy != null &&
              taxonomy.tags.isNotEmpty) ...[
            SizedBox(height: 8.h),
            SizedBox(
              height: 28.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: taxonomy.tags.take(12).length,
                separatorBuilder: (_, _) => SizedBox(width: 6.w),
                itemBuilder: (context, idx) {
                  final tag = taxonomy.tags[idx];
                  final active = _selectedTag == tag.slug;
                  return _FilterPill(
                    label: '#${tag.name}',
                    active: active,
                    onTap: () {
                      setState(() {
                        _selectedTag = active ? '' : tag.slug;
                      });
                      unawaited(_loadCategoryDramas(reset: true));
                    },
                  );
                },
              ),
            ),
          ],
          if (_selectedCategory != 'all' && sorts.isNotEmpty) ...[
            SizedBox(height: 8.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sorts.map((opt) {
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: _FilterPill(
                      label: opt.name,
                      active: _sortBy == opt.code,
                      onTap: () {
                        setState(() => _sortBy = opt.code);
                        unawaited(_loadCategoryDramas(reset: true));
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: active ? AppColors.borderLight : AppColors.searchBarBg,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.chipLabel(isSelected: active),
        ),
      ),
    );
  }
}

class _InlineRetryBox extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _InlineRetryBox({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10.h),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: Text(retryLabel),
          ),
        ],
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
  final String? seeAllLabel;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    this.seeAllLabel,
    this.onSeeAll,
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
        if (seeAllLabel != null && onSeeAll != null) ...[
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onSeeAll,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(seeAllLabel!, style: AppTextStyles.seeAll),
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
      ],
    );
  }
}

class _HeroBannerItem extends StatelessWidget {
  final DramaCard drama;
  final LocaleState locale;
  final VoidCallback onWatchNow;

  const _HeroBannerItem({
    required this.drama,
    required this.locale,
    required this.onWatchNow,
  });

  @override
  Widget build(BuildContext context) {
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
              child: DramaNetworkImage(
                imageUrl: drama.coverUrl,
                fit: BoxFit.cover,
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
                    drama.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heroSerifItalic,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    drama.description,
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
  final DramaCard drama;
  final LocaleState locale;
  final VoidCallback onTap;

  const _ContinueWatchingCard({
    required this.drama,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cw = drama.continueWatching;
    final epNo = (cw?.episodeNumber ?? 0) > 0 ? cw!.episodeNumber : 1;
    final totalEps = drama.totalEpisodes > 0 ? drama.totalEpisodes : epNo;
    final progress = (cw != null && cw.percentWatched > 0)
        ? (cw.percentWatched / 100.0).clamp(0.05, 1.0)
        : (epNo / totalEps).clamp(0.1, 1.0);

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
                    opacity: 0.45,
                    child: DramaNetworkImage(
                      imageUrl: drama.coverUrl,
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
              drama.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.continueCardTitle,
            ),
            SizedBox(height: 2.h),
            Text(
              '${locale.tr('episode_prefix')} $epNo',
              style: AppTextStyles.continueEpisodeText,
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterGridItem extends StatelessWidget {
  final DramaCard drama;
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
            drama.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.posterTitle,
          ),
        ],
      ),
    );
  }
}
