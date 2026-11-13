import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../security/drama_crypto_engine.dart';

class DramaPaywallException extends DioException {
  final Map<String, dynamic> paywallData;
  DramaPaywallException({
    required super.requestOptions,
    required super.response,
    required this.paywallData,
  }) : super(message: 'Episode unlock required.');
}

class DramaSecurityDioInterceptor extends Interceptor {
  final Dio dio;
  final DramaCryptoEngine crypto;
  final List<String> fallbackApiUrls;
  final String versionCode;
  final String deviceId;
  final String Function() getAppLanguage;
  final String timezoneName;
  final Future<void> Function()? onSessionRefreshNeeded;

  DramaSecurityDioInterceptor({
    required this.dio,
    required this.crypto,
    this.fallbackApiUrls = const [],
    required this.versionCode,
    required this.deviceId,
    required this.getAppLanguage,
    required this.timezoneName,
    this.onSessionRefreshNeeded,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Cho phép HTTP 402 đi vào onResponse để giải mã dữ liệu unlock_options mượt mà
    options.validateStatus = (status) => status != null && (status >= 200 && status < 300 || status == 402);

    final ts = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = crypto.generateNonce();
    final usedSeed = crypto.sessionToken.isNotEmpty ? crypto.sessionSeed : '';

    // Chuẩn hoá Raw JSON Body thành mảng byte cố định để băm SHA-256 khớp 100% với gói gửi đi
    List<int> bodyBytes = const [];
    if (options.data != null && options.method.toUpperCase() != 'GET') {
      final jsonStr = options.data is String ? options.data as String : jsonEncode(options.data);
      options.data = jsonStr;
      bodyBytes = utf8.encode(jsonStr);
      options.headers['Content-Type'] = 'application/json';
    }

    // LƯU Ý: Chỉ truyền path (VD: "/v1/dramas/new"), không bao gồm query string
    final pathOnly = options.uri.path;
    final sign = crypto.computeRequestSignature(
      method: options.method,
      pathOnly: pathOnly,
      timestamp: ts,
      nonce: nonce,
      deviceId: deviceId,
      bodyBytes: bodyBytes,
    );

    // QUAN TRỌNG: HTTP Request Headers đi qua Cloudflare HTTPS bắt buộc dùng dấu gạch ngang '-'
    // (không dùng dấu '_' trong tên HTTP Header để tránh bị Cloudflare Edge lọc bỏ;
    //  riêng 9 tham số trên Firebase Remote Config thì bắt buộc dùng dấu '_' như rc_app_code!)
    options.headers.addAll({
      'X-App-Code': crypto.appCode, // Giá trị lấy từ rc_app_code trên Firebase Remote Config
      'X-Package-Name': crypto.packageName,
      'X-Version-Code': versionCode,
      'X-Platform': Platform.isIOS ? 'ios' : 'android',
      'X-Device-Id': deviceId,
      'X-App-Lang': getAppLanguage(),
      'X-Timezone-Offset': DateTime.now().timeZoneOffset.inMinutes.toString(),
      'X-Crypto-Ver': 'v2',
      'X-Timestamp': ts,
      'X-Nonce': nonce,
      'X-Sign': sign,
      if (crypto.sessionToken.isNotEmpty) 'X-Session-Token': crypto.sessionToken,
      if (crypto.accessToken.isNotEmpty)
        'Authorization': 'Bearer ${crypto.accessToken}',
      if (crypto.enforceApkCert && crypto.apkCertSha256.isNotEmpty)
        'X-Apk-Cert-Sha256': crypto.apkCertSha256,
    });

    // Lưu vào extra của chính request này để lúc nhận Response lấy đúng ts/nonce/seed ra giải mã
    options.extra['_drama_ts'] = ts;
    options.extra['_drama_nonce'] = nonce;
    options.extra['_drama_seed'] = usedSeed;

    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // Tự động chuyển sang domain dự phòng (rc_api_url_fallback) nếu domain chính lỗi kết nối/DNS
    final isConnErr = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout;
    final fbIdx = (err.requestOptions.extra['_drama_fb_idx'] as int?) ?? 0;

    if (isConnErr && fbIdx < fallbackApiUrls.length) {
      final nextBase = fallbackApiUrls[fbIdx];
      dio.options.baseUrl = nextBase;
      final retryOpts = err.requestOptions..baseUrl = nextBase;
      retryOpts.extra['_drama_fb_idx'] = fbIdx + 1;
      try {
        final retryResp = await dio.fetch(retryOpts);
        return handler.resolve(retryResp);
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      }
    }
    handler.next(err);
  }

  @override
  Future<void> onResponse(Response response, ResponseInterceptorHandler handler) async {
    final body = response.data is String ? jsonDecode(response.data as String) : response.data;
    if (body is Map<String, dynamic> && body['data'] is String) {
      final encStr = body['data'] as String;
      if (encStr.startsWith('v2.')) {
        final decResult = await crypto.decryptV2Response(
          encryptedData: encStr,
          versionCode: versionCode,
          reqTimestamp: response.requestOptions.extra['_drama_ts'] as String,
          reqNonce: response.requestOptions.extra['_drama_nonce'] as String,
          usedSessionSeed: response.requestOptions.extra['_drama_seed'] as String,
        );
        body['data'] = decResult.json;

        if (decResult.sessionExpiredOnServer &&
            !response.requestOptions.uri.path.endsWith('/app/init')) {
          crypto.sessionToken = '';
          crypto.sessionSeed = '';
          onSessionRefreshNeeded?.call();
        }
      }
    }

    response.data = body;

    // Nếu là HTTP 402 Paywall -> Ném DramaPaywallException kèm sẵn unlock_options đã giải mã!
    if (response.statusCode == 402 || (body is Map && body['code'] == 402)) {
      final paywallInfo = (body is Map && body['data'] is Map<String, dynamic>)
          ? body['data'] as Map<String, dynamic>
          : <String, dynamic>{};
      return handler.reject(DramaPaywallException(
        requestOptions: response.requestOptions,
        response: response,
        paywallData: paywallInfo,
      ));
    }

    handler.next(response);
  }
}
