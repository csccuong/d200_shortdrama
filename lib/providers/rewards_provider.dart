import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/di/injection.dart';
import '../models/rewards_models.dart';
import '../services/api/event_tracker_service.dart';
import '../services/api/rewards_api_service.dart';
import 'wallet_provider.dart';

// ============================================================================
// REWARDS STATE
// ============================================================================

class RewardsState {
  final RewardsOverview? overview;
  final bool isCheckingIn;
  final bool isClaimingTask;

  const RewardsState({
    this.overview,
    this.isCheckingIn = false,
    this.isClaimingTask = false,
  });

  RewardsState copyWith({
    RewardsOverview? overview,
    bool? isCheckingIn,
    bool? isClaimingTask,
  }) {
    return RewardsState(
      overview: overview ?? this.overview,
      isCheckingIn: isCheckingIn ?? this.isCheckingIn,
      isClaimingTask: isClaimingTask ?? this.isClaimingTask,
    );
  }
}

// ============================================================================
// REWARDS NOTIFIER
// ============================================================================

class RewardsNotifier extends AsyncNotifier<RewardsState> {
  @override
  Future<RewardsState> build() async {
    return const RewardsState();
  }

  RewardsApiService get _service => inject<RewardsApiService>();

  /// Fetches the rewards overview: wallet, check-in schedule, and tasks.
  Future<void> fetchOverview(String lang) async {
    state = const AsyncValue.loading();
    try {
      final overview = await _service.fetchOverview(lang: lang);
      ref.read(walletProvider.notifier).updateFromWalletInfo(overview.wallet);
      state = AsyncValue.data(RewardsState(overview: overview));
    } catch (e, st) {
      debugPrint('RewardsNotifier.fetchOverview error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Performs daily check-in. Pass adBonus=true if user watched an ad
  /// for bonus coins.
  Future<void> checkIn({bool adBonus = false}) async {
    final current = state.value;
    if (current == null || current.isCheckingIn) return;

    state = AsyncValue.data(current.copyWith(isCheckingIn: true));
    try {
      await _service.checkIn(adBonus: adBonus);
      inject<DramaEventTracker>().track(
        'checkin',
        sourceScreen: 'rewards',
        props: {'ad_bonus': adBonus},
      );
      // Refresh overview to get updated streak and wallet
      final overview = await _service.fetchOverview(
        lang: AppConstants.selectedLanguageCode,
      );
      ref.read(walletProvider.notifier).updateFromWalletInfo(overview.wallet);
      state = AsyncValue.data(RewardsState(
        overview: overview,
        isCheckingIn: false,
      ));
    } catch (e) {
      debugPrint('RewardsNotifier.checkIn error: $e');
      state = AsyncValue.data(current.copyWith(isCheckingIn: false));
    }
  }

  /// Claims a completed task reward.
  Future<void> claimTask(String taskCode) async {
    final current = state.value;
    if (current == null || current.isClaimingTask) return;

    state = AsyncValue.data(current.copyWith(isClaimingTask: true));
    try {
      await _service.claimTask(taskCode);
      inject<DramaEventTracker>().track(
        'reward_claim',
        sourceScreen: 'rewards',
        props: {'task_code': taskCode},
      );
      // Refresh overview to get updated tasks and wallet
      final overview = await _service.fetchOverview(
        lang: AppConstants.selectedLanguageCode,
      );
      ref.read(walletProvider.notifier).updateFromWalletInfo(overview.wallet);
      state = AsyncValue.data(RewardsState(
        overview: overview,
        isClaimingTask: false,
      ));
    } catch (e) {
      debugPrint('RewardsNotifier.claimTask error: $e');
      state = AsyncValue.data(current.copyWith(isClaimingTask: false));
    }
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final rewardsProvider = AsyncNotifierProvider<RewardsNotifier, RewardsState>(
  RewardsNotifier.new,
);
