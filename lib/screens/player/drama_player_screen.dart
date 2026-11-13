import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ads/const/ad_id_extension.dart';
import '../../ads/const/ad_id_name.dart';
import '../../ads/nativefull/native_full_screen.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/screen_utils.dart';
import '../../models/drama_card.dart';
import '../../models/episode_detail.dart';
import '../../providers/app_providers.dart';
import '../../services/firebase_remote_config_service.dart';
import '../../widgets/episode_selector_sheet.dart';
import '../../widgets/floating_drama_native_ad.dart';
import '../../widgets/player_settings_sheet.dart';
import '../../widgets/short_video_item.dart';

class DramaPlayerScreen extends ConsumerStatefulWidget {
  final DramaCard? dramaCard;
  final String? dramaId;
  final int initialEpisode;
  final int initialPositionSec;
  final String sourceScreen;

  const DramaPlayerScreen({
    super.key,
    this.dramaCard,
    this.dramaId,
    this.initialEpisode = 1,
    this.initialPositionSec = 0,
    this.sourceScreen = 'home',
  }) : assert(dramaCard != null || dramaId != null);

  @override
  ConsumerState<DramaPlayerScreen> createState() => _DramaPlayerScreenState();
}

class _DramaPlayerScreenState extends ConsumerState<DramaPlayerScreen> {
  static const int _nativeFullEveryEpisodes = 2;
  static const int _heartbeatIntervalSec = 30;

  late PageController _pageController;
  late int _currentEpisode;
  int _episodeChangesSinceNativeFull = 0;
  bool _nativeFullOpen = false;

  final Set<int> _locallyUnlockedEpisodes = {};
  bool _fullDramaUnlocked = false;
  final Set<String> _notifiedTasks = {};

  Timer? _watchTimer;
  int _watchSecondsDelta = 0;
  int _lastPosSec = 0;
  int _lastDurSec = 0;
  bool _isChildPlaying = false;
  bool _didUseInitialSeek = false;

  String get _resolvedDramaId =>
      widget.dramaId ?? widget.dramaCard?.dramaId ?? '';

