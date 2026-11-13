import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/injection.dart';
import '../models/init_response.dart';
import '../models/play_response.dart';
import '../models/rewards_models.dart';
import '../models/user_profile.dart';
import '../services/api/account_api_service.dart';

// ============================================================================
// WALLET STATE — Syncs coin balance and VIP status with server
// ============================================================================

class WalletState {
  final int coinBalance;
  final int bonusCoinBalance;
  final int totalCoins;
  final bool isVip;
  final String? vipExpiresAt;
  final int adUnlocksRemainingToday;

  const WalletState({
    this.coinBalance = 0,
    this.bonusCoinBalance = 0,
    this.totalCoins = 0,
    this.isVip = false,
    this.vipExpiresAt,
    this.adUnlocksRemainingToday = 0,
  });

  WalletState copyWith({
    int? coinBalance,
    int? bonusCoinBalance,
    int? totalCoins,
    bool? isVip,
    String? vipExpiresAt,
    int? adUnlocksRemainingToday,
    bool clearVipExpiry = false,
  }) {
    return WalletState(
      coinBalance: coinBalance ?? this.coinBalance,
      bonusCoinBalance: bonusCoinBalance ?? this.bonusCoinBalance,
      totalCoins: totalCoins ?? this.totalCoins,
      isVip: isVip ?? this.isVip,
      vipExpiresAt:
          clearVipExpiry ? null : (vipExpiresAt ?? this.vipExpiresAt),
      adUnlocksRemainingToday:
          adUnlocksRemainingToday ?? this.adUnlocksRemainingToday,
    );
  }
}

// ============================================================================
// WALLET NOTIFIER
// ============================================================================

class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() => const WalletState();

  /// Syncs wallet from the POST /v1/app/init response data.
  void updateFromInitResponse(InitResponse initData) {
    final user = initData.user;
    state = state.copyWith(
      coinBalance: user.coinBalance,
      bonusCoinBalance: user.bonusCoinBalance,
      totalCoins: user.totalCoins,
      isVip: user.isVip,
      vipExpiresAt: user.vipExpiresAt,
      adUnlocksRemainingToday: user.adUnlocksRemainingToday,
    );
  }

  /// Syncs wallet after a successful episode unlock.
  void updateFromUnlock(UnlockResponse unlockData) {
    state = state.copyWith(
      coinBalance: unlockData.coinBalance,
      bonusCoinBalance: unlockData.bonusCoinBalance,
      totalCoins: unlockData.totalCoins,
      adUnlocksRemainingToday: unlockData.adUnlocksRemainingToday,
    );
  }

  /// Syncs wallet from the user profile response.
  void updateFromProfile(UserProfile profile) {
    state = state.copyWith(
      coinBalance: profile.coinBalance,
      bonusCoinBalance: profile.bonusCoinBalance,
      totalCoins: profile.totalCoins,
      isVip: profile.isVip,
      vipExpiresAt: profile.vipExpiresAt,
      adUnlocksRemainingToday: profile.adUnlocksRemainingToday,
    );
  }

  /// Syncs wallet from RewardsOverview.wallet snapshot.
  void updateFromWalletInfo(WalletInfo wallet) {
    state = state.copyWith(
      coinBalance: wallet.coinBalance,
      bonusCoinBalance: wallet.bonusCoinBalance,
      totalCoins: wallet.totalCoins,
    );
  }

  /// Re-fetches profile from the server and updates wallet state.
  Future<void> refreshFromServer() async {
    try {
      final accountService = inject<AccountApiService>();
      final profile = await accountService.fetchProfile();
      updateFromProfile(profile);
    } catch (e) {
      debugPrint('WalletNotifier.refreshFromServer error: $e');
    }
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(
  WalletNotifier.new,
);
