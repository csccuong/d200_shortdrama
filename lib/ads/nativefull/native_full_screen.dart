import 'dart:async';
import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/screen_utils.dart';
import '../const/ad_id_factory.dart';
import '../const/ad_id_name.dart';

class NativeFullScreen extends StatefulWidget {
  final String nativeFullId;
  final String? nativeFullHighId;
  final String? adIdName;
  final String? adIdNameHigh;
  final VoidCallback handleNavigate;

  const NativeFullScreen({
    super.key,
    required this.nativeFullId,
    required this.handleNavigate,
    this.nativeFullHighId,
    this.adIdName,
    this.adIdNameHigh,
  });

  @override
  State<NativeFullScreen> createState() => _NativeFullScreenState();
}

class _NativeFullScreenState extends State<NativeFullScreen> {
  bool _closeLocked = true;
  int _secondsLeft = 2;
  Timer? _timer;
  Timer? _loadTimeoutTimer;
  bool _adShown = false;
  bool _navigated = false;
  bool _showCloseButton = false;

  @override
  void initState() {
    super.initState();
    if (!AppConstants.isMobilePlatform ||
        EasyAds.instance.isPremiumUser ||
        AppConstants.isPremiumUser.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigate();
      });
      return;
    }
    EasyAds.instance.appLifecycleReactor?.setOnSplashScreen(true);

    // Fallback timeout applies ONLY while waiting for initial ad fill;
    // once the ad displays, user must explicitly tap Close to continue.
    _loadTimeoutTimer = Timer(const Duration(seconds: 8), () {
      if (!_adShown && !_navigated && mounted) {
        _handleNavigate();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loadTimeoutTimer?.cancel();
    if (AppConstants.isMobilePlatform) {
      EasyAds.instance.appLifecycleReactor?.setOnSplashScreen(false);
    }
    super.dispose();
  }

  void _startCountdown() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        setState(() {
          _closeLocked = false;
          _secondsLeft = 0;
        });
        _timer?.cancel();
      }
    });
  }

  void _onAdShown() {
    if (!mounted) return;
    _adShown = true;
    _loadTimeoutTimer?.cancel();
    setState(() {
      _showCloseButton = true;
    });
    _startCountdown();
  }

  void _handleNavigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timer?.cancel();
    _loadTimeoutTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.handleNavigate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.paddingOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final adHeight = (screenHeight - mediaPadding.top - mediaPadding.bottom)
        .clamp(320.0, screenHeight);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Stack(
          children: [
            SafeArea(
              top: true,
              bottom: true,
              child: widget.nativeFullHighId != null
                  ? EasyNativeAdHigh(
                      factoryId: NativeFactoryId.nativeFull,
                      adId: widget.nativeFullId,
                      adIdHigh: widget.nativeFullHighId!,
                      adIdName: widget.adIdName ?? MyAdIdName.nativeFull,
                      adIdNameHigh: widget.adIdNameHigh,
                      height: adHeight,
                      onImpression: _onAdShown,
                      onFailedToLoad: _handleNavigate,
                    )
                  : EasyNativeAd(
                      factoryId: NativeFactoryId.nativeFull,
                      adId: widget.nativeFullId,
                      adIdName: widget.adIdName ?? MyAdIdName.nativeFull,
                      height: adHeight,
                      onImpression: _onAdShown,
                      onFailedToLoad: _handleNavigate,
                    ),
            ),
            if (_showCloseButton)
              Positioned(
                top: mediaPadding.top + 32.h,
                right: 14.w,
                child: Material(
                  color: AppColors.transparent,
                  child: InkWell(
                    onTap: _closeLocked ? null : _handleNavigate,
                    borderRadius: BorderRadius.circular(20.r),
                    child: Container(
                      width: 38.w,
                      height: 38.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.overlayDark,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.borderMedium,
                          width: 1,
                        ),
                      ),
                      child: _closeLocked
                          ? Text(
                              '$_secondsLeft',
                              style: const TextStyle(
                                color: AppColors.textWhite70,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : Icon(
                              Icons.close_rounded,
                              color: AppColors.textPrimary,
                              size: 20.sp,
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
