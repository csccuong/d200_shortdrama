import 'package:dio/dio.dart';
import 'package:dxx_shortdrama/core/network/api_endpoints.dart';
import 'package:dxx_shortdrama/models/rewards_models.dart';

/// Group F: Rewards center — check-in, tasks & coins (3 endpoints).
class RewardsApiService {
  final Dio _dio;

  RewardsApiService(this._dio);

  /// F1. GET /v1/rewards/overview — wallet, 7-day check-in & task list.
  Future<RewardsOverview> fetchOverview({String lang = 'en'}) async {
    final resp = await _dio.get(
      ApiEndpoints.rewardsOverview,
      queryParameters: {'lang': lang},
    );
    return RewardsOverview.fromJson(
        resp.data['data'] as Map<String, dynamic>);
  }

  /// F2. POST /v1/rewards/check-in — daily check-in.
  ///
  /// [adBonus] = true after watching a rewarded ad for extra coins.
  Future<Map<String, dynamic>> checkIn({bool adBonus = false}) async {
    final resp = await _dio.post(
      ApiEndpoints.rewardsCheckIn,
      data: {'ad_bonus': adBonus},
    );
    return resp.data['data'] as Map<String, dynamic>;
  }

  /// F3. POST /v1/rewards/tasks/{task_code}/claim — claim a completed task.
  Future<Map<String, dynamic>> claimTask(String taskCode) async {
    final resp = await _dio.post(ApiEndpoints.rewardsTaskClaim(taskCode));
    return resp.data['data'] as Map<String, dynamic>;
  }
}
