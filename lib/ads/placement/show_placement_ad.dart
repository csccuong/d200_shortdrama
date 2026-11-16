import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../const/ad_id_extension.dart';
import '../const/ad_id_name.dart';
import '../../services/firebase_remote_config_service.dart';

bool _isVip(WidgetRef ref) {
  return AppConstants.isPremiumUser.value || ref.read(userWalletProvider).isVip;
}

bool _hasUnit(String adId) => adId.isNotEmpty && adId != 'null';

bool interAllEnabled(WidgetRef ref) {
  if (!AppConstants.isMobilePlatform || _isVip(ref)) return false;
  if (!FirebaseRemoteConfigService.interAllEnabled) {
    return false;
  }
  return _hasUnit(MyAdIdName.interAll.getId);
}

bool rewardAllEnabled(WidgetRef ref) {
  if (!AppConstants.isMobilePlatform || _isVip(ref)) return false;
  if (!FirebaseRemoteConfigService.rewardAllEnabled) {
    return false;
  }
  return _hasUnit(MyAdIdName.rewardedAd.getId);
}

/// Loads the interstitial only when this is called, then shows the loading popup.
/// [next] always runs once the ad is dismissed, fails, or is skipped.
void showInterAllThen(BuildContext context, WidgetRef ref, VoidCallback next) {
  var continued = false;
  void proceed() {
    if (continued) return;
    continued = true;
    if (!context.mounted) return;
    next();
  }

  if (!interAllEnabled(ref) || EasyAds.instance.isFullscreenAdShowing) {
    proceed();
    return;
  }

  EasyAds.instance.showInterstitialAd(
    context,
    adNetwork: AdNetwork.admob,
    adId: MyAdIdName.interAll.getId,
    adIdName: MyAdIdName.interAll,
    adDissmissed: proceed,
    onFailed: proceed,
  );
}

/// Shows a rewarded ad without preloading. Returns true only after the reward is earned.
Future<bool> showRewardUnlock(BuildContext context, WidgetRef ref) async {
  if (!rewardAllEnabled(ref) || EasyAds.instance.isFullscreenAdShowing) {
    return false;
  }
  return awaitRewardedUnlock(
    context,
    adId: MyAdIdName.rewardedAd.getId,
    adIdName: MyAdIdName.rewardedAd,
  );
}

/// Core rewarded-ad unlock flow shared across production UI and widget tests.
Future<bool> awaitRewardedUnlock(
  BuildContext context, {
  required String adId,
  String? adIdName,
}) async {
  if (EasyAds.instance.isFullscreenAdShowing) {
    return false;
  }

  final completer = Completer<bool>();
  var earned = false;
  var dismissed = false;
  Timer? dismissGraceTimer;

  final sub = EasyAds.instance.onEvent.listen((event) {
    if (event.adUnitType == AdUnitType.rewarded &&
        event.type == AdEventType.earnedReward) {
      earned = true;
      dismissGraceTimer?.cancel();
      if (dismissed && !completer.isCompleted) {
        completer.complete(true);
      }
    }
  });

  final started = EasyAds.instance.showRewardAd(
    context,
    adNetwork: AdNetwork.admob,
    adId: adId,
    adIdName: adIdName,
    adDissmissed: () {
      dismissed = true;
      if (completer.isCompleted) return;
      if (earned) {
        completer.complete(true);
      } else {
        // Yield briefly in case GMA/mediation fires onUserEarnedReward just
        // after onAdDismissedFullScreenContent.
        dismissGraceTimer?.cancel();
        dismissGraceTimer = Timer(const Duration(milliseconds: 400), () {
          if (!completer.isCompleted) completer.complete(earned);
        });
      }
    },
    onFailed: () {
      dismissGraceTimer?.cancel();
      if (!completer.isCompleted) completer.complete(false);
    },
  );

  if (!started && !completer.isCompleted) {
    completer.complete(false);
  }

  try {
    return await completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        EasyAds.instance.setFullscreenAdShowing(false);
        return false;
      },
    );
  } finally {
    dismissGraceTimer?.cancel();
    await sub.cancel();
  }
}
