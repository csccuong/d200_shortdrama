import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../network/drama_dio_interceptor.dart';
import '../security/drama_crypto_engine.dart';
import '../security/drama_remote_config_service.dart';

class AppStartupCoordinator {
  static const _storage = FlutterSecureStorage();
  static const String _accessTokenKey = 'drama_access_token';

  /// Override at build time with `--dart-define=APP_NATIVE_SECRET=...`.
  static const String defaultAppNativeSecret = String.fromEnvironment(
    'APP_NATIVE_SECRET',
    defaultValue: 'G10_NativeGuard_Android_2026_x9A7pQ2m',
  );

  static bool get hasValidNativeSecret =>
      defaultAppNativeSecret.isNotEmpty &&
      !defaultAppNativeSecret.contains('<APP_NATIVE_SECRET');

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.dramota.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  DramaCryptoEngine? _crypto;
  DramaBootstrapConfig? _bootstrap;
  bool _initialized = false;
  bool _interceptorAdded = false;

  bool get isInitialized => _initialized;

  DramaCryptoEngine get crypto => _crypto ??= _createCryptoEngine(
        Platform.isIOS ? 'shorttv_ios' : 'default_app',
        '',
      );

  DramaBootstrapConfig get bootstrap =>
      _bootstrap ??
      const DramaBootstrapConfig(
        appCode: 'default_app',
        primaryApiUrl: 'https://api.dramota.com',
        fallbackApiUrls: [],
        mediaCdnUrl: 'https://api.dramota.com',
        cryptoSalt: '',
        sslPins: [],
        reviewVersionCode: 0,
        isMaintenance: false,
        maintenanceMessage: '',
      );

  DramaCryptoEngine _createCryptoEngine(String appCode, String packageName) {
    return DramaCryptoEngine(
      appCode: appCode,
      packageName: packageName,
      appNativeSecret: defaultAppNativeSecret,
    );
  }

  /// Resolves relative media paths (`/v1/stream/...`) against primaryApiUrl.
  String resolveMediaUrl(String relativeOrFullUrl) {
    final trimmed = relativeOrFullUrl.trim();
    if (trimmed.isEmpty) return '';
    if (_initialized) return bootstrap.resolveMediaUrl(trimmed);
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://api.dramota.com${trimmed.startsWith('/') ? trimmed : '/$trimmed'}';
  }

  /// Applies a fresh session bundle + optional JWT returned by auth endpoints.
  Future<void> applyAuthSession({
    Map<String, dynamic>? session,
    String? accessToken,
    bool clearAccessToken = false,
  }) async {
    if (session != null) {
      final token = session['session_token']?.toString();
      final seed = session['ephemeral_seed']?.toString();
      crypto.applySession(token: token, seed: seed);
    }
    if (clearAccessToken) {
      crypto.applySession(clearJwt: true);
      try {
        await _storage.delete(key: _accessTokenKey);
      } catch (_) {}
    } else if (accessToken != null && accessToken.isNotEmpty) {
      crypto.applySession(jwtAccessToken: accessToken);
      try {
        await _storage.write(key: _accessTokenKey, value: accessToken);
      } catch (_) {}
    }
  }

