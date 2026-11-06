import 'package:flutter/material.dart';

/// Centralized Color Palette & Gradients for DXX ShortDrama.
class AppColors {
  AppColors._();

  // ===========================================================================
  // 1. BACKGROUNDS & SURFACES
  // ===========================================================================
  static const Color black = Colors.black;
  static const Color transparent = Colors.transparent;
  static const Color background = Color(0xFF040605);
  static const Color scaffoldDark = Color(0xFF040605);
  static const Color surface = Color(0xFF141418);
  static const Color surfaceCard = Color(0xFF181822);
  static const Color surfaceLockedCard = Color(0xFF1A1A24);
  static const Color surfacePopularPack = Color(0xFF281826);
  static const Color surfaceBannerFallback = Color(0xFF1A1418);
  static const Color surfaceSheet = Color(0xFF16161F);
  static const Color searchBarBg = Color(0xFF17171C);
  static const Color bottomBarBg = Color(0xFF141419);
  static const Color profileTileBg = Color(0xFF141519);
  static const Color adLoadingBg = Color(0xFF0A0B0E);
  static const Color languageLoadingScrim = Color(0xCC040605);
  static const Color languageCardBg = Color(0xFF131518);
  static const Color languageCardBorder = Color(0xFF202329);
  static const Color languageRadioUnselected = Color(0xFF9196A1);
  static const Color languageGroupCircleBg = Color(0xFF757880);
  static const Color languageBubbleBlue = Color(0xFF2878FF);
  static const Color languageBubbleDarkText = Color(0xFF3C4048);
  static const Color languageTreeLine = Color(0xFFD0D4DC);
  static const Color languageHandFill = Color(0xFFFFFFFF);
  static const Color languageHandStroke = Color(0xFF15161A);
  static const Color languageHandRipple = Color(0x52FFFFFF);
  static const Color onboardDotInactive = Color(0xFF23242E);
  static const Color splashGlassBase = Color(0x8C1E1B1E);
  static const Color splashGlassRim = Color(0x47FFFFFF);
  static const Color splashGlassInnerSheenFill = Color(0x26FFFFFF);
  static const Color splashGlassDropShadow = Color(0xB8000000);
  static const Color splashCrimsonGlowShadow = Color(0x6BFA3C41);
  static const Color splashRubyTriangleGlow = Color(0x8FFA3C41);
  static const Color splashRubyCoralTop = Color(0xFFFF9A9E);
  static const Color splashRubyMid = Color(0xFFFA363E);
  static const Color splashRubyDeep = Color(0xFFC20B18);
  static const Color splashRubyRimLight = Color(0x99FFD4D6);
  static const Color splashRubyUpperFacet = Color(0x42FFFFFF);
  static const Color splashProgressTrack = Color(0x2BFFFFFF);
  static const Color splashSparkCore = Color(0xFFFFFFFF);
  static const Color splashSparkMidGlow = Color(0xFFFF757A);
  static const Color splashSparkOuterGlow = Color(0xCCFA3C41);
  static const Color splashPosterTileBorder = Color(0x1CFFFFFF);
  static const Color floatingAdCardBg = Color(0xFF1F1F1F);
  static const Color floatingAdCardBorder = Colors.transparent;
  static const Color floatingAdCloseBg = Color(0x8A000000);
  static const Color floatingAdDragHandle = Color(0x33FFFFFF);
  static const Color floatingAdShadow = Color(0x9E000000);
  static const Color floatingAdHeadlineDark = Color(0xFFFFFFFF);
  static const Color floatingAdPreviewMediaBg = Color(0xFF141418);
  static const Color floatingAdDivider = Color(0x1FFFFFFF);

  // ===========================================================================
  // 2. BRAND & ACCENT COLORS
  // ===========================================================================
  static const Color primary = Color(0xFFF61B29);
  static const Color primaryBright = Color(0xFFF61B29);
  static const Color primaryDark = Color(0xFFB10A16);
  static const Color gradientRedStart = Color(0xFFFA3C41);
  static const Color gradientRedEnd = Color(0xFFB10A16);
  static const Color secondaryOrange = Color(0xFFFF7A00);
  static const Color gold = Color(0xFFFFB800);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color success = Color(0xFF00E676);
  static const Color error = Colors.redAccent;

