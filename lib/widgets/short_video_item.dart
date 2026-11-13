import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../ads/const/ad_id_extension.dart';
import '../ads/const/ad_id_name.dart';
import '../ads/placement/show_placement_ad.dart';
import '../core/network/drama_dio_interceptor.dart';
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
  final void Function(int episodeNo, bool fullDrama)? onEpisodeUnlocked;
  final void Function(int posSec, int durSec, bool isPlaying)? onPlaybackUpdate;

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
    this.onEpisodeUnlocked,
    this.onPlaybackUpdate,
  });

  @override
  ConsumerState<ShortVideoItem> createState() => _ShortVideoItemState();
}

class _ShortVideoItemState extends ConsumerState<ShortVideoItem> {
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

  int? _likeCountOverride;
  bool? _isLikedOverride;
  int? _shareCountOverride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.previewInfo != null || widget.isActive) {
        _initEpisode();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ShortVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drama.dramaId != widget.drama.dramaId ||
        oldWidget.episodeNo != widget.episodeNo ||
        oldWidget.previewInfo?.videoUrl != widget.previewInfo?.videoUrl) {
      _disposeController();
      _resetEpisodeState();
      if (widget.previewInfo != null || widget.isActive) {
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
      if (!mounted) return;
      setState(() {
        _isLoadingPlay = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _startVideoStream({
    required String videoUrl,
    required List<SubtitleTrack> subtitles,
  }) async {
    _subTracks = subtitles;
    unawaited(_loadSubtitlesForLanguage(ref.read(localeProvider).subtitleLanguage));

    final factory = ref.read(videoControllerFactoryProvider);
    final ctrl = factory.createFromUrl(videoUrl);
    _controller = ctrl;

    await ctrl.initialize();
    if (!mounted || _controller != ctrl) {
      await ctrl.dispose();
      return;
    }

    if (widget.initialPositionSec > 0 && !_didApplyInitialSeek) {
      final durSec = ctrl.value.duration.inSeconds;
      if (durSec <= 0 || widget.initialPositionSec < durSec - 2) {
        await ctrl.seekTo(Duration(seconds: widget.initialPositionSec));
      }
      _didApplyInitialSeek = true;
    }

    await ctrl.setPlaybackSpeed(ref.read(userWalletProvider).playbackSpeed);
    ctrl.addListener(_onVideoTick);

    setState(() {
      _isLoadingPlay = false;
      _isInitialized = true;
    });
    _updatePlaybackState();
  }

  Future<void> _loadSubtitlesForLanguage(String langCode) async {
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

    SubtitleTrack? match;
    for (final t in _subTracks) {
      if (t.language.toLowerCase() == langCode.toLowerCase()) {
        match = t;
        break;
      }
    }
    match ??= _subTracks.firstWhere(
      (t) => t.isDefault,
      orElse: () => _subTracks.first,
    );

    if (match.url.isEmpty) return;
    final cues = await SrtParser.loadSubtitleUrl(match.url);
    if (!mounted) return;
    setState(() {
      _cues = cues;
      if (_controller != null && _controller!.value.isInitialized) {
        _activeSubtitle = SrtParser.findActiveText(
          _cues,
          _controller!.value.position,
        );
      }
    });
  }

  void _updatePlaybackState() {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) {
      widget.onPlaybackUpdate?.call(0, 0, false);
      return;
    }
    if (widget.isActive && !_isPausedByUser) {
      ctrl.play();
      final posSec = ctrl.value.position.inSeconds;
      final durSec = ctrl.value.duration.inSeconds;
      widget.onPlaybackUpdate?.call(posSec, durSec, true);
    } else {
      ctrl.pause();
      final posSec = ctrl.value.position.inSeconds;
      final durSec = ctrl.value.duration.inSeconds;
      widget.onPlaybackUpdate?.call(posSec, durSec, false);
    }
  }

  void _onVideoTick() {
    final ctrl = _controller;
    if (ctrl == null || !mounted || !ctrl.value.isInitialized) return;

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
        ctrl.seekTo(Duration.zero);
        ctrl.play();
        _didTriggerEnd = false;
      }
    }
  }

  void _togglePlayPause() {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
        _isPausedByUser = true;
        widget.onPlaybackUpdate?.call(
          ctrl.value.position.inSeconds,
          ctrl.value.duration.inSeconds,
          false,
        );
      } else {
        ctrl.play();
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
    setState(() => _isUnlocking = true);
    final earned = await showRewardUnlock(context, ref);
    if (!mounted) return;
    if (!earned) {
      setState(() => _isUnlocking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(localeProvider).tr('reward_ad_failed'))),
      );
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
      if (!mounted) return;
      setState(() => _isUnlocking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unlock failed: $e')),
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

  Future<void> _handleLike() async {
    final currentCount = _likeCountOverride ?? widget.drama.likeCount;

    final result = await ref.read(mylistProvider.notifier).toggleLike(
          widget.drama.dramaId,
          currentLikeCount: currentCount,
          episodeNumber: widget.showFullDramaButton ? 0 : widget.episodeNo,
        );
    if (!mounted) return;
    setState(() {
      _isLikedOverride = result.isLiked;
      _likeCountOverride = result.likeCount;
    });
    if (widget.showFullDramaButton && result.isLiked) {
      ref.read(feedProvider.notifier).trackEvent(widget.drama.dramaId, 'like');
    }
  }

  Future<void> _handleShare() async {
    final shareUrl =
        'https://dramota.com/drama/${widget.drama.dramaId}?ep=${widget.episodeNo}';
    await Clipboard.setData(
      ClipboardData(text: '${widget.drama.title} - $shareUrl'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.drama.title} link copied'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final res = await ref.read(dramaApiServiceProvider).shareDrama(
            widget.drama.dramaId,
            channel: 'copy_link',
            episodeNumber: widget.episodeNo,
          );
      if (mounted) {
        setState(() => _shareCountOverride = res.shareCount);
      }
      ref.read(eventTrackerProvider).track(
        'drama_share',
        dramaId: widget.drama.dramaId,
        episodeNumber: widget.episodeNo,
        sourceScreen: widget.sourceScreen,
      );
      if (widget.showFullDramaButton) {
        ref
            .read(feedProvider.notifier)
            .trackEvent(widget.drama.dramaId, 'share');
      }
    } catch (_) {
      // Non-fatal analytics/share call
    }
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n > 0 ? '$n' : '';
  }

  void _disposeController() {
    final ctrl = _controller;
    _controller = null;
    ctrl?.removeListener(_onVideoTick);
    ctrl?.dispose();
  }

  @override
  void dispose() {
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
          ctrl.setPlaybackSpeed(nextSpeed);
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
    final isLiked = _isLikedOverride ??
        (ref.watch(
              mylistProvider.select(
                (s) => s.likedIds.contains(widget.drama.dramaId),
              ),
            ) ||
            widget.drama.isLiked);
    final likeCount = _likeCountOverride ?? widget.drama.likeCount;
    final shareCount = _shareCountOverride ?? widget.drama.shareCount;

    final langOpt = AppStrings.getLanguageOption(locale.subtitleLanguage);
    final bottomPad =
        widget.showFullDramaButton ? 0.0 : MediaQuery.paddingOf(context).bottom;
    final totalEps = widget.drama.totalEpisodes > 0
        ? widget.drama.totalEpisodes
        : widget.episodeNo;
    final isLocked = _paywall != null;
    final subLangCodes = _subTracks.isNotEmpty
        ? _subTracks.map((t) => t.language).toList()
        : widget.drama.availableSubLangs;

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
              right: 82.w,
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

          // 5. Right Side Frosted Glass Action Buttons
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
                SizedBox(height: 11.h),
                _ActionIconButton(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  iconColor:
                      isLiked ? AppColors.primaryBright : AppColors.textPrimary,
                  label: _formatCount(likeCount).isNotEmpty
                      ? _formatCount(likeCount)
                      : 'Like',
                  onTap: _handleLike,
                ),
                SizedBox(height: 11.h),
                _ActionIconButton(
                  icon: Icons.share_rounded,
                  label: _formatCount(shareCount).isNotEmpty
                      ? _formatCount(shareCount)
                      : 'Share',
                  onTap: _handleShare,
                ),
                SizedBox(height: 11.h),
                if (widget.onOpenEpisodeList != null) ...[
                  _ActionIconButton(
                    iconAsset:
                        _isEpisodeSheetOpen ? _icEpisodesSelected : _icEpisodes,
                    label: '$totalEps ${locale.tr('player_eps_short')}',
                    onTap: _handleOpenEpisodeList,
                  ),
                  SizedBox(height: 11.h),
                ],
                _ActionIconButton(
                  iconAsset:
                      locale.subtitlesEnabled ? _icSubtitleSelected : _icSubtitle,
                  label: locale.subtitlesEnabled
                      ? '${langOpt.flag} ${langOpt.code.toUpperCase()}'
                      : locale.tr('sub_off'),
                  onTap: () => PlayerSettingsSheet.show(
                    context,
                    availableSubLangs: subLangCodes,
                  ),
                  onLongPress: () =>
                      ref.read(localeProvider.notifier).toggleSubtitlesEnabled(),
                ),
                SizedBox(height: 11.h),
                _ActionIconButton(
                  icon: Icons.speed_rounded,
                  label: _formatSpeed(playbackSpeed),
                  onTap: () => _cyclePlaybackSpeed(playbackSpeed),
                  onLongPress: () => PlayerSettingsSheet.show(
                    context,
                    availableSubLangs: subLangCodes,
                  ),
                ),
              ],
            ),
          ),

          // 6. Bottom-Left Drama Info & Frosted "Watch Full Series" Button
          Positioned(
            left: 16.w,
            right: 80.w,
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        DramaNetworkImage(
          imageUrl: widget.drama.coverUrl,
          fit: BoxFit.cover,
        ),
        const ColoredBox(color: AppColors.overlayMedium),
        const Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
          ),
        ),
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
    final hasAdQuota =
        opts.allowAdUnlock && opts.adUnlocksRemainingToday > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        DramaNetworkImage(imageUrl: widget.drama.coverUrl, fit: BoxFit.cover),
        const ColoredBox(color: AppColors.overlayHeavy),
        Center(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 26.w),
            padding: EdgeInsets.all(22.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceLockedCard,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBright.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: AppColors.primaryBright,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  '${locale.tr('unlock_ep_title')} ${widget.episodeNo}',
                  style: AppTextStyles.h2,
                ),
                SizedBox(height: 6.h),
                Text(
                  _blockReason == 'DAILY_LIMIT_REACHED'
                      ? 'Daily free ad limit reached (${opts.adUnlocksRemainingToday}/${opts.adUnlockDailyLimit})'
                      : '${locale.tr('current_balance')}: ${opts.userTotalCoins} ${locale.tr('coins')}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
                SizedBox(height: 16.h),
                if (hasAdQuota) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUnlocking ? null : _unlockWithRewardAd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBright,
                        foregroundColor: AppColors.textPrimary,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.ondemand_video_rounded, size: 19.sp),
                      label: Text(
                        _isUnlocking
                            ? locale.tr('watching_ad')
                            : '${locale.tr('watch_ad_free')} (${opts.adUnlocksRemainingToday}/${opts.adUnlockDailyLimit})',
                        style: AppTextStyles.buttonMedium,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                ],
                // TODO(IAP): Re-enable Top Up / VIP fallback when Rewards & IAP are active.
                if (opts.coinCost > 0 && opts.canAffordSingle) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isUnlocking
                          ? null
                          : () => _unlockWithCoins(fullDrama: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.gold),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.monetization_on_rounded, size: 18.sp),
                      label: Text(
                        '${locale.tr('unlock_ep_title')} (${opts.coinCost} ${locale.tr('coins')})',
                        // : '${locale.tr('top_up_btn')} / ${locale.tr('tab_vip')} (${opts.coinCost} ${locale.tr('coins')})',
                        style: AppTextStyles.buttonMedium,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                ],
                if (opts.fullDramaCoinCost > 0 &&
                    opts.fullDramaRemainingEpisodes > 1 &&
                    opts.canAffordFullDrama)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isUnlocking
                          ? null
                          : () => _unlockWithCoins(fullDrama: true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textWhite70,
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                      ),
                      child: Text(
                        '${locale.tr('full_series')} (${opts.fullDramaRemainingEpisodes} ${locale.tr('episodes_suffix')} • ${opts.fullDramaCoinCost} ${locale.tr('coins')}${opts.fullDramaDiscountPct > 0 ? ' -${opts.fullDramaDiscountPct}%' : ''})',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ),
                // TODO(IAP): Re-enable "Upgrade to VIP" CTA when IAP is integrated.
                // SizedBox(height: 4.h),
                // TextButton(
                //   onPressed: _openRewardsOrVip,
                //   child: Text(
                //     locale.tr('upgrade_vip_title'),
                //     style: AppTextStyles.caption.copyWith(
                //       color: AppColors.primaryBright,
                //       decoration: TextDecoration.underline,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final String? iconAsset;
  final IconData? icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ActionIconButton({
    this.iconAsset,
    this.icon,
    this.iconColor = AppColors.textPrimary,
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
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: iconAsset != null
                    ? Image.asset(
                        iconAsset!,
                        width: 40.w,
                        height: 40.w,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      )
                    : Container(
                        width: 40.w,
                        height: 40.w,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.playerGlassCircle,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: 20.sp,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 4.h),
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
