/// A single day in the 7-day check-in schedule.
class CheckInDay {
  final int day;
  final int reward;
  final bool isClaimed;
  final bool isToday;

  CheckInDay({
    required this.day,
    this.reward = 0,
    this.isClaimed = false,
    this.isToday = false,
  });

  factory CheckInDay.fromJson(Map<String, dynamic> json) {
    return CheckInDay(
      day: json['day'] as int? ?? 0,
      reward: json['reward'] as int? ?? 0,
      isClaimed: json['is_claimed'] as bool? ?? false,
      isToday: json['is_today'] as bool? ?? false,
    );
  }
}

/// 7-day check-in schedule with current streak info.
class CheckInSchedule {
  final int streak;
  final bool canCheckinToday;
  final List<CheckInDay> schedule;

  CheckInSchedule({
    this.streak = 0,
    this.canCheckinToday = false,
    this.schedule = const [],
  });

  factory CheckInSchedule.fromJson(Map<String, dynamic> json) {
    return CheckInSchedule(
      streak: json['streak'] as int? ?? 0,
      canCheckinToday: json['can_checkin_today'] as bool? ?? false,
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((e) =>
                  CheckInDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// A reward task (e.g., watch_10m, share_app).
class RewardTask {
  final String taskCode;
  final String title;
  final String description;
  final int progress;
  final int target;
  final int rewardCoins;
  final bool canClaim;
  final bool isCompleted;

  RewardTask({
    required this.taskCode,
    this.title = '',
    this.description = '',
    this.progress = 0,
    this.target = 0,
    this.rewardCoins = 0,
    this.canClaim = false,
    this.isCompleted = false,
  });

  factory RewardTask.fromJson(Map<String, dynamic> json) {
    return RewardTask(
      taskCode: json['task_code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      progress: json['progress'] as int? ?? 0,
      target: json['target'] as int? ?? 0,
      rewardCoins: json['reward_coins'] as int? ?? 0,
      canClaim: json['can_claim'] as bool? ?? false,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }
}

/// Wallet balance snapshot.
class WalletInfo {
  final int coinBalance;
  final int bonusCoinBalance;
  final int totalCoins;

  WalletInfo({
    this.coinBalance = 0,
    this.bonusCoinBalance = 0,
    this.totalCoins = 0,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      coinBalance: json['coin_balance'] as int? ?? 0,
      bonusCoinBalance: json['bonus_coin_balance'] as int? ?? 0,
      totalCoins: json['total_coins'] as int? ?? 0,
    );
  }
}

/// Full response for GET /v1/rewards/overview.
class RewardsOverview {
  final WalletInfo wallet;
  final CheckInSchedule checkin;
  final List<RewardTask> tasks;

  RewardsOverview({
    WalletInfo? wallet,
    CheckInSchedule? checkin,
    this.tasks = const [],
  })  : wallet = wallet ?? WalletInfo(),
        checkin = checkin ?? CheckInSchedule();

  factory RewardsOverview.fromJson(Map<String, dynamic> json) {
    return RewardsOverview(
      wallet: json['wallet'] != null
          ? WalletInfo.fromJson(
              json['wallet'] as Map<String, dynamic>)
          : null,
      checkin: json['checkin'] != null
          ? CheckInSchedule.fromJson(
              json['checkin'] as Map<String, dynamic>)
          : null,
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) =>
                  RewardTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
