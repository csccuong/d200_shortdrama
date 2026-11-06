import 'package:country_flags/country_flags.dart';
import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/const/ad_id_extension.dart';
import '../../ads/const/ad_id_factory.dart';
import '../../ads/const/ad_id_name.dart';
import '../../ads/dimens/ad_dimen.dart';
import '../../core/constants/app_constants.dart';
import '../../core/helper/firebase_helper.dart';
import '../../core/utils/screen_utils.dart';
import '../../providers/app_providers.dart';
import '../../services/app_strings.dart';
import '../../services/firebase_remote_config_service.dart';
import '../../widgets/app_loading.dart';
import '../onboard/onboard_activity.dart';
import 'language_controller.dart';

class LanguageActivity extends ConsumerStatefulWidget {
  final bool isFirstLaunch;

  const LanguageActivity({
    super.key,
    this.isFirstLaunch = false,
  });

  @override
  ConsumerState<LanguageActivity> createState() => _LanguageActivityState();
}

class _LanguageActivityState extends ConsumerState<LanguageActivity> {
  final LanguageController _controller = LanguageController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dropdownGroupKeys = {};
  String? _autoRevealGroupId;

  @override
  void initState() {
    super.initState();
    _controller.isFirstLaunch = widget.isFirstLaunch;
    _controller.canClick = !widget.isFirstLaunch;
    FirebaseHelper.logLanguageView(isFirstLaunch: widget.isFirstLaunch);
    if (widget.isFirstLaunch && AppConstants.isMobilePlatform) {
      EasyAds.instance.appLifecycleReactor?.setOnSplashScreen(true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentLang = ref.read(localeProvider).appLanguage;
      _controller.init(
        firstLaunch: widget.isFirstLaunch,
        currentLangCode: currentLang,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _shouldShowLanguageAd() {
    if (!AppConstants.isMobilePlatform ||
        AppConstants.isPremiumUser.value ||
        !widget.isFirstLaunch ||
        !_controller.isShouldShowAds) {
      return false;
    }
    if (_controller.isShowClickAds) {
      return FirebaseRemoteConfigService.getBoolConfigByKey(
        FirebaseRemoteConfigService.native_language_click,
      );
    }
    return FirebaseRemoteConfigService.getBoolConfigByKey(
      FirebaseRemoteConfigService.native_language,
    );
  }

  String _previewTr(String key) {
    final langCode =
        _controller.selectedLanguageCode ?? ref.read(localeProvider).appLanguage;
    return AppStrings.tr(langCode, key);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);

    return PopScope(
      canPop: !widget.isFirstLaunch,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _buildHeader(),
                      SizedBox(height: 8.h),
                      Expanded(child: _buildLanguageList()),
                      _buildNativeAd(),
                    ],
                  ),
                ),
                if (_controller.isLoading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.languageLoadingScrim,
                      child: Center(
                        child: AppLoading(
                          width: 96.w,
                          height: 96.w,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hasSelection = _controller.hasSelection;

    return SizedBox(
      height: 56.h,
      width: double.infinity,
      child: Stack(
        children: [
          Center(
            child: Text(
              _previewTr('select_language_title'),
              style: AppTextStyles.languageHeaderTitle,
            ),
          ),
          if (!widget.isFirstLaunch)
            Positioned(
              left: 16.w,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  key: const ValueKey('language_back_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _controller.onSelectBack(context),
                  child: Container(
                    width: 38.r,
                    height: 38.r,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.languageCardBg,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.languageCardBorder),
                    ),
                    child: Icon(
                      AppScreenUtils.isIOS
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                      size: 19.sp,
                    ),
                  ),
                ),
              ),
            ),
          if (hasSelection && _controller.isShouldShowNext)
            Positioned(
              right: 12.w,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _controller.canClick ? 1.0 : 0.4,
                  child: GestureDetector(
                    key: const ValueKey('language_done_button'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _controller.onClickNext(
                      context,
                      ref: ref,
                      onNavigateNext: () {
                        Navigator.of(context).pushReplacement(
                          AppScreenUtils.adaptivePageRoute<void>(
                            settings:
                                const RouteSettings(name: 'OnboardActivity'),
                            builder: (_) => const OnboardActivity(),
                          ),
                        );
                      },
                    ),
                    child: SizedBox(
                      width: 44.w,
                      height: 40.h,
                      child: Center(
                        child: Icon(
                          Icons.done_rounded,
                          color: AppColors.textPrimary,
                          size: 25.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (hasSelection && !_controller.isShouldShowNext)
            Positioned(
              right: 22.w,
              top: 0,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: 22.r,
                  height: 22.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageList() {
    return ListView.builder(
      controller: _scrollController,
      physics: AppScreenUtils.adaptiveScrollPhysics,
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 20.h),
      itemCount: _controller.groups.length,
      itemBuilder: (context, index) {
        final group = _controller.groups[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: group.isDropdown
              ? _buildDropdownGroup(group)
              : _buildSingleLanguageCard(group),
        );
      },
    );
  }

  BoxDecoration _languageCardDecoration({required bool isSelected}) {
    final radius = BorderRadius.circular(22.r);
    if (isSelected) {
      return BoxDecoration(
        borderRadius: radius,
        gradient: AppColors.primaryGradient,
      );
    }
    return BoxDecoration(
      borderRadius: radius,
      color: AppColors.languageCardBg,
      border: Border.all(
        color: AppColors.languageCardBorder,
        width: 1.0,
      ),
    );
  }

  Widget _buildSingleLanguageCard(LanguageGroupModel group) {
    final isSelected = _controller.selectedVariantId == group.groupId;

    return GestureDetector(
      key: ValueKey('lang_single_${group.groupId}'),
      onTap: () => _controller.onSelectSingleGroup(group),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 62.h.clamp(58.0, 74.0),
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        decoration: _languageCardDecoration(isSelected: isSelected),
        child: Row(
          children: [
            _CircularCountryFlag(
              countryCode: group.singleCountryCode ?? 'us',
              size: 36.r,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: _TwoLineLanguageLabel(
                title: group.title,
                nativeSubtitle: group.nativeName,
                isSelected: isSelected,
              ),
            ),
            SizedBox(width: 10.w),
            _LanguageRadioDot(isSelected: isSelected),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownGroup(LanguageGroupModel group) {
    final groupBoxKey =
        _dropdownGroupKeys.putIfAbsent(group.groupId, () => GlobalKey());
    final isExpanded = _controller.expandedGroupId == group.groupId;
    final hasSelectedChild = group.variants.any(
      (v) => v.variantId == _controller.selectedVariantId,
    );
    final highlightParentAsSelected = hasSelectedChild && !isExpanded;
    final showHandOnEnglish =
        group.groupId == 'en' && _controller.showEnglishHandHint;

    return Column(
      key: groupBoxKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              key: ValueKey('lang_group_${group.groupId}'),
              onTap: () {
                final willExpand = _controller.expandedGroupId != group.groupId;
                _autoRevealGroupId = willExpand ? group.groupId : null;
                _controller.onToggleDropdownGroup(group);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 62.h.clamp(58.0, 74.0),
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                decoration: _languageCardDecoration(
                  isSelected: highlightParentAsSelected,
                ),
                child: Row(
                  children: [
                    const _TranslateGroupBadge(),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: _TwoLineLanguageLabel(
                        title: group.title,
                        nativeSubtitle: group.nativeName,
                        isSelected: highlightParentAsSelected,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: highlightParentAsSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showHandOnEnglish)
              Positioned(
                right: 6.w,
                bottom: -8.h,
                child: const IgnorePointer(
                  child: _AnimatedEnglishTapHand(
                    key: ValueKey('english_tap_hand_hint'),
                  ),
                ),
              ),
          ],
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: isExpanded ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic,
          builder: (context, factor, child) {
            if (_autoRevealGroupId == group.groupId && factor > 0.0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scrollController.hasClients) return;
                if (_autoRevealGroupId != group.groupId) return;
                final ctx = groupBoxKey.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(
                    ctx,
                    alignmentPolicy:
                        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                  );
                }
                if (factor >= 1.0) {
                  _autoRevealGroupId = null;
                }
              });
            }
            if (factor <= 0.0) {
              return const SizedBox.shrink();
            }
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: factor,
                child: child,
              ),
            );
          },
          child: isExpanded
              ? _buildExpandedVariantsTree(group)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildExpandedVariantsTree(LanguageGroupModel group) {
    final childHeight = 58.h.clamp(56.0, 70.0);
    final childGap = 10.h;
    final topGap = 10.h;
    final childIndent = 38.w;
    final trunkX = 22.w;

    return CustomPaint(
      painter: _DropdownTreeConnectorPainter(
        itemCount: group.variants.length,
        topGap: topGap,
        itemHeight: childHeight,
        itemGap: childGap,
        trunkX: trunkX,
        childLeftX: childIndent,
        cornerRadius: 12.r,
        lineColor: AppColors.languageTreeLine,
      ),
      child: Padding(
        padding: EdgeInsets.only(left: childIndent, top: topGap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(group.variants.length, (idx) {
            final variant = group.variants[idx];
            final isLast = idx == group.variants.length - 1;
            final isSelected =
                _controller.selectedVariantId == variant.variantId;

            return GestureDetector(
              key: ValueKey('lang_variant_${variant.variantId}'),
              onTap: () => _controller.onSelectVariant(variant),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: childHeight,
                width: double.infinity,
                margin: EdgeInsets.only(bottom: isLast ? 0 : childGap),
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                decoration: _languageCardDecoration(isSelected: isSelected),
                child: Row(
                  children: [
                    Expanded(
                      child: _TwoLineLanguageLabel(
                        title: variant.title,
                        nativeSubtitle: variant.nativeName,
                        isSelected: isSelected,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    _CircularCountryFlag(
                      countryCode: variant.countryCode,
                      size: 26.r,
                    ),
                    SizedBox(width: 12.w),
                    _LanguageRadioDot(isSelected: isSelected),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNativeAd() {
    if (!_shouldShowLanguageAd()) {
      return SizedBox(height: MediaQuery.paddingOf(context).bottom);
    }

    return SafeArea(
      top: false,
      child: _controller.isShowClickAds
          ? EasyNativeAdHigh(
              key: const ValueKey('nativeLanguageClick'),
              factoryId: NativeFactoryId.nativeMedia2,
              adId: MyAdIdName.nativeLanguageClick.getId,
              adIdHigh: MyAdIdName.nativeLanguageClickHigh.getId,
              adIdName: MyAdIdName.nativeLanguageClick,
              adIdNameHigh: MyAdIdName.nativeLanguageClickHigh,
              height: AdDimen.mediumNativeHeight,
              onImpression: _controller.onAdImpression,
            )
          : EasyNativeAdHigh(
              key: const ValueKey('nativeLanguage'),
              factoryId: NativeFactoryId.nativeMedia,
              adId: MyAdIdName.nativeLanguage.getId,
              adIdHigh: MyAdIdName.nativeLanguageHigh.getId,
              adIdName: MyAdIdName.nativeLanguage,
              adIdNameHigh: MyAdIdName.nativeLanguageHigh,
              height: AdDimen.mediumNativeHeight,
            ),
    );
  }
}

class _TwoLineLanguageLabel extends StatelessWidget {
  final String title;
  final String nativeSubtitle;
  final bool isSelected;

  const _TwoLineLanguageLabel({
    required this.title,
    required this.nativeSubtitle,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h.clamp(2.0, 6.0)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.languageItemTitle(isSelected: isSelected),
              ),
              SizedBox(height: 2.h),
              Text(
                nativeSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.languageItemNativeSubtitle(
                  isSelected: isSelected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White double-ring radio dot when selected (on red gradient card),
/// or thin muted grey ring when unselected (on dark card).
class _LanguageRadioDot extends StatelessWidget {
  final bool isSelected;

  const _LanguageRadioDot({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final size = 22.r;
    final inner = 12.r;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          width: isSelected ? 2.0 : 1.5,
          color: isSelected
              ? AppColors.textPrimary
              : AppColors.languageRadioUnselected,
        ),
      ),
      child: isSelected
          ? Container(
              width: inner,
              height: inner,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textPrimary,
              ),
            )
          : null,
    );
  }
}

class _CircularCountryFlag extends StatelessWidget {
  final String countryCode;
  final double size;

  const _CircularCountryFlag({
    required this.countryCode,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size * 1.48,
            height: size,
            child: CountryFlag.fromCountryCode(countryCode),
          ),
        ),
      ),
    );
  }
}

/// Circular grey translate icon badge with overlapping white `A` + blue `文` speech bubbles.
class _TranslateGroupBadge extends StatelessWidget {
  const _TranslateGroupBadge();

  @override
  Widget build(BuildContext context) {
    final circleSize = 36.r;
    final bubbleW = 14.r;
    final bubbleH = 13.r;

    return Container(
      width: circleSize,
      height: circleSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.languageGroupCircleBg,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 7.r,
            top: 7.5.r,
            child: Container(
              width: bubbleW,
              height: bubbleH,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(3.5.r),
                  topRight: Radius.circular(3.5.r),
                  bottomRight: Radius.circular(3.5.r),
                  bottomLeft: Radius.circular(1.r),
                ),
              ),
              child: Text(
                'A',
                style: AppTextStyles.languageBubbleLatinText,
              ),
            ),
          ),
          Positioned(
            right: 7.r,
            bottom: 7.5.r,
            child: Container(
              width: bubbleW,
              height: bubbleH,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.languageBubbleBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(3.5.r),
                  topRight: Radius.circular(3.5.r),
                  bottomLeft: Radius.circular(3.5.r),
                  bottomRight: Radius.circular(1.r),
                ),
              ),
              child: Text(
                '文',
                style: AppTextStyles.languageBubbleCjkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the vertical trunk line + rounded L-shaped branches connecting the
/// expanded parent language card to each indented regional child card.
class _DropdownTreeConnectorPainter extends CustomPainter {
  final int itemCount;
  final double topGap;
  final double itemHeight;
  final double itemGap;
  final double trunkX;
  final double childLeftX;
  final double cornerRadius;
  final Color lineColor;

  const _DropdownTreeConnectorPainter({
    required this.itemCount,
    required this.topGap,
    required this.itemHeight,
    required this.itemGap,
    required this.trunkX,
    required this.childLeftX,
    required this.cornerRadius,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount <= 0) return;

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final maxR = (childLeftX - trunkX).clamp(2.0, cornerRadius);
    final lastCenterY =
        topGap + (itemCount - 1) * (itemHeight + itemGap) + itemHeight / 2;

    final spineEndY = (lastCenterY - maxR).clamp(0.0, size.height);
    canvas.drawLine(Offset(trunkX, 0), Offset(trunkX, spineEndY), paint);

    for (int i = 0; i < itemCount; i++) {
      final centerY = topGap + i * (itemHeight + itemGap) + itemHeight / 2;
      final startY = (centerY - maxR).clamp(0.0, centerY);
      final r = (centerY - startY).clamp(1.0, maxR);

      final branchPath = Path()
        ..moveTo(trunkX, startY)
        ..arcToPoint(
          Offset(trunkX + r, centerY),
          radius: Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(childLeftX, centerY);

      canvas.drawPath(branchPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DropdownTreeConnectorPainter oldDelegate) {
    return oldDelegate.itemCount != itemCount ||
        oldDelegate.itemHeight != itemHeight ||
        oldDelegate.lineColor != lineColor;
  }
}

/// Animated cartoon tapping hand + ripple hint guiding users to tap `English`.
class _AnimatedEnglishTapHand extends StatefulWidget {
  const _AnimatedEnglishTapHand({super.key});

  @override
  State<_AnimatedEnglishTapHand> createState() =>
      _AnimatedEnglishTapHandState();
}

class _AnimatedEnglishTapHandState extends State<_AnimatedEnglishTapHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    if (AppConstants.isFlutterTest) {
      _controller.value = 0.42;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boxSize = 46.r;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        double press;
        if (t < 0.44) {
          press = Curves.easeOutCubic.transform(t / 0.44);
        } else if (t < 0.86) {
          press = 1.0 - Curves.easeInOut.transform((t - 0.44) / 0.42);
        } else {
          press = 0.0;
        }

        final rippleT = ((t - 0.24) / 0.62).clamp(0.0, 1.0);
        final rippleScale = 0.45 + rippleT * 1.15;
        final rippleAlpha = (1.0 - rippleT) * 0.75;

        final dx = (1.0 - press) * 4.5.r;
        final dy = (1.0 - press) * 5.5.r;
        final handScale = 1.0 - press * 0.11;

        return SizedBox(
          width: boxSize,
          height: boxSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 5.r,
                top: 3.r,
                child: Opacity(
                  opacity: rippleAlpha.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: rippleScale,
                    child: Container(
                      width: 18.r,
                      height: 18.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.languageHandRipple,
                          width: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6.r + dx,
                top: 6.r + dy,
                child: Transform.scale(
                  scale: handScale,
                  alignment: Alignment.topLeft,
                  child: Transform.rotate(
                    angle: -0.46,
                    alignment: Alignment.topCenter,
                    child: CustomPaint(
                      size: Size(32.r, 34.r),
                      painter: const _CartoonPointingHandPainter(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CartoonPointingHandPainter extends CustomPainter {
  const _CartoonPointingHandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 36.0;
    final sy = size.height / 38.0;

    Path buildHandPath() {
      final p = Path();
      p.moveTo(12.5 * sx, 19.5 * sy);
      p.lineTo(12.5 * sx, 5.2 * sy);
      p.arcToPoint(
        Offset(18.2 * sx, 5.2 * sy),
        radius: Radius.elliptical(2.85 * sx, 2.85 * sy),
        clockwise: true,
      );
      p.lineTo(18.2 * sx, 13.8 * sy);
      p.arcToPoint(
        Offset(23.4 * sx, 15.0 * sy),
        radius: Radius.elliptical(2.65 * sx, 2.65 * sy),
        clockwise: true,
      );
      p.lineTo(23.4 * sx, 16.0 * sy);
      p.arcToPoint(
        Offset(28.3 * sx, 17.4 * sy),
        radius: Radius.elliptical(2.55 * sx, 2.55 * sy),
        clockwise: true,
      );
      p.lineTo(28.3 * sx, 18.6 * sy);
      p.arcToPoint(
        Offset(32.6 * sx, 20.6 * sy),
        radius: Radius.elliptical(2.35 * sx, 2.35 * sy),
        clockwise: true,
      );
      p.lineTo(32.6 * sx, 25.0 * sy);
      p.cubicTo(
        32.6 * sx,
        31.2 * sy,
        28.8 * sx,
        35.0 * sy,
        22.5 * sx,
        35.0 * sy,
      );
      p.lineTo(16.0 * sx, 35.0 * sy);
      p.cubicTo(
        12.4 * sx,
        35.0 * sy,
        9.8 * sx,
        31.5 * sy,
        5.2 * sx,
        24.6 * sy,
      );
      p.arcToPoint(
        Offset(9.6 * sx, 21.0 * sy),
        radius: Radius.elliptical(2.7 * sx, 2.7 * sy),
        clockwise: true,
      );
      p.lineTo(12.5 * sx, 23.6 * sy);
      p.close();
      return p;
    }

    final handPath = buildHandPath();

    canvas.drawShadow(handPath, AppColors.overlayDark, 3.5, true);

    final fillPaint = Paint()
      ..color = AppColors.languageHandFill
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.languageHandStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(handPath, fillPaint);
    canvas.drawPath(handPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CartoonPointingHandPainter oldDelegate) =>
      false;
}
