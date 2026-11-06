import 'dart:async';

import 'package:easy_ads_flutter/easy_ads_flutter.dart';
import 'package:easy_ads_flutter/src/utils/easy_loading_splash.dart';
import 'package:flutter/material.dart';

class EasyAppOpenAd extends StatefulWidget {
  final AdNetwork adNetwork;

  const EasyAppOpenAd({
    Key? key,
    this.adNetwork = AdNetwork.admob,
  }) : super(key: key);

  @override
  State<EasyAppOpenAd> createState() => _EasyAppOpenAdState();
}

class _EasyAppOpenAdState extends State<EasyAppOpenAd>
    with WidgetsBindingObserver {
  StreamSubscription? _streamSubscription;
  static int _loadAndShowCallCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Load and show ad logic first, then set fullscreen flag
    _loadAndShowAppOpenAd();

    _streamSubscription = EasyAds.instance.onEvent.listen((event) {
      if (event.adUnitType == AdUnitType.appOpen) {
        switch (event.type) {
          case AdEventType.adShowed:
            // Ad is showing, no need to update UI state
            break;
          case AdEventType.adFailedToLoad:
          case AdEventType.adFailedToShow:
            EasyAds.instance.setFullscreenAdShowing(false);
            if (mounted) {
              Navigator.of(context).pop();
            }
            break;
          case AdEventType.adDismissed:
            EasyAds.instance.setFullscreenAdShowing(false);
            if (mounted) {
              Navigator.of(context).pop();
            }
            break;
          default:
            break;
        }
      }
    });
    super.initState();
  }

  /// Load app open ad, then show it immediately
  /// This is the simplified approach for app resume scenarios
  Future<void> _loadAndShowAppOpenAd() async {
    _loadAndShowCallCount++;
    print(
        '[EasyAppOpenAd] loadAndShowAppOpenAd called - Count: $_loadAndShowCallCount');

    if (EasyAds.instance.isFullscreenAdShowing) {
      print('[EasyAppOpenAd] Fullscreen ad already showing, skipping');
      return;
    }

    // Set fullscreen flag before loading
    EasyAds.instance.setFullscreenAdShowing(true);

    // Step 1: Load the ad
    print('[EasyAppOpenAd] Loading app open ad...');
    EasyAds.instance.loadAppOpenAd(adNetwork: widget.adNetwork);

    // Step 2: Wait for ad to load with immediate show on success
    print(
        '[EasyAppOpenAd] Waiting for ad to load (checking every 50ms, max 5 seconds)...');

    bool adShown = false;
    int attempts = 0;
    const int maxAttempts = 100; // 5 seconds max (50ms * 100)

    while (!adShown && attempts < maxAttempts && mounted) {
      await Future.delayed(
        const Duration(
          milliseconds: 50,
        ),
      ); // Check more frequently
      attempts++;

      // Check if ad is loaded and show immediately
      if (EasyAds.instance.isAppOpenAdLoaded(adNetwork: widget.adNetwork)) {
        print(
            '[EasyAppOpenAd] Ad loaded successfully after ${attempts * 50}ms, showing immediately!');

        // Show the ad using the public method
        print('[EasyAppOpenAd] Calling showAd() for app open');
        final success = await EasyAds.instance
            .showAd(AdUnitType.appOpen, adNetwork: widget.adNetwork);
        if (success) {
          adShown = true; // Mark as shown to exit loop
        } else {
          print('[EasyAppOpenAd] Failed to show ad');
          adShown = true; // Exit loop to avoid infinite waiting
        }
      } else if (attempts % 20 == 0) {
        // Log every second (20 * 50ms = 1000ms)
        print('[EasyAppOpenAd] Still waiting... ${attempts * 50}ms elapsed');
      }
    }

    // If we exit the loop without showing an ad, it means timeout
    if (!adShown && mounted) {
      print(
          '[EasyAppOpenAd] Ad failed to load within timeout (${attempts * 50}ms), dismissing');
      EasyAds.instance.setFullscreenAdShowing(false);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamSubscription?.cancel();
    // Reset fullscreen flag when disposing
    EasyAds.instance.setFullscreenAdShowing(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: EasyLoadingSplash(
        customSplash: EasyAds.configuredLoadingSplash,
        message: EasyAds.configuredLoadingMessage,
      ),
    );
  }
}