  // ===========================================================================
  // 3. TEXT & ICON COLORS
  // ===========================================================================
  static const Color textPrimary = Colors.white;
  static const Color textWhite70 = Colors.white70;
  static const Color textWhite60 = Colors.white60;
  static const Color textWhite54 = Colors.white54;
  static const Color textWhite38 = Colors.white38;
  static const Color textWhite24 = Colors.white24;
  static const Color textSecondary = Color(0xFFB4B4BE);
  static const Color textMuted = Color(0xFF8E8E98);
  static const Color textHint = Color(0xFF7C7C87);
  static const Color navInactive = Color(0xFF9096A5);
  static const Color profileIdText = Color(0xFF9EA4B3);
  static const Color profileChevron = Color(0xFFA0A5B5);
  static const Color vipGoldTextDark = Color(0xFF3B260E);
  static const Color vipGoldSubtextDark = Color(0xFF5A411E);
  static const Color vipActivateBtnBg = Color(0xFF473723);
  static const Color vipActivateBtnText = Color(0xFFF3D999);
  static const Color rewardHeroRedTitle = Color(0xFFFA434D);
  static const Color rewardPlanCardBg = Color(0xFF131416);
  static const Color rewardPlanRadioInactive = Color(0xFF8C92A0);
  static const Color rewardPriceYellow = Color(0xFFF6DC24);

  // ===========================================================================
  // 4. BORDERS, OVERLAYS & DIVIDERS
  // ===========================================================================
  static const Color borderSubtle = Color(0x14FFFFFF); // ~8% white
  static const Color borderLight = Color(0x1FFFFFFF); // ~12% white
  static const Color borderMedium = Color(0x3DFFFFFF); // ~24% white
  static const Color divider = Color(0x1AFFFFFF); // ~10% white
  static const Color glassFill = Color(0x12FFFFFF); // ~7% white
  static const Color playerGlassCircle = Color(0x26FFFFFF); // ~15% frosted glass
  static const Color playerGlassButton = Color(0x33FFFFFF); // ~20% frosted button
  static const Color playerProgressPlayed = Color(0xEBFFFFFF); // ~92% white bar
  static const Color playerProgressTrack = Color(0x33FFFFFF); // ~20% white track
  static const Color overlayMedium = Color(0x8C000000); // ~55% black
  static const Color overlayDark = Color(0xA6000000); // ~65% black
  static const Color overlayHeavy = Color(0xD1000000); // ~82% black

