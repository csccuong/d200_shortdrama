import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../ads/const/ad_id_extension.dart';
import '../ads/const/ad_id_name.dart';
import '../ads/placement/show_placement_ad.dart';
import '../core/network/drama_dio_interceptor.dart';
import '../core/utils/app_toast.dart';
import '../core/utils/screen_utils.dart';
import '../models/drama_card.dart';
import '../models/drama_models.dart';
import '../models/feed_response.dart';
import '../models/play_response.dart';
import '../providers/app_providers.dart';
import '../services/app_strings.dart';
import '../services/srt_parser.dart';
import 'drama_network_image.dart';
import 'player_settings_sheet.dart';
import 'unlock_reward_overlay.dart';

class ShortVideoItem extends ConsumerStatefulWidget {
  final DramaCard drama;
  final int episodeNo;
  final bool isActive;
  final PreviewInfo? previewInfo;
  final int initialPositionSec;
  final String sourceScreen;
  final VoidCallback? onVideoEnded;
  final FutureOr<void> Function()? onOpenEpisodeList;
  final VoidCallback? onOpenFullDrama;
  final bool showFullDramaButton;
  final int? requiredUnlockEpisode;
  final void Function(int episodeNo, bool fullDrama)? onEpisodeUnlocked;
  final void Function(int posSec, int durSec, bool isPlaying)? onPlaybackUpdate;
  final void Function(List<String> subLangs)? onSubtitlesLoaded;

  const ShortVideoItem({
    super.key,
    required this.drama,
    required this.episodeNo,
    required this.isActive,
    this.previewInfo,
    this.initialPositionSec = 0,
    this.sourceScreen = 'player',
    this.onVideoEnded,
    this.onOpenEpisodeList,
    this.onOpenFullDrama,
    this.showFullDramaButton = false,
    this.requiredUnlockEpisode,
    this.onEpisodeUnlocked,
    this.onPlaybackUpdate,
    this.onSubtitlesLoaded,
  });

  @override
  ConsumerState<ShortVideoItem> createState() => _ShortVideoItemState();
}

