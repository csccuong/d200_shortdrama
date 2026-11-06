import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/const/ad_id_extension.dart';
import '../ads/const/ad_id_factory.dart';
import '../ads/const/ad_id_name.dart';
import '../ads/dimens/ad_dimen.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import '../services/firebase_remote_config_service.dart';

/// Home bottom collapsible ad controller for `MainShellScreen`.
///
/// Behavior:
/// 1. Reuses `layout_native_media` (`NativeFactoryId.nativeMedia`).
/// 2. Starts loading both `native_collap` (`MyAdIdName.nativeCollap`) and
///    `banner_all` (`MyAdIdName.bannerAll`) simultaneously when initialized.
/// 3. While `native_collap` is expanded on the Home tab (`isActive == true`),
///    it **overlays (`đè lên`)** the bottom `navigationBar` at the bottom of
///    `MainShellScreen` without pushing `body` up.
/// 4. The collapse button is built directly in Flutter as a small circular button
///    stacked on the top-right of the native ad card. Tapping it calls `_collapse()`,
///    which disposes `native_collap` and reveals `navigationBar` with `banner_all`
///    displayed **underneath** `navigationBar`.
class HomeCollapsibleAd extends ConsumerStatefulWidget {
  const HomeCollapsibleAd({
    super.key,
    required this.navigationBar,
    this.body,
    this.isActive = true,
    this.debugForcePreview = false,
  });

  /// Main screen content above the bottom navigation bar.
  final Widget? body;

  /// Bottom navigation bar (`_FiveTabBottomBar`).
  final Widget navigationBar;

  /// Whether the Home tab is currently active (`currentIndex == 0`).
  final bool isActive;

  /// Test-only flag to render deterministic preview placeholders in widget tests.
  final bool debugForcePreview;

  @override
  ConsumerState<HomeCollapsibleAd> createState() => _HomeCollapsibleAdState();
}

class _HomeCollapsibleAdState extends ConsumerState<HomeCollapsibleAd> {
  static const double _nativeHeight = AdDimen.mediumNativeHeight;
  static const double _bannerFallbackHeight = AdDimen.nativeBannerHeight;

  EasyAdBase? _nativeAd;
  EasyAdBase? _bannerAd;

