import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class EasyGsmService {
  static final EasyGsmService _instance = EasyGsmService._internal();
  factory EasyGsmService() => _instance;
  EasyGsmService._internal();

  String? gsmAccessToken;

  final String urlGSMDev = 'https://gsmdev.cscmobicorp.com';
  final String urlGSMProd = 'https://gsm.cscmobicorp.com';
  final String urlLogin = '/api/auth/login';

  Future<String?> loginGSM({
    required String gsmAppId,
    required bool isProd,
    String? deviceId,
  }) async {
    try {
      final baseUrl = isProd ? urlGSMProd : urlGSMDev;
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;
      final packageName = packageInfo.packageName;

      final requestBody = {
        'appId': gsmAppId,
        'deviceId': deviceId ?? "device_id_12345",
        'pkName': packageName,
        'os': Platform.isIOS ? 2 : 1,
        'version': appVersion,
      };

      final uri = Uri.parse('$baseUrl$urlLogin');
      final response = await http.post(
        uri,
        body: json.encode(requestBody),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData is Map && jsonData.containsKey('accessToken')) {
          gsmAccessToken = jsonData['accessToken']?.toString();
          debugPrint('✅ EasyAds GSM Login Successful. AccessToken: $gsmAccessToken');
          return gsmAccessToken;
        }
      } else {
        debugPrint('⚠️ EasyAds GSM Login Failed. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ EasyAds GSM Login Error: $e');
    }
    return null;
  }
}