class _ShortVideoItemState extends ConsumerState<ShortVideoItem>
    with WidgetsBindingObserver {
  static const List<double> _speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
  static const String _icSave = 'assets/icons/ic_player_save.png';
  static const String _icSaveSelected =
      'assets/icons/ic_player_save_selected.png';
  static const String _icEpisodes = 'assets/icons/ic_player_episodes.png';
  static const String _icEpisodesSelected =
      'assets/icons/ic_player_episodes_selected.png';
  static const String _icSubtitle = 'assets/icons/ic_player_subtitle.png';
  static const String _icSubtitleSelected =
      'assets/icons/ic_player_subtitle_selected.png';

  VideoPlayerController? _controller;
  List<SubtitleTrack> _subTracks = [];
  List<SubtitleCue> _cues = [];
  String? _activeSubtitle;
  int _subtitleLoadSeq = 0;

  bool _isLoadingPlay = false;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  PaywallResponse? _paywall;
  String _blockReason = '';
  bool _isUnlocking = false;

  bool _isPausedByUser = false;
  bool _didTriggerEnd = false;
  bool _didApplyInitialSeek = false;
  bool _isEpisodeSheetOpen = false;
  bool _hasRequestedPlay = false;
  int _lastTickEmitSec = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.isActive) {
        _initEpisode();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_safePause(ctrl));
    } else if (state == AppLifecycleState.resumed) {
      _updatePlaybackState();
    }
  }

  @override
  void didUpdateWidget(covariant ShortVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drama.dramaId != widget.drama.dramaId ||
        oldWidget.episodeNo != widget.episodeNo ||
        oldWidget.previewInfo?.videoUrl != widget.previewInfo?.videoUrl) {
      _disposeController();
      _resetEpisodeState();
      if (widget.isActive) {
        _initEpisode();
      }
    } else if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive &&
          !_hasRequestedPlay &&
          _paywall == null &&
          !_isInitialized) {
        _initEpisode();
      } else {
        _updatePlaybackState();
      }
    }
  }

  void _resetEpisodeState() {
    _isLoadingPlay = false;
    _isInitialized = false;
    _hasError = false;
    _errorMessage = '';
    _paywall = null;
    _blockReason = '';
    _isPausedByUser = false;
    _didTriggerEnd = false;
    _didApplyInitialSeek = false;
    _hasRequestedPlay = false;
    _subTracks = [];
    _cues = [];
    _activeSubtitle = null;
    _subtitleLoadSeq++;
    _lastTickEmitSec = -1;
  }

  Future<void> _initEpisode() async {
    if (_isLoadingPlay) return;
    _hasRequestedPlay = true;
    _isLoadingPlay = true;
    _isInitialized = false;
    _hasError = false;
    _didTriggerEnd = false;
    _paywall = null;
    _blockReason = '';
    _activeSubtitle = null;
    if (mounted) setState(() {});

    try {
      final preview = widget.previewInfo;
      if (preview != null) {
        await _startVideoStream(
          videoUrl: preview.videoUrl,
          subtitles: preview.subtitles,
        );
        return;
      }

      final locale = ref.read(localeProvider);
      final dramaApi = ref.read(dramaApiServiceProvider);
      final playResp = await dramaApi.playEpisode(
        widget.drama.dramaId,
        widget.episodeNo,
        lang: locale.appLanguage,
      );
      if (!mounted) return;
      await _startVideoStream(
        videoUrl: playResp.videoUrl,
        subtitles: playResp.subtitles,
      );
    } on DramaPaywallException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPlay = false;
        _paywall = PaywallResponse.fromJson(e.paywallData);
        _blockReason =
            e.paywallData['block_reason'] as String? ?? 'EPISODE_LOCKED';
      });
    } catch (e, st) {
      debugPrint(
        'ShortVideoItem._initEpisode error (${widget.drama.dramaId} ep ${widget.episodeNo}): $e\n$st',
      );
      _disposeController();
      if (!mounted) return;
      setState(() {
        _isLoadingPlay = false;
        _hasError = true;
        _errorMessage = ref.read(localeProvider).tr('generic_error_toast');
      });
    }
  }

  Future<void> _safePlay(VideoPlayerController? ctrl) async {
    if (ctrl == null) return;
    try {
      await ctrl.play();
    } catch (e) {
      debugPrint('ShortVideoItem.play error: $e');
    }
  }

  Future<void> _safePause(VideoPlayerController? ctrl) async {
    if (ctrl == null) return;
    try {
      await ctrl.pause();
    } catch (e) {
      debugPrint('ShortVideoItem.pause error: $e');
    }
  }

  Future<void> _safeSeekTo(VideoPlayerController? ctrl, Duration pos) async {
    if (ctrl == null) return;
    try {
      await ctrl.seekTo(pos);
    } catch (e) {
      debugPrint('ShortVideoItem.seekTo error: $e');
    }
  }

  Future<void> _safeSetPlaybackSpeed(
    VideoPlayerController? ctrl,
    double speed,
  ) async {
    if (ctrl == null) return;
    try {
      await ctrl.setPlaybackSpeed(speed);
    } catch (e) {
      debugPrint('ShortVideoItem.setPlaybackSpeed error: $e');
    }
  }

  Future<void> _safeDisposeController(VideoPlayerController? ctrl) async {
    if (ctrl == null) return;
    ctrl.removeListener(_onVideoTick);
    try {
      await ctrl.dispose();
    } catch (e) {
      debugPrint('ShortVideoItem.dispose error: $e');
    }
  }

  Future<void> _startVideoStream({
    required String videoUrl,
    required List<SubtitleTrack> subtitles,
  }) async {
    final trimmedUrl = videoUrl.trim();
    if (trimmedUrl.isEmpty) {
      throw StateError('Empty video URL');
    }

    final playableSubs = subtitles
        .where((t) => t.language.trim().isNotEmpty && t.url.trim().isNotEmpty)
        .toList();
    _subTracks = playableSubs;
    widget.onSubtitlesLoaded?.call(
      playableSubs.map((t) => t.language.trim()).toList(),
    );
    unawaited(_loadSubtitlesForLanguage(ref.read(localeProvider).subtitleLanguage));

    final factory = ref.read(videoControllerFactoryProvider);
    final ctrl = factory.createFromUrl(trimmedUrl);
    _controller = ctrl;

    await ctrl.initialize().timeout(const Duration(seconds: 20));
    if (!mounted || _controller != ctrl) {
      unawaited(_safeDisposeController(ctrl));
      return;
    }
    if (ctrl.value.hasError) {
      throw StateError(ctrl.value.errorDescription ?? 'Video init failed');
    }

    if (widget.initialPositionSec > 0 && !_didApplyInitialSeek) {
      final durSec = ctrl.value.duration.inSeconds;
      if (durSec <= 0 || widget.initialPositionSec < durSec - 2) {
        await _safeSeekTo(ctrl, Duration(seconds: widget.initialPositionSec));
      }
      _didApplyInitialSeek = true;
    }

    await _safeSetPlaybackSpeed(ctrl, ref.read(userWalletProvider).playbackSpeed);
    if (!mounted || _controller != ctrl) return;
    ctrl.addListener(_onVideoTick);

    setState(() {
      _isLoadingPlay = false;
      _isInitialized = true;
    });
    _updatePlaybackState();
  }

  Future<void> _loadSubtitlesForLanguage(String langCode) async {
    final seq = ++_subtitleLoadSeq;
    final locale = ref.read(localeProvider);
    if (!locale.subtitlesEnabled || _subTracks.isEmpty) {
      if (mounted) {
        setState(() {
          _cues = const [];
          _activeSubtitle = null;
        });
      }
      return;
    }

    final match = AppStrings.resolveSubtitleCandidate<SubtitleTrack>(
      _subTracks,
      (t) => t.language,
      langCode,
      isDefault: (t) => t.isDefault,
    );

    if (match == null || match.url.isEmpty) {
      if (mounted) {
        setState(() {
          _cues = const [];
          _activeSubtitle = null;
        });
      }
      return;
    }

    final tracksSnapshot = _subTracks;
    try {
      final cues = await SrtParser.loadSubtitleUrl(match.url);
      if (!mounted ||
          seq != _subtitleLoadSeq ||
          !identical(_subTracks, tracksSnapshot)) {
        return;
      }
      setState(() {
        _cues = cues;
        if (_controller != null && _controller!.value.isInitialized) {
          _activeSubtitle = SrtParser.findActiveText(
            _cues,
            _controller!.value.position,
          );
        } else {
          _activeSubtitle = null;
        }
      });
    } catch (e) {
      debugPrint('ShortVideoItem._loadSubtitlesForLanguage error: $e');
      if (!mounted ||
          seq != _subtitleLoadSeq ||
          !identical(_subTracks, tracksSnapshot)) {
        return;
      }
      setState(() {
        _cues = const [];
        _activeSubtitle = null;
      });
    }
  }

  void _updatePlaybackState() {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) {
      widget.onPlaybackUpdate?.call(0, 0, false);
      return;
    }
    if (widget.isActive && !_isPausedByUser) {
      unawaited(_safePlay(ctrl));
      final posSec = ctrl.value.position.inSeconds;
      final durSec = ctrl.value.duration.inSeconds;
      widget.onPlaybackUpdate?.call(posSec, durSec, true);
    } else {
      unawaited(_safePause(ctrl));
      final posSec = ctrl.value.position.inSeconds;
      final durSec = ctrl.value.duration.inSeconds;
      widget.onPlaybackUpdate?.call(posSec, durSec, false);
    }
  }

  void _onVideoTick() {
    final ctrl = _controller;
    if (ctrl == null || !mounted) return;
    if (ctrl.value.hasError) {
      debugPrint(
        'ShortVideoItem playback error (${widget.drama.dramaId} ep ${widget.episodeNo}): ${ctrl.value.errorDescription}',
      );
      _disposeController();
      setState(() {
        _isLoadingPlay = false;
        _isInitialized = false;
        _hasError = true;
        _errorMessage = ref.read(localeProvider).tr('generic_error_toast');
      });
      return;
    }
    if (!ctrl.value.isInitialized) return;

    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;
    final posSec = pos.inSeconds;

    if (posSec != _lastTickEmitSec) {
      _lastTickEmitSec = posSec;
      widget.onPlaybackUpdate?.call(
        posSec,
        dur.inSeconds,
        ctrl.value.isPlaying,
      );
    }

    final sub = SrtParser.findActiveText(_cues, pos);
    if (sub != _activeSubtitle) {
      setState(() {
        _activeSubtitle = sub;
      });
    }

    if (dur.inMilliseconds > 500 &&
        pos.inMilliseconds >= dur.inMilliseconds - 250 &&
        !_didTriggerEnd) {
      _didTriggerEnd = true;
      final autoPlay = ref.read(userWalletProvider).autoPlayNext;
      if (autoPlay && widget.onVideoEnded != null) {
        widget.onVideoEnded!();
      } else {
        unawaited(_safeSeekTo(ctrl, Duration.zero));
        unawaited(_safePlay(ctrl));
        _didTriggerEnd = false;
      }
    }
  }

  void _togglePlayPause() {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        unawaited(_safePause(ctrl));
        _isPausedByUser = true;
        widget.onPlaybackUpdate?.call(
          ctrl.value.position.inSeconds,
          ctrl.value.duration.inSeconds,
          false,
        );
      } else {
        unawaited(_safePlay(ctrl));
        _isPausedByUser = false;
        widget.onPlaybackUpdate?.call(
          ctrl.value.position.inSeconds,
          ctrl.value.duration.inSeconds,
          true,
        );
      }
    });
  }

  Future<void> _handleOpenEpisodeList() async {
    final cb = widget.onOpenEpisodeList;
    if (cb == null) return;
    setState(() => _isEpisodeSheetOpen = true);
    try {
      await cb();
    } finally {
      if (mounted) {
        setState(() => _isEpisodeSheetOpen = false);
      }
    }
  }

  void _cyclePlaybackSpeed(double currentSpeed) {
    final idx = _speeds.indexOf(currentSpeed);
    final nextSpeed = _speeds[(idx + 1) % _speeds.length];
    ref.read(userWalletProvider.notifier).setPlaybackSpeed(nextSpeed);
  }

  String _formatSpeed(double speed) {
    if (speed == speed.roundToDouble()) {
      return '${speed.toStringAsFixed(1)}x';
    }
    return '${speed}x';
  }

  Future<void> _unlockWithRewardAd() async {
    if (_isUnlocking) return;
    final reqEp = widget.requiredUnlockEpisode;
    if (reqEp != null) {
      final msg = ref
          .read(localeProvider)
          .tr('unlock_in_order_toast')
          .replaceAll('{ep}', '$reqEp');
      AppToast.show(context, msg);
      return;
    }
    setState(() => _isUnlocking = true);
    final earned = await showRewardUnlock(context, ref);
    if (!mounted) return;
    if (!earned) {
      setState(() => _isUnlocking = false);
      AppToast.show(context, ref.read(localeProvider).tr('reward_ad_failed'));
      return;
    }

    await _performApiUnlock(
      method: 'ad',
      unlockFullDrama: false,
      adNetwork: 'admob',
      adUnitId: MyAdIdName.rewardedAd.getId,
    );
  }

  Future<void> _unlockWithCoins({required bool fullDrama}) async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);
    await _performApiUnlock(
      method: 'coins',
      unlockFullDrama: fullDrama,
    );
  }

  Future<void> _performApiUnlock({
    required String method,
    required bool unlockFullDrama,
    String? adNetwork,
    String? adUnitId,
  }) async {
    try {
      final resp = await ref.read(dramaApiServiceProvider).unlockEpisode(
            widget.drama.dramaId,
            widget.episodeNo,
            method,
            unlockFullDrama: unlockFullDrama,
            adNetwork: adNetwork,
            adUnitId: adUnitId,
          );
      if (!mounted) return;

      ref.read(walletProvider.notifier).updateFromUnlock(resp);
      ref.read(eventTrackerProvider).track(
        'episode_unlock',
        dramaId: widget.drama.dramaId,
        episodeNumber: widget.episodeNo,
        sourceScreen: widget.sourceScreen,
        props: {
          'method': method,
          'full_drama': unlockFullDrama,
        },
      );
      widget.onEpisodeUnlocked?.call(widget.episodeNo, unlockFullDrama);

      setState(() {
        _paywall = null;
        _blockReason = '';
        _isUnlocking = false;
      });
      await _startVideoStream(
        videoUrl: resp.videoUrl,
        subtitles: resp.subtitles,
      );
    } catch (e) {
      debugPrint('ShortVideoItem._performApiUnlock error: $e');
      if (!mounted) return;
      setState(() => _isUnlocking = false);
      AppToast.show(
        context,
        ref.read(localeProvider).tr('generic_error_toast'),
      );
    }
  }

  // TODO(IAP): Re-enable when Rewards/IAP tab is integrated.
  // void _openRewardsOrVip() {
  //   ref.read(shellTabIndexProvider.notifier).setTab(3);
  //   if (!widget.showFullDramaButton && Navigator.of(context).canPop()) {
  //     Navigator.of(context).pop();
  //   }
  // }

  void _disposeController() {
    final ctrl = _controller;
    _controller = null;
    unawaited(_safeDisposeController(ctrl));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  Widget _buildFullBleedVideo(VideoPlayerController ctrl) {
    final rawSize = ctrl.value.size;
    final videoWidth = rawSize.width > 0 ? rawSize.width : 1080.0;
    final videoHeight = rawSize.height > 0 ? rawSize.height : 1920.0;

    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: videoWidth,
            height: videoHeight,
            child: VideoPlayer(ctrl),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<double>(
      userWalletProvider.select((s) => s.playbackSpeed),
      (prev, nextSpeed) {
        final ctrl = _controller;
        if (ctrl != null && _isInitialized) {
          unawaited(_safeSetPlaybackSpeed(ctrl, nextSpeed));
        }
      },
    );

    ref.listen<LocaleState>(localeProvider, (prev, next) {
      if (prev?.subtitleLanguage != next.subtitleLanguage ||
          prev?.subtitlesEnabled != next.subtitlesEnabled) {
        _loadSubtitlesForLanguage(next.subtitleLanguage);
      }
    });

    final locale = ref.watch(localeProvider);
    final playbackSpeed =
        ref.watch(userWalletProvider.select((s) => s.playbackSpeed));

    final isFav = ref.watch(
      mylistProvider.select(
        (s) => s.favoriteIds.contains(widget.drama.dramaId),
      ),
    ) ||
        widget.drama.isFavorited;

    final hasPlayableSubs = _subTracks.isNotEmpty;
    final subLangCodes = _subTracks.map((t) => t.language).toList();
    final sheetSubLangs =
        _isLoadingPlay ? widget.drama.availableSubLangs : subLangCodes;
    final activeSubTrack = AppStrings.resolveSubtitleCandidate<SubtitleTrack>(
      _subTracks,
      (t) => t.language,
      locale.subtitleLanguage,
      isDefault: (t) => t.isDefault,
    );
    final activeSubCode = activeSubTrack?.language ?? locale.subtitleLanguage;
    final langOpt = AppStrings.getLanguageOption(activeSubCode);
    final bottomPad =
        widget.showFullDramaButton ? 0.0 : MediaQuery.paddingOf(context).bottom;
    final totalEps = widget.drama.totalEpisodes > 0
        ? widget.drama.totalEpisodes
        : widget.episodeNo;
    final isLocked = _paywall != null;

    return Container(
      color: AppColors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video / Paywall / Error / Loading layer
          if (isLocked)
            _buildLockedOverlay(locale)
          else if (_hasError)
            _buildErrorView(locale)
          else if (_isInitialized && _controller != null)
            _buildFullBleedVideo(_controller!)
          else
            _buildLoadingView(),

          // 2. Center Play Icon when paused
          if (!isLocked && _isInitialized && _isPausedByUser)
            IgnorePointer(
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: const BoxDecoration(
                    color: AppColors.overlayMedium,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.textPrimary,
                    size: 54.sp,
                  ),
                ),
              ),
            ),

          // 3. Bottom Scrim Gradient
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 270.h,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.bottomScrimGradient,
                ),
              ),
            ),
          ),

          // 4. Synchronized VTT/SRT Subtitle Overlay
          if (!isLocked &&
              locale.subtitlesEnabled &&
              _activeSubtitle != null &&
              _activeSubtitle!.isNotEmpty)
            Positioned(
              left: 20.w,
              right: widget.showFullDramaButton ? 20.w : 82.w,
              bottom: (widget.showFullDramaButton ? 168.h : 122.h) + bottomPad,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.overlayDark,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      _activeSubtitle!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitleOverlay,
                    ),
                  ),
                ),
              ),
            ),

          // 5. Right Side Frosted Glass Action Buttons (Full Drama Player only)
          if (!widget.showFullDramaButton)
            Positioned(
              right: 12.w,
              bottom: 18.h + bottomPad,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIconButton(
                    iconAsset: isFav ? _icSaveSelected : _icSave,
                    label: isFav
                        ? locale.tr('saved')
                        : locale.tr('player_save_short'),
                    onTap: () {
                      ref.read(mylistProvider.notifier).toggleFavorite(
                            widget.drama,
                            episodeNumber: widget.episodeNo,
                          );
                      if (widget.showFullDramaButton && !isFav) {
                        ref
                            .read(feedProvider.notifier)
                            .trackEvent(widget.drama.dramaId, 'favorite');
                      }
                    },
                  ),
                  SizedBox(height: 15.h),
                  if (widget.onOpenEpisodeList != null) ...[
                    _ActionIconButton(
                      iconAsset: _isEpisodeSheetOpen
                          ? _icEpisodesSelected
                          : _icEpisodes,
                      label: '$totalEps ${locale.tr('player_eps_short')}',
                      onTap: _handleOpenEpisodeList,
                    ),
                    SizedBox(height: 15.h),
                  ],
                  _ActionIconButton(
                    iconAsset: hasPlayableSubs && locale.subtitlesEnabled
                        ? _icSubtitleSelected
                        : _icSubtitle,
                    label: (!hasPlayableSubs || _isLoadingPlay)
                        ? locale.tr('sub_label')
                        : (locale.subtitlesEnabled
                            ? '${langOpt.flag} ${langOpt.code.toUpperCase()}'
                            : locale.tr('sub_off')),
                    onTap: () => PlayerSettingsSheet.show(
                      context,
                      availableSubLangs: sheetSubLangs,
                      subtitlesOnly: true,
                    ),
                    onLongPress: hasPlayableSubs
                        ? () => ref
                            .read(localeProvider.notifier)
                            .toggleSubtitlesEnabled()
                        : null,
                  ),
                  SizedBox(height: 15.h),
                  _ActionIconButton(
                    icon: Icons.speed_rounded,
                    label: _formatSpeed(playbackSpeed),
                    onTap: () => _cyclePlaybackSpeed(playbackSpeed),
                    onLongPress: () => PlayerSettingsSheet.show(
                      context,
                      availableSubLangs: sheetSubLangs,
                    ),
                  ),
                ],
              ),
            ),

          // 6. Bottom-Left Drama Info & Frosted "Watch Full Series" Button
          Positioned(
            left: 16.w,
            right: widget.showFullDramaButton ? 16.w : 80.w,
            bottom: 18.h + bottomPad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.5.h,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.badgePrimaryGradient,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '${locale.tr('player_ep_badge')} ${widget.episodeNo} / $totalEps',
                    style: AppTextStyles.playerEpBadge,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  widget.drama.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.playerDramaTitle,
                ),
                if (widget.drama.description.isNotEmpty) ...[
                  SizedBox(height: 5.h),
                  Text(
                    widget.drama.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.playerDramaDesc,
                  ),
                ],
                if (widget.showFullDramaButton &&
                    widget.onOpenFullDrama != null) ...[
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: widget.onOpenFullDrama,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 9.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.playerGlassButton,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20.w,
                            height: 20.w,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              gradient: AppColors.badgePrimaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: AppColors.textPrimary,
                              size: 14.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Text(
                              '${locale.tr('watch_full_drama')} ($totalEps ${locale.tr('player_episodes_full')})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.playerWatchFullBtn,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 7. Edge-to-Edge Bottom Progress Bar
          if (!isLocked && _isInitialized && _controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPad,
              child: SizedBox(
                height: 10.h,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 2.5.h,
                    child: VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      padding: EdgeInsets.zero,
                      colors: const VideoProgressColors(
                        playedColor: AppColors.playerProgressPlayed,
                        bufferedColor: AppColors.playerProgressTrack,
                        backgroundColor: AppColors.playerProgressTrack,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    final showSpinner = _isLoadingPlay || widget.isActive;
    return Stack(
      fit: StackFit.expand,
      children: [
        DramaNetworkImage(
          imageUrl: widget.drama.coverUrl,
          fit: BoxFit.cover,
        ),
        if (showSpinner) ...[
          const ColoredBox(color: AppColors.overlayMedium),
          const Center(
            child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorView(LocaleState locale) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 46.sp),
            SizedBox(height: 12.h),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: _initEpisode,
              icon: const Icon(Icons.refresh),
              label: Text(locale.tr('retry_btn')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedOverlay(LocaleState locale) {
    final opts = _paywall?.unlockOptions ?? UnlockOptions();
    return UnlockRewardOverlay(
      coverUrl: widget.drama.coverUrl,
      episodeNo: widget.episodeNo,
      blockReason: _blockReason,
      options: opts,
      isUnlocking: _isUnlocking,
      locale: locale,
      onUnlockWithAd: _unlockWithRewardAd,
      onUnlockWithCoins: () => _unlockWithCoins(fullDrama: false),
      onUnlockFullDrama: () => _unlockWithCoins(fullDrama: true),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final String? iconAsset;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ActionIconButton({
    this.iconAsset,
    this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 74.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconAsset != null
                ? Image.asset(
                    iconAsset!,
                    width: 42.w,
                    height: 42.w,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  )
                : Container(
                    width: 42.w,
                    height: 42.w,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.playerGlassCircle,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.textPrimary,
                      size: 21.sp,
                    ),
                  ),
            SizedBox(height: 5.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.actionIconLabel,
            ),
          ],
        ),
      ),
    );
  }
}
