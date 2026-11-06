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

class _NativeFullScreenState extends State<NativeFullScreen>
    with WidgetsBindingObserver {
  bool _closeLocked = true;
  int _secondsLeft = 2;
  Timer? _timer;
  Timer? _autoNavigateTimer;
  bool _navigated = false;
  bool _showCloseButton = false;
  bool _shouldNavigateOnResume = false;

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
    WidgetsBinding.instance.addObserver(this);

    Future.delayed(const Duration(seconds: 10), () {
      if (!_navigated && mounted) {
        _handleNavigate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _autoNavigateTimer?.cancel();
    if (AppConstants.isMobilePlatform) {
      EasyAds.instance.appLifecycleReactor?.setOnSplashScreen(false);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_navigated) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _shouldNavigateOnResume = true;
    } else if (state == AppLifecycleState.resumed && _shouldNavigateOnResume) {
      _shouldNavigateOnResume = false;
      Future.delayed(const Duration(milliseconds: 300), _handleNavigate);
    }
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
    setState(() {
      _showCloseButton = true;
    });
    _startCountdown();
    _autoNavigateTimer?.cancel();
    _autoNavigateTimer = Timer(const Duration(seconds: 8), () {
      if (!_navigated && mounted) {
        _handleNavigate();
      }
    });
  }

  void _handleNavigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _timer?.cancel();
    _autoNavigateTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.handleNavigate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Stack(
          children: [
            widget.nativeFullHighId != null
                ? EasyNativeAdHigh(
                    factoryId: NativeFactoryId.nativeFull,
                    adId: widget.nativeFullId,
                    adIdHigh: widget.nativeFullHighId!,
                    adIdName: widget.adIdName ?? MyAdIdName.nativeFull,
                    adIdNameHigh: widget.adIdNameHigh,
                    height: screenHeight,
                    onImpression: _onAdShown,
                    onFailedToLoad: _handleNavigate,
                  )
                : EasyNativeAd(
                    factoryId: NativeFactoryId.nativeFull,
                    adId: widget.nativeFullId,
                    adIdName: widget.adIdName ?? MyAdIdName.nativeFull,
                    height: screenHeight,
                    onImpression: _onAdShown,
                    onFailedToLoad: _handleNavigate,
                  ),
            if (_showCloseButton)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10.h,
                right: 12.w,
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
                      child: Icon(
                        Icons.close_rounded,
                        color: _closeLocked
                            ? AppColors.textWhite54
                            : AppColors.textPrimary,
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
