import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app_initializer.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/router/app_route_observer.dart';
import 'core/utils/screen_utils.dart';
import 'fo/splash/splash_activity.dart';
import 'services/firebase_remote_config_service.dart';

const String env = Environment.dev;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await FirebaseRemoteConfigService.initFirebaseRemoteConfig();
  } catch (e) {
    debugPrint('Firebase initialization skipped/error: $e');
  }
  await setupDependencies();
  await AppInitializer.init(
    navigatorKey: inject<AppNavigationService>().navigatorKey,
  );
  await AppScreenUtils.configureSystemUI();
  runApp(const BobDramaApp());
}

class BobDramaApp extends StatelessWidget {
  final Widget? initialHome;

  const BobDramaApp({super.key, this.initialHome});

  @override
  Widget build(BuildContext context) {
    ensureDependenciesRegistered();
    final navService = inject<AppNavigationService>();

    return ProviderScope(
      key: const ValueKey('riverpod_root_scope'),
      child: ScreenUtilInit(
        designSize: AppScreenUtils.designSize,
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppScreenUtils.systemUiOverlayStyle,
            child: MaterialApp(
              key: const ValueKey('riverpod_material_app_5tabs'),
              navigatorKey: navService.navigatorKey,
              navigatorObservers: [AppRouteObserver()],
              title: 'DXX ShortDrama',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              home: child,
            ),
          );
        },
        child:
            initialHome ??
            const SplashActivity(key: ValueKey('splash_root_activity')),
      ),
    );
  }
}
