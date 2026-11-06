import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../ads/placement/show_placement_ad.dart';
import '../core/utils/screen_utils.dart';
import '../models/drama_models.dart';
import '../providers/app_providers.dart';
import '../services/app_strings.dart';
import '../services/srt_parser.dart';
import 'player_settings_sheet.dart';

class ShortVideoItem extends ConsumerStatefulWidget {
  final Drama drama;
  final int episodeNo;
  final bool isActive;
  final VoidCallback? onVideoEnded;
  final FutureOr<void> Function()? onOpenEpisodeList;
  final VoidCallback? onOpenFullDrama;
  final bool showFullDramaButton;

  const ShortVideoItem({
    super.key,
    required this.drama,
    required this.episodeNo,
    required this.isActive,
    this.onVideoEnded,
    this.onOpenEpisodeList,
    this.onOpenFullDrama,
    this.showFullDramaButton = false,
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
  List<SubtitleCue> _cues = [];
  String? _activeSubtitle;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isPausedByUser = false;
  bool _didTriggerEnd = false;
  bool _isWatchingAd = false;
  bool _isEpisodeSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initEpisode();
    });
  }

  @override
  void didUpdateWidget(covariant ShortVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drama.slug != widget.drama.slug ||
        oldWidget.episodeNo != widget.episodeNo) {
      _disposeController();
      _initEpisode();
    } else if (oldWidget.isActive != widget.isActive) {
      _updatePlaybackState();
    }
  }

  Future<void> _initEpisode() async {
    _isInitialized = false;
    _hasError = false;
    _didTriggerEnd = false;
    _activeSubtitle = null;

    final wallet = ref.read(userWalletProvider);
    if (!wallet.isEpisodeUnlocked(widget.drama, widget.episodeNo)) {
      if (mounted) setState(() {});
      return;
    }

    final ctrl = createDramaVideoController(
      drama: widget.drama,
      episodeNo: widget.episodeNo,
      customStreamBaseUrl: wallet.customStreamBaseUrl,
    );
    _controller = ctrl;

    try {
      await ctrl.initialize();
      if (!mounted || _controller != ctrl) return;
      ctrl.addListener(_onVideoTick);
      ctrl.setPlaybackSpeed(ref.read(userWalletProvider).playbackSpeed);
      _isInitialized = true;
      _updatePlaybackState();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _updatePlaybackState() {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    if (widget.isActive && !_isPausedByUser) {
      ctrl.play();
      final slug = widget.drama.slug;
      final epNo = widget.episodeNo;
      Future.microtask(() {
        if (mounted) {
          ref.read(watchlistProvider.notifier).recordWatchHistory(slug, epNo);
        }
      });
    } else {
      ctrl.pause();
    }
  }

  void _onVideoTick() {
    final ctrl = _controller;
    if (ctrl == null || !mounted || !ctrl.value.isInitialized) return;

    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;

    final sub = SrtParser.findActiveText(_cues, pos);
    if (sub != _activeSubtitle) {
      setState(() {
        _activeSubtitle = sub;
      });
    } else {
      setState(() {});
    }

    if (dur.inMilliseconds > 500 &&
        pos.inMilliseconds >= dur.inMilliseconds - 200 &&
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
      } else {
        ctrl.play();
        _isPausedByUser = false;
      }
    });
  }

  Future<void> _handleOpenEpisodeList() async {
    final cb = widget.onOpenEpisodeList;
    if (cb == null) return;
    setState(() {
      _isEpisodeSheetOpen = true;
    });
    try {
      await cb();
    } finally {
      if (mounted) {
        setState(() {
          _isEpisodeSheetOpen = false;
        });
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
    if (_isWatchingAd) return;
    setState(() => _isWatchingAd = true);
    final earned = await showRewardUnlock(context, ref);
    if (!mounted) return;
    setState(() => _isWatchingAd = false);
    if (earned) {
      ref
          .read(userWalletProvider.notifier)
          .unlockEpisodeByAd(widget.drama, widget.episodeNo);
      _initEpisode();
      return;
    }
    final locale = ref.read(localeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(locale.tr('reward_ad_failed'))),
    );
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

    final locale = ref.watch(localeProvider);
    final playbackSpeed =
        ref.watch(userWalletProvider.select((s) => s.playbackSpeed));
    final isUnlocked = ref.watch(
      userWalletProvider.select(
        (s) => s.isEpisodeUnlocked(widget.drama, widget.episodeNo),
      ),
    );
    final isFav = ref.watch(
      watchlistProvider.select((s) => s.isFavorite(widget.drama.slug)),
    );

    final cuesAsync = ref.watch(
      episodeSubtitlesProvider(
        (slug: widget.drama.slug, episodeNo: widget.episodeNo),
      ),
    );
    _cues = cuesAsync.asData?.value ?? [];
    if (_controller != null && _controller!.value.isInitialized) {
      _activeSubtitle =
          SrtParser.findActiveText(_cues, _controller!.value.position);
    }

    final langOpt = AppStrings.getLanguageOption(locale.subtitleLanguage);
    final bottomPad =
        widget.showFullDramaButton ? 0.0 : MediaQuery.paddingOf(context).bottom;

    return Container(
      color: AppColors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-bleed Video layer or Poster background
          if (!isUnlocked)
            _buildLockedOverlay(locale)
          else if (_hasError)
            _buildErrorView(locale)
          else if (_isInitialized && _controller != null)
            _buildFullBleedVideo(_controller!)
          else
            _buildLoadingView(),

          // 2. Center Play Icon when paused
          if (isUnlocked && _isInitialized && _isPausedByUser)
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

          // 3. Bottom Scrim Gradient for Crisp Readability
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

          // 4. Synchronized .srt Subtitle Overlay
          if (isUnlocked &&
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
                  onTap: () => ref
                      .read(watchlistProvider.notifier)
                      .toggleFavorite(widget.drama.slug),
                ),
                SizedBox(height: 15.h),
                if (widget.onOpenEpisodeList != null) ...[
                  _ActionIconButton(
                    iconAsset:
                        _isEpisodeSheetOpen ? _icEpisodesSelected : _icEpisodes,
                    label:
                        '${widget.drama.totalEpisodes} ${locale.tr('player_eps_short')}',
                    onTap: _handleOpenEpisodeList,
                  ),
                  SizedBox(height: 15.h),
                ],
                _ActionIconButton(
                  iconAsset:
                      locale.subtitlesEnabled ? _icSubtitleSelected : _icSubtitle,
                  label: locale.subtitlesEnabled
                      ? '${langOpt.flag} ${langOpt.code.toUpperCase()}'
                      : locale.tr('sub_off'),
                  onTap: () => PlayerSettingsSheet.show(context),
                  onLongPress: () =>
                      ref.read(localeProvider.notifier).toggleSubtitlesEnabled(),
                ),
                SizedBox(height: 15.h),
                _ActionIconButton(
                  icon: Icons.speed_rounded,
                  label: _formatSpeed(playbackSpeed),
                  onTap: () => _cyclePlaybackSpeed(playbackSpeed),
                  onLongPress: () => PlayerSettingsSheet.show(context),
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
                    '${locale.tr('player_ep_badge')} ${widget.episodeNo} / ${widget.drama.totalEpisodes}',
                    style: AppTextStyles.playerEpBadge,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  locale.dramaTitle(widget.drama),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.playerDramaTitle,
                ),
                SizedBox(height: 5.h),
                Text(
                  locale.dramaDescription(widget.drama),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.playerDramaDesc,
                ),
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
                                  '${locale.tr('watch_full_drama')} (${widget.drama.totalEpisodes} ${locale.tr('player_episodes_full')})',
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

          // 7. Minimal Edge-to-Edge Bottom Progress Bar
          if (isUnlocked && _isInitialized && _controller != null)
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
        Image.asset(
          widget.drama.posterAssetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.black),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          widget.drama.posterAssetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.black),
        ),
        const ColoredBox(color: AppColors.overlayHeavy),
        Center(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 28.w),
            padding: EdgeInsets.all(24.w),
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
                    size: 34.sp,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  '${locale.tr('unlock_ep_title')} ${widget.episodeNo}',
                  style: AppTextStyles.h2,
                ),
                SizedBox(height: 8.h),
                Text(
                  locale.tr('locked_title'),
                  style: AppTextStyles.caption,
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isWatchingAd ? null : _unlockWithRewardAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBright,
                      foregroundColor: AppColors.textPrimary,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    icon: Icon(Icons.ondemand_video_rounded, size: 20.sp),
                    label: Text(
                      _isWatchingAd
                          ? locale.tr('watching_ad')
                          : locale.tr('watch_ad_free'),
                      style: AppTextStyles.buttonMedium,
                    ),
                  ),
                ),
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
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: iconAsset != null
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
