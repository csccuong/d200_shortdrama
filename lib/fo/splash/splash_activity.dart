import 'dart:math' as math;
import 'dart:ui' as ui;

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

    if (AppConstants.isFlutterTest) {
      _wallDriftController.value = 0.28;
      _shimmerController.value = 0.45;
    } else {
      _wallDriftController.repeat();
      _shimmerController.repeat();
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

          // 3. Foreground Glassmorphism Shimmer Emblem, Tagline, Spark Progress & Ad
          SafeArea(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return Column(
                  children: [
                    const Spacer(flex: 5),

                    // Frosted-glass squircle emblem with diagonal shimmer & 3D Ruby Play icon
                    RepaintBoundary(
                      child: _GlassShimmerBrandEmblem(
                        shimmerAnimation: _shimmerController,
                      ),
                    ),
                    SizedBox(height: 20.h.clamp(12.0, 24.0)),

                    // Brand Title
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Text(
                        'DXX ShortDrama',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.splashAppTitle,
                      ),
                    ),
                    SizedBox(height: 7.h.clamp(4.0, 10.0)),

                    // Localized Tagline
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28.w),
                      child: Text(
                        locale.tr('splash_tagline'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.splashTagline,
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
    ['', '', '', ''],
    ['', '', '', ''],
    ['', '', '', ''],
    ['', '', '', ''],
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
      child: assetPath.isEmpty
          ? const DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.splashPosterFallbackGradient,
              ),
            )
          : Image.asset(
              assetPath,
              width: width,
              height: height,
              fit: BoxFit.cover,
              cacheWidth: 260,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.splashPosterFallbackGradient,
                ),
              ),
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

/// Frosted-glass squircle logo with diagonal sheen, animated shimmer sweep,
/// and 3D Ruby Play Triangle (or `assets/images/splash_thumb.png` if provided).
class _GlassShimmerBrandEmblem extends StatelessWidget {
  final Animation<double> shimmerAnimation;

  const _GlassShimmerBrandEmblem({
    required this.shimmerAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final boxSize = 114.r.clamp(84.0, 124.0);
    final cornerRadius = 28.r.clamp(21.0, 31.0);
    final borderRadius = BorderRadius.circular(cornerRadius);
    final playSize = boxSize * 0.54;

    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: AppColors.splashCrimsonGlowShadow,
            blurRadius: 34,
            spreadRadius: 2,
            offset: Offset(6, 10),
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
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Base dark frosted glass + subtle surface gradient
              const ColoredBox(color: AppColors.splashGlassBase),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.splashGlassSurfaceGradient,
                ),
              ),

              // Signature Concept 1 diagonal upper-left glass reflection facet
              const CustomPaint(
                painter: _GlassSquircleDiagonalFacetPainter(),
              ),

              // Center brand artwork (`splash_thumb.png` if present, else 3D Ruby Play icon)
              Center(
                child: Image.asset(
                  'assets/images/splash_thumb.png',
                  width: boxSize * 0.72,
                  height: boxSize * 0.72,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => SizedBox(
                    width: playSize,
                    height: playSize,
                    child: const CustomPaint(
                      painter: _RubyPlayTrianglePainter(),
                    ),
                  ),
                ),
              ),

              // Animated diagonal light shimmer sweep
              AnimatedBuilder(
                animation: shimmerAnimation,
                builder: (context, child) {
                  // Sweep across [-1.35 * boxSize, +1.35 * boxSize]
                  final dx = (shimmerAnimation.value * 2.7 - 1.35) * boxSize;
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

              // Crisp glass specular rim border
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
    );
  }
}

class _GlassSquircleDiagonalFacetPainter extends CustomPainter {
  const _GlassSquircleDiagonalFacetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final facetPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.74, 0)
      ..lineTo(size.width * 0.24, size.height)
      ..lineTo(0, size.height)
      ..close();

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width * 0.62, size.height * 0.78),
        const [
          AppColors.splashGlassInnerSheenFill,
          AppColors.transparent,
        ],
      );

    canvas.drawPath(facetPath, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassSquircleDiagonalFacetPainter oldDelegate) =>
      false;
}

class _RubyPlayTrianglePainter extends CustomPainter {
  const _RubyPlayTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final vertices = <Offset>[
      Offset(w * 0.22, h * 0.12),
      Offset(w * 0.22, h * 0.88),
      Offset(w * 0.88, h * 0.50),
    ];

    final trianglePath = _buildRoundedPolygonPath(vertices, radius: w * 0.115);

    // 1. Soft neon ruby glow behind the play emblem
    final glowPaint = Paint()
      ..color = AppColors.splashRubyTriangleGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);
    canvas.drawPath(trianglePath, glowPaint);

    // 2. 3D ruby-coral-crimson gradient body
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.20, h * 0.14),
        Offset(w * 0.84, h * 0.84),
        const [
          AppColors.splashRubyCoralTop,
          AppColors.splashRubyMid,
          AppColors.splashRubyDeep,
        ],
        const [0.0, 0.48, 1.0],
      );
    canvas.drawPath(trianglePath, bodyPaint);

    // 3. Upper-left crystal facet reflection inside the play triangle
    canvas.save();
    canvas.clipPath(trianglePath);
    final crystalFacet = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.66, 0)
      ..lineTo(w * 0.26, h)
      ..lineTo(0, h)
      ..close();
    final facetPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.18, h * 0.12),
        Offset(w * 0.58, h * 0.64),
        const [
          AppColors.splashRubyUpperFacet,
          AppColors.transparent,
        ],
      );
    canvas.drawPath(crystalFacet, facetPaint);
    canvas.restore();

    // 4. Specular rim highlight
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.splashRubyRimLight;
    canvas.drawPath(trianglePath, rimPaint);
  }

  Path _buildRoundedPolygonPath(List<Offset> points, {required double radius}) {
    final path = Path();
    final count = points.length;
    for (var i = 0; i < count; i++) {
      final prev = points[(i - 1 + count) % count];
      final curr = points[i];
      final next = points[(i + 1) % count];

      final toPrev = prev - curr;
      final toNext = next - curr;
      final dPrev = toPrev.distance;
      final dNext = toNext.distance;
      final r = math.min(radius, math.min(dPrev, dNext) * 0.42);

      final start = curr + (toPrev / dPrev) * r;
      final end = curr + (toNext / dNext) * r;

      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, end.dx, end.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _RubyPlayTrianglePainter oldDelegate) => false;
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
