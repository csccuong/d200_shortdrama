import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:dxx_shortdrama/core/network/api_endpoints.dart';
import 'package:dxx_shortdrama/models/iap_models.dart';
import 'package:dxx_shortdrama/models/user_profile.dart';
import 'package:dxx_shortdrama/services/api/app_api_service.dart';
import 'package:flutter/foundation.dart';

/// Exception thrown when `POST /v1/iap/verify` rejects a receipt (HTTP 400/403).
class IapVerificationException implements Exception {
  final int? statusCode;
  final String message;

  const IapVerificationException({
    this.statusCode,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Group G: Profile, settings, IAP & account APIs (10 endpoints).
class AccountApiService {
  final Dio _dio;

  AccountApiService(this._dio);

  /// G1. GET /v1/me/profile — full user profile + wallet balance.
  Future<UserProfile> fetchProfile() async {
    final resp = await _dio.get(ApiEndpoints.profile);
    return UserProfile.fromJson(resp.data['data'] as Map<String, dynamic>);
  }

  /// G2. PUT /v1/me/profile — update display name, avatar, gender, birth year or password.
  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? gender,
    int? birthYear,
    String? currentPassword,
    String? newPassword,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (gender != null) body['gender'] = gender;
    if (birthYear != null) body['birth_year'] = birthYear;
    if (currentPassword != null) body['current_password'] = currentPassword;
    if (newPassword != null) body['new_password'] = newPassword;

    final resp = await _dio.put(ApiEndpoints.profileUpdate, data: body);
    return resp.data['data'] as Map<String, dynamic>? ?? {};
  }

  /// G3. PUT /v1/me/settings — update user preferences.
  Future<void> updateSettings(UserSettings settings) async {
    await _dio.put(
      ApiEndpoints.settings,
      data: settings.toJson(),
    );
  }

  /// G4. POST /v1/auth/register — email/password registration & merge guest assets.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? displayName,
    String? gender,
    int? birthYear,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (displayName != null) body['display_name'] = displayName;
    if (gender != null) body['gender'] = gender;
    if (birthYear != null) body['birth_year'] = birthYear;

    final resp = await _dio.post(ApiEndpoints.authRegister, data: body);
    return resp.data['data'] as Map<String, dynamic>;
  }

  /// G5. POST /v1/auth/login — email/password login & merge guest assets.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.authLogin,
      data: {
        'email': email,
        'password': password,
      },
    );
    return resp.data['data'] as Map<String, dynamic>;
  }

  /// G6. POST /v1/auth/social-login — link social account & merge guest data.
  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String providerUserId,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{
      'provider': provider,
      'provider_user_id': providerUserId,
    };
    if (email != null) body['email'] = email;
    if (displayName != null) body['display_name'] = displayName;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    final resp = await _dio.post(ApiEndpoints.socialLogin, data: body);
    return resp.data['data'] as Map<String, dynamic>;
  }

  /// G7. POST /v1/auth/logout — logout current device & issue fresh guest session.
  Future<Map<String, dynamic>> logout() async {
    final resp = await _dio.post(ApiEndpoints.authLogout, data: <String, dynamic>{});
    return resp.data['data'] as Map<String, dynamic>? ?? {};
  }

  /// G8. GET /v1/iap/catalog — VIP subscriptions & coin packages.
  Future<IapCatalog> fetchIapCatalog({String lang = 'en'}) async {
    final resp = await _dio.get(
      ApiEndpoints.iapCatalog,
      queryParameters: {'lang': lang},
    );
    return IapCatalog.fromJson(resp.data['data'] as Map<String, dynamic>);
  }

  /// G9. POST /v1/iap/verify — verify store receipt after purchase or restore.
  Future<Map<String, dynamic>> verifyIap({
    required String productId,
    required String purchaseToken,
    String orderId = '',
    bool isRestore = false,
    bool? isIosOverride,
  }) async {
    final isIos = isIosOverride ?? (!kIsWeb && Platform.isIOS);
    final payload = isIos
        ? <String, dynamic>{
            'platform': 'ios',
            'product_id': productId,
            'transaction_id': orderId,
            'receipt_data': purchaseToken,
            if (isRestore) 'is_restore': true,
          }
        : <String, dynamic>{
            'platform': 'android',
            'product_id': productId,
            'purchase_token': purchaseToken,
            'order_id': orderId,
            if (isRestore) 'is_restore': true,
          };
    try {
      final resp = await _dio.post(ApiEndpoints.iapVerify, data: payload);
      return resp.data['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      final msg = AppApiService.extractServerErrorMessage(e);
      throw IapVerificationException(
        statusCode: e.response?.statusCode,
        message: msg.isNotEmpty ? msg : (e.message ?? 'Verification failed'),
      );
    }
  }

  /// G10. DELETE /v1/me/account — permanently delete account & device data.
  Future<void> deleteAccount() async {
    await _dio.delete(ApiEndpoints.deleteAccount);
  }
}
