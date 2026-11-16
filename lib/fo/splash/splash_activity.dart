import 'dart:math' as math;

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/const/ad_id_extension.dart';
import '../../ads/const/ad_id_name.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/screen_utils.dart';
import '../../providers/app_providers.dart';
import '../../core/router/app_route_observer.dart';
import '../../services/firebase_remote_config_service.dart';
import 'splash_controller.dart';

class SplashActivity extends ConsumerStatefulWidget {
  final VoidCallback? onFinished;

  const SplashActivity({
    super.key,
    this.onFinished,
  });

  @override
  ConsumerState<SplashActivity> createState() => _SplashActivityState();
}

class _SplashActivityState extends ConsumerState<SplashActivity>
    with TickerProviderStateMixin {
  final SplashController _controller = SplashController();
  late final AnimationController _wallDriftController;
  late final AnimationController _shimmerController;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    AppRouteObserver.logScreen('SplashActivity');
    _wallDriftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    if (AppConstants.isFlutterTest) {
      _wallDriftController.value = 0.28;
      _shimmerController.value = 0.45;
      _entranceController.value = 1.0;
    } else {
      _wallDriftController.repeat();
      _shimmerController.repeat();
      _entranceController.forward();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.init(
          context,
          ref: ref,
          onFinished: widget.onFinished,
        );
      }
    });
  }

  @override
  void dispose() {
    _wallDriftController.dispose();
    _shimmerController.dispose();
    _entranceController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final showBannerSplash = AppConstants.isMobilePlatform &&
        !AppConstants.isPremiumUser.value &&
        FirebaseRemoteConfigService.getBoolConfigByKey(
          FirebaseRemoteConfigService.banner_splash,
        );
    final entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Tilted 4-Column Drifting Drama Poster Wall (GPU-isolated)
          RepaintBoundary(
            child: _TiltedDriftingPosterWall(
              animation: _wallDriftController,
            ),
          ),

          // 2. Cinema Top/Bottom/Side Vignettes + Breathing Crimson Center Glow
          _CinemaSpotlightVignette(
            pulseAnimation: _shimmerController,
          ),

          // 3. Foreground App Icon Emblem, Brand Title, Tagline, Spark Progress & Ad
          SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return Column(
                  children: [
                    const Spacer(flex: 5),

                    FadeTransition(
                      opacity: entranceFade,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(entranceFade),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Glowing squircle app_icon.png with pulse halo & shimmer sweep
                            RepaintBoundary(
                              child: _GlassShimmerBrandEmblem(
                                shimmerAnimation: _shimmerController,
                              ),
                            ),
                            SizedBox(height: 22.h.clamp(14.0, 26.0)),

                            // Brand Title
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: Text(
                                'Dramota',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.splashAppTitle.copyWith(
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h.clamp(4.0, 10.0)),

                            // Localized Tagline
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32.w),
                              child: Text(
                                locale.tr('splash_tagline'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.splashTagline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 6),

                    // Glowing Crimson Progress Bar with Spark Tip
                    _GlowingSparkProgressBar(
                      progress: _controller.percentLoading,
                    ),
                    SizedBox(height: 10.h.clamp(6.0, 14.0)),

                    // Ad Notice Caption
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Text(
                        locale.tr('splash_ad_notice'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.splashAdNotice,
                      ),
                    ),

                    // Separated Splash Banner Ad
                    if (showBannerSplash) ...[
                      SizedBox(height: 12.h.clamp(8.0, 14.0)),
                      EasyBannerAd(
                        adId: MyAdIdName.bannerSplash.getId,
                        adIdName: MyAdIdName.bannerSplash,
                      ),
                    ],
                    SizedBox(height: 14.h.clamp(8.0, 18.0)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tilted 4-column poster wall drifting smoothly in alternating vertical directions.
class _TiltedDriftingPosterWall extends StatelessWidget {
  final Animation<double> animation;

  const _TiltedDriftingPosterWall({
    required this.animation,
  });

  static const List<List<String>> _posterColumns = [
    [
      'assets/images/onboard1.webp',
      'assets/images/onboard4.webp',
      'assets/images/onboard2.webp',
      'assets/images/onboard3.webp',
    ],
    [
      'assets/images/onboard3.webp',
      'assets/images/onboard2.webp',
      'assets/images/rewards_hero_banner.jpg',
      'assets/images/onboard1.webp',
    ],
    [
      'assets/images/onboard2.webp',
      'assets/images/onboard1.webp',
      'assets/images/onboard4.webp',
      'assets/images/rewards_hero_banner.jpg',
    ],
    [
      'assets/images/onboard4.webp',
      'assets/images/rewards_hero_banner.jpg',
      'assets/images/onboard3.webp',
      'assets/images/onboard2.webp',
    ],
  ];

  static const List<double> _phaseOffsets = [0.0, 0.37, 0.18, 0.61];

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth > 0 ? constraints.maxWidth : 390.0;
          final maxH = constraints.maxHeight > 0 ? constraints.maxHeight : 844.0;
          const colCount = 4;
          const gap = 10.0;

          // Overscan width & height so the +13.5° tilt covers every corner seamlessly.
          final wallWidth = math.max(maxW * 1.44, maxH * 0.82);
          final tileWidth = (wallWidth - gap * (colCount - 1)) / colCount;
          final tileHeight = tileWidth * 1.42;
          final singleCycleHeight = 4 * (tileHeight + gap);
          // Repeat enough cycles to cover tall 21:9 screens + 1 full drift cycle.
          final repeatCopies =
              math.max(3, ((maxH * 1.55) / singleCycleHeight).ceil() + 2);
          final stripHeight = repeatCopies * singleCycleHeight;

          return Transform.rotate(
            angle: 0.235, // ~13.5° cinema tilt matching Concept 1
            child: OverflowBox(
              minWidth: wallWidth,
              maxWidth: wallWidth,
              minHeight: stripHeight,
              maxHeight: stripHeight,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(colCount, (colIndex) {
                      final posters = _posterColumns[colIndex];
                      final isUpward = colIndex.isEven;
                      final phase =
                          (animation.value + _phaseOffsets[colIndex]) % 1.0;
                      // Seamless cyclic translation across exactly one cycle height.
                      final dy = isUpward
                          ? -phase * singleCycleHeight +
                              (singleCycleHeight * 0.5)
                          : (phase - 0.5) * singleCycleHeight;

                      return Padding(
                        padding: EdgeInsets.only(
                          right: colIndex < colCount - 1 ? gap : 0,
                        ),
                        child: Transform.translate(
                          offset: Offset(0, dy),
                          child: SizedBox(
                            width: tileWidth,
                            height: stripHeight,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                repeatCopies * posters.length,
                                (itemIndex) {
                                  final assetPath =
                                      posters[itemIndex % posters.length];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: gap),
                                    child: _PosterWallTile(
                                      assetPath: assetPath,
                                      width: tileWidth,
                                      height: tileHeight,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PosterWallTile extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;

  const _PosterWallTile({
    required this.assetPath,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(11.r.clamp(8.0, 14.0));
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: AppColors.splashPosterTileBorder,
          width: 0.8,
        ),
        gradient: AppColors.splashPosterFallbackGradient,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            width: width,
            height: height,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: 260,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.splashPosterFallbackGradient,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.36),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-layer cinema vignette + gently breathing crimson spotlight behind the emblem.
class _CinemaSpotlightVignette extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _CinemaSpotlightVignette({
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.splashPosterSideVignette,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.splashPosterWallVignette,
            ),
          ),
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              final wave = math.sin(pulseAnimation.value * 2 * math.pi);
              final scale = 1.0 + 0.07 * wave;
              final opacity = 0.86 + 0.14 * ((wave + 1) * 0.5);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.splashCrimsonCenterGlow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glowing squircle brand emblem displaying `assets/images/app_icon.png`
/// with breathing crimson halo rings, gentle scale pulse, and diagonal shimmer sweep.
class _GlassShimmerBrandEmblem extends StatelessWidget {
  final Animation<double> shimmerAnimation;

  const _GlassShimmerBrandEmblem({
    required this.shimmerAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final boxSize = 114.r.clamp(90.0, 126.0);
    final cornerRadius = 28.r.clamp(22.0, 32.0);
    final borderRadius = BorderRadius.circular(cornerRadius);

    return SizedBox(
      width: boxSize * 1.38,
      height: boxSize * 1.38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer & inner breathing crimson halo rings
          AnimatedBuilder(
            animation: shimmerAnimation,
            builder: (context, _) {
              final wave = (math.sin(shimmerAnimation.value * 2 * math.pi) + 1) * 0.5;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 1.0 + 0.08 * wave,
                    child: Container(
                      width: boxSize * 1.32,
                      height: boxSize * 1.32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cornerRadius * 1.32),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.14 + 0.12 * wave),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 1.0 + 0.04 * (1 - wave),
                    child: Container(
                      width: boxSize * 1.15,
                      height: boxSize * 1.15,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cornerRadius * 1.15),
                        border: Border.all(
                          color: AppColors.splashRubyMid.withValues(alpha: 0.25 + 0.18 * (1 - wave)),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Main squircle app_icon.png with breathing scale + diagonal light shimmer
          AnimatedBuilder(
            animation: shimmerAnimation,
            builder: (context, child) {
              final pulse = math.sin(shimmerAnimation.value * 2 * math.pi);
              final scale = 1.0 + 0.022 * pulse;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.splashCrimsonGlowShadow,
                    blurRadius: 38,
                    spreadRadius: 3,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.splashGlassDropShadow,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/app_icon.png',
                      width: boxSize,
                      height: boxSize,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),

                    // Animated diagonal light shimmer sweep across app_icon.png
                    AnimatedBuilder(
                      animation: shimmerAnimation,
                      builder: (context, child) {
                        final dx = (shimmerAnimation.value * 2.8 - 1.4) * boxSize;
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.splashShimmerBandGradient,
                        ),
                      ),
                    ),

                    // Crisp specular rim border
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: AppColors.splashGlassRim,
                          width: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sleek horizontal crimson progress bar with a glowing white-ruby spark orb tip.
class _GlowingSparkProgressBar extends StatelessWidget {
  final double progress;

  const _GlowingSparkProgressBar({
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.04, 1.0);
    final barWidth = 264.w.clamp(200.0, 304.0);
    const trackHeight = 4.5;
    const horizontalPad = 12.0;
    const containerHeight = 24.0;
    final activeWidth = barWidth * clamped;

    return SizedBox(
      width: barWidth + horizontalPad * 2,
      height: containerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background track
          Positioned(
            left: horizontalPad,
            right: horizontalPad,
            top: (containerHeight - trackHeight) * 0.5,
            height: trackHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.splashProgressTrack,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // Filled glowing crimson bar
          Positioned(
            left: horizontalPad,
            top: (containerHeight - trackHeight) * 0.5,
            width: activeWidth,
            height: trackHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.splashCrimsonGlowShadow,
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // Leading-edge glowing spark orb
          Positioned(
            left: horizontalPad + activeWidth - 3.5,
            top: (containerHeight - 7.0) * 0.5,
            width: 7.0,
            height: 7.0,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.splashSparkCore,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.splashSparkMidGlow,
                    blurRadius: 6,
                    spreadRadius: 1.6,
                  ),
                  BoxShadow(
                    color: AppColors.splashSparkOuterGlow,
                    blurRadius: 14,
                    spreadRadius: 3.6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
