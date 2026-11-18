import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/constants/app_constants.dart';
import '../core/di/injection.dart';
import '../core/l10n/app_l10n.dart';
import '../core/startup/app_startup_coordinator.dart';
import '../models/iap_models.dart';
import '../models/promo_feedback_models.dart';
import '../models/user_profile.dart';
import '../services/api/account_api_service.dart';
import '../services/api/app_api_service.dart';
import '../services/iap_service.dart';
import 'app_providers.dart';

class AccountState {
  final UserProfile? profile;
  final IapCatalog? iapCatalog;
  final Map<String, ProductDetails> storeProducts;
  final bool isLoadingProfile;
  final bool isLoadingCatalog;
  final bool isAuthenticating;
  final bool isPurchasing;
  final String? errorMessage;

  const AccountState({
    this.profile,
    this.iapCatalog,
    this.storeProducts = const {},
    this.isLoadingProfile = false,
    this.isLoadingCatalog = false,
    this.isAuthenticating = false,
    this.isPurchasing = false,
    this.errorMessage,
  });

  AccountState copyWith({
    UserProfile? profile,
    IapCatalog? iapCatalog,
    Map<String, ProductDetails>? storeProducts,
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
      storeProducts: storeProducts ?? this.storeProducts,
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
  IapService get _iapService => inject<IapService>();
  Future<IapCatalog?>? _inFlightCatalog;
  int _purchaseOpId = 0;
  bool _didSyncStoreSubscriptions = false;

  @override
  AccountState build() => const AccountState();

  void _syncProfileDownstream(
    UserProfile profile, {
    bool preserveVerifiedVip = false,
  }) {
    final effectiveProfile = (preserveVerifiedVip && !profile.isVip)
        ? UserProfile(
            userUid: profile.userUid,
            deviceId: profile.deviceId,
            authProvider: profile.authProvider,
            isGuest: profile.isGuest,
            email: profile.email,
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl,
            gender: profile.gender,
            birthYear: profile.birthYear,
            isVip: true,
            vipExpiresAt: profile.vipExpiresAt,
            coinBalance: profile.coinBalance,
            bonusCoinBalance: profile.bonusCoinBalance,
            totalCoins: profile.totalCoins,
            adUnlocksUsedToday: profile.adUnlocksUsedToday,
            adUnlocksRemainingToday: profile.adUnlocksRemainingToday,
            todayWatchSeconds: profile.todayWatchSeconds,
            checkinStreak: profile.checkinStreak,
            canCheckinToday: profile.canCheckinToday,
            favoritesCount: profile.favoritesCount,
            watchLaterCount: profile.watchLaterCount,
            watchedDramasCount: profile.watchedDramasCount,
            settings: profile.settings,
          )
        : profile;
    ref.read(walletProvider.notifier).updateFromProfile(effectiveProfile);
    ref.read(userWalletProvider.notifier).syncFromApi(
          isVip: effectiveProfile.isVip,
          autoPlayNext: effectiveProfile.settings.autoPlayNext,
        );
  }

  Future<UserProfile?> fetchProfile({bool preserveVerifiedVip = false}) async {
    state = state.copyWith(isLoadingProfile: true, clearError: true);
    try {
      final profile = await _service.fetchProfile();
      state = state.copyWith(profile: profile, isLoadingProfile: false);
      _syncProfileDownstream(
        profile,
        preserveVerifiedVip: preserveVerifiedVip,
      );
      return profile;
    } catch (e) {
      debugPrint('AccountNotifier.fetchProfile error: $e');
      state = state.copyWith(
        isLoadingProfile: false,
        errorMessage: AppStrings.genericError(),
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
        errorMessage: AppStrings.genericError(),
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
        errorMessage: AppStrings.genericError(),
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
        errorMessage: AppStrings.genericError(),
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
        errorMessage: AppStrings.genericError(),
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
        errorMessage: AppStrings.genericError(),
      );
      return false;
    }
  }

  Future<void> _ensureIapInitialized() async {
    await _iapService.initialize(
      onVerifyPurchase: verifyIap,
    );
  }

  Future<IapCatalog?> fetchIapCatalog({
    String? lang,
    bool forceRefresh = false,
  }) async {
    final cached = state.iapCatalog;
    if (!forceRefresh &&
        cached != null &&
        cached.subscriptions.isNotEmpty &&
        _iapService.hasAllCatalogProducts(cached)) {
      return cached;
    }

    final existing = _inFlightCatalog;
    if (existing != null) return existing;

    final resolvedLang =
        (lang != null && lang.trim().isNotEmpty)
            ? lang.trim()
            : AppConstants.selectedLanguageCode;
    final future = _runFetchIapCatalog(
      lang: resolvedLang,
      forceRefresh: forceRefresh,
    ).whenComplete(() {
      _inFlightCatalog = null;
    });
    _inFlightCatalog = future;
    return future;
  }

  Future<IapCatalog?> _runFetchIapCatalog({
    required String lang,
    required bool forceRefresh,
  }) async {
    final fallbackCatalog = const IapCatalog(
      subscriptions: IapCatalog.defaultVipSubscriptions,
    );
    state = state.copyWith(
      isLoadingCatalog: true,
      iapCatalog: state.iapCatalog ?? fallbackCatalog,
    );

    IapCatalog resolvedCatalog = state.iapCatalog ?? fallbackCatalog;
    try {
      final serverCatalog = await _service
          .fetchIapCatalog(lang: lang)
          .timeout(const Duration(seconds: 6));
      if (serverCatalog.subscriptions.isNotEmpty) {
        resolvedCatalog = serverCatalog;
      }
    } catch (e) {
      debugPrint('AccountNotifier.fetchIapCatalog API warning: $e');
    }

    var storeProducts = _iapService.cachedProducts;
    try {
      await _ensureIapInitialized();
      storeProducts = await _iapService.queryCatalogProducts(
        resolvedCatalog,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint('AccountNotifier.fetchIapCatalog store error: $e');
    } finally {
      state = state.copyWith(
        iapCatalog: resolvedCatalog,
        storeProducts: storeProducts,
        isLoadingCatalog: false,
      );
    }
    return resolvedCatalog;
  }

  void cancelPendingPurchase() {
    _purchaseOpId++;
    _iapService.cancelPendingPurchases();
    if (state.isPurchasing) {
      state = state.copyWith(isPurchasing: false);
    }
  }

  Future<IapPurchaseResult> purchaseProduct({
    required String productId,
    required bool isConsumable,
  }) async {
    if (state.isPurchasing) {
      return IapPurchaseResult(
        outcome: IapPurchaseOutcome.error,
        productId: productId,
        message: 'Purchase already in progress',
      );
    }

    final opId = ++_purchaseOpId;
    state = state.copyWith(isPurchasing: true, clearError: true);
    try {
      await _ensureIapInitialized();
      final result = await _iapService.buyProduct(
        productId,
        isConsumable: isConsumable,
      );
      if (opId == _purchaseOpId) {
        state = state.copyWith(
          isPurchasing: false,
          storeProducts: _iapService.cachedProducts,
        );
      }
      return result;
    } catch (e) {
      debugPrint('AccountNotifier.purchaseProduct error: $e');
      if (opId == _purchaseOpId) {
        state = state.copyWith(
          isPurchasing: false,
          errorMessage: AppStrings.genericError(),
        );
      }
      return IapPurchaseResult(
        outcome: IapPurchaseOutcome.error,
        productId: productId,
        message: e.toString(),
      );
    }
  }

  Future<bool> restorePurchases() async {
    final outcome = await restorePurchasesWithOutcome();
    return outcome == IapRestoreOutcome.restoredVip;
  }

  Future<IapRestoreOutcome> restorePurchasesWithOutcome() async {
    state = state.copyWith(isPurchasing: true, clearError: true);
    try {
      await _ensureIapInitialized();
      return await _iapService.restorePurchasesWithOutcome();
    } finally {
      state = state.copyWith(isPurchasing: false);
    }
  }

  /// Silently queries Google Play / App Store for active subscriptions at startup
  /// so VIP status is restored even if the initial /v1/app/init payload lagged.
  Future<void> syncActiveStoreSubscriptions({bool force = false}) async {
    if (_didSyncStoreSubscriptions && !force) return;
    _didSyncStoreSubscriptions = true;
    try {
      await _ensureIapInitialized();
      await _iapService.restorePurchases(silent: true);
    } catch (e) {
      debugPrint('AccountNotifier.syncActiveStoreSubscriptions error: $e');
    }
  }

  Future<void> _refreshAfterVerify({required bool keepVipIfVerified}) async {
    try {
      await Future.wait([
        fetchProfile(preserveVerifiedVip: keepVipIfVerified),
        ref
            .read(rewardsProvider.notifier)
            .fetchOverview(AppConstants.selectedLanguageCode),
      ]);
    } catch (refreshErr) {
      debugPrint(
        'AccountNotifier.verifyIap post-verify refresh warning: $refreshErr',
      );
    }
  }

  bool _isSubscriptionProductId(String productId) {
    return (state.iapCatalog?.subscriptions ??
                IapCatalog.defaultVipSubscriptions)
            .any((s) => s.productId == productId) ||
        IapCatalog.defaultVipSubscriptions.any((s) => s.productId == productId);
  }

  bool _isAlreadyProcessedReceiptError(Object error) {
    if (error is! DioException) return false;
    final status = error.response?.statusCode;
    if (status != 400 && status != 409) return false;
    final msg = (error.message ?? '').toLowerCase();
    final dataStr = (error.response?.data?.toString() ?? '').toLowerCase();
    return msg.contains('already processed') ||
        dataStr.contains('already processed');
  }

  void _applyVerifiedSubscriptionVip(
    String productId, {
    Map<String, dynamic> verifyData = const {},
    bool? verifiedVip = true,
  }) {
    ref.read(walletProvider.notifier).applyIapVerifyResponse(
          verifyData,
          fallbackIsVip: verifiedVip,
        );
    final planCode = verifyData['vip_plan_code']?.toString().trim();
    if (verifiedVip != null) {
      if (verifiedVip) {
        final adsEnabled = verifyData['ads_enabled'] as bool?;
        AppConstants.serverAdsEnabled.value = adsEnabled ?? false;
      }
      ref.read(userWalletProvider.notifier).syncFromApi(
            isVip: verifiedVip,
            vipPlanName:
                (planCode != null && planCode.isNotEmpty) ? planCode : productId,
            autoPlayNext:
                state.profile?.settings.autoPlayNext ??
                ref.read(userWalletProvider).autoPlayNext,
          );
    }
    if (verifiedVip == true) {
      ref.invalidate(dramaDetailProvider);
      ref.invalidate(playEpisodeProvider);
      final lang = AppConstants.selectedLanguageCode;
      unawaited(ref.read(homeProvider.notifier).fetchHome(lang));
      if (ref.read(feedProvider).items.isNotEmpty) {
        unawaited(ref.read(feedProvider.notifier).fetchInitialFeed(lang));
      }
    }
    unawaited(_refreshAfterVerify(keepVipIfVerified: verifiedVip == true));
  }

  Future<IapVerifyResult> verifyIap(IapVerifyRequest request) async {
    final isSubscriptionProduct = _isSubscriptionProductId(request.productId);
    try {
      final verifyData = await _service.verifyIap(
        productId: request.productId,
        purchaseToken: request.purchaseToken,
        orderId: request.orderId,
        isRestore: request.isRestore,
      );

      final isVerified = (verifyData['verified'] as bool?) ?? true;
      final serverMessage = verifyData['message']?.toString().trim();
      if (!isVerified) {
        return IapVerifyResult(
          verified: false,
          isVip: false,
          message: serverMessage,
        );
      }

      final verifiedVip =
          (verifyData['is_vip'] as bool?) ??
          (isSubscriptionProduct ? true : null);

      if (request.isRestore && verifiedVip != true) {
        return IapVerifyResult(
          verified: false,
          isVip: false,
          message: serverMessage,
        );
      }

      _applyVerifiedSubscriptionVip(
        request.productId,
        verifyData: verifyData,
        verifiedVip: verifiedVip,
      );
      return IapVerifyResult(
        verified: true,
        isVip: verifiedVip == true,
        message: serverMessage,
      );
    } on IapVerificationException catch (e) {
      debugPrint('AccountNotifier.verifyIap rejected: ${e.message}');
      state = state.copyWith(errorMessage: e.message);
      return IapVerifyResult(
        verified: false,
        isVip: false,
        message: e.message,
      );
    } catch (e) {
      if (!request.isRestore &&
          isSubscriptionProduct &&
          _isAlreadyProcessedReceiptError(e)) {
        debugPrint(
          'AccountNotifier.verifyIap: receipt already processed for active '
          'subscription ${request.productId} — restoring VIP state.',
        );
        _applyVerifiedSubscriptionVip(request.productId, verifiedVip: true);
        return const IapVerifyResult(verified: true, isVip: true);
      }
      debugPrint('AccountNotifier.verifyIap error: $e');
      state = state.copyWith(errorMessage: AppStrings.genericError());
      return IapVerifyResult(
        verified: false,
        isVip: false,
        message: AppStrings.genericError(),
      );
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
        errorMessage: AppStrings.genericError(),
      );
      return false;
    }
  }

  /// Clears `isVip` on the cached profile after a Store refund or expiry.
  void clearProfileVip() {
    final p = state.profile;
    if (p == null || !p.isVip) return;
    state = state.copyWith(
      profile: UserProfile(
        userUid: p.userUid,
        deviceId: p.deviceId,
        authProvider: p.authProvider,
        isGuest: p.isGuest,
        email: p.email,
        displayName: p.displayName,
        avatarUrl: p.avatarUrl,
        gender: p.gender,
        birthYear: p.birthYear,
        isVip: false,
        vipExpiresAt: null,
        coinBalance: p.coinBalance,
        bonusCoinBalance: p.bonusCoinBalance,
        totalCoins: p.totalCoins,
        adUnlocksUsedToday: p.adUnlocksUsedToday,
        adUnlocksRemainingToday: p.adUnlocksRemainingToday,
        todayWatchSeconds: p.todayWatchSeconds,
        checkinStreak: p.checkinStreak,
        canCheckinToday: p.canCheckinToday,
        favoritesCount: p.favoritesCount,
        watchLaterCount: p.watchLaterCount,
        watchedDramasCount: p.watchedDramasCount,
        settings: p.settings,
      ),
    );
  }

  /// Calls `POST /v1/promo/redeem` with raw trimmed [code] (never validated client-side).
  Future<PromoFeedbackResult> redeemPromoCode(String code) async {
    final res = await inject<AppApiService>().redeemPromoCode(code);
    if (res.vipActivated) {
      await _activateVipFromPromoOrFeedback(res);
    }
    return res;
  }

  /// Calls `POST /v1/feedback` and activates VIP if `vip_activated == true`.
  Future<PromoFeedbackResult> submitFeedback(
    String content, {
    String category = 'general',
    String contact = '',
  }) async {
    final res = await inject<AppApiService>().submitFeedback(
      content: content,
      category: category,
      contact: contact,
    );
    if (res.vipActivated) {
      await _activateVipFromPromoOrFeedback(res);
    }
    return res;
  }

  Future<void> _activateVipFromPromoOrFeedback(PromoFeedbackResult res) async {
    // 1. Update global VIP state immediately
    ref
        .read(walletProvider.notifier)
        .applyPromoVipActivation(vipExpiresAt: res.vipExpiresAt);
    final updatedProfile = res.profile ??
        (state.profile != null
            ? UserProfile(
                userUid: state.profile!.userUid,
                deviceId: state.profile!.deviceId,
                authProvider: state.profile!.authProvider,
                isGuest: state.profile!.isGuest,
                email: state.profile!.email,
                displayName: state.profile!.displayName,
                avatarUrl: state.profile!.avatarUrl,
                gender: state.profile!.gender,
                birthYear: state.profile!.birthYear,
                isVip: true,
                vipExpiresAt: res.vipExpiresAt ?? state.profile!.vipExpiresAt,
                coinBalance: state.profile!.coinBalance,
                bonusCoinBalance: state.profile!.bonusCoinBalance,
                totalCoins: state.profile!.totalCoins,
                adUnlocksUsedToday: state.profile!.adUnlocksUsedToday,
                adUnlocksRemainingToday:
                    state.profile!.adUnlocksRemainingToday,
                todayWatchSeconds: state.profile!.todayWatchSeconds,
                checkinStreak: state.profile!.checkinStreak,
                canCheckinToday: state.profile!.canCheckinToday,
                favoritesCount: state.profile!.favoritesCount,
                watchLaterCount: state.profile!.watchLaterCount,
                watchedDramasCount: state.profile!.watchedDramasCount,
                settings: state.profile!.settings,
              )
            : null);
    if (updatedProfile != null) {
      state = state.copyWith(profile: updatedProfile);
    }
    ref.read(userWalletProvider.notifier).syncFromApi(
          isVip: true,
          vipPlanName: res.vipPlanCode ?? 'vip_unlimited',
          autoPlayNext:
              updatedProfile?.settings.autoPlayNext ??
              ref.read(userWalletProvider).autoPlayNext,
        );

    // 2. Disable all ads (Banner, Native, Interstitial, App Open)
    AppConstants.serverAdsEnabled.value = res.adsEnabled ?? false;
    AppConstants.isPremiumUser.value = true;

    // 3. Clear RAM caches for drama details & episode lock statuses
    ref.invalidate(dramaDetailProvider);
    ref.invalidate(playEpisodeProvider);

    // 4. Re-sync session (/v1/app/init) & reload Home / For You / Rewards
    final lang = AppConstants.selectedLanguageCode;
    await ref.read(sessionProvider.notifier).refreshSession();
    final reloads = <Future<void>>[
      ref.read(homeProvider.notifier).fetchHome(lang),
      ref.read(rewardsProvider.notifier).fetchOverview(lang),
    ];
    if (ref.read(feedProvider).items.isNotEmpty) {
      reloads.add(ref.read(feedProvider.notifier).fetchInitialFeed(lang));
    }
    await Future.wait(reloads);
  }
}

final accountProvider = NotifierProvider<AccountNotifier, AccountState>(
  AccountNotifier.new,
);
