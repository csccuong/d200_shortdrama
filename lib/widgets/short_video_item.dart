import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../ads/const/ad_id_extension.dart';
import '../ads/const/ad_id_name.dart';
import '../ads/placement/show_placement_ad.dart';
import '../core/network/drama_dio_interceptor.dart';
import '../core/utils/app_toast.dart';
import '../core/utils/episode_playback_helper.dart';
import '../core/utils/screen_utils.dart';
import '../models/drama_card.dart';
import '../models/drama_models.dart';
import '../models/feed_response.dart';
import '../models/play_response.dart';
import '../models/stream_bundle.dart';
import '../providers/app_providers.dart';
import '../services/app_strings.dart';
import '../services/srt_parser.dart';
import 'drama_network_image.dart';
import 'player_settings_sheet.dart';
import 'premium_upgrade_dialog.dart';
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
  final VoidCallback? onPreviewExpired;
  final bool showFullDramaButton;
  final int? requiredUnlockEpisode;
  final void Function(int episodeNo, bool fullDrama)? onEpisodeUnlocked;
  final void Function(int posSec, int durSec, bool isPlaying)? onPlaybackUpdate;
  final void Function(List<String> subLangs)? onSubtitlesLoaded;
  final void Function(int episodeNo, bool visible)? onPaywallVisibilityChanged;
  final ValueChanged<bool>? onControlsVisibilityChanged;

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
    this.onPreviewExpired,
    this.showFullDramaButton = false,
    this.requiredUnlockEpisode,
    this.onEpisodeUnlocked,
    this.onPlaybackUpdate,
    this.onSubtitlesLoaded,
    this.onPaywallVisibilityChanged,
    this.onControlsVisibilityChanged,
  });

  @override
  ConsumerState<ShortVideoItem> createState() => _ShortVideoItemState();
}

