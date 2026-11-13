import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/di/injection.dart';
import '../core/startup/app_startup_coordinator.dart';
import '../models/iap_models.dart';
import '../models/user_profile.dart';
import '../services/api/account_api_service.dart';
import 'app_providers.dart';

class AccountState {
  final UserProfile? profile;
  final IapCatalog? iapCatalog;
  final bool isLoadingProfile;
  final bool isLoadingCatalog;
  final bool isAuthenticating;
  final bool isPurchasing;
  final String? errorMessage;

  const AccountState({
    this.profile,
    this.iapCatalog,
    this.isLoadingProfile = false,
    this.isLoadingCatalog = false,
    this.isAuthenticating = false,
    this.isPurchasing = false,
    this.errorMessage,
  });

  AccountState copyWith({
    UserProfile? profile,
    IapCatalog? iapCatalog,
    bool? isLoadingProfile,
    bool? isLoadingCatalog,
    bool? isAuthenticating,
    bool? isPurchasing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AccountState(
      profile: profile ?? this.profile,
      iapCatalog: iapCatalog ?? this.iapCatalog,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      isLoadingCatalog: isLoadingCatalog ?? this.isLoadingCatalog,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AccountNotifier extends Notifier<AccountState> {
  AccountApiService get _service => inject<AccountApiService>();
  AppStartupCoordinator get _coordinator => inject<AppStartupCoordinator>();

  @override
  AccountState build() => const AccountState();

  void _syncProfileDownstream(UserProfile profile) {
    ref.read(walletProvider.notifier).updateFromProfile(profile);
    ref.read(userWalletProvider.notifier).syncFromApi(
          isVip: profile.isVip,
          autoPlayNext: profile.settings.autoPlayNext,
        );
  }

  Future<UserProfile?> fetchProfile() async {
    state = state.copyWith(isLoadingProfile: true, clearError: true);
    try {
      final profile = await _service.fetchProfile();
      state = state.copyWith(profile: profile, isLoadingProfile: false);
      _syncProfileDownstream(profile);
      return profile;
    } catch (e) {
      debugPrint('AccountNotifier.fetchProfile error: $e');
      state = state.copyWith(
        isLoadingProfile: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? gender,
    int? birthYear,
    String? currentPassword,
    String? newPassword,
  }) async {
    state = state.copyWith(isLoadingProfile: true, clearError: true);
    try {
      await _service.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
        gender: gender,
        birthYear: birthYear,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await fetchProfile();
      return true;
    } catch (e) {
      debugPrint('AccountNotifier.updateProfile error: $e');
      state = state.copyWith(
        isLoadingProfile: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> updateSettings({
    String? appLanguage,
    String? subtitleLanguage,
    bool? autoPlayNext,
    String? videoQuality,
    bool? wifiOnly,
  }) async {
    final prev = state.profile?.settings ??
        UserSettings(
          appLanguage: AppConstants.selectedLanguageCode,
          subtitleLanguage: AppConstants.selectedLanguageCode,
        );
    final next = UserSettings(
      appLanguage: appLanguage ?? prev.appLanguage,
      subtitleLanguage: subtitleLanguage ?? prev.subtitleLanguage,
      autoPlayNext: autoPlayNext ?? prev.autoPlayNext,
      videoQuality: videoQuality ?? prev.videoQuality,
      wifiOnly: wifiOnly ?? prev.wifiOnly,
    );
    if (state.profile != null) {
      state = state.copyWith(profile: state.profile!.copyWith(settings: next));
    }
    ref.read(userWalletProvider.notifier).syncFromApi(
          isVip: state.profile?.isVip ?? AppConstants.isPremiumUser.value,
          autoPlayNext: next.autoPlayNext,
        );
    try {
      await _service.updateSettings(next);
    } catch (e) {
      debugPrint('AccountNotifier.updateSettings error: $e');
    }
  }

  Future<void> _applyAuthPayload(Map<String, dynamic> data) async {
    final accessToken = data['access_token']?.toString();
    final sess = data['session'] as Map<String, dynamic>?;
    await _coordinator.applyAuthSession(
      accessToken: accessToken,
      session: sess,
    );

    final rawUser = (data['profile'] as Map<String, dynamic>?) ??
        (data['user'] as Map<String, dynamic>?);
    if (rawUser != null) {
      final profile = UserProfile.fromJson(rawUser);
      state = state.copyWith(profile: profile, isAuthenticating: false);
      _syncProfileDownstream(profile);
    } else {
      await fetchProfile();
      state = state.copyWith(isAuthenticating: false);
    }

    await Future.wait([
      ref.read(mylistProvider.notifier).fetchFavorites(),
      ref.read(mylistProvider.notifier).fetchHistory(),
      ref
          .read(rewardsProvider.notifier)
          .fetchOverview(AppConstants.selectedLanguageCode),
    ]);
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
    String? gender,
    int? birthYear,
  }) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final data = await _service.register(
        email: email,
        password: password,
        displayName: displayName,
        gender: gender,
        birthYear: birthYear,
      );
      await _applyAuthPayload(data);
      return true;
    } catch (e) {
      debugPrint('AccountNotifier.register error: $e');
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final data = await _service.login(email: email, password: password);
      await _applyAuthPayload(data);
      return true;
    } catch (e) {
      debugPrint('AccountNotifier.login error: $e');
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> socialLogin({
    required String provider,
    required String providerUserId,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final data = await _service.socialLogin(
        provider: provider,
        providerUserId: providerUserId,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      await _applyAuthPayload(data);
      return true;
    } catch (e) {
      debugPrint('AccountNotifier.socialLogin error: $e');
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> logout() async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final data = await _service.logout();
      final sess = data['session'] as Map<String, dynamic>?;
      await _coordinator.applyAuthSession(
        session: sess,
        clearAccessToken: true,
      );
      await fetchProfile();
      await ref.read(mylistProvider.notifier).fetchFavorites();
      await ref.read(mylistProvider.notifier).fetchHistory();
      state = state.copyWith(isAuthenticating: false);
      return true;
    } catch (e) {
      debugPrint('AccountNotifier.logout error: $e');
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<IapCatalog?> fetchIapCatalog({String? lang}) async {
    state = state.copyWith(isLoadingCatalog: true);
    try {
      final catalog = await _service.fetchIapCatalog(
        lang: lang ?? AppConstants.selectedLanguageCode,
      );
      state = state.copyWith(iapCatalog: catalog, isLoadingCatalog: false);
      return catalog;
    } catch (e) {
      debugPrint('AccountNotifier.fetchIapCatalog error: $e');
      state = state.copyWith(isLoadingCatalog: false);
      return null;
    }
  }

  Future<bool> verifyIap({
    required String productId,
    required String purchaseToken,
  }) async {
    state = state.copyWith(isPurchasing: true, clearError: true);
    try {
      await _service.verifyIap(
        productId: productId,
        purchaseToken: purchaseToken,
      );
      await fetchProfile();
      await ref
          .read(rewardsProvider.notifier)
          .fetchOverview(AppConstants.selectedLanguageCode);
      state = state.copyWith(isPurchasing: false);
      return true;
    } catch (e) {
      debugPrint('AccountNotifier.verifyIap error: $e');
      state = state.copyWith(
        isPurchasing: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      await _service.deleteAccount();
      await _coordinator.applyAuthSession(clearAccessToken: true);
      await ref.read(sessionProvider.notifier).initializeSession();
      await fetchProfile();
      await ref.read(mylistProvider.notifier).deleteFavorites(clearAll: true);
      await ref.read(mylistProvider.notifier).deleteHistory(clearAll: true);
      state = state.copyWith(isAuthenticating: false);
      return true;
    } catch (e) {
      debugPrint('AccountNotifier.deleteAccount error: $e');
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(
  AccountNotifier.new,
);