  bool _nativeEnabled = false;
  bool _bannerEnabled = false;
  bool _nativeLoaded = false;
  bool _bannerLoaded = false;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    if (widget.debugForcePreview) {
      _nativeEnabled = true;
      _bannerEnabled = true;
      _nativeLoaded = true;
      _bannerLoaded = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initAds();
      });
    }
  }

  bool get _isVip =>
      AppConstants.isPremiumUser.value || ref.read(userWalletProvider).isVip;

  void _initAds() {
    if (!AppConstants.isMobilePlatform || _isVip) return;

    _nativeEnabled = FirebaseRemoteConfigService.getBoolConfigByKey(
      FirebaseRemoteConfigService.native_collap,
    );
    _bannerEnabled = FirebaseRemoteConfigService.getBoolConfigByKey(
      FirebaseRemoteConfigService.banner_all,
    );

    if (!_nativeEnabled && !_bannerEnabled) return;

    // Load both native_collap (reusing layout_native_media) and banner_all simultaneously.
    if (_nativeEnabled) {
      final unitId = MyAdIdName.nativeCollap.getId;
      if (unitId.isNotEmpty && unitId != 'null') {
        final ad = EasyAds.instance.createNative(
          adNetwork: AdNetwork.admob,
          factoryId: NativeFactoryId.nativeMedia,
          adId: unitId,
          adIdName: MyAdIdName.nativeCollap,
          height: _nativeHeight,
        );
        if (ad != null) {
          _nativeAd = ad;
          final prevLoaded = ad.onAdLoaded;
          ad.onAdLoaded = (adNetwork, adUnitType, data) {
            prevLoaded?.call(adNetwork, adUnitType, data);
            if (mounted && !_collapsed) {
              setState(() => _nativeLoaded = true);
            }
          };
          final prevFailed = ad.onAdFailedToLoad;
          ad.onAdFailedToLoad = (adNetwork, adUnitType, data, errorMessage) {
            prevFailed?.call(adNetwork, adUnitType, data, errorMessage);
            if (mounted) {
              setState(() {
                _nativeLoaded = false;
                _collapsed = true;
              });
            }
          };
          ad.load();
        } else {
          _collapsed = true;
        }
      } else {
        _collapsed = true;
      }
    } else {
      _collapsed = true;
    }

    if (_bannerEnabled) {
      final bannerUnitId = MyAdIdName.bannerAll.getId;
      if (bannerUnitId.isNotEmpty && bannerUnitId != 'null') {
        final banner = EasyAds.instance.createBanner(
          adNetwork: AdNetwork.admob,
          adSize: AdSize.banner,
          adId: bannerUnitId,
          adIdName: MyAdIdName.bannerAll,
          isCollapsible: false,
        );
        if (banner != null) {
          _bannerAd = banner;
          final prevLoaded = banner.onAdLoaded;
          banner.onAdLoaded = (adNetwork, adUnitType, data) {
            prevLoaded?.call(adNetwork, adUnitType, data);
            if (mounted) {
              setState(() => _bannerLoaded = true);
            }
          };
          final prevFailed = banner.onAdFailedToLoad;
          banner.onAdFailedToLoad = (
            adNetwork,
            adUnitType,
            data,
            errorMessage,
          ) {
            prevFailed?.call(adNetwork, adUnitType, data, errorMessage);
            if (mounted) {
              setState(() => _bannerLoaded = false);
            }
          };
          banner.load();
        }
      }
    }
  }

  void _collapse() {
    if (!mounted || _collapsed) return;
    _nativeAd?.dispose();
    _nativeAd = null;
    setState(() {
      _collapsed = true;
      _nativeLoaded = false;
    });
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVip =
        AppConstants.isPremiumUser.value || ref.watch(userWalletProvider).isVip;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final canShowAds = widget.debugForcePreview || !isVip;

    final showNative =
        canShowAds &&
        widget.isActive &&
        !_collapsed &&
        _nativeEnabled &&
        _nativeLoaded &&
        (widget.debugForcePreview || _nativeAd != null);

    final showBanner =
        canShowAds &&
        widget.isActive &&
        _collapsed &&
        _bannerEnabled &&
        _bannerLoaded &&
        (widget.debugForcePreview || _bannerAd != null);

    // Base layout: [body, navigationBar, (banner underneath navigationBar when collapsed)]
    final baseColumn = Column(
      mainAxisSize: widget.body != null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.body != null) Expanded(child: widget.body!),
        widget.navigationBar,
        if (showBanner)
          ColoredBox(
            key: const Key('home_banner_all_slot'),
            color: AppColors.bottomBarBg,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPad),
              child: SizedBox(
                height: _bannerFallbackHeight,
                width: double.infinity,
                child: widget.debugForcePreview
                    ? const SizedBox.expand()
                    : (_bannerAd?.show() as Widget? ?? const SizedBox.shrink()),
              ),
            ),
          )
        else if (bottomPad > 0)
          ColoredBox(
            color: AppColors.bottomBarBg,
            child: SizedBox(height: bottomPad, width: double.infinity),
          ),
      ],
    );

    if (!showNative) {
      return baseColumn;
    }

    // Expanded state: native_collap overlays (`đè lên`) the navigation bar at the bottom.
    // The small collapse button is rendered in Flutter at the top-right of the ad card.
    return Stack(
      children: [
        baseColumn,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ColoredBox(
            key: const Key('home_native_collap_slot'),
            color: AppColors.bottomBarBg,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPad),
              child: SizedBox(
                height: _nativeHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Native ad platform view (reusing layout_native_media)
                    widget.debugForcePreview
                        ? const SizedBox.expand()
                        : (_nativeAd?.show() as Widget? ??
                            const SizedBox.shrink()),

                    // Small circular collapse button at top-right
                    Positioned(
                      top: 12,
                      right: 15,
                      child: GestureDetector(
                        key: const Key('home_native_collap_close_button'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _collapse,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.overlayMedium,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
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
      ],
    );
  }
}
