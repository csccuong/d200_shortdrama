import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/utils/screen_utils.dart';
import '../models/play_response.dart';
import '../providers/app_providers.dart';
import 'drama_network_image.dart';

/// High-CTR paywall / unlock reward overlay shown on locked drama episodes.
class UnlockRewardOverlay extends StatefulWidget {
  final String coverUrl;
  final int episodeNo;
  final String blockReason;
  final UnlockOptions options;
  final bool isUnlocking;
  final LocaleState locale;
  final VoidCallback onUnlockWithAd;
  final VoidCallback? onOpenRewardsOrVip;

  const UnlockRewardOverlay({
    super.key,
    required this.coverUrl,
    required this.episodeNo,
    required this.blockReason,
    required this.options,
    required this.isUnlocking,
    required this.locale,
    required this.onUnlockWithAd,
    this.onOpenRewardsOrVip,
  });

  @override
  State<UnlockRewardOverlay> createState() => _UnlockRewardOverlayState();
}

class _UnlockRewardOverlayState extends State<UnlockRewardOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opts = widget.options;
    final hasAdQuota =
        opts.allowAdUnlock && opts.adUnlocksRemainingToday > 0;
    final locale = widget.locale;

    return Stack(
      fit: StackFit.expand,
      children: [
        DramaNetworkImage(imageUrl: widget.coverUrl, fit: BoxFit.cover),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 1.05,
                  colors: [
                    Color(0x9E1A0C12),
                    AppColors.overlayHeavy,
                  ],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: 360.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.r),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x55FFD56B),
                    Color(0x40FA3C41),
                    Color(0x18FFFFFF),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBright.withValues(alpha: 0.22),
                    blurRadius: 34,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                  const BoxShadow(
                    color: AppColors.overlayHeavy,
                    blurRadius: 26,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(1.3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22.7.r),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLockedCard,
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.95),
                            radius: 1.15,
                            colors: [
                              AppColors.primaryBright.withValues(alpha: 0.18),
                              AppColors.gold.withValues(alpha: 0.05),
                              AppColors.surfaceLockedCard,
                            ],
                            stops: const [0.0, 0.42, 0.92],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 20.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _UnlockHeroEmblem(animation: _animCtrl),
                          SizedBox(height: 12.h),
                          Text(
                            '${locale.tr('unlock_ep_title')} ${widget.episodeNo}',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.h2.copyWith(
                              fontSize: 19.sp,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (widget.blockReason == 'DAILY_LIMIT_REACHED') ...[
                            _DailyLimitPill(
                              options: opts,
                            ),
                            SizedBox(height: 16.h),
                          ] else
                            SizedBox(height: 18.h),
                          if (hasAdQuota) ...[
                            _RewardAdCtaButton(
                              animation: _animCtrl,
                              isUnlocking: widget.isUnlocking,
                              label: widget.isUnlocking
                                  ? locale.tr('watching_ad')
                                  : locale.tr('watch_ad_free'),
                              quotaText:
                                  '${opts.adUnlocksRemainingToday}/${opts.adUnlockDailyLimit}',
                              onTap: widget.onUnlockWithAd,
                            ),
                            SizedBox(height: 10.h),
                          ],
                          if (widget.onOpenRewardsOrVip != null)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: widget.isUnlocking
                                    ? null
                                    : widget.onOpenRewardsOrVip,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.gold.withValues(alpha: 0.08),
                                  foregroundColor: AppColors.gold,
                                  side: BorderSide(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.72),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  padding:
                                      EdgeInsets.symmetric(vertical: 11.h),
                                ),
                                icon: Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 18.sp,
                                ),
                                label: Text(
                                  locale.tr('upgrade_vip_title'),
                                  style: AppTextStyles.buttonMedium.copyWith(
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
}

class _DailyLimitPill extends StatelessWidget {
  final UnlockOptions options;

  const _DailyLimitPill({required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.primaryBright.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_bottom_rounded,
            size: 14.sp,
            color: AppColors.primaryBright,
          ),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              'Daily free ad limit reached (${options.adUnlocksRemainingToday}/${options.adUnlockDailyLimit})',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textWhite70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardAdCtaButton extends StatelessWidget {
  final Animation<double> animation;
  final bool isUnlocking;
  final String label;
  final String quotaText;
  final VoidCallback onTap;

  const _RewardAdCtaButton({
    required this.animation,
    required this.isUnlocking,
    required this.label,
    required this.quotaText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        final shimmerX = -1.3 + t * 2.6;

        return GestureDetector(
          onTap: isUnlocking ? null : onTap,
          child: Container(
            width: double.infinity,
            height: 48.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFFF5A36),
                  AppColors.primaryBright,
                  AppColors.gradientRedEnd,
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFC875).withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBright.withValues(
                    alpha: isUnlocking ? 0.15 : (0.34 + 0.18 * pulse),
                  ),
                  blurRadius: 18 + 6 * pulse,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13.r),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Top gloss sheen
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 22.h,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Diagonal light sweep
                  if (!isUnlocking)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: FractionallySizedBox(
                          widthFactor: 0.45,
                          alignment: Alignment(shimmerX, 0),
                          child: Transform.rotate(
                            angle: 0.35,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.20),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Row(
                      children: [
                        Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                          child: isUnlocking
                              ? Padding(
                                  padding: EdgeInsets.all(6.w),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.textPrimary,
                                  size: 20.sp,
                                ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.buttonMedium.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.26),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            quotaText,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom-drawn animated golden & ruby reward unlock emblem.
class _UnlockHeroEmblem extends StatelessWidget {
  final Animation<double> animation;

  const _UnlockHeroEmblem({required this.animation});

  @override
  Widget build(BuildContext context) {
    final size = 94.w;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final wave = math.sin(t * 2 * math.pi);
        final scale = 1.0 + 0.035 * wave;
        final floatY = -2.5 * wave;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _UnlockRewardPainter(phase: t),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UnlockRewardPainter extends CustomPainter {
  final double phase;

  _UnlockRewardPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.54;
    final pulse = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);

    // 1. Ambient gold-crimson radial aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC145).withValues(alpha: 0.42 + 0.14 * pulse),
          AppColors.primaryBright.withValues(alpha: 0.24 + 0.10 * pulse),
          Colors.transparent,
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.52));
    canvas.drawCircle(Offset(cx, cy), w * 0.52, auraPaint);

    // 2. Soft halo ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFE694).withValues(alpha: 0.65),
          AppColors.primaryBright.withValues(alpha: 0.35),
          const Color(0xFFFFB800).withValues(alpha: 0.15),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.39));
    canvas.drawCircle(Offset(cx, cy), w * 0.39, ringPaint);

    // 3. Open metallic gold shackle (signals ready-to-unlock!)
    final shacklePath = Path()
      ..moveTo(cx - w * 0.16, cy - h * 0.08)
      ..lineTo(cx - w * 0.16, cy - h * 0.23)
      ..cubicTo(
        cx - w * 0.16,
        cy - h * 0.40,
        cx + w * 0.19,
        cy - h * 0.41,
        cx + w * 0.20,
        cy - h * 0.22,
      )
      ..lineTo(cx + w * 0.20, cy - h * 0.17);

    final shackleGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.095
      ..color = const Color(0xFFFFC84D).withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(shacklePath, shackleGlow);

    final shacklePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.075
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF6C9),
          Color(0xFFFFC83D),
          Color(0xFFD68910),
        ],
      ).createShader(Rect.fromLTWH(cx - w * 0.22, cy - h * 0.42, w * 0.45, h * 0.36));
    canvas.drawPath(shacklePath, shacklePaint);

    // Subtle specular highlight on shackle
    final shackleSpec = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.02
      ..color = Colors.white.withValues(alpha: 0.72);
    final specPath = Path()
      ..moveTo(cx - w * 0.165, cy - h * 0.16)
      ..lineTo(cx - w * 0.165, cy - h * 0.23)
      ..quadraticBezierTo(cx - w * 0.14, cy - h * 0.34, cx - w * 0.02, cy - h * 0.355);
    canvas.drawPath(specPath, shackleSpec);

    // 4. Ruby-crimson 3D lock body with golden rim
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + h * 0.06),
        width: w * 0.50,
        height: h * 0.39,
      ),
      Radius.circular(w * 0.13),
    );

    canvas.drawRRect(
      bodyRect.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFF684D),
          Color(0xFFFA2E3B),
          Color(0xFFA60816),
        ],
      ).createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, bodyPaint);

    // Glossy top facet inside body
    canvas.save();
    canvas.clipRRect(bodyRect);
    final sheenRect = Rect.fromLTWH(
      bodyRect.left,
      bodyRect.top,
      bodyRect.width,
      bodyRect.height * 0.45,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, bodyRect.top + bodyRect.height * 0.14),
        width: bodyRect.width * 1.15,
        height: bodyRect.height * 0.52,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(sheenRect),
    );
    canvas.restore();

    // Metallic gold border around body
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF2B2),
          Color(0xFFFFB800),
          Color(0xFFE07B00),
        ],
      ).createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, rimPaint);

    // 5. Center glowing Play Triangle inside golden circle
    final playCenter = Offset(cx, cy + h * 0.065);
    canvas.drawCircle(
      playCenter,
      w * 0.115,
      Paint()..color = Colors.black.withValues(alpha: 0.24),
    );
    final playSize = w * 0.125;
    final playPath = Path()
      ..moveTo(playCenter.dx - playSize * 0.38, playCenter.dy - playSize * 0.56)
      ..lineTo(playCenter.dx + playSize * 0.62, playCenter.dy)
      ..lineTo(playCenter.dx - playSize * 0.38, playCenter.dy + playSize * 0.56)
      ..close();
    canvas.drawPath(
      playPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFFFFE59D),
          ],
        ).createShader(Rect.fromCircle(center: playCenter, radius: playSize)),
    );

    // 6. Twinkling 4-point sparkles
    _drawSparkle(
      canvas,
      Offset(w * 0.80, h * 0.24),
      w * 0.085 * (0.75 + 0.35 * pulse),
      const Color(0xFFFFF3B0),
    );
    _drawSparkle(
      canvas,
      Offset(w * 0.19, h * 0.30),
      w * 0.065 * (0.75 + 0.35 * (1 - pulse)),
      const Color(0xFFFF9EA6),
    );
    _drawSparkle(
      canvas,
      Offset(w * 0.83, h * 0.72),
      w * 0.055 * (0.70 + 0.35 * (1 - pulse)),
      const Color(0xFFFFD166),
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _UnlockRewardPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
