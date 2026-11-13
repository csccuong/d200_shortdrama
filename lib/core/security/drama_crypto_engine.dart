import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

class DramaCryptoEngine {
  String appCode;
  final String packageName;
  final String appNativeSecret;
  bool enforceApkCert;
  final String apkCertSha256;

  String activeSalt;
  String sessionToken = '';
  String sessionSeed = '';
  String accessToken = '';

  void applySession({
    String? token,
    String? seed,
    String? jwtAccessToken,
    bool clearJwt = false,
  }) {
    if (token != null) sessionToken = token;
    if (seed != null) sessionSeed = seed;
    if (clearJwt) {
      accessToken = '';
    } else if (jwtAccessToken != null) {
      accessToken = jwtAccessToken;
    }
  }

  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Random _secureRandom = Random.secure();

  DramaCryptoEngine({
    required this.appCode,
    required this.packageName,
    required this.appNativeSecret,
    this.activeSalt = 'drama_dynamic_salt_2026',
    this.enforceApkCert = false,
    this.apkCertSha256 = '',
  });

  String get _normalizedApkCert =>
      apkCertSha256.toLowerCase().replaceAll(':', '').trim();

  String get _certPart => enforceApkCert ? _normalizedApkCert : '';

  /// Sinh Nonce ngẫu nhiên chống Replay Attack (VD: "nc_8f1a2b3c4d5e6f708192")
  String generateNonce() {
    final bytes = List<int>.generate(10, (_) => _secureRandom.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'nc_$hex';
  }

  /// Băm SHA-256 trả về 32 bytes
  Uint8List _sha256Bytes(String input) {
    final digest = crypto.sha256.convert(utf8.encode(input));
    return Uint8List.fromList(digest.bytes);
  }

  /// [LAYER 0] Giải mã từng key phẳng `enc_v2:<Base64>` từ Firebase Remote Config (AAD = rcKeyName)
  /// - Trả về `""` ngay nếu giá trị đang để trống (VD: `rc_api_url_fallback = ""` hoặc `rc_ssl_pins = ""`).
  /// - Tự động đồng bộ trạng thái `enforceApkCert` nếu Admin bật/tắt ràng buộc chữ ký APK trên CMS.
  Future<String> decryptRemoteConfigKey({
    required String rcKeyName,
    required String encryptedValue,
  }) async {
    final trimmed = encryptedValue.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('enc_v2:')) {
      return trimmed;
    }

    final raw = base64.decode(trimmed.substring('enc_v2:'.length));
    if (raw.length < 28) {
      throw const FormatException('Invalid enc_v2 payload length');
    }

    final iv = raw.sublist(0, 12);
    final tag = raw.sublist(raw.length - 16);
    final cipherText = raw.sublist(12, raw.length - 16);
    final secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(tag));
    final aadBytes = utf8.encode(rcKeyName);

    Future<String> decryptWithCert(String cert) async {
      final material = 'RC_V2|$appCode|$packageName|$appNativeSecret|$cert';
      final keyBytes = _sha256Bytes(material);
      final clearBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(keyBytes),
        aad: aadBytes, // BẮT BUỘC: AAD chính là tên key (VD: "rc_api_url_primary")
      );
      return utf8.decode(clearBytes);
    }

    try {
      return await decryptWithCert(_certPart);
    } on SecretBoxAuthenticationError {
      // Tự động thích ứng nếu Admin vừa bật/tắt enforce_apk_cert trên CMS mà không cần build lại App!
      if (_normalizedApkCert.isNotEmpty) {
        final altEnforce = !enforceApkCert;
        final altCert = altEnforce ? _normalizedApkCert : '';
        final plain = await decryptWithCert(altCert);
        enforceApkCert = altEnforce;
        return plain;
      }
      rethrow;
    }
  }

  /// [LAYER 4] Ký chữ ký Request `X-Sign` bằng HMAC-SHA256
  /// Lưu ý: [pathOnly] CHỈ chứa đường dẫn (VD: "/v1/dramas/new"), KHÔNG chứa "?page=1"
  String computeRequestSignature({
    required String method,
    required String pathOnly,
    required String timestamp,
    required String nonce,
    required String deviceId,
    List<int> bodyBytes = const [],
  }) {
    final signMaterial =
        'SIGN_V2|$appCode|$packageName|$appNativeSecret|$activeSalt|$_certPart';
    final signKey = _sha256Bytes(signMaterial);

    final bodyHashHex = crypto.sha256.convert(bodyBytes).toString();
    final canonical = [
      method.toUpperCase(),
      pathOnly,
      timestamp,
      nonce,
      deviceId,
      bodyHashHex,
    ].join('\n');

    final hmac = crypto.Hmac(crypto.sha256, signKey);
    return hmac.convert(utf8.encode(canonical)).toString();
  }

  /// [LAYER 3] Giải mã trường `data: "v2.<Base64>"` động theo từng Request
  /// Hỗ trợ tự động fallback về seed rỗng nếu phiên Redis 2 giờ vừa hết hạn.
  Future< ({dynamic json, bool sessionExpiredOnServer}) > decryptV2Response({
    required String encryptedData,
    required String versionCode,
    required String reqTimestamp,
    required String reqNonce,
    String? usedSessionSeed,
  }) async {
    if (!encryptedData.startsWith('v2.')) {
      return (json: encryptedData, sessionExpiredOnServer: false);
    }

    final raw = base64.decode(encryptedData.substring(3));
    if (raw.length < 28) {
      throw const FormatException('Invalid v2 response ciphertext');
    }

    final iv = raw.sublist(0, 12);
    final tag = raw.sublist(raw.length - 16);
    final cipherText = raw.sublist(12, raw.length - 16);
    final secretBox = SecretBox(cipherText, nonce: iv, mac: Mac(tag));

    final seedToTry = usedSessionSeed ?? sessionSeed;

    Future<dynamic> tryDecryptWithSeed(String seed) async {
      final respMaterial =
          'RESP_V2|$appCode|$packageName|$versionCode|$appNativeSecret|$activeSalt|$seed|$reqTimestamp|$reqNonce|$_certPart';
      final keyBytes = _sha256Bytes(respMaterial);
      final clearBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(keyBytes),
      );
      return jsonDecode(utf8.decode(clearBytes));
    }

    try {
      final decoded = await tryDecryptWithSeed(seedToTry);
      return (json: decoded, sessionExpiredOnServer: false);
    } on SecretBoxAuthenticationError {
      // Nếu thiết bị gửi X-Session-Token cũ đã hết TTL 2h trên Redis, Server đã mã hoá bằng seed=""
      if (seedToTry.isNotEmpty) {
        final decodedFallback = await tryDecryptWithSeed('');
        return (json: decodedFallback, sessionExpiredOnServer: true);
      }
      rethrow;
    }
  }
}
