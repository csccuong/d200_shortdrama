import 'dart:async';
import 'dart:math' as math;

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/const/ad_id_extension.dart';
import '../ads/const/ad_id_factory.dart';
import '../ads/const/ad_id_name.dart';
import '../ads/dimens/ad_dimen.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/screen_utils.dart';
import '../providers/app_providers.dart';
import '../services/firebase_remote_config_service.dart';

/// Floating native pip over [DramaPlayerScreen].
///
/// The card loads with the episode, appears immediately when ready, and if
/// dismissed, re-appears after 20 seconds.
class FloatingDramaNativeAd extends ConsumerStatefulWidget {
  final String dramaSlug;
  final int episodeNo;
  final bool hold;
  final bool debugForcePreview;

  const FloatingDramaNativeAd({
    super.key,
    required this.dramaSlug,
    this.episodeNo = 1,
    this.hold = false,
    this.debugForcePreview = false,
  });

  @override
  ConsumerState<FloatingDramaNativeAd> createState() =>
      _FloatingDramaNativeAdState();
}

class _FloatingDramaNativeAdState extends ConsumerState<FloatingDramaNativeAd> {
  static const Duration _reShowDelay = Duration(seconds: 20);

  EasyAdBase? _nativeAd;
  Timer? _reShowTimer;
  Offset? _position;
  bool _isAdLoaded = false;
  bool _isDismissed = false;

  double get _resolvedCardWidth =>
      AdDimen.dramaPopupNativeWidth.w.clamp(236.0, 292.0);

