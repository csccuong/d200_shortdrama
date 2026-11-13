import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/dimens/ad_dimen.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/screen_utils.dart';
import '../../providers/app_providers.dart';
import 'onboard_controller.dart';

class OnboardActivity extends ConsumerStatefulWidget {
  const OnboardActivity({super.key});

  @override
  ConsumerState<OnboardActivity> createState() => _OnboardActivityState();
}

class _OnboardActivityState extends ConsumerState<OnboardActivity> {
  final OnboardController _controller = OnboardController();

  @override
  void initState() {
    super.initState();
    if (AppConstants.isMobilePlatform) {
      EasyAds.instance.appLifecycleReactor?.setOnSplashScreen(true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.init();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _buttonLabel(LocaleState locale) {
    return locale.tr('onboard_next');
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final steps = _controller.getSteps();

            return PageView.builder(
              controller: _controller.pageController,
              // physics: const NeverScrollableScrollPhysics(),
              itemCount: steps.length,
              onPageChanged: _controller.onChangePage,
              itemBuilder: (context, index) {
                final step = steps[index];
                if (step.isFullAd) {
                  return _buildFullAdPage(step, steps);
                }
                return _buildIntroPage(locale, step, steps);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullAdPage(OnboardStep step, List<OnboardStep> steps) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          step.fullAd?.show() ?? const SizedBox.shrink(),
          if (_controller.isFullAdNextButtonVisible)
            Positioned(
              right: 16.w,
              top: 12.h,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => _controller.onSelectNext(context, steps),
                  child: Container(
                    width: 38.w,
                    height: 38.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.overlayDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderMedium),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                      size: 22.sp,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntroPage(
    LocaleState locale,
    OnboardStep step,
    List<OnboardStep> steps,
  ) {
    final hasAd = step.hasAd;
    final isSmallBtnLayout =
        _controller.currentTabOnboard == 0 || _controller.currentTabOnboard == 3;

    return Column(
      children: [
        // 1. Top Visual Artwork (replaceable via assets/images/onboard1..4.png)
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                step.image,
                fit: step.fit,
                width: double.infinity,
                errorBuilder: (_, _, _) => step.fallbackPoster.isNotEmpty
                    ? Image.asset(
                        step.fallbackPoster,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColors.surface),
                      )
                    : const ColoredBox(color: AppColors.surface),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.onboardImageBottomGradient,
                ),
              ),
            ],
          ),
        ),

        // 2. Bottom Copy + Dots + Next Button + Native Ad
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  locale.tr(step.titleKey),
                  style: AppTextStyles.onboardTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 22.w),
                child: Text(
                  locale.tr(step.descKey),
                  style: AppTextStyles.onboardDesc,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 18.h),
              if (isSmallBtnLayout) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPillDotsIndicator(),
                      _buildSmallNextButton(locale, steps),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                if (hasAd)
                  EasyNativeAd(
                    key: ValueKey('${step.adIdName ?? step.adId}_${step.titleKey}'),
                    factoryId: step.factoryId,
                    adId: step.adId,
                    adIdName: step.adIdName,
                    height: AdDimen.mediumNativeHeight,
                  )
                else if (AppConstants.isMobilePlatform &&
                    !AppConstants.isPremiumUser.value)
                  const SizedBox(height: AdDimen.mediumNativeHeight)
                else
                  SizedBox(height: 16.h),
              ] else ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _buildPillDotsIndicator(),
                  ),
                ),
                SizedBox(height: 16.h),
                _buildBigNextButton(locale, steps),
                SizedBox(height: 18.h),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillDotsIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_controller.totalPage, (idx) {
        final isActive = idx == _controller.currentTabOnboard;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: isActive ? 26.w : 22.w,
          height: 6.h,
          margin: EdgeInsets.only(right: idx == _controller.totalPage - 1 ? 0 : 7.w),
          decoration: BoxDecoration(
            color: isActive ? null : AppColors.onboardDotInactive,
            gradient: isActive ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(4.r),
          ),
        );
      }),
    );
  }

  Widget _buildSmallNextButton(LocaleState locale, List<OnboardStep> steps) {
    final introIndex = _controller.currentTabOnboard;
    final isLoading =
        (introIndex == 0 && _controller.isIntro1AdLoading) ||
            (introIndex == 3 && _controller.isIntro4AdLoading);

    if (isLoading) {
      return SizedBox(
        width: 88.w,
        height: 38.h,
        child: Center(
          child: SizedBox(
            width: 22.w,
            height: 22.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2.3,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _controller.onSelectNext(context, steps),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: AppColors.transparent,
          border: Border.all(color: AppColors.primary, width: 1.0),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Text(
          _buttonLabel(locale),
          style: AppTextStyles.onboardSmallNextBtn,
        ),
      ),
    );
  }

  Widget _buildBigNextButton(LocaleState locale, List<OnboardStep> steps) {
    return GestureDetector(
      onTap: () => _controller.onSelectNext(context, steps),
      child: Container(
        width: double.infinity,
        height: 50.h,
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.r),
          gradient: AppColors.primaryGradient,
        ),
        child: Text(
          _buttonLabel(locale),
          style: AppTextStyles.onboardBigNextBtn,
        ),
      ),
    );
  }
}
