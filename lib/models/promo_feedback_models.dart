import 'user_profile.dart';

/// Response model for `POST /v1/promo/redeem` and `POST /v1/feedback`.
class PromoFeedbackResult {
  final bool submitted;
  final bool redeemed;
  final bool vipActivated;
  final bool isVip;
  final String? vipPlanCode;
  final String? vipExpiresAt;
  final bool? adsEnabled;
  final String? paywallMode;
  final String message;
  final UserProfile? profile;

  const PromoFeedbackResult({
    this.submitted = false,
    this.redeemed = false,
    this.vipActivated = false,
    this.isVip = false,
    this.vipPlanCode,
    this.vipExpiresAt,
    this.adsEnabled,
    this.paywallMode,
    this.message = '',
    this.profile,
  });

  factory PromoFeedbackResult.fromJson(
    Map<String, dynamic> json, {
    String fallbackMessage = '',
  }) {
    final rawProfile = json['profile'];
    return PromoFeedbackResult(
      submitted: json['submitted'] as bool? ?? false,
      redeemed: json['redeemed'] as bool? ?? false,
      vipActivated: json['vip_activated'] as bool? ?? false,
      isVip: json['is_vip'] as bool? ?? false,
      vipPlanCode: json['vip_plan_code']?.toString(),
      vipExpiresAt: json['vip_expires_at']?.toString(),
      adsEnabled: json['ads_enabled'] as bool?,
      paywallMode: json['paywall_mode']?.toString(),
      message: (json['message']?.toString().trim().isNotEmpty ?? false)
          ? json['message'].toString().trim()
          : fallbackMessage,
      profile: rawProfile is Map<String, dynamic>
          ? UserProfile.fromJson(rawProfile)
          : (rawProfile is Map
              ? UserProfile.fromJson(Map<String, dynamic>.from(rawProfile))
              : null),
    );
  }
}