class _ShortVideoItemState extends ConsumerState<ShortVideoItem>
    with WidgetsBindingObserver {
  static const Duration _controlsAutoHideDelay = Duration(seconds: 3);
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
  bool _lastNotifiedPaywallVisible = false;

  void _notifyPaywallVisibility(bool visible) {
    if (_lastNotifiedPaywallVisible == visible) return;
    _lastNotifiedPaywallVisible = visible;
    widget.onPaywallVisibilityChanged?.call(widget.episodeNo, visible);
  }

  void _setPaywallState(PaywallResponse? paywall, String blockReason) {
    _paywall = paywall;
    _blockReason = blockReason;
    _notifyPaywallVisibility(paywall != null);
    if (paywall != null) {
      _setControlsVisible(true, scheduleAutoHide: false);
    }
  }

  bool _isPausedByUser = false;
  bool _didTriggerEnd = false;
  bool _didApplyInitialSeek = false;
  bool _isEpisodeSheetOpen = false;
  bool _isSettingsSheetOpen = false;
  bool _isScrubbing = false;
  bool _controlsVisible = true;
  bool _isAppForeground = true;
  Timer? _hideControlsTimer;
  bool _hasRequestedPlay = false;
  int _lastTickEmitSec = -1;

  StreamBundle? _streamBundle;
  Duration _lastPosition = Duration.zero;
  bool _hasRetried403 = false;
  bool _isRenewingStream = false;

  bool get _canPlayInForeground {
    final bindingState = WidgetsBinding.instance.lifecycleState;
    final bindingResumed =
        bindingState == null || bindingState == AppLifecycleState.resumed;
    return _isAppForeground && bindingResumed;
  }

  void _setControlsVisible(bool visible, {bool scheduleAutoHide = true}) {
    if (_controlsVisible != visible && mounted) {
      setState(() => _controlsVisible = visible);
    } else {
      _controlsVisible = visible;
    }
    if (widget.isActive) {
      widget.onControlsVisibilityChanged?.call(visible);
    }
    if (visible && scheduleAutoHide) {
      _scheduleControlsAutoHide();
    } else {
      _hideControlsTimer?.cancel();
      _hideControlsTimer = null;
    }
  }

  void _scheduleControlsAutoHide() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
    if (!mounted ||
        !widget.isActive ||
        !_controlsVisible ||
        !_isInitialized ||
        _paywall != null ||
        _hasError ||
        _isPausedByUser ||
        _isScrubbing ||
        _isEpisodeSheetOpen ||
        _isSettingsSheetOpen) {
      return;
    }
    _hideControlsTimer = Timer(_controlsAutoHideDelay, () {
      if (!mounted ||
          !widget.isActive ||
          !_isInitialized ||
          _paywall != null ||
          _hasError ||
          _isPausedByUser ||
          _isScrubbing ||
          _isEpisodeSheetOpen ||
          _isSettingsSheetOpen) {
        return;
      }
      _setControlsVisible(false, scheduleAutoHide: false);
    });
  }

  void _onVideoAreaTap() {
    if (!_isInitialized || _paywall != null || _hasError) return;
    if (_controlsVisible) {
      _setControlsVisible(false, scheduleAutoHide: false);
    } else {
      _setControlsVisible(true);
    }
  }

  @override
  void initState() {
    super.initState();
    final initialLifecycle = WidgetsBinding.instance.lifecycleState;
    _isAppForeground =
        initialLifecycle == null || initialLifecycle == AppLifecycleState.resumed;
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
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _isAppForeground = false;
      _hideControlsTimer?.cancel();
      if (ctrl != null && (_isInitialized || ctrl.value.isInitialized)) {
        _lastPosition = ctrl.value.position;
        unawaited(_safePause(ctrl));
      }
    } else if (state == AppLifecycleState.resumed) {
      _isAppForeground = true;
      if (!widget.isActive) return;
      final bundle = _streamBundle;
      if (bundle != null && bundle.isExpired) {
        _handleExpiredStream(autoPlayAfter: !_isPausedByUser);
        return;
      }
      _updatePlaybackState();
    }
  }

  @override
  void didUpdateWidget(covariant ShortVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drama.dramaId != widget.drama.dramaId ||
        oldWidget.episodeNo != widget.episodeNo ||
        oldWidget.previewInfo?.videoUrl != widget.previewInfo?.videoUrl ||
        oldWidget.previewInfo?.expireAt != widget.previewInfo?.expireAt) {
      if (oldWidget.episodeNo != widget.episodeNo &&
          _lastNotifiedPaywallVisible) {
        _lastNotifiedPaywallVisible = false;
        widget.onPaywallVisibilityChanged?.call(oldWidget.episodeNo, false);
      }
      _disposeController();
      _resetEpisodeState();
      if (widget.isActive) {
        widget.onControlsVisibilityChanged?.call(true);
        _initEpisode();
      }
    } else if (oldWidget.isActive != widget.isActive) {
      if (!widget.isActive) {
        _hideControlsTimer?.cancel();
        _hideControlsTimer = null;
      } else {
        _setControlsVisible(true, scheduleAutoHide: false);
      }
      if (widget.isActive &&
          !_hasRequestedPlay &&
          _paywall == null &&
          !_isInitialized) {
        _initEpisode();
      } else if (widget.isActive &&
          _streamBundle != null &&
          _streamBundle!.isExpired) {
        _handleExpiredStream(autoPlayAfter: !_isPausedByUser);
      } else {
        _updatePlaybackState();
      }
    }
  }

  void _resetEpisodeState() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
    _controlsVisible = true;
    _isScrubbing = false;
    _isLoadingPlay = false;
    _isInitialized = false;
    _hasError = false;
    _errorMessage = '';
    _setPaywallState(null, '');
    _isPausedByUser = false;
    _didTriggerEnd = false;
    _didApplyInitialSeek = false;
    _hasRequestedPlay = false;
    _subTracks = [];
    _cues = [];
    _activeSubtitle = null;
    _subtitleLoadSeq++;
    _lastTickEmitSec = -1;
    _streamBundle = null;
    _lastPosition = Duration.zero;
    _hasRetried403 = false;
    _isRenewingStream = false;
  }

  Future<void> _initEpisode() async {
    if (_isLoadingPlay) return;
    _hasRequestedPlay = true;
    _hasRetried403 = false;
    _isLoadingPlay = true;
    _isInitialized = false;
    _hasError = false;
    _didTriggerEnd = false;
    _setPaywallState(null, '');
    _activeSubtitle = null;
    if (mounted) setState(() {});

    try {
      final preview = widget.previewInfo;
      if (preview != null) {
        if (preview.isStreamExpired && widget.onPreviewExpired != null) {
          widget.onPreviewExpired!();
          if (mounted) {
            setState(() {
              _isLoadingPlay = false;
              _hasRequestedPlay = false;
            });
          }
          return;
        }
        if (!preview.isStreamExpired) {
          final bundle = preview.toStreamBundle();
          _streamBundle = bundle;
          await _startVideoStream(bundle);
          return;
        }
      }

      final locale = ref.read(localeProvider);
      final dramaApi = ref.read(dramaApiServiceProvider);
      final bundle = await EpisodePlaybackHelper(dramaApi)
          .ensureFreshEpisodeStream(
        dramaId: widget.drama.dramaId,
        episodeNumber: widget.episodeNo,
        cachedBundle: _streamBundle,
        lang: locale.appLanguage,
      );
      if (!mounted) return;
      _streamBundle = bundle;
      await _startVideoStream(bundle);
    } on DramaPaywallException catch (e) {
      _handleEpisodePaywall(e);
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

  void _handleEpisodePaywall(DramaPaywallException e) {
    if (!mounted) return;
    ref.read(sessionProvider.notifier).handleInAppRefundDetected();
    setState(() {
      _isLoadingPlay = false;
      _setPaywallState(
        PaywallResponse.fromJson(e.paywallData),
        e.paywallData['block_reason'] as String? ?? 'EPISODE_LOCKED',
      );
    });
  }

  Future<void> _safePlay(VideoPlayerController? ctrl) async {
    if (ctrl == null || !mounted || !_canPlayInForeground || !widget.isActive) {
      return;
    }
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

  void _handleExpiredStream({required bool autoPlayAfter}) {
    if (widget.previewInfo != null) {
      if (widget.onPreviewExpired != null) {
        widget.onPreviewExpired!();
        return;
      }
    }
    unawaited(
      _renewEpisodeStream(
        forceRefresh: true,
        autoPlayAfter: autoPlayAfter,
      ),
    );
  }

  Future<void> _handle403SafetyRetry() async {
    if (_hasRetried403) return;
    _hasRetried403 = true;
    debugPrint(
      'ShortVideoItem 403 safety retry (${widget.drama.dramaId} ep ${widget.episodeNo})',
    );
    if (widget.previewInfo != null && widget.onPreviewExpired != null) {
      _disposeController();
      if (mounted) {
        setState(() {
          _isLoadingPlay = true;
          _isInitialized = false;
          _hasError = false;
        });
      }
      widget.onPreviewExpired!();
      return;
    }
    await _renewEpisodeStream(
      forceRefresh: true,
      autoPlayAfter: !_isPausedByUser,
    );
  }

  Future<void> _renewEpisodeStream({
    required bool forceRefresh,
    required bool autoPlayAfter,
  }) async {
    if (_isRenewingStream) return;
    _isRenewingStream = true;
    final ctrl = _controller;
    final currentPos =
        (ctrl != null && ctrl.value.isInitialized) ? ctrl.value.position : _lastPosition;
    if (currentPos > Duration.zero) {
      _lastPosition = currentPos;
    }
    final savedPos = _lastPosition;

    _disposeController();
    if (mounted) {
      setState(() {
        _isLoadingPlay = true;
        _isInitialized = false;
        _hasError = false;
      });
    }

    try {
      final locale = ref.read(localeProvider);
      final dramaApi = ref.read(dramaApiServiceProvider);
      final bundle = await EpisodePlaybackHelper(dramaApi)
          .ensureFreshEpisodeStream(
        dramaId: widget.drama.dramaId,
        episodeNumber: widget.episodeNo,
        cachedBundle: forceRefresh ? null : _streamBundle,
        lang: locale.appLanguage,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      _streamBundle = bundle;
      await _startVideoStream(
        bundle,
        resumePosition: savedPos,
        autoPlayAfter: autoPlayAfter,
      );
    } on DramaPaywallException catch (e) {
      _handleEpisodePaywall(e);
    } catch (e, st) {
      debugPrint(
        'ShortVideoItem._renewEpisodeStream error (${widget.drama.dramaId} ep ${widget.episodeNo}): $e\n$st',
      );
      _disposeController();
      if (!mounted) return;
      setState(() {
        _isLoadingPlay = false;
        _hasError = true;
        _errorMessage = ref.read(localeProvider).tr('generic_error_toast');
      });
    } finally {
      _isRenewingStream = false;
    }
  }

  Future<void> _startVideoStream(
    StreamBundle bundle, {
    Duration? resumePosition,
    bool autoPlayAfter = true,
  }) async {
    final trimmedUrl = bundle.videoUrl.trim();
    if (trimmedUrl.isEmpty) {
      throw StateError('Empty video URL');
    }

    final playableSubs = bundle.subtitles
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

    try {
      await ctrl.initialize().timeout(const Duration(seconds: 20));
    } catch (e) {
      if (mounted &&
          _controller == ctrl &&
          !_hasRetried403 &&
          EpisodePlaybackHelper.isHttp403Error(e)) {
        await _handle403SafetyRetry();
        return;
      }
      rethrow;
    }

    if (!mounted || _controller != ctrl) {
      unawaited(_safeDisposeController(ctrl));
      return;
    }
    if (ctrl.value.hasError) {
      final errDesc = ctrl.value.errorDescription;
      if (!_hasRetried403 && EpisodePlaybackHelper.isHttp403Error(errDesc)) {
        await _handle403SafetyRetry();
        return;
      }
      throw StateError(errDesc ?? 'Video init failed');
    }

    final targetSeek = resumePosition != null && resumePosition > Duration.zero
        ? resumePosition
        : (widget.initialPositionSec > 0 && !_didApplyInitialSeek
            ? Duration(seconds: widget.initialPositionSec)
            : null);

    if (targetSeek != null && targetSeek > Duration.zero) {
      final durMs = ctrl.value.duration.inMilliseconds;
      if (durMs <= 0 || targetSeek.inMilliseconds < durMs - 2000) {
        await _safeSeekTo(ctrl, targetSeek);
        _lastPosition = targetSeek;
      }
    }
    _didApplyInitialSeek = true;

    await _safeSetPlaybackSpeed(ctrl, ref.read(userWalletProvider).playbackSpeed);
    if (!mounted || _controller != ctrl) return;
    ctrl.addListener(_onVideoTick);

    setState(() {
      _isLoadingPlay = false;
      _isInitialized = true;
      _isPausedByUser = !autoPlayAfter;
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
    if (widget.isActive && !_isPausedByUser && _canPlayInForeground) {
      unawaited(_safePlay(ctrl));
      final posSec = ctrl.value.position.inSeconds;
      final durSec = ctrl.value.duration.inSeconds;
      widget.onPlaybackUpdate?.call(posSec, durSec, true);
      _scheduleControlsAutoHide();
    } else {
      _hideControlsTimer?.cancel();
      _hideControlsTimer = null;
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
      final errDesc = ctrl.value.errorDescription;
      debugPrint(
        'ShortVideoItem playback error (${widget.drama.dramaId} ep ${widget.episodeNo}): $errDesc',
      );
      if (ctrl.value.position > Duration.zero) {
        _lastPosition = ctrl.value.position;
      }
      if (!_hasRetried403 && EpisodePlaybackHelper.isHttp403Error(errDesc)) {
        unawaited(_handle403SafetyRetry());
        return;
      }
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
    if (pos > Duration.zero) {
      _lastPosition = pos;
    }
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
    if (!ctrl.value.isPlaying &&
        _streamBundle != null &&
        _streamBundle!.isExpired) {
      _isPausedByUser = false;
      _handleExpiredStream(autoPlayAfter: true);
      return;
    }
    final shouldPause = ctrl.value.isPlaying;
    setState(() {
      if (shouldPause) {
        _lastPosition = ctrl.value.position;
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
    if (shouldPause) {
      _setControlsVisible(true, scheduleAutoHide: false);
    } else {
      _setControlsVisible(true);
    }
  }

  Future<void> _handleOpenEpisodeList() async {
    final cb = widget.onOpenEpisodeList;
    if (cb == null) return;
    _hideControlsTimer?.cancel();
    setState(() => _isEpisodeSheetOpen = true);
    try {
      await cb();
    } finally {
      if (mounted) {
        setState(() => _isEpisodeSheetOpen = false);
        _scheduleControlsAutoHide();
      }
    }
  }

  Future<void> _openPlayerSettings(
    List<String> availableSubLangs, {
    bool subtitlesOnly = false,
  }) async {
    _hideControlsTimer?.cancel();
    _isSettingsSheetOpen = true;
    try {
      await PlayerSettingsSheet.show(
        context,
        availableSubLangs: availableSubLangs,
        subtitlesOnly: subtitlesOnly,
      );
    } finally {
      _isSettingsSheetOpen = false;
      if (mounted) {
        _scheduleControlsAutoHide();
      }
    }
  }

  void _cyclePlaybackSpeed(double currentSpeed) {
    final idx = _speeds.indexOf(currentSpeed);
    final nextSpeed = _speeds[(idx + 1) % _speeds.length];
    ref.read(userWalletProvider.notifier).setPlaybackSpeed(nextSpeed);
    _scheduleControlsAutoHide();
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
        _setPaywallState(null, '');
        _isUnlocking = false;
      });
      if (resp.videoUrl.trim().isNotEmpty) {
        final bundle = resp.toStreamBundle();
        _streamBundle = bundle;
        await _startVideoStream(bundle);
      } else {
        await _initEpisode();
      }
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

  Future<void> _openRewardsOrVip() async {
    final purchased = await PremiumUpgradeDialog.show(
      context,
      closeDelaySeconds: 0,
      sourceScreen: 'player_paywall',
    );
    if (!mounted) return;
    if (purchased && _paywall != null && widget.isActive) {
      unawaited(_initEpisode());
    }
  }

  void _disposeController() {
    final ctrl = _controller;
    _controller = null;
    unawaited(_safeDisposeController(ctrl));
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
    _notifyPaywallVisibility(false);
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  Widget _buildFullBleedVideo(VideoPlayerController ctrl) {
    final rawSize = ctrl.value.size;
    final videoWidth = rawSize.width > 0 ? rawSize.width : 1080.0;
    final videoHeight = rawSize.height > 0 ? rawSize.height : 1920.0;

    return GestureDetector(
      onTap: _onVideoAreaTap,
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

    ref.listen<bool>(
      userWalletProvider.select((s) => s.isVip),
      (prev, isVip) {
        if (isVip && prev != true && _paywall != null && widget.isActive) {
          unawaited(_initEpisode());
        }
      },
    );

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

    final mediaQuery = MediaQuery.of(context);
    final rawBottomInset = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.systemGestureInsets.bottom,
    );
    // Keep seekbar well clear of Android's bottom multitasking gesture zone
    // even under immersiveSticky (where padding.bottom can report 0).
    final seekBarBottom = widget.showFullDramaButton
        ? 6.h
        : math.max(rawBottomInset, 28.h);
    final controlsContentBottom = seekBarBottom + 32.h;

    final totalEps = widget.drama.totalEpisodes > 0
        ? widget.drama.totalEpisodes
        : widget.episodeNo;
    final isLocked = _paywall != null;
    final showChrome =
        isLocked || _hasError || !_isInitialized || _controlsVisible;
    const animDuration = Duration(milliseconds: 220);

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

          // 2. Center Play / Pause Button (visible on tap or when paused; auto-hides in 3s while playing)
          if (!isLocked && !_hasError && _isInitialized)
            Center(
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: animDuration,
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: const BoxDecoration(
                        color: AppColors.overlayMedium,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPausedByUser
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: AppColors.textPrimary,
                        size: 50.sp,
                      ),
                    ),
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
              child: AnimatedOpacity(
                opacity: showChrome ? 1.0 : 0.0,
                duration: animDuration,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.bottomScrimGradient,
                  ),
                ),
              ),
            ),
          ),

          // 4. Synchronized VTT/SRT Subtitle Overlay (remains visible in fullscreen)
          if (!isLocked &&
              locale.subtitlesEnabled &&
              _activeSubtitle != null &&
              _activeSubtitle!.isNotEmpty)
            AnimatedPositioned(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              left: 20.w,
              right: (widget.showFullDramaButton || !showChrome) ? 20.w : 82.w,
              bottom: showChrome
                  ? controlsContentBottom +
                      (widget.showFullDramaButton ? 150.h : 106.h)
                  : seekBarBottom + 14.h,
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
              bottom: controlsContentBottom,
              child: IgnorePointer(
                ignoring: !showChrome,
                child: AnimatedOpacity(
                  opacity: showChrome ? 1.0 : 0.0,
                  duration: animDuration,
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
                          _scheduleControlsAutoHide();
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
                        onTap: () => unawaited(
                          _openPlayerSettings(
                            sheetSubLangs,
                            subtitlesOnly: true,
                          ),
                        ),
                        onLongPress: hasPlayableSubs
                            ? () {
                                ref
                                    .read(localeProvider.notifier)
                                    .toggleSubtitlesEnabled();
                                _scheduleControlsAutoHide();
                              }
                            : null,
                      ),
                      SizedBox(height: 15.h),
                      _ActionIconButton(
                        icon: Icons.speed_rounded,
                        label: _formatSpeed(playbackSpeed),
                        onTap: () => _cyclePlaybackSpeed(playbackSpeed),
                        onLongPress: () => unawaited(
                          _openPlayerSettings(sheetSubLangs),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Bottom-Left Drama Info & Frosted "Watch Full Series" Button
          Positioned(
            left: 16.w,
            right: widget.showFullDramaButton ? 16.w : 80.w,
            bottom: controlsContentBottom,
            child: IgnorePointer(
              ignoring: !showChrome,
              child: AnimatedOpacity(
                opacity: showChrome ? 1.0 : 0.0,
                duration: animDuration,
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
            ),
          ),

          // 7. TikTok-style Seek Bar (raised above system multitasking gesture bar)
          if (!isLocked && _isInitialized && _controller != null)
            Positioned(
              left: 14.w,
              right: 14.w,
              bottom: seekBarBottom,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: animDuration,
                  child: _TikTokVideoSeekBar(
                    controller: _controller!,
                    onScrubStart: () {
                      _isScrubbing = true;
                      _hideControlsTimer?.cancel();
                    },
                    onScrubEnd: () {
                      _isScrubbing = false;
                      _scheduleControlsAutoHide();
                    },
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
      onOpenRewardsOrVip: _openRewardsOrVip,
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

class _TikTokVideoSeekBar extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubEnd;

  const _TikTokVideoSeekBar({
    required this.controller,
    this.onScrubStart,
    this.onScrubEnd,
  });

  @override
  State<_TikTokVideoSeekBar> createState() => _TikTokVideoSeekBarState();
}

class _TikTokVideoSeekBarState extends State<_TikTokVideoSeekBar> {
  bool _isDragging = false;
  double _dragFraction = 0.0;
  DateTime _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);

  double _fractionFromOffset(double dx, double width) {
    if (width <= 0) return 0.0;
    return (dx / width).clamp(0.0, 1.0);
  }

  void _seekToFraction(double fraction, Duration duration, {bool force = false}) {
    if (duration.inMilliseconds <= 0) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSeekAt).inMilliseconds < 120) return;
    _lastSeekAt = now;
    final targetMs = (duration.inMilliseconds * fraction).round();
    unawaited(widget.controller.seekTo(Duration(milliseconds: targetMs)));
  }

  String _formatDuration(Duration d) {
    final totalSec = d.inSeconds.clamp(0, 359999);
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final duration = value.duration;
        final totalMs = duration.inMilliseconds;
        final currentFraction = totalMs > 0
            ? (value.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0;
        final displayFraction = _isDragging ? _dragFraction : currentFraction;
        final displayPos = totalMs > 0
            ? Duration(milliseconds: (totalMs * displayFraction).round())
            : Duration.zero;

        final trackHeight = _isDragging ? 6.h : 3.h;
        final thumbSize = _isDragging ? 14.r : 8.r;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final thumbCenterX = (width * displayFraction).clamp(
              thumbSize / 2,
              math.max(thumbSize / 2, width - thumbSize / 2),
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (_isDragging && totalMs > 0)
                  Positioned(
                    bottom: 36.h,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.overlayDark,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '${_formatDuration(displayPos)} / ${_formatDuration(duration)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    if (totalMs <= 0) return;
                    widget.onScrubStart?.call();
                    final f = _fractionFromOffset(details.localPosition.dx, width);
                    setState(() => _dragFraction = f);
                    _seekToFraction(f, duration, force: true);
                    widget.onScrubEnd?.call();
                  },
                  onHorizontalDragStart: (details) {
                    if (totalMs <= 0) return;
                    widget.onScrubStart?.call();
                    setState(() {
                      _isDragging = true;
                      _dragFraction = _fractionFromOffset(
                        details.localPosition.dx,
                        width,
                      );
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    if (totalMs <= 0) return;
                    final f = _fractionFromOffset(details.localPosition.dx, width);
                    setState(() => _dragFraction = f);
                    _seekToFraction(f, duration);
                  },
                  onHorizontalDragEnd: (_) {
                    if (!_isDragging) return;
                    _seekToFraction(_dragFraction, duration, force: true);
                    setState(() => _isDragging = false);
                    widget.onScrubEnd?.call();
                  },
                  onHorizontalDragCancel: () {
                    if (!_isDragging) return;
                    setState(() => _isDragging = false);
                    widget.onScrubEnd?.call();
                  },
                  child: SizedBox(
                    height: 32.h,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: trackHeight,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.playerProgressTrack,
                            borderRadius: BorderRadius.circular(trackHeight / 2),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: displayFraction,
                          child: Container(
                            height: trackHeight,
                            decoration: BoxDecoration(
                              color: AppColors.playerProgressPlayed,
                              borderRadius: BorderRadius.circular(
                                trackHeight / 2,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: thumbCenterX - thumbSize / 2,
                          child: Container(
                            width: thumbSize,
                            height: thumbSize,
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withValues(alpha: 0.45),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
