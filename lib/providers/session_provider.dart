import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/di/injection.dart';
import '../core/l10n/app_l10n.dart';
import '../core/startup/app_startup_coordinator.dart';
import '../core/security/drama_remote_config_service.dart';
import '../models/init_response.dart';
import '../services/api/app_api_service.dart';
import '../services/attribution_helper.dart';
import '../services/shared_preference_service.dart';
import 'app_providers.dart';

// ============================================================================
// SESSION STATE — Holds full API session lifecycle
// ============================================================================

class SessionState {
  final bool isInitialized;
  final AppStartupCoordinator? coordinator;
  final DramaBootstrapConfig? bootstrapConfig;
  final InitResponse? initData;
  final String? deviceId;
  final Dio? dio;
  final String? error;

  const SessionState({
    this.isInitialized = false,
    this.coordinator,
    this.bootstrapConfig,
    this.initData,
    this.deviceId,
    this.dio,
    this.error,
  });

  SessionState copyWith({
    bool? isInitialized,
    AppStartupCoordinator? coordinator,
    DramaBootstrapConfig? bootstrapConfig,
    InitResponse? initData,
    String? deviceId,
    Dio? dio,
    String? error,
    bool clearError = false,
  }) {
    return SessionState(
      isInitialized: isInitialized ?? this.isInitialized,
      coordinator: coordinator ?? this.coordinator,
      bootstrapConfig: bootstrapConfig ?? this.bootstrapConfig,
      initData: initData ?? this.initData,
      deviceId: deviceId ?? this.deviceId,
      dio: dio ?? this.dio,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================================================
// SESSION NOTIFIER — Manages full startup flow via AppStartupCoordinator
// ============================================================================

class SessionNotifier extends AsyncNotifier<SessionState> {
  Future<SessionState>? _inFlightInit;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  Future<SessionState> build() async {
    ref.onDispose(() {
      unawaited(_connectivitySub?.cancel());
      _connectivitySub = null;
    });
    return const SessionState();
  }

  void _listenForConnectivityRecovery() {
    if (AppConstants.isFlutterTest || _connectivitySub != null) return;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) return;
      if (state.asData?.value.isInitialized == true || _inFlightInit != null) {
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (state.asData?.value.isInitialized == true || _inFlightInit != null) {
          return;
        }
        unawaited(ensureInitialized());
      });
    });
  }

  void _stopConnectivityListener() {
    unawaited(_connectivitySub?.cancel());
    _connectivitySub = null;
  }

  /// Runs the full startup flow:
  /// 1. Bootstrap RC keys → 2. Dio setup → 3. POST /v1/app/init
  /// Returns the initialized state. Throws on maintenance/force-update.
  Future<SessionState> initializeSession() {
    final existing = _inFlightInit;
    if (existing != null) return existing;
    final future = _runInitializeSession().whenComplete(() {
      _inFlightInit = null;
    });
    _inFlightInit = future;
    return future;
  }

  Future<SessionState> _runInitializeSession() async {
    state = const AsyncValue.loading();
    try {
      final coordinator = inject<AppStartupCoordinator>();
      final initDataMap = await coordinator.initializeApp();

      final initResponse = InitResponse.fromJson(initDataMap);
      final deviceId = await coordinator.getOrCreatePersistentDeviceId();

      ref.read(walletProvider.notifier).updateFromInitResponse(initResponse);

      if (!initResponse.user.isVip && !AppConstants.isFlutterTest) {
        await ref
            .read(accountProvider.notifier)
            .syncActiveStoreSubscriptions()
            .timeout(const Duration(seconds: 3), onTimeout: () {});
      }

      final effectiveVip =
          initResponse.user.isVip || ref.read(walletProvider).isVip;
      AppConstants.serverAdsEnabled.value =
          initResponse.appConfig.ads.adsEnabled;
      AppConstants.isPremiumUser.value = effectiveVip;
      unawaited(SharedPreferenceService.setIsPremiumUser(effectiveVip));
      ref.read(userWalletProvider.notifier).syncFromApi(
            isVip: effectiveVip,
            vipPlanName: effectiveVip ? 'VIP' : 'FREE',
            autoPlayNext: initResponse.user.settings.autoPlayNext,
          );

      final sessionState = SessionState(
        isInitialized: true,
        coordinator: coordinator,
        bootstrapConfig: coordinator.bootstrap,
        initData: initResponse,
        deviceId: deviceId,
        dio: coordinator.dio,
      );

      _stopConnectivityListener();
      state = AsyncValue.data(sessionState);
      AttributionHelper.onLatePaidAttribution = _syncLatePaidAttribution;
      if (await AttributionHelper.getCachedTrafficType() == 'paid' &&
          !await AttributionHelper.hasSyncedPaidAttribution()) {
        unawaited(_syncLatePaidAttribution());
      }
      unawaited(ref.read(accountProvider.notifier).fetchIapCatalog());
      return sessionState;
    } on StateError catch (e, st) {
      debugPrint('SessionNotifier.initializeSession StateError: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    } catch (e, st) {
      debugPrint('SessionNotifier.initializeSession error: $e');
      _listenForConnectivityRecovery();
      final errorState = SessionState(
        isInitialized: false,
        error: AppStrings.genericError(),
      );
      state = AsyncValue.error(e, st);
      return errorState;
    }
  }

  /// Ensures the session is initialized before screen retry/refresh calls.
  Future<bool> ensureInitialized() async {
    if (state.asData?.value.isInitialized == true) return true;
    try {
      final res = await initializeSession();
      return res.isInitialized;
    } catch (e) {
      debugPrint('SessionNotifier.ensureInitialized failed: $e');
      return false;
    }
  }

  /// Re-calls POST /v1/app/init to get a new session token without
  /// re-doing the full RC bootstrap.
  Future<void> refreshSession() async {
    final current = state.value;
    if (current?.coordinator == null) return;

    try {
      final coordinator = current!.coordinator!;
      final initDataMap = await coordinator.initializeApp();
      final initResponse = InitResponse.fromJson(initDataMap);

      ref.read(walletProvider.notifier).updateFromInitResponse(initResponse);
      if (!initResponse.user.isVip && !AppConstants.isFlutterTest) {
        await ref
            .read(accountProvider.notifier)
            .syncActiveStoreSubscriptions(force: true)
            .timeout(const Duration(seconds: 3), onTimeout: () {});
      }
      final effectiveVip =
          initResponse.user.isVip || ref.read(walletProvider).isVip;
      AppConstants.serverAdsEnabled.value =
          initResponse.appConfig.ads.adsEnabled;
      AppConstants.isPremiumUser.value = effectiveVip;
      unawaited(SharedPreferenceService.setIsPremiumUser(effectiveVip));
      ref.read(userWalletProvider.notifier).syncFromApi(
            isVip: effectiveVip,
            vipPlanName: effectiveVip ? 'VIP' : 'FREE',
            autoPlayNext: initResponse.user.settings.autoPlayNext,
          );

      state = AsyncValue.data(current.copyWith(
        initData: initResponse,
        clearError: true,
      ));
    } catch (e, st) {
      debugPrint('SessionNotifier.refreshSession error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void>? _inFlightAttributionSync;

  Future<void> _syncLatePaidAttribution() {
    final existing = _inFlightAttributionSync;
    if (existing != null) return existing;
    final future = _runSyncLatePaidAttribution().whenComplete(() {
      _inFlightAttributionSync = null;
    });
    _inFlightAttributionSync = future;
    return future;
  }

  Future<void> _runSyncLatePaidAttribution() async {
    final current = state.asData?.value;
    if (current == null || !current.isInitialized) return;
    if (await AttributionHelper.hasSyncedPaidAttribution()) return;

    final deviceId = current.deviceId ?? '';
    if (deviceId.isEmpty) return;

    try {
      final installReferrer =
          await AttributionHelper.getAndroidInstallReferrer();
      await inject<AppApiService>().reportAttribution(
        deviceId: deviceId,
        trafficType: 'paid',
        installReferrer: installReferrer,
      );
      await AttributionHelper.markPaidAttributionSynced();

      final lang = AppConstants.selectedLanguageCode;
      if (ref.read(homeProvider).asData?.value.homeData != null) {
        unawaited(ref.read(homeProvider.notifier).fetchHome(lang));
      }
      if (ref.read(feedProvider).items.isNotEmpty) {
        unawaited(ref.read(feedProvider.notifier).fetchInitialFeed(lang));
      }
    } catch (e) {
      debugPrint('SessionNotifier._syncLatePaidAttribution error: $e');
    }
  }

  /// Section 5.2 (IAP Guide): if `/play` returns HTTP 402 while RAM `isVip` is
  /// still `true` (e.g. Store approved a refund mid-session), immediately
  /// downgrade VIP, re-enable ads, clear episode caches, and refresh `/app/init`.
  void handleInAppRefundDetected() {
    final hasRamVip = AppConstants.isPremiumUser.value ||
        ref.read(userWalletProvider).isVip ||
        ref.read(walletProvider).isVip ||
        (ref.read(accountProvider).profile?.isVip ?? false);
    if (!hasRamVip) return;

    ref.read(walletProvider.notifier).revokeVip();
    ref.read(accountProvider.notifier).clearProfileVip();
    ref.read(userWalletProvider.notifier).syncFromApi(
          isVip: false,
          vipPlanName: 'FREE',
        );
    AppConstants.serverAdsEnabled.value = true;
    AppConstants.isPremiumUser.value = false;
    unawaited(SharedPreferenceService.setIsPremiumUser(false));
    ref.invalidate(dramaDetailProvider);
    ref.invalidate(playEpisodeProvider);
    unawaited(refreshSession());
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

/// Convenience accessor for the configured Dio instance.
/// Throws if session is not yet initialized.
final dioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionProvider).requireValue;
  final dio = session.dio;
  if (dio == null) {
    throw StateError('Dio not available — session not initialized.');
  }
  return dio;
});

/// Returns a generic, user-friendly error message without exposing HTTP status codes or raw exception details.
String? formatDisplayApiError(Object? err) {
  if (err == null) return null;
  return AppStrings.genericError();
}

extension SessionAsyncX on AsyncValue<SessionState> {
  bool get isReady => asData?.value.isInitialized ?? false;

  Object? get failure => error ?? asData?.value.error;

  String? get failureText => formatDisplayApiError(failure);
}

/// Ensures session initialization before executing a user-triggered retry or
/// pull-to-refresh on any screen, while keeping offline widget tests safe.
Future<bool> ensureSessionForUserAction(WidgetRef ref) async {
  if (AppConstants.isFlutterTest) {
    final current = ref.read(sessionProvider);
    if (current.hasValue) return current.isReady;
    try {
      return (await ref.read(sessionProvider.future)).isInitialized;
    } catch (_) {
      return false;
    }
  }
  return ref.read(sessionProvider.notifier).ensureInitialized();
}
