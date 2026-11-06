import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Centralized Responsive TextStyles for DXX ShortDrama (scaled with ScreenUtil `.sp`).
class AppTextStyles {
  AppTextStyles._();

  // ===========================================================================
  // 1. HEADINGS & BRAND LOGO
  // ===========================================================================
  static TextStyle get brandLogoD => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 23.sp,
        fontWeight: FontWeight.w900,
        height: 1.0,
        letterSpacing: -0.8,
      );

  static TextStyle get brandLogoRest => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22.sp,
        fontWeight: FontWeight.w900,
        height: 1.0,
        letterSpacing: -0.6,
      );

  static TextStyle get h1 => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 21.sp,
        fontWeight: FontWeight.w800,
      );

  static TextStyle get h2 => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18.sp,
        fontWeight: FontWeight.w800,
      );

  static TextStyle get h3 => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get sectionTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15.5.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get heroSerifItalic => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 21.sp,
        fontFamily: 'Georgia',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w500,
        height: 1.15,
      );

  // ===========================================================================
  // 2. CARD & LIST ITEM STYLES
  // ===========================================================================
  static TextStyle get cardTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14.5.sp,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get posterTitle => TextStyle(
        color: AppColors.textPrimary.withValues(alpha: 0.92),
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        height: 1.25,
      );

  static TextStyle get continueCardTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get continueEpisodeText => TextStyle(
        color: AppColors.textHint,
        fontSize: 11.sp,
      );

  static TextStyle get numberHighlight => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20.sp,
        fontWeight: FontWeight.w800,
      );

  static TextStyle get priceGold => TextStyle(
        color: AppColors.gold,
        fontSize: 17.sp,
        fontWeight: FontWeight.w800,
      );

  // ===========================================================================
  // 3. BODY, INPUTS & CAPTIONS
  // ===========================================================================
  static TextStyle get bodyMedium => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13.5.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyRegular => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13.sp,
        fontWeight: FontWeight.normal,
      );

  static TextStyle get searchHint => TextStyle(
        color: AppColors.textHint,
        fontSize: 12.5.sp,
      );

  static TextStyle get bodySmall => TextStyle(
        color: AppColors.textWhite70,
        fontSize: 12.sp,
        height: 1.3,
      );

  static TextStyle get caption => TextStyle(
        color: AppColors.textMuted,
        fontSize: 11.5.sp,
      );

  static TextStyle get captionSmall => TextStyle(
        color: AppColors.textWhite54,
        fontSize: 10.5.sp,
      );

  static TextStyle get captionAccent => TextStyle(
        color: AppColors.primaryBright,
        fontSize: 11.5.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get captionCyan => TextStyle(
        color: AppColors.cyan,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get captionGold => TextStyle(
        color: AppColors.gold,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get seeAll => TextStyle(
        color: AppColors.textMuted,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      );

  // ===========================================================================
  // 4. TABS, CHIPS & NAVIGATION
  // ===========================================================================
  static TextStyle get topTabActive => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get topTabInactive => TextStyle(
        color: AppColors.textMuted,
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get forYouHeaderTabActive => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        shadows: const [
          Shadow(
            color: AppColors.overlayDark,
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      );

  static TextStyle get forYouHeaderTabInactive => TextStyle(
        color: AppColors.textPrimary.withValues(alpha: 0.68),
        fontSize: 15.5.sp,
        fontWeight: FontWeight.w500,
        shadows: const [
          Shadow(
            color: AppColors.overlayDark,
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      );

  static TextStyle get watchlistHeaderTabActive => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get watchlistHeaderTabInactive => TextStyle(
        color: AppColors.textMuted,
        fontSize: 16.sp,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get emptyStateTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18.5.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle get emptyStateSubtitle => TextStyle(
        color: AppColors.textMuted,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle get exploreButtonText => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13.5.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get dialogBody => TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle get dialogSecondaryBtn => TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13.5.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get splashAppTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 25.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        shadows: const [
          Shadow(
            color: AppColors.overlayHeavy,
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      );

  static TextStyle get splashTagline => TextStyle(
        color: AppColors.textPrimary.withValues(alpha: 0.80),
        fontSize: 13.5.sp,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        shadows: const [
          Shadow(
            color: AppColors.overlayHeavy,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      );

  static TextStyle get splashAdNotice => TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.78),
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get floatingAdBadge => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 8.5.sp,
        fontWeight: FontWeight.w800,
        height: 1.0,
      );

  static TextStyle get floatingAdPreviewHeadline => TextStyle(
        color: AppColors.floatingAdHeadlineDark,
        fontSize: 11.5.sp,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle get floatingAdPreviewCta => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13.5.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get languageHeaderTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 19.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get languageSubtitle => TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
      );

  static TextStyle languageItemTitle({required bool isSelected}) => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15.sp,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        height: 1.2,
      );

  static TextStyle languageItemNativeSubtitle({bool isSelected = false}) =>
      TextStyle(
        color: isSelected
            ? AppColors.textPrimary.withValues(alpha: 0.84)
            : AppColors.textSecondary,
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        height: 1.25,
      );

  static TextStyle get languageBubbleLatinText => TextStyle(
        color: AppColors.languageBubbleDarkText,
        fontSize: 8.sp,
        fontWeight: FontWeight.w800,
        height: 1.0,
      );

  static TextStyle get languageBubbleCjkText => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 8.sp,
        fontWeight: FontWeight.w800,
        height: 1.0,
      );

  static TextStyle get onboardTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      );

  static TextStyle get onboardDesc => TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13.5.sp,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  static TextStyle get onboardSmallNextBtn => TextStyle(
        color: AppColors.primary,
        fontSize: 13.5.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get onboardBigNextBtn => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  static TextStyle get profileGuestName => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 19.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle get profileIdLabel => TextStyle(
        color: AppColors.profileIdText,
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get vipBannerTitle => TextStyle(
        color: AppColors.vipGoldTextDark,
        fontSize: 18.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      );

  static TextStyle get vipBannerSubtitle => TextStyle(
        color: AppColors.vipGoldSubtextDark,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get vipActivateButton => TextStyle(
        color: AppColors.vipActivateBtnText,
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get profileMenuTitle => TextStyle(
        color: AppColors.textPrimary.withValues(alpha: 0.93),
        fontSize: 14.5.sp,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get rewardHeroUnlock => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 27.sp,
        fontFamily: 'Georgia',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        height: 1.15,
      );

  static TextStyle get rewardHeroHighlight => TextStyle(
        color: AppColors.rewardHeroRedTitle,
        fontSize: 27.sp,
        fontFamily: 'Georgia',
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w700,
        height: 1.15,
      );

  static TextStyle get rewardHeroSubtitle => TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get rewardFeatureTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get rewardFeatureDesc => TextStyle(
        color: AppColors.textMuted,
        fontSize: 10.5.sp,
        height: 1.3,
      );

  static TextStyle get rewardPlanTitle => TextStyle(
        color: AppColors.textPrimary.withValues(alpha: 0.92),
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w500,
      );

  static TextStyle rewardPlanPrice({required bool isSelected}) => TextStyle(
        color: isSelected ? AppColors.rewardPriceYellow : AppColors.textPrimary,
        fontSize: 20.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      );

  static TextStyle get rewardSaveBadge => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get rewardContinueBtn => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get rewardVipSectionTitle => TextStyle(
        color: AppColors.rewardPriceYellow,
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get rewardVipBadgeText => TextStyle(
        color: AppColors.vipGoldTextDark,
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
        height: 1.0,
      );

  static TextStyle get rewardAdSlashText => TextStyle(
        color: AppColors.primary,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
        height: 1.0,
      );

  static TextStyle chipLabel({required bool isSelected, bool darkOnGold = false}) =>
      TextStyle(
        color: isSelected
            ? (darkOnGold ? AppColors.black : AppColors.textPrimary)
            : AppColors.textWhite70,
        fontSize: 11.5.sp,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      );

  static TextStyle bottomNavLabel({required bool isSelected}) => TextStyle(
        color: isSelected ? AppColors.primaryBright : AppColors.navInactive,
        fontSize: 11.sp,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      );

  // ===========================================================================
  // 5. BUTTONS, BADGES & VIDEO SUBTITLES
  // ===========================================================================
  static TextStyle get buttonMedium => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get buttonSmallBold => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 11.5.sp,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get buttonDarkBold => TextStyle(
        color: AppColors.black,
        fontSize: 12.sp,
        fontWeight: FontWeight.w800,
      );

  static TextStyle get badgeSmall => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 9.5.sp,
        fontWeight: FontWeight.w800,
      );

  static TextStyle get badgeGold => TextStyle(
        color: AppColors.gold,
        fontSize: 9.5.sp,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get rankTopLabel => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 10.sp,
        fontWeight: FontWeight.w800,
        height: 1.05,
      );

  static TextStyle get rankNumberLabel => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w800,
        height: 1.1,
      );

  static TextStyle get hotBadgeText => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 10.5.sp,
        fontWeight: FontWeight.w600,
        height: 1.0,
      );

  static TextStyle get filterButtonLabel => TextStyle(
        color: AppColors.profileIdText,
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get playerHeaderTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14.5.sp,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: AppColors.black, blurRadius: 6),
        ],
      );

  static TextStyle get playerHeaderSubtitle => TextStyle(
        color: AppColors.textWhite70,
        fontSize: 11.5.sp,
        shadows: const [
          Shadow(color: AppColors.black, blurRadius: 4),
        ],
      );

  static TextStyle get actionIconLabel => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 11.5.sp,
        fontWeight: FontWeight.w600,
        shadows: const [
          Shadow(
            color: AppColors.overlayDark,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      );

  static TextStyle get playerEpBadge => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get playerDramaTitle => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        shadows: const [
          Shadow(
            color: AppColors.overlayDark,
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      );

  static TextStyle get playerDramaDesc => TextStyle(
        color: AppColors.textPrimary.withValues(alpha: 0.86),
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w400,
        height: 1.36,
        shadows: const [
          Shadow(
            color: AppColors.overlayDark,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      );

  static TextStyle get playerWatchFullBtn => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get subtitleOverlay => TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        height: 1.35,
        shadows: const [
          Shadow(
            color: AppColors.black,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      );
}
