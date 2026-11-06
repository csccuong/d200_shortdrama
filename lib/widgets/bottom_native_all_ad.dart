import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/const/ad_id_extension.dart';
import '../ads/const/ad_id_factory.dart';
import '../ads/const/ad_id_name.dart';
import '../ads/dimens/ad_dimen.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/screen_utils.dart';
import '../providers/app_providers.dart';
import '../services/firebase_remote_config_service.dart';

/// Native slot sitting above the bottom tabs.
/// Loads only while [tabIndex] is the visible shell tab.
class BottomNativeAllAd extends ConsumerStatefulWidget {
  final int tabIndex;

  const BottomNativeAllAd({super.key, required this.tabIndex});

  @override
  ConsumerState<BottomNativeAllAd> createState() => _BottomNativeAllAdState();
}

class _BottomNativeAllAdState extends ConsumerState<BottomNativeAllAd> {
  EasyAdBase? _nativeAd;
  bool _loaded = false;
  bool _requested = false;

  double get _height => AdDimen.smallNativeAdHeight.h.clamp(120.0, 150.0);

  bool _isActive(int? shellIndex) => shellIndex == widget.tabIndex;

  bool _allowed(int shellIndex) {
    if (!_isActive(shellIndex) || !AppConstants.isMobilePlatform) return false;
    if (AppConstants.isPremiumUser.value) return false;
    if (ref.read(userWalletProvider).isVip) return false;
    return FirebaseRemoteConfigService.getBoolConfigByKey(
      FirebaseRemoteConfigService.native_all,
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  void _load() {
    if (_requested) return;
    _requested = true;
    final adId = MyAdIdName.nativeAll.getId;
    if (adId.isEmpty || adId == 'null') return;
    final ad = EasyAds.instance.createNative(
      adNetwork: AdNetwork.admob,
      factoryId: NativeFactoryId.nativeMediaSmall,
      adId: adId,
      adIdName: MyAdIdName.nativeAll,
      height: _height,
    );
    if (ad == null) return;
    _nativeAd = ad;
    ad.onAdLoaded = (adNetwork, adUnitType, data) {
      if (!mounted) return;
      setState(() => _loaded = true);
    };
    ad.onAdFailedToLoad = (adNetwork, adUnitType, data, errorMessage) {
      if (!mounted) return;
      setState(() => _loaded = false);
    };
    ad.load();
  }

  void _clear() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _loaded = false;
    _requested = false;
  }

  @override
  Widget build(BuildContext context) {
    final shellIndex = ref.watch(shellTabIndexProvider);
    final isVip =
        AppConstants.isPremiumUser.value || ref.watch(userWalletProvider).isVip;

    if (!_allowed(shellIndex) || isVip) {
      if (_nativeAd != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(_clear);
        });
      }
      return const SizedBox.shrink();
    }

    if (!_requested) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _requested) return;
        if (!_allowed(ref.read(shellTabIndexProvider))) return;
        setState(_load);
      });
    }

    if (!_loaded || _nativeAd == null) return const SizedBox.shrink();

    return ColoredBox(
      color: AppColors.background,
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: _nativeAd!.show() as Widget,
      ),
    );
  }
}
