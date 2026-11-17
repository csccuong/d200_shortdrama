import 'package:flutter/material.dart';

import '../core/utils/screen_utils.dart';
import '../core/utils/vip_package_helper.dart';

/// Shared selectable VIP subscription plan card with radial red glow and radio indicator.
class VipPackageCard extends StatelessWidget {
  final RewardVipPackage package;
  final bool isSelected;
  final VoidCallback onTap;
  final double? horizontalPadding;

  const VipPackageCard({
    super.key,
    required this.package,
    required this.isSelected,
    required this.onTap,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final radius = 8.r;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(top: 10.h),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isSelected ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, selectionProgress, child) {
                return CustomPaint(
                  painter: _VipPlanCardPainter(
                    selectionProgress: selectionProgress,
                    radius: radius,
                  ),
                  child: child,
                );
              },
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding ?? 8.w,
                  18.h,
                  horizontalPadding ?? 8.w,
                  14.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      package.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.rewardPlanTitle,
                    ),
                    SizedBox(height: 10.h),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        package.price,
                        style: AppTextStyles.rewardPlanPrice(
                          isSelected: isSelected,
                        ),
                      ),
                    ),
                    if (package.periodLabel.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        package.periodLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.captionSmall.copyWith(
                          color: isSelected
                              ? AppColors.textPrimary.withValues(alpha: 0.85)
                              : AppColors.textWhite60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    SizedBox(height: 14.h),
                    Container(
                      width: 20.w,
                      height: 20.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.rewardPlanRadioInactive,
                          width: isSelected ? 1.8 : 1.4,
                        ),
                      ),
                      child: isSelected
                          ? Container(
                              width: 11.w,
                              height: 11.w,
                              decoration: const BoxDecoration(
                                color: AppColors.textPrimary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            if (package.discountBadge != null)
              Positioned(
                top: -10.h,
                left: 4.w,
                right: 4.w,
                child: Center(
                  child: Container(
                    height: 20.h,
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: AppColors.textPrimary.withValues(alpha: 0.22),
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        package.discountBadge!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.rewardSaveBadge,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VipPlanCardPainter extends CustomPainter {
  final double selectionProgress;
  final double radius;

  const _VipPlanCardPainter({
    required this.selectionProgress,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outerRRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final basePaint = Paint()
      ..color = AppColors.rewardPlanCardBg
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRRect(outerRRect, basePaint);

    if (selectionProgress > 0.001) {
      final glowPaint = Paint()
        ..shader = AppColors.rewardSelectedPlanGradient.createShader(rect)
        ..color = AppColors.textPrimary.withValues(alpha: selectionProgress)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawRRect(outerRRect, glowPaint);
    }

    final innerRect = rect.deflate(0.5);
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular((radius - 0.5).clamp(0.0, radius)),
    );

    if (selectionProgress < 0.999) {
      final unselectedBorderPaint = Paint()
        ..color = AppColors.borderSubtle.withValues(
          alpha: AppColors.borderSubtle.a * (1.0 - selectionProgress),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true;
      canvas.drawRRect(innerRRect, unselectedBorderPaint);
    }

    if (selectionProgress > 0.001) {
      final selectedBorderPaint = Paint()
        ..shader = AppColors.rewardSelectedPlanBorderGradient.createShader(rect)
        ..color = AppColors.textPrimary.withValues(alpha: selectionProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true;
      canvas.drawRRect(innerRRect, selectedBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VipPlanCardPainter oldDelegate) {
    return oldDelegate.selectionProgress != selectionProgress ||
        oldDelegate.radius != radius;
  }
}