  // ===========================================================================
  // 5. GRADIENTS
  // ===========================================================================
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradientRedStart, gradientRedEnd],
  );

  static const LinearGradient badgePrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientRedStart, gradientRedEnd],
  );

  static const LinearGradient exploreCtaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradientRedStart, gradientRedEnd],
  );

  static const RadialGradient emptyArtworkMaskGradient = RadialGradient(
    radius: 0.52,
    stops: [0.0, 0.78, 1.0],
    colors: [
      Colors.white,
      Colors.white,
      Colors.transparent,
    ],
  );

  static const LinearGradient brandIconGradient = LinearGradient(
    colors: [primaryBright, secondaryOrange],
  );

  static const LinearGradient vipCardGradient = LinearGradient(
    colors: [Color(0xFF3A2410), Color(0xFF21172B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient profileAvatarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF52555D),
      Color(0xFF8F939C),
    ],
  );

  static const LinearGradient profileVipGoldGradient = LinearGradient(
    begin: Alignment(-0.85, 0.95),
    end: Alignment(0.75, -0.95),
    stops: [0.0, 0.42, 0.78, 1.0],
    colors: [
      Color(0xFFCCA03C),
      Color(0xFFE7C568),
      Color(0xFFFDF0B4),
      Color(0xFFE5C162),
    ],
  );

  static const LinearGradient vipPlanHighlightGradient = LinearGradient(
    colors: [Color(0xFF342214), Color(0xFF1F1924)],
  );

  static const LinearGradient rewardFeatureIconBoxGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF22242A),
      Color(0xFF0D0F12),
    ],
  );

  /// Selected VIP package inner radial edge glow overlaid on [rewardPlanCardBg] (#131416):
  /// Center is #F61B29 at 0% opacity; outer edges glow #F61B29 along an angled ellipse.
  static const RadialGradient rewardSelectedPlanGradient = RadialGradient(
    center: Alignment.center,
    radius: 1.0,
    stops: [0.0, 0.42, 0.72, 1.0],
    colors: [
      Color(0x00F61B29),
      Color(0x00F61B29),
      Color(0x24F61B29),
      Color(0x4DF61B29),
    ],
    transform: _EllipticalPlanGlowTransform(),
  );

  /// Selected VIP package 1px inner linear gradient border (#EA5A64 -> #B10A16).
  static const LinearGradient rewardSelectedPlanBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
    colors: [
      Color(0xFFEA5A64),
      Color(0xB3B10A16),
      Color(0xCCB10A16),
    ],
  );

  static const LinearGradient vipPosterBadgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF6E39B),
      Color(0xFFD5B152),
    ],
  );

  static const LinearGradient rewardHeroLeftScrim = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    stops: [0.0, 0.28, 0.62, 1.0],
    colors: [
      Color(0xFF040605),
      Color(0xEB040605),
      Color(0x59040605),
      Colors.transparent,
    ],
  );

  static const LinearGradient rewardHeroBottomScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 0.82, 1.0],
    colors: [
      Color(0x55040605),
      Colors.transparent,
      Color(0xCC040605),
      Color(0xFF040605),
    ],
  );

  static const LinearGradient walletBannerGradient = LinearGradient(
    colors: [Color(0xFF2B1B3D), Color(0xFF1A162B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient heroBannerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    stops: const [0.0, 0.48, 0.78, 1.0],
    colors: [
      const Color(0xFF141115).withValues(alpha: 0.96),
      const Color(0xFF2B181E).withValues(alpha: 0.82),
      const Color(0xFF3A1D22).withValues(alpha: 0.35),
      Colors.transparent,
    ],
  );

  static LinearGradient posterBottomGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.6, 1.0],
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.35),
    ],
  );

  static LinearGradient bottomScrimGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.85),
    ],
  );

  static LinearGradient topHeaderScrimGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.black.withValues(alpha: 0.58),
      Colors.transparent,
    ],
  );

  static const LinearGradient languageTileBgGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF16171F),
      Color(0xFF111218),
    ],
  );

  static const LinearGradient languageTileSelectedGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF2A1217),
      Color(0xFF161217),
    ],
  );

  static const LinearGradient splashBackdropGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
    colors: [
      Color(0x99040605),
      Color(0xD9040605),
      Color(0xFF040605),
    ],
  );

  static const LinearGradient splashPosterFallbackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF281519),
      Color(0xFF121218),
    ],
  );

  static const LinearGradient splashPosterWallVignette = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.26, 0.54, 0.80, 1.0],
    colors: [
      Color(0xE0040605),
      Color(0x94040605),
      Color(0x8F040605),
      Color(0xD6040605),
      Color(0xFA040605),
    ],
  );

  static const RadialGradient splashPosterSideVignette = RadialGradient(
    center: Alignment(0.0, -0.06),
    radius: 0.95,
    stops: [0.0, 0.62, 1.0],
    colors: [
      Colors.transparent,
      Color(0x38040605),
      Color(0xB8040605),
    ],
  );

  static const RadialGradient splashCrimsonCenterGlow = RadialGradient(
    center: Alignment(0.06, -0.08),
    radius: 0.56,
    stops: [0.0, 0.36, 0.72, 1.0],
    colors: [
      Color(0x6BFA3C41),
      Color(0x38D91622),
      Color(0x14B10A16),
      Colors.transparent,
    ],
  );

  static const LinearGradient splashGlassSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.48, 1.0],
    colors: [
      Color(0x3DFFFFFF),
      Color(0x1AFFFFFF),
      Color(0x14FA3C41),
    ],
  );

  static const LinearGradient splashShimmerBandGradient = LinearGradient(
    begin: Alignment(-1.0, -0.45),
    end: Alignment(1.0, 0.45),
    stops: [0.0, 0.38, 0.50, 0.62, 1.0],
    colors: [
      Colors.transparent,
      Color(0x08FFFFFF),
      Color(0x47FFFFFF),
      Color(0x08FFFFFF),
      Colors.transparent,
    ],
  );

  static const LinearGradient onboardImageBottomGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.58, 1.0],
    colors: [
      Colors.transparent,
      Color(0x66040605),
      Color(0xFF040605),
    ],
  );
}

class _EllipticalPlanGlowTransform extends GradientTransform {
  const _EllipticalPlanGlowTransform();

  // Precomputed cos(-0.76 rad) and sin(-0.76 rad) for Figma angled radial ellipse:
  // Major axis (sx = 1.16) along bottom-left <-> top-right,
  // Minor axis (sy = 0.72) along top-left <-> bottom-right.
  static const double _c = 0.724836;
  static const double _s = -0.688921;
  static const double _sx = 1.16;
  static const double _sy = 0.72;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    const m00 = _sx * _c;
    const m10 = _sx * _s;
    const m01 = -_sy * _s;
    const m11 = _sy * _c;
    final tx = cx - cx * m00 - cy * m01;
    final ty = cy - cx * m10 - cy * m11;
    return Matrix4(
      m00, m10, 0.0, 0.0,
      m01, m11, 0.0, 0.0,
      0.0, 0.0, 1.0, 0.0,
      tx,  ty,  0.0, 1.0,
    );
  }
}
