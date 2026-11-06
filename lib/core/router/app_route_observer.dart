import 'package:flutter/material.dart';
import '../helper/firebase_helper.dart';

/// NavigatorObserver that tracks screen views with standardized Activity/Screen names.
class AppRouteObserver extends NavigatorObserver {
  static const Map<String, String> _screenNameMap = {
    'splash': 'SplashActivity',
    'SplashActivity': 'SplashActivity',
    'language': 'LanguageActivity',
    'LanguageActivity': 'LanguageActivity',
    'onboard': 'OnboardActivity',
    'OnboardActivity': 'OnboardActivity',
    'main': 'MainShellScreen',
  };

  static String? _lastLoggedScreen;

  static void logScreen(String screenName) {
    if (_lastLoggedScreen == screenName) return;
    _lastLoggedScreen = screenName;
    FirebaseHelper.setTrackingScreenName(screenName);
  }

  static void resetLastLoggedScreen() {
    _lastLoggedScreen = null;
  }

  void _trackRoute(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      final screenName = _screenNameMap[name] ?? name;
      logScreen(screenName);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackRoute(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackRoute(newRoute);
    }
  }
}
