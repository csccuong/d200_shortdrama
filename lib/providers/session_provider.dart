import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/di/injection.dart';
import '../core/startup/app_startup_coordinator.dart';
import '../core/security/drama_remote_config_service.dart';
import '../models/init_response.dart';
import 'wallet_provider.dart';

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

  @override
  Future<SessionState> build() async {
    return const SessionState();
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
      AppConstants.isPremiumUser.value = initResponse.user.isVip;

      final sessionState = SessionState(
        isInitialized: true,
        coordinator: coordinator,
        bootstrapConfig: coordinator.bootstrap,
        initData: initResponse,
        deviceId: deviceId,
        dio: coordinator.dio,
      );

      state = AsyncValue.data(sessionState);
      return sessionState;
    } on StateError catch (e, st) {
      debugPrint('SessionNotifier.initializeSession StateError: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    } catch (e, st) {
      debugPrint('SessionNotifier.initializeSession error: $e');
      final errorState = SessionState(
        isInitialized: false,
        error: e.toString(),
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
      AppConstants.isPremiumUser.value = initResponse.user.isVip;

      state = AsyncValue.data(current.copyWith(
        initData: initResponse,
        clearError: true,
      ));
    } catch (e, st) {
      debugPrint('SessionNotifier.refreshSession error: $e');
      state = AsyncValue.error(e, st);
    }
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

/// Extracts a concise user-facing error message from Dio / runtime errors.
String? formatDisplayApiError(Object? err) {
  if (err == null) return null;
  if (err is DioException) {
    final msg = err.message?.trim();
    if (msg != null && msg.isNotEmpty) return msg;
  }
  return err.toString();
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
    return ref.read(sessionProvider).isReady;
  }
  return ref.read(sessionProvider.notifier).ensureInitialized();
}
