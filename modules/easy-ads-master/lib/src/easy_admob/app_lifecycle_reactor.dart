// Copyright 2021 Google LLC
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

import '../../easy_ads_flutter.dart';

/// Listens for app foreground events and shows app open ads.
class AppLifecycleReactor with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey;

  bool _onSplashScreen = true;
  bool _isExcludeScreen = false;
  bool _wasInactive = false;

  bool _pausedByAd = false;
  DateTime? _onSplashScreenFalseTime;
  bool _allowAppOpenAd = false;

  // Track transient transitions like device rotation or keyboard toggles
  Orientation? _inactiveOrientation;
  DateTime? _inactiveTime;

  AppLifecycleReactor({required this.navigatorKey});

  void setAllowAppOpenAd(bool value) {
    _allowAppOpenAd = value;
  }

  void listenToAppStateChanges() {
    AppStateEventNotifier.startListening();
    AppStateEventNotifier.appStateStream
        .forEach((state) => _onAppStateChanged(state));
    WidgetsBinding.instance.addObserver(this);
  }

  void setOnSplashScreen(bool value) {
    _onSplashScreen = value;
    if (!value) {
      _onSplashScreenFalseTime = DateTime.now();
    }
  }

  void setIsExcludeScreen(bool value) {
    _isExcludeScreen = value;
  }

  void _onAppStateChanged(AppState appState) async {
    // Deprecated in favor of didChangeAppLifecycleState
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Track inactive → resumed path (e.g., recent apps view)
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (!_wasInactive) {
        _wasInactive = true;
        _inactiveTime = DateTime.now();
        if (navigatorKey.currentContext != null) {
          try {
            _inactiveOrientation = MediaQuery.maybeOf(navigatorKey.currentContext!)?.orientation;
          } catch (e) {
            _inactiveOrientation = null;
          }
        }
      }
      if (EasyAds.instance.isFullscreenAdShowing ||
          EasyAds.instance.isManualAppOpenAdShowing) {
        _pausedByAd = true;
      }
    } else if (state == AppLifecycleState.resumed && _wasInactive) {
      _wasInactive = false;
      final wasPausedByAd = _pausedByAd;
      _pausedByAd = false; // Reset

      if (_onSplashScreen) return;
      if (!_allowAppOpenAd) return;

      // Ignore landscape orientation
      Orientation? currentOrientation;
      if (navigatorKey.currentContext != null) {
        try {
          currentOrientation = MediaQuery.maybeOf(navigatorKey.currentContext!)?.orientation;
        } catch (e) {
          currentOrientation = null;
        }
      }

      if (currentOrientation == Orientation.landscape) {
        debugPrint("AppLifecycleReactor: Suppressing app open ad (Landscape orientation)");
        return;
      }

      // Ignore transient resumes within 2 seconds of leaving the splash screen
      if (_onSplashScreenFalseTime != null &&
          DateTime.now().difference(_onSplashScreenFalseTime!).inSeconds < 2) {
        return;
      }

      if (_isExcludeScreen) {
        _isExcludeScreen = false;
        return;
      }

      if (wasPausedByAd) return;

      // Suppress ad if it was a quick transition (e.g., orientation change, keyboard popup)
      if (_inactiveTime != null) {
        final timeDiff = DateTime.now().difference(_inactiveTime!);
        Orientation? currentOrientation;
        if (navigatorKey.currentContext != null) {
          try {
            currentOrientation = MediaQuery.maybeOf(navigatorKey.currentContext!)?.orientation;
          } catch (e) {
            currentOrientation = null;
          }
        }

        final orientationChanged = _inactiveOrientation != null &&
            currentOrientation != null &&
            _inactiveOrientation != currentOrientation;

        // Reset tracking variables
        _inactiveTime = null;
        _inactiveOrientation = null;

        // If orientation changed or time spent inactive is very short (< 1500ms),
        // or if it changed orientation within a reasonable timeframe (< 4000ms), suppress ad.
        if (timeDiff.inMilliseconds < 1500 || (orientationChanged && timeDiff.inMilliseconds < 4000)) {
          debugPrint("AppLifecycleReactor: Suppressing app open ad (orientationChanged: $orientationChanged, duration: ${timeDiff.inMilliseconds}ms)");
          return;
        }
      }

      if (navigatorKey.currentContext != null &&
          !EasyAds.instance.isFullscreenAdShowing &&
          !EasyAds.instance.isManualAppOpenAdShowing) {
        EasyAds.instance.showAppOpenAd(navigatorKey.currentContext!);
      }
    }
  }
}