  /// Đọc hoặc tạo device_id bền vững trong Keychain (iOS) / EncryptedStorage (Android)
  Future<String> getOrCreatePersistentDeviceId() async {
    const key = 'drama_persistent_device_id';
    final existing = await _storage.read(key: key);
    if (existing != null && existing.length >= 8) return existing;

    final deviceInfo = DeviceInfoPlugin();
    String newId;
    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      newId = 'and_${android.id}_${const Uuid().v4().substring(0, 8)}';
    } else {
      newId = 'ios_${const Uuid().v4().replaceAll('-', '')}';
    }
    await _storage.write(key: key, value: newId);
    return newId;
  }

  /// Khởi động toàn bộ hệ thống theo đúng thứ tự: Remote Config -> Dio -> POST /v1/app/init
  Future<Map<String, dynamic>> initializeApp() async {
    final pkgInfo = await PackageInfo.fromPlatform();
    final deviceId = await getOrCreatePersistentDeviceId();

    if (!hasValidNativeSecret) {
      debugPrint(
        '[DramaStartup] WARNING: APP_NATIVE_SECRET is still using the CMS '
        'placeholder for package "${pkgInfo.packageName}". Signed requests '
        'will fail with HTTP 403 "Access denied." until configured via '
        'defaultAppNativeSecret or --dart-define=APP_NATIVE_SECRET=...',
      );
    }

    if (_crypto == null || _crypto!.packageName != pkgInfo.packageName) {
      final existingAppCode = _crypto?.appCode ??
          (Platform.isIOS ? 'shorttv_ios' : 'default_app');
      _crypto = _createCryptoEngine(existingAppCode, pkgInfo.packageName);

      final savedJwt = await _storage.read(key: _accessTokenKey);
      if (savedJwt != null && savedJwt.isNotEmpty) {
        _crypto!.accessToken = savedJwt;
      }
    }

    if (!_initialized || _bootstrap == null) {
      // BƯỚC 0: Đọc & giải mã 9 key phẳng rc_* từ Firebase Remote Config (0% JSON)
      final rcService = DramaRemoteConfigService(
        cryptoEngine: _crypto!,
        compiledDefaultApiUrl: 'https://api.dramota.com',
      );
      final fetchedBootstrap = await rcService.fetchAndDecryptBootstrap();
      if (fetchedBootstrap.isMaintenance) {
        throw StateError(fetchedBootstrap.maintenanceMessage);
      }

      _bootstrap = fetchedBootstrap;
      dio.options.baseUrl = fetchedBootstrap.primaryApiUrl;
      if (!_interceptorAdded) {
        dio.interceptors.add(DramaSecurityDioInterceptor(
          dio: dio,
          crypto: _crypto!,
          fallbackApiUrls: fetchedBootstrap.fallbackApiUrls,
          versionCode: pkgInfo.buildNumber.isEmpty ? '100' : pkgInfo.buildNumber,
          deviceId: deviceId,
          getAppLanguage: () => AppConstants.selectedLanguageCode,
          timezoneName: DateTime.now().timeZoneName,
          onSessionRefreshNeeded: () => _performInitHandshake(deviceId, pkgInfo),
        ));
        _interceptorAdded = true;
      }
      _initialized = true;
    }

    // BƯỚC 1: Gọi POST /v1/app/init
    return await _performInitHandshake(deviceId, pkgInfo);
  }

  Future<Map<String, dynamic>> _performInitHandshake(
    String deviceId,
    PackageInfo pkgInfo,
  ) async {
    final deviceInfo = DeviceInfoPlugin();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenRes = '${view.physicalSize.width.toInt()}x${view.physicalSize.height.toInt()}';
    final locale = WidgetsBinding.instance.platformDispatcher.locale;

    Map<String, dynamic> payload = {
      'device_id': deviceId,
      'app_version_name': pkgInfo.version,
      'screen_resolution': screenRes,
      'system_language': locale.toLanguageTag(),
      'app_language': AppConstants.selectedLanguageCode,
      'locale_country_code': locale.countryCode ?? 'US',
      'timezone_offset_min': DateTime.now().timeZoneOffset.inMinutes,
    };

    if (Platform.isAndroid) {
      final a = await deviceInfo.androidInfo;
      payload.addAll({
        'device_brand': a.manufacturer,
        'device_model': a.model,
        'device_name': a.product,
        'os_version': 'Android ${a.version.release}',
        'os_sdk_int': a.version.sdkInt,
        'cpu_abi': a.supportedAbis.isNotEmpty ? a.supportedAbis.first : '',
        'is_emulator': !a.isPhysicalDevice,
      });
    } else if (Platform.isIOS) {
      final i = await deviceInfo.iosInfo;
      payload.addAll({
        'device_brand': 'Apple',
        'device_model': i.utsname.machine,
        'device_name': i.name,
        'os_version': 'iOS ${i.systemVersion}',
        'is_emulator': !i.isPhysicalDevice,
      });
    }

    final resp = await dio.post('/v1/app/init', data: payload);
    final body = resp.data;
    if (body is! Map<String, dynamic> || body['data'] is! Map<String, dynamic>) {
      throw FormatException('Unexpected /v1/app/init response: $body');
    }
    final initData = body['data'] as Map<String, dynamic>;

    // Lưu ngay session_token & ephemeral_seed vào CryptoEngine cho toàn bộ phiên làm việc!
    final sess = (initData['session'] as Map<String, dynamic>?) ??
        (initData['security'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    crypto.sessionToken = sess['session_token']?.toString() ?? '';
    crypto.sessionSeed = sess['ephemeral_seed']?.toString() ?? '';

    return initData;
  }
}
