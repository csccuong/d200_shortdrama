import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/placement/show_placement_ad.dart';
import '../../core/di/injection.dart';
import '../../core/startup/app_startup_coordinator.dart';
import '../../core/utils/screen_utils.dart';
import '../../models/drama_card.dart';
import '../../models/episode_detail.dart';
import '../../models/feed_response.dart';
import '../../models/taxonomy_models.dart';
import '../../providers/app_providers.dart';
import '../../widgets/drama_network_image.dart';
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
  final ScrollController _allDramasScrollCtrl = ScrollController();
  final Dio _prefetchDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  final Set<String> _prefetchedUrls = {};

  int _topTab = 0; // 0: For you (Vertical Feed) | 1: All Dramas
  int _currentIndex = 0;
  bool _isPushedRouteActive = false;

  // Per-slide preview telemetry tracking
  int _activePosSec = 0;
  bool _didTrackStart = false;
  bool _didTrackWatch3s = false;
  bool _didTrackFinish = false;

  // All Dramas filter & pagination state
  String _selectedCategory = 'all';
  String _selectedCountry = 'all';
  String _selectedRegion = 'all';
  String _selectedAudioMode = 'all';
  String _selectedTag = '';
  String _sortBy = 'popular';
  List<DramaCard> _allDramas = [];
  int _allPage = 1;
  bool _allHasMore = true;
  bool _isLoadingAll = false;
  String? _allError;

  @override
  void initState() {
    super.initState();
    _allDramasScrollCtrl.addListener(_onAllDramasScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isTabActive) {
        _ensureFeedLoaded();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ShortsFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isTabActive && widget.isTabActive) {
      _ensureFeedLoaded();
      if (_topTab == 1 && _allDramas.isEmpty) {
        unawaited(_loadAllDramas(reset: true));
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _allDramasScrollCtrl.dispose();
    _prefetchDio.close();
    super.dispose();
  }

  void _ensureFeedLoaded() {
    final sessionReady =
        ref.read(sessionProvider).asData?.value.isInitialized ?? false;
    final feed = ref.read(feedProvider);
    if (sessionReady && feed.items.isEmpty && !feed.isLoadingMore) {
      unawaited(
        ref
            .read(feedProvider.notifier)
            .fetchInitialFeed(ref.read(localeProvider).appLanguage),
      );
    }
  }

  void _onAllDramasScroll() {
    if (!_allDramasScrollCtrl.hasClients) return;
    if (_allDramasScrollCtrl.position.pixels >=
            _allDramasScrollCtrl.position.maxScrollExtent - 300 &&
        _allHasMore &&
        !_isLoadingAll) {
      unawaited(_loadAllDramas(reset: false));
    }
  }

  Future<void> _loadAllDramas({required bool reset}) async {
    if (_isLoadingAll && !reset) return;
    final nextPage = reset ? 1 : (_allPage + 1);
    setState(() {
      _isLoadingAll = true;
      if (reset) _allError = null;
    });

    try {
      final res = await ref.read(homeApiServiceProvider).browseDramas(
            page: nextPage,
            pageSize: 21,
            country: _selectedCountry,
            region: _selectedRegion,
            audioMode: _selectedAudioMode,
            category: _selectedCategory,
            tags: _selectedTag,
            sort: _sortBy,
            lang: ref.read(localeProvider).appLanguage,
          );
      if (!mounted) return;
      setState(() {
        _allDramas = reset ? res.items : [..._allDramas, ...res.items];
        _allPage = res.pagination.page;
        _allHasMore = res.pagination.hasMore;
        _isLoadingAll = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAll = false;
        _allError = e.toString();
      });
    }
  }

  void _prefetchAhead(List<ForYouItem> items, int currentIdx) {
    final coord = inject<AppStartupCoordinator>();
    for (int offset = 1; offset <= 2; offset++) {
      final targetIdx = currentIdx + offset;
      if (targetIdx >= items.length) continue;
      final rawUrl = items[targetIdx].preview?.videoUrl ?? '';
      if (rawUrl.isEmpty) continue;
      final resolved = coord.resolveMediaUrl(rawUrl);
      if (resolved.isEmpty || _prefetchedUrls.contains(resolved)) continue;
      _prefetchedUrls.add(resolved);
      unawaited(
        _prefetchDio
            .get<List<int>>(
              resolved,
              options: Options(
                headers: const {'Range': 'bytes=0-1500000'},
                responseType: ResponseType.bytes,
              ),
            )
            .then<void>((_) {}, onError: (_) {}),
      );
    }
  }

  Future<void> _openFullDrama(
    DramaCard drama, {
    int? startEpisode,
    int positionSec = 0,
    bool fromForYouButton = false,
  }) async {
    final ep = startEpisode ??
        ((drama.continueWatching?.episodeNumber ?? 0) > 0
            ? drama.continueWatching!.episodeNumber
            : 1);

    if (fromForYouButton) {
      ref.read(feedProvider.notifier).trackEvent(
            drama.dramaId,
            'click_full_drama',
          );
    }
    ref.read(eventTrackerProvider).track(
      fromForYouButton ? 'click_full_drama' : 'drama_click',
      dramaId: drama.dramaId,
      episodeNumber: ep,
      positionSec: positionSec,
      sourceScreen: _topTab == 0 ? 'for_you' : 'all_dramas',
    );

    setState(() => _isPushedRouteActive = true);
    showInterAllThen(context, ref, () async {
      await _pushFullDrama(
        drama,
        ep,
        positionSec: positionSec,
      );
    });
  }

  Future<void> _pushFullDrama(
    DramaCard drama,
    int startEp, {
    int positionSec = 0,
  }) async {
    await ref.read(navigationServiceProvider).push(
          context,
          DramaPlayerScreen(
            dramaCard: drama,
            dramaId: drama.dramaId,
            initialEpisode: startEp,
            initialPositionSec: positionSec,
            sourceScreen: _topTab == 0 ? 'for_you' : 'all_dramas',
          ),
        );
    if (mounted) {
      setState(() => _isPushedRouteActive = false);
    }
  }

  Future<void> _openEpisodeSheet(DramaCard drama, int currentEp) async {
    EpisodesListResponse? epRes;
    try {
      epRes = await ref.read(dramaApiServiceProvider).fetchEpisodes(
            drama.dramaId,
            pageSize: 100,
            lang: ref.read(localeProvider).appLanguage,
          );
    } catch (_) {
      epRes = null;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => EpisodeSelectorSheet(
        drama: drama,
        currentEpisode: currentEp,
        episodes: epRes?.items ?? const [],
        isVipUser: epRes?.isUserVip ?? false,
        onSelectEpisode: (epNo) => _openFullDrama(drama, startEpisode: epNo),
      ),
    );
  }

  void _openFilterSheet(Taxonomy? taxonomy, LocaleState locale) {
    final categories = <({String slug, String name})>[
      (slug: 'all', name: locale.tr('all_categories')),
      if (taxonomy != null)
        ...taxonomy.categories.map((c) => (slug: c.slug, name: c.name)),
    ];
    final countries = taxonomy?.facets.countries ?? const <FacetCountry>[];
    final regions = taxonomy?.facets.regions ?? const <FacetRegion>[];
    final audioModes = taxonomy?.facets.audioModes ?? const <FacetAudioMode>[];
    final sorts = (taxonomy?.facets.sorts.isNotEmpty ?? false)
        ? taxonomy!.facets.sorts
        : [
            FacetSort(code: 'popular', name: locale.tr('sort_popular')),
            FacetSort(code: 'rating', name: locale.tr('sort_rating')),
            FacetSort(code: 'latest', name: locale.tr('tab_new')),
            FacetSort(code: 'trending', name: locale.tr('trending_now')),
          ];

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
              constraints: BoxConstraints(maxHeight: 0.82.sh),
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
              child: SingleChildScrollView(
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
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = 'all';
                              _selectedCountry = 'all';
                              _selectedRegion = 'all';
                              _selectedAudioMode = 'all';
                              _selectedTag = '';
                              _sortBy = 'popular';
                            });
                            setSheetState(() {});
                            unawaited(_loadAllDramas(reset: true));
                          },
                          child: Text(
                            locale.tr('cat_all'),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryBright,
                            ),
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
                    if (categories.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(
                        locale.tr('tab_categories'),
                        style: AppTextStyles.caption,
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: categories.map((c) {
                          final active = c.slug == _selectedCategory;
                          return _FilterSheetChip(
                            label: c.name,
                            active: active,
                            onTap: () {
                              setState(() => _selectedCategory = c.slug);
                              setSheetState(() {});
                              unawaited(_loadAllDramas(reset: true));
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    if (countries.isNotEmpty) ...[
                      SizedBox(height: 14.h),
                      Text('Country', style: AppTextStyles.caption),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          _FilterSheetChip(
                            label: locale.tr('cat_all'),
                            active: _selectedCountry == 'all',
                            onTap: () {
                              setState(() => _selectedCountry = 'all');
                              setSheetState(() {});
                              unawaited(_loadAllDramas(reset: true));
                            },
                          ),
                          ...countries.map(
                            (c) => _FilterSheetChip(
                              label: '${c.flag} ${c.name}'.trim(),
                              active: _selectedCountry == c.code,
                              onTap: () {
                                setState(() => _selectedCountry = c.code);
                                setSheetState(() {});
                                unawaited(_loadAllDramas(reset: true));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (regions.isNotEmpty) ...[
                      SizedBox(height: 14.h),
                      Text('Region', style: AppTextStyles.caption),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          _FilterSheetChip(
                            label: locale.tr('cat_all'),
                            active: _selectedRegion == 'all',
                            onTap: () {
                              setState(() => _selectedRegion = 'all');
                              setSheetState(() {});
                              unawaited(_loadAllDramas(reset: true));
                            },
                          ),
                          ...regions.map(
                            (r) => _FilterSheetChip(
                              label: r.name,
                              active: _selectedRegion == r.code,
                              onTap: () {
                                setState(() => _selectedRegion = r.code);
                                setSheetState(() {});
                                unawaited(_loadAllDramas(reset: true));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (audioModes.isNotEmpty) ...[
                      SizedBox(height: 14.h),
                      Text(locale.tr('sub_label'), style: AppTextStyles.caption),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          _FilterSheetChip(
                            label: locale.tr('cat_all'),
                            active: _selectedAudioMode == 'all',
                            onTap: () {
                              setState(() => _selectedAudioMode = 'all');
                              setSheetState(() {});
                              unawaited(_loadAllDramas(reset: true));
                            },
                          ),
                          ...audioModes.map(
                            (a) => _FilterSheetChip(
                              label: a.name,
                              active: _selectedAudioMode == a.code,
                              onTap: () {
                                setState(() => _selectedAudioMode = a.code);
                                setSheetState(() {});
                                unawaited(_loadAllDramas(reset: true));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 14.h),
                    Text(locale.tr('filter_sort'), style: AppTextStyles.caption),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: sorts.map((opt) {
                        return _FilterSheetChip(
                          label: opt.name,
                          active: _sortBy == opt.code,
                          onTap: () {
                            setState(() => _sortBy = opt.code);
                            setSheetState(() {});
                            unawaited(_loadAllDramas(reset: true));
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSearchSheet() async {
    setState(() => _isPushedRouteActive = true);
    final selectedDrama = await showModalBottomSheet<DramaCard>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => const _ForYouSearchSheet(),
    );
    if (!mounted) return;
    if (selectedDrama != null) {
      await _openFullDrama(selectedDrama);
    } else {
      setState(() => _isPushedRouteActive = false);
    }
  }

  bool get _hasActiveBrowseFilter =>
      _selectedCategory != 'all' ||
      _selectedCountry != 'all' ||
      _selectedRegion != 'all' ||
      _selectedAudioMode != 'all' ||
      _selectedTag.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!widget.isTabActive) {
      return const ColoredBox(color: AppColors.background);
    }

    final feedState = ref.watch(feedProvider);
    final locale = ref.watch(localeProvider);
    final sessionAsync = ref.watch(sessionProvider);
    final taxonomy = sessionAsync.asData?.value.initData?.taxonomy;
    final autoPlayNext =
        ref.watch(userWalletProvider.select((s) => s.autoPlayNext));

    ref.listen<LocaleState>(localeProvider, (prev, next) {
      if (prev?.appLanguage != next.appLanguage &&
          (sessionAsync.asData?.value.isInitialized ?? false)) {
        unawaited(ref.read(feedProvider.notifier).fetchInitialFeed(next.appLanguage));
        if (_topTab == 1) {
          unawaited(_loadAllDramas(reset: true));
        }
      }
    });

    final feedItems = feedState.items;

    return Stack(
      children: [
        // Sub-tab 0: Vertical Short Video Feed ("For you")
        if (_topTab == 0)
          _buildForYouFeed(
            feedItems: feedItems,
            feedState: feedState,
            locale: locale,
            autoPlayNext: autoPlayNext,
          )
        // Sub-tab 1: "All Dramas" Browser (3 Columns + Multi-Facet Filter)
        else
          _buildAllDramasBrowser(taxonomy: taxonomy, locale: locale),

        // Subtle Top Scrim over Video Feed
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

        // Floating Top Header: "For you" | "All Dramas" + Search Icon
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
                          onTap: () {
                            setState(() => _topTab = 1);
                            if (_allDramas.isEmpty && !_isLoadingAll) {
                              unawaited(_loadAllDramas(reset: true));
                            }
                          },
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _openSearchSheet,
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
  }

  Widget _buildForYouFeed({
    required List<ForYouItem> feedItems,
    required FeedState feedState,
    required LocaleState locale,
    required bool autoPlayNext,
  }) {
    if (feedItems.isEmpty && feedState.isLoadingMore) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
        ),
      );
    }

    if (feedItems.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.movie_filter_outlined,
                color: AppColors.textWhite38,
                size: 46.sp,
              ),
              SizedBox(height: 12.h),
              Text(
                locale.tr('empty_following'),
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 14.h),
              ElevatedButton.icon(
                onPressed: () => unawaited(
                  ref
                      .read(feedProvider.notifier)
                      .fetchInitialFeed(locale.appLanguage),
                ),
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
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      onRefresh: () =>
          ref.read(feedProvider.notifier).refresh(locale.appLanguage),
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: AppScreenUtils.adaptiveScrollPhysics,
        itemCount: feedItems.length,
        onPageChanged: (idx) {
          if (_currentIndex < feedItems.length && _activePosSec < 3) {
            final prev = feedItems[_currentIndex];
            ref.read(feedProvider.notifier).trackEvent(
                  prev.dramaId,
                  'skip_fast',
                );
            ref.read(eventTrackerProvider).track(
              'skip_fast',
              dramaId: prev.dramaId,
              watchedSec: _activePosSec,
              sourceScreen: 'for_you',
            );
          }

          setState(() {
            _currentIndex = idx;
            _activePosSec = 0;
            _didTrackStart = false;
            _didTrackWatch3s = false;
            _didTrackFinish = false;
          });

          // Prefetch next cursor when reaching last 5 items (doc §6.1)
          if (idx >= feedItems.length - 5 && feedState.hasMore) {
            unawaited(
              ref.read(feedProvider.notifier).loadMore(locale.appLanguage),
            );
          }

          // Prefetch bytes 0-1.5MB for upcoming 2 slides
          _prefetchAhead(feedItems, idx);
        },
        itemBuilder: (context, index) {
          final item = feedItems[index];
          final previewEp = item.preview?.episodeNumber ?? 1;
          final targetEp = (item.preview?.watchFullDramaTargetEpisode ?? 0) > 0
              ? item.preview!.watchFullDramaTargetEpisode
              : previewEp;
          final active = widget.isTabActive &&
              _topTab == 0 &&
              !_isPushedRouteActive &&
              _currentIndex == index;

          return ShortVideoItem(
            drama: item,
            episodeNo: previewEp,
            previewInfo: item.preview,
            sourceScreen: 'for_you',
            isActive: active,
            showFullDramaButton: true,
            onOpenFullDrama: () => _openFullDrama(
              item,
              startEpisode: targetEp,
              positionSec: _activePosSec,
              fromForYouButton: true,
            ),
            onOpenEpisodeList: () => _openEpisodeSheet(item, previewEp),
            onPlaybackUpdate: (posSec, durSec, isPlaying) {
              if (!active || !isPlaying) return;
              _activePosSec = posSec;
              if (!_didTrackStart) {
                _didTrackStart = true;
                ref.read(eventTrackerProvider).track(
                  'preview_start',
                  dramaId: item.dramaId,
                  episodeNumber: previewEp,
                  sourceScreen: 'for_you',
                );
              }
              if (!_didTrackWatch3s && posSec >= 3) {
                _didTrackWatch3s = true;
                ref
                    .read(feedProvider.notifier)
                    .trackEvent(item.dramaId, 'watch_3s');
                ref.read(eventTrackerProvider).track(
                  'watch_3s',
                  dramaId: item.dramaId,
                  episodeNumber: previewEp,
                  watchedSec: posSec,
                  sourceScreen: 'for_you',
                );
              }
            },
            onVideoEnded: () {
              if (!_didTrackFinish) {
                _didTrackFinish = true;
                ref
                    .read(feedProvider.notifier)
                    .trackEvent(item.dramaId, 'finish_preview');
                ref.read(eventTrackerProvider).track(
                  'finish_preview',
                  dramaId: item.dramaId,
                  episodeNumber: previewEp,
                  sourceScreen: 'for_you',
                );
              }
              if (autoPlayNext && _currentIndex < feedItems.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildAllDramasBrowser({
    required Taxonomy? taxonomy,
    required LocaleState locale,
  }) {
    return Container(
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
                onTap: () => _openFilterSheet(taxonomy, locale),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedCategory == 'all'
                            ? locale.tr('tab_filter')
                            : '${locale.tr('tab_filter')} • $_selectedCategory',
                        style: AppTextStyles.filterButtonLabel,
                      ),
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.tune_rounded,
                        color: _hasActiveBrowseFilter
                            ? AppColors.primary
                            : AppColors.profileIdText,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceCard,
              onRefresh: () => _loadAllDramas(reset: true),
              child: _allDramas.isEmpty && _isLoadingAll
                  ? const Center(
                      child: CircularProgressIndicator.adaptive(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBright,
                        ),
                      ),
                    )
                  : _allDramas.isEmpty && _allError != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _allError!,
                                style: AppTextStyles.caption,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 12.h),
                              ElevatedButton(
                                onPressed: () =>
                                    unawaited(_loadAllDramas(reset: true)),
                                child: Text(locale.tr('retry_btn')),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          controller: _allDramasScrollCtrl,
                          padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 24.h),
                          physics: AlwaysScrollableScrollPhysics(
                            parent: AppScreenUtils.adaptiveScrollPhysics,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                AppScreenUtils.posterGridColumns(context),
                            mainAxisSpacing: 14.h,
                            crossAxisSpacing: 10.w,
                            childAspectRatio: 0.61,
                          ),
                          itemCount: _allDramas.length,
                          itemBuilder: (context, idx) {
                            final d = _allDramas[idx];
                            return _AllDramasPosterCard(
                              drama: d,
                              locale: locale,
                              onTap: () => _openFullDrama(
                                d,
                                positionSec:
                                    d.continueWatching?.positionSec ?? 0,
                              ),
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

class _FilterSheetChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterSheetChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: active ? null : AppColors.searchBarBg,
          gradient: active ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: active ? AppColors.transparent : AppColors.borderSubtle,
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
  const _ForYouSearchSheet();

  @override
  ConsumerState<_ForYouSearchSheet> createState() => _ForYouSearchSheetState();
}

class _ForYouSearchSheetState extends ConsumerState<_ForYouSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<String> _hotKeywords = [];
  List<DramaCard> _hotDramas = [];
  List<DramaCard> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadHot());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHot() async {
    try {
      final lang = ref.read(localeProvider).appLanguage;
      final data = await ref.read(homeApiServiceProvider).searchHot(lang: lang);
      final rawKws = data['hot_keywords'] ?? data['keywords'];
      final rawDramas = data['hot_dramas'] ?? data['trending'] ?? data['dramas'];
      if (!mounted) return;
      setState(() {
        if (rawKws is List) {
          _hotKeywords = rawKws
              .map((e) => e is Map ? (e['keyword'] ?? e['title'] ?? '').toString() : e.toString())
              .where((s) => s.trim().isNotEmpty)
              .take(8)
              .toList();
        }
        if (rawDramas is List) {
          _hotDramas = rawDramas
              .whereType<Map<String, dynamic>>()
              .map(DramaCard.fromJson)
              .toList();
        }
      });
    } catch (_) {
      final rec = ref.read(homeProvider).asData?.value.recommendedDramas ?? const [];
      if (mounted && rec.isNotEmpty) {
        setState(() => _hotDramas = rec.take(9).toList());
      }
    }
  }

  void _onChanged(String val) {
    setState(() => _query = val);
    _debounce?.cancel();
    final q = val.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(q));
    });
  }

  Future<void> _runSearch(String q) async {
    setState(() => _isLoading = true);
    try {
      final lang = ref.read(localeProvider).appLanguage;
      final res =
          await ref.read(homeApiServiceProvider).search(query: q, lang: lang);
      if (!mounted || _query.trim() != q) return;
      setState(() {
        _searchResults = res.items;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom +
        AppScreenUtils.bottomSafeInset(context);
    final q = _query.trim();
    final results = q.isEmpty ? _hotDramas : _searchResults;

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
                          onChanged: _onChanged,
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
                            _onChanged('');
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
          if (q.isEmpty && _hotKeywords.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: _hotKeywords.map((kw) {
                return GestureDetector(
                  onTap: () {
                    _searchCtrl.text = kw;
                    _onChanged(kw);
                  },
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: AppColors.searchBarBg,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(kw, style: AppTextStyles.caption),
                  ),
                );
              }).toList(),
            ),
          ],
          SizedBox(height: 14.h),
          Text(
            q.isEmpty
                ? locale.tr('trending_now')
                : '${locale.tr('search_results')} (${results.length})',
            style: AppTextStyles.sectionTitle,
          ),
          SizedBox(height: 10.h),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBright,
                      ),
                    ),
                  )
                : GridView.builder(
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
  final DramaCard drama;
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
                  DramaNetworkImage(
                    imageUrl: drama.coverUrl,
                    fit: BoxFit.cover,
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
                        drama.isVip
                            ? locale.tr('tab_vip')
                            : locale.tr('badge_hot'),
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
              drama.title,
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