  @override
  void initState() {
    super.initState();
    final safeInitialEp = widget.initialEpisode < 1 ? 1 : widget.initialEpisode;
    _currentEpisode = safeInitialEp;
    _pageController = PageController(initialPage: safeInitialEp - 1);
    _lastPosSec = widget.initialPositionSec;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(eventTrackerProvider).track(
        'episode_start',
        dramaId: _resolvedDramaId,
        episodeNumber: _currentEpisode,
        positionSec: widget.initialPositionSec,
        sourceScreen: widget.sourceScreen,
      );
      _startHeartbeatTicker();
    });
  }

  void _startHeartbeatTicker() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isChildPlaying || _nativeFullOpen) return;
      _watchSecondsDelta++;
      if (_watchSecondsDelta >= _heartbeatIntervalSec) {
        unawaited(_flushWatchProgress(episodeNumber: _currentEpisode));
      }
    });
  }

  Future<void> _flushWatchProgress({
    required int episodeNumber,
    bool saveHistory = true,
  }) async {
    final delta = _watchSecondsDelta.clamp(0, 180);
    _watchSecondsDelta = 0;

    if (saveHistory && _resolvedDramaId.isNotEmpty) {
      unawaited(
        ref.read(mylistProvider.notifier).saveHistory(
              dramaId: _resolvedDramaId,
              episodeNumber: episodeNumber,
              positionSec: _lastPosSec,
              durationSec: _lastDurSec,
            ),
      );
    }

    if (delta <= 0 || _resolvedDramaId.isEmpty) return;

    try {
      final resp = await ref.read(appApiServiceProvider).heartbeat(
            watchSecondsDelta: delta,
            dramaId: _resolvedDramaId,
            episodeNumber: episodeNumber,
            positionSec: _lastPosSec,
            durationSec: _lastDurSec,
          );

      final claimable = resp['claimable_watch_tasks'] as List<dynamic>? ?? [];
      if (claimable.isNotEmpty && mounted) {
        final newCodes = claimable
            .map((e) => e.toString())
            .where((c) => c.isNotEmpty && !_notifiedTasks.contains(c))
            .toList();
        if (newCodes.isNotEmpty) {
          _notifiedTasks.addAll(newCodes);
          unawaited(
            ref
                .read(rewardsProvider.notifier)
                .fetchOverview(AppConstants.selectedLanguageCode),
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${ref.read(localeProvider).tr('claim_btn')}: ${newCodes.join(', ')}',
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (_) {
      // Do not interrupt video playback on transient telemetry errors
    }
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    final ep = _currentEpisode;
    final delta = _watchSecondsDelta.clamp(0, 180);
    final pos = _lastPosSec;
    final dur = _lastDurSec;
    final id = _resolvedDramaId;
    if (id.isNotEmpty) {
      unawaited(
        Future(() async {
          try {
            await ref.read(mylistProvider.notifier).saveHistory(
                  dramaId: id,
                  episodeNumber: ep,
                  positionSec: pos,
                  durationSec: dur,
                );
            if (delta > 0) {
              await ref.read(appApiServiceProvider).heartbeat(
                    watchSecondsDelta: delta,
                    dramaId: id,
                    episodeNumber: ep,
                    positionSec: pos,
                    durationSec: dur,
                  );
            }
          } catch (_) {}
        }),
      );
    }
    _pageController.dispose();
    super.dispose();
  }

  int _resolveTotalEpisodes(DramaCard? card, List<EpisodeItem> episodes) {
    if (card != null && card.totalEpisodes > 0) return card.totalEpisodes;
    if (episodes.isNotEmpty) return episodes.length;
    return _currentEpisode > 1 ? _currentEpisode : 1;
  }

  void _jumpToEpisode(int epNo, int totalEpisodes) {
    final target = epNo.clamp(1, totalEpisodes);
    if (target != _currentEpisode) {
      unawaited(_flushWatchProgress(episodeNumber: _currentEpisode));
    }
    setState(() {
      _currentEpisode = target;
      _lastPosSec = 0;
      _lastDurSec = 0;
      _didUseInitialSeek = true;
    });
    _pageController.jumpToPage(target - 1);
  }

  Future<void> _openEpisodeSheet(
    DramaCard drama,
    List<EpisodeItem> episodes,
    bool isVipUser,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => EpisodeSelectorSheet(
        drama: drama,
        currentEpisode: _currentEpisode,
        episodes: episodes,
        isVipUser: isVipUser,
        locallyUnlockedEpisodes: _locallyUnlockedEpisodes,
        fullDramaUnlocked: _fullDramaUnlocked,
        onSelectEpisode: (epNo) => _jumpToEpisode(
          epNo,
          _resolveTotalEpisodes(drama, episodes),
        ),
      ),
    );
  }

  bool get _canShowNativeFull {
    if (!AppConstants.isMobilePlatform) return false;
    final apiVip = ref.read(walletProvider).isVip;
    final legacyVip = ref.read(userWalletProvider).isVip;
    if (AppConstants.isPremiumUser.value || apiVip || legacyVip) {
      return false;
    }
    if (!FirebaseRemoteConfigService.getBoolConfigByKey(
      FirebaseRemoteConfigService.native_full,
    )) {
      return false;
    }
    final adId = MyAdIdName.nativeFull.getId;
    return adId.isNotEmpty && adId != 'null';
  }

  void _onEpisodeChanged() {
    if (_nativeFullOpen || !_canShowNativeFull) return;
    _episodeChangesSinceNativeFull++;
    if (_episodeChangesSinceNativeFull < _nativeFullEveryEpisodes) return;
    _episodeChangesSinceNativeFull = 0;
    _nativeFullOpen = true;
    setState(() {});
    _presentNativeFull();
  }

  Future<void> _presentNativeFull() async {
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (routeContext, _, _) {
          return NativeFullScreen(
            nativeFullId: MyAdIdName.nativeFull.getId,
            adIdName: MyAdIdName.nativeFull,
            handleNavigate: () {
              final routeNav = Navigator.of(routeContext);
              if (routeNav.canPop()) routeNav.pop();
            },
          );
        },
      ),
    );
    _nativeFullOpen = false;
    if (mounted) setState(() {});
  }

  void _onVideoEnded(int totalEpisodes) {
    ref.read(eventTrackerProvider).track(
      'episode_complete',
      dramaId: _resolvedDramaId,
      episodeNumber: _currentEpisode,
      watchedSec: _lastDurSec,
      sourceScreen: widget.sourceScreen,
    );
    unawaited(_flushWatchProgress(episodeNumber: _currentEpisode));

    final autoPlay = ref.read(userWalletProvider).autoPlayNext;
    if (autoPlay && _currentEpisode < totalEpisodes) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final detailAsync = ref.watch(dramaDetailProvider(_resolvedDramaId));
    final detailData = detailAsync.asData?.value;

    final effectiveDrama = detailData?.dramaDetail ?? widget.dramaCard;
    final episodes = detailData?.episodes.items ?? const <EpisodeItem>[];
    final isVipUser = (detailData?.episodes.isUserVip ?? false) ||
        ref.watch(walletProvider.select((s) => s.isVip));

    if (effectiveDrama == null) {
      if (detailAsync.isLoading) {
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator.adaptive(
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
        ),
        body: Center(
          child: Text(
            detailAsync.error?.toString() ?? 'Unable to load drama',
            style: AppTextStyles.bodySmall,
          ),
        ),
      );
    }

    final totalEpisodes = _resolveTotalEpisodes(effectiveDrama, episodes);
    final subLangs = effectiveDrama.availableSubLangs;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: AppScreenUtils.adaptiveScrollPhysics,
            itemCount: totalEpisodes,
            onPageChanged: (index) {
              final prevEp = _currentEpisode;
              final nextEp = index + 1;
              if (prevEp != nextEp) {
                unawaited(_flushWatchProgress(episodeNumber: prevEp));
              }
              setState(() {
                _currentEpisode = nextEp;
                _lastPosSec = 0;
                _lastDurSec = 0;
                _didUseInitialSeek = true;
                _isChildPlaying = false;
              });
              ref.read(eventTrackerProvider).track(
                'episode_start',
                dramaId: _resolvedDramaId,
                episodeNumber: nextEp,
                sourceScreen: widget.sourceScreen,
              );
              _onEpisodeChanged();
            },
            itemBuilder: (context, index) {
              final epNo = index + 1;
              final initPos =
                  !_didUseInitialSeek && epNo == widget.initialEpisode
                      ? widget.initialPositionSec
                      : 0;
              return ShortVideoItem(
                drama: effectiveDrama,
                episodeNo: epNo,
                initialPositionSec: initPos,
                sourceScreen: widget.sourceScreen,
                isActive: _currentEpisode == epNo && !_nativeFullOpen,
                onVideoEnded: () => _onVideoEnded(totalEpisodes),
                onOpenEpisodeList: () =>
                    _openEpisodeSheet(effectiveDrama, episodes, isVipUser),
                showFullDramaButton: false,
                onEpisodeUnlocked: (unlockedEp, fullDrama) {
                  setState(() {
                    _locallyUnlockedEpisodes.add(unlockedEp);
                    if (fullDrama) _fullDramaUnlocked = true;
                  });
                  ref.invalidate(dramaDetailProvider(_resolvedDramaId));
                },
                onPlaybackUpdate: (posSec, durSec, isPlaying) {
                  if (epNo != _currentEpisode) return;
                  final wasPlaying = _isChildPlaying;
                  _lastPosSec = posSec;
                  _lastDurSec = durSec;
                  _isChildPlaying = isPlaying;
                  if (wasPlaying && !isPlaying && _watchSecondsDelta > 0) {
                    unawaited(
                      _flushWatchProgress(episodeNumber: _currentEpisode),
                    );
                  }
                },
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        AppScreenUtils.isIOS
                            ? Icons.arrow_back_ios_new_rounded
                            : Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                        size: 20.sp,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            effectiveDrama.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.playerHeaderTitle,
                          ),
                          Text(
                            '${locale.tr('episode_prefix')} $_currentEpisode / $totalEpisodes',
                            style: AppTextStyles.playerHeaderSubtitle,
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openEpisodeSheet(
                        effectiveDrama,
                        episodes,
                        isVipUser,
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.overlayMedium,
                        foregroundColor: AppColors.textPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                      icon: Icon(Icons.list_rounded, size: 17.sp),
                      label: Text(
                        locale.tr('select_episode'),
                        style: AppTextStyles.buttonMedium,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    GestureDetector(
                      onTap: () => PlayerSettingsSheet.show(
                        context,
                        availableSubLangs: subLangs,
                      ),
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: const BoxDecoration(
                          color: AppColors.overlayMedium,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: AppColors.textPrimary,
                          size: 19.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          FloatingDramaNativeAd(
            dramaSlug: _resolvedDramaId,
            episodeNo: _currentEpisode,
            hold: _nativeFullOpen,
          ),
        ],
      ),
    );
  }
}
