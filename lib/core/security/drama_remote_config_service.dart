import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'drama_crypto_engine.dart';

class DramaBootstrapConfig {
  final String appCode;
  final String primaryApiUrl;
  final List<String> fallbackApiUrls;
  final String mediaCdnUrl;
  final String cryptoSalt;
  final List<String> sslPins;
  final int reviewVersionCode;
  final bool isMaintenance;
  final String maintenanceMessage;

  const DramaBootstrapConfig({
    required this.appCode,
    required this.primaryApiUrl,
    required this.fallbackApiUrls,
    required this.mediaCdnUrl,
    required this.cryptoSalt,
    required this.sslPins,
    required this.reviewVersionCode,
    required this.isMaintenance,
    required this.maintenanceMessage,
  });

  /// Ghép URL đầy đủ cho link `/v1/stream/{token}.mp4` hoặc `.vtt`
  /// Lưu ý: Đường dẫn `/v1/stream/...` đi qua primaryApiUrl để xác thực Opaque Token rồi 302 sang CDN!
  String resolveMediaUrl(String relativeOrFullUrl) {
    if (relativeOrFullUrl.startsWith('http://') || relativeOrFullUrl.startsWith('https://')) {
      return relativeOrFullUrl;
    }
    return '${primaryApiUrl.replaceAll(RegExp(r'/+$'), '')}$relativeOrFullUrl';
  }
}

class DramaRemoteConfigService {
  final DramaCryptoEngine cryptoEngine;
  final String compiledDefaultApiUrl;

  DramaRemoteConfigService({
    required this.cryptoEngine,
    required this.compiledDefaultApiUrl,
  });

  static List<String> _splitCsv(String raw) => raw
      .split(',')
      .map((s) => s.trim().replaceAll(RegExp(r'/+$'), ''))
      .where((s) => s.isNotEmpty)
      .toList();

  Future<DramaBootstrapConfig> fetchAndDecryptBootstrap() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 4),
      minimumFetchInterval: const Duration(minutes: 15),
    ));

    // Toàn bộ 9 tham số chuỗi phẳng rc_* (0% JSON, tương thích 100% Firebase Console, không dấu '-')
    await rc.setDefaults(const {
      'rc_app_code': '',
      'rc_api_url_primary': '',
      'rc_api_url_fallback': '',
      'rc_media_cdn': '',
      'rc_crypto_salt': '',
      'rc_ssl_pins': '',
      'rc_review_ver': '0',
      'rc_maintenance_enabled': 'false',
      'rc_maintenance_msg': 'System maintenance in progress.',
    });

    try {
      await rc.fetchAndActivate();
    } catch (_) {
      // Mạng yếu hoặc Google bị chặn -> Dùng giá trị cache đã lưu lần trước hoặc fallback
    }

    // 1. Đọc rc_app_code (Plaintext) ĐẦU TIÊN để đồng bộ appCode trước khi dẫn xuất RC_V2!
    final rcAppCode = rc.getString('rc_app_code').trim();
    if (rcAppCode.isNotEmpty) {
      cryptoEngine.appCode = rcAppCode;
    }

    // 2. Ba key Plaintext vận hành nhanh (0% JSON)
    final maintRaw = rc.getString('rc_maintenance_enabled').trim().toLowerCase();
    final isMaint = maintRaw == 'true' || maintRaw == '1';
    final maintMsg = rc.getString('rc_maintenance_msg').trim().isNotEmpty
        ? rc.getString('rc_maintenance_msg').trim()
        : 'System maintenance in progress.';
    final reviewVer = int.tryParse(rc.getString('rc_review_ver').trim()) ?? 0;

    // 3. Giải mã trực tiếp 5 key chuỗi phẳng enc_v2: (AAD = tên key, không cần jsonDecode!)
    String primaryUrl = compiledDefaultApiUrl;
    final rawPriEnc = rc.getString('rc_api_url_primary').trim();
    if (rawPriEnc.isNotEmpty) {
      final decPri = (await cryptoEngine.decryptRemoteConfigKey(
        rcKeyName: 'rc_api_url_primary',
        encryptedValue: rawPriEnc,
      )).trim().replaceAll(RegExp(r'/+$'), '');
      if (decPri.startsWith('http')) {
        primaryUrl = decPri;
      }
    }

    List<String> fallbacks = [];
    final rawFbEnc = rc.getString('rc_api_url_fallback').trim();
    if (rawFbEnc.isNotEmpty) {
      final decFb = await cryptoEngine.decryptRemoteConfigKey(
        rcKeyName: 'rc_api_url_fallback',
        encryptedValue: rawFbEnc,
      );
      fallbacks = _splitCsv(decFb);
    }

    String cdnUrl = '';
    final rawCdnEnc = rc.getString('rc_media_cdn').trim();
    if (rawCdnEnc.isNotEmpty) {
      cdnUrl = (await cryptoEngine.decryptRemoteConfigKey(
        rcKeyName: 'rc_media_cdn',
        encryptedValue: rawCdnEnc,
      )).trim().replaceAll(RegExp(r'/+$'), '');
    }

    String salt = cryptoEngine.activeSalt;
    final rawSaltEnc = rc.getString('rc_crypto_salt').trim();
    if (rawSaltEnc.isNotEmpty) {
      final decSalt = (await cryptoEngine.decryptRemoteConfigKey(
        rcKeyName: 'rc_crypto_salt',
        encryptedValue: rawSaltEnc,
      )).trim();
      if (decSalt.isNotEmpty) {
        salt = decSalt;
      }
    }
    cryptoEngine.activeSalt = salt;

    List<String> pins = [];
    final rawPinsEnc = rc.getString('rc_ssl_pins').trim();
    if (rawPinsEnc.isNotEmpty) {
      final decPins = await cryptoEngine.decryptRemoteConfigKey(
        rcKeyName: 'rc_ssl_pins',
        encryptedValue: rawPinsEnc,
      );
      pins = decPins
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.startsWith('sha256/'))
          .toList();
    }

    return DramaBootstrapConfig(
      appCode: cryptoEngine.appCode,
      primaryApiUrl: primaryUrl,
      fallbackApiUrls: fallbacks,
      mediaCdnUrl: cdnUrl,
      cryptoSalt: salt,
      sslPins: pins,
      reviewVersionCode: reviewVer,
      isMaintenance: isMaint,
      maintenanceMessage: maintMsg,
    );
  }
}