  double get _resolvedCardHeight =>
      AdDimen.dramaPopupNativeHeight.h.clamp(244.0, 302.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _beginEpisodeCycle();
    });
  }

  @override
  void didUpdateWidget(covariant FloatingDramaNativeAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    final episodeChanged = oldWidget.dramaSlug != widget.dramaSlug ||
        oldWidget.episodeNo != widget.episodeNo;
    if (episodeChanged) {
      _beginEpisodeCycle();
      return;
    }
    if (oldWidget.hold != widget.hold) {
      if (widget.hold) {
        // When held (e.g. video modal open), widget hides automatically in build
      } else if (!_isDismissed && !_isAdLoaded && _nativeAd == null) {
        _loadPip();
      }
    }
  }

  void _beginEpisodeCycle() {
    _reShowTimer?.cancel();
    _disposeNativeAd();
    _isDismissed = false;
    _isAdLoaded = false;

    if (widget.debugForcePreview) {
      _isAdLoaded = true;
      _notify();
      return;
    }

    if (widget.hold || !_canRequestPip) {
      _notify();
      return;
    }

    _loadPip();
    _notify();
  }

  void _notify() {
    if (!mounted) return;
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return;
    }
    setState(() {});
  }

  bool get _canRequestPip {
    final isVip =
        AppConstants.isPremiumUser.value || ref.read(userWalletProvider).isVip;
    final enabledByConfig = FirebaseRemoteConfigService.getBoolConfigByKey(
      FirebaseRemoteConfigService.native_pip,
    );
    return AppConstants.isMobilePlatform && !isVip && enabledByConfig;
  }

  void _loadPip() {
    final adId = MyAdIdName.nativePip.getId;
    if (adId.isEmpty || adId == 'null') return;

    final ad = EasyAds.instance.createNative(
      adNetwork: AdNetwork.admob,
      factoryId: NativeFactoryId.nativeDramaPopup,
      adId: adId,
      adIdName: MyAdIdName.nativePip,
      height: _resolvedCardHeight,
    );

    if (ad == null) return;
    _nativeAd = ad;

    final originalLoaded = ad.onAdLoaded;
    ad.onAdLoaded = (adNetwork, adUnitType, data) {
      originalLoaded?.call(adNetwork, adUnitType, data);
      if (mounted && !_isDismissed) {
        setState(() {
          _isAdLoaded = true;
        });
      }
    };

    final originalFailed = ad.onAdFailedToLoad;
    ad.onAdFailedToLoad = (adNetwork, adUnitType, data, errorMessage) {
      originalFailed?.call(adNetwork, adUnitType, data, errorMessage);
      if (mounted) {
        setState(() {
          _isAdLoaded = false;
          _isDismissed = true;
        });
        // Sau 20s tự động thử tải lại
        _reShowTimer?.cancel();
        _reShowTimer = Timer(_reShowDelay, () {
          if (!mounted || widget.hold || !_canRequestPip) return;
          setState(() => _isDismissed = false);
          _loadPip();
        });
      }
    };

    ad.load();
  }

  void _dismissAd() {
    _disposeNativeAd();
    _reShowTimer?.cancel();
    if (mounted) {
      setState(() {
        _isDismissed = true;
        _isAdLoaded = false;
      });
    }

    // Khi người dùng bấm tắt, sau 20s sẽ tự động tải lại và hiển thị lại
    _reShowTimer = Timer(_reShowDelay, () {
      if (!mounted || widget.hold) return;
      if (!widget.debugForcePreview && !_canRequestPip) return;

      setState(() {
        _isDismissed = false;
        if (widget.debugForcePreview) {
          _isAdLoaded = true;
        }
      });

      if (!widget.debugForcePreview) {
        _loadPip();
      }
    });
  }

  void _disposeNativeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
  }

  @override
  void dispose() {
    _reShowTimer?.cancel();
    _disposeNativeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVip =
        AppConstants.isPremiumUser.value || ref.watch(userWalletProvider).isVip;
    if (widget.hold ||
        _isDismissed ||
        !_isAdLoaded ||
        (!widget.debugForcePreview && isVip)) {
      return const SizedBox.shrink();
    }

    final cardWidth = _resolvedCardWidth;
    final cardHeight = _resolvedCardHeight;
    final safePadding = MediaQuery.paddingOf(context);

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW =
              constraints.maxWidth > 0 ? constraints.maxWidth : 390.0;
          final maxH =
              constraints.maxHeight > 0 ? constraints.maxHeight : 844.0;

          const edgeMargin = 8.0;
          final minX = edgeMargin;
          final maxX = math.max(minX, maxW - cardWidth - edgeMargin);
          final minY = safePadding.top + edgeMargin;
          final maxY = math.max(
            minY,
            maxH - cardHeight - safePadding.bottom - edgeMargin,
          );

          final defaultX = ((maxW - cardWidth) * 0.5).clamp(minX, maxX);
          final defaultY = (maxH * 0.19).clamp(minY, maxY);

          final currentX = (_position?.dx ?? defaultX).clamp(minX, maxX);
          final currentY = (_position?.dy ?? defaultY).clamp(minY, maxY);
          final cardRadius = BorderRadius.circular(18.r.clamp(14.0, 20.0));

          return Stack(
            children: [
              Positioned(
                left: currentX,
                top: currentY,
                width: cardWidth,
                height: cardHeight,
                child: GestureDetector(
                  key: const ValueKey('floating_drama_native_ad_card'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    _position = Offset(currentX, currentY);
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      final base = _position ?? Offset(currentX, currentY);
                      _position = Offset(
                        (base.dx + details.delta.dx).clamp(minX, maxX),
                        (base.dy + details.delta.dy).clamp(minY, maxY),
                      );
                    });
                  },
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.92, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.floatingAdCardBg,
                        borderRadius: cardRadius,
                        border: AppColors.floatingAdCardBorder ==
                                Colors.transparent
                            ? null
                            : Border.all(
                                color: AppColors.floatingAdCardBorder,
                              ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.floatingAdShadow,
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: cardRadius,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Native PlatformView (or preview card in widget tests)
                            SizedBox.expand(
                              child: widget.debugForcePreview
                                  ? const _FloatingAdPreviewBody()
                                  : (_nativeAd?.show() as Widget? ??
                                      const SizedBox.shrink()),
                            ),

                            // 2. Subtle top drag handle indicator
                            Positioned(
                              top: 4.h.clamp(3.0, 5.0),
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: Container(
                                    width: 28.w.clamp(24.0, 34.0),
                                    height: 3.0,
                                    decoration: BoxDecoration(
                                      color: AppColors.floatingAdDragHandle,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // 3. Top-right Close (X) button to dismiss the ad
                            Positioned(
                              top: 8.r.clamp(4.0, 8.0),
                              right: 8.r.clamp(4.0, 8.0),
                              child: GestureDetector(
                                key: const ValueKey(
                                  'floating_drama_native_ad_close',
                                ),
                                behavior: HitTestBehavior.opaque,
                                onTap: _dismissAd,
                                child: Padding(
                                  padding: EdgeInsets.all(3.r.clamp(2.0, 4.0)),
                                  child: Container(
                                    width: 22.r.clamp(20.0, 26.0),
                                    height: 22.r.clamp(20.0, 26.0),
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: AppColors.floatingAdCloseBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: AppColors.textPrimary,
                                      size: 13.5.sp.clamp(12.0, 16.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pure-Flutter preview mirroring `layout_native_drama_popup.xml` for widget testing.
class _FloatingAdPreviewBody extends StatelessWidget {
  const _FloatingAdPreviewBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 15,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gradientRedStart,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AD',
                  style: AppTextStyles.floatingAdBadge,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 26),
                  child: Text(
                    'Sponsored Recommendation',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.floatingAdPreviewHeadline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.floatingAdPreviewMediaBg,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            height: 1,
            color: AppColors.floatingAdDivider,
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Install',
              style: AppTextStyles.floatingAdPreviewCta,
            ),
          ),
        ],
      ),
    );
  }
}
