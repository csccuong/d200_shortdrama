# 📱 Tài Liệu Tích Hợp API Cho Flutter App (`v4.5`)

Tài liệu hướng dẫn trực tiếp cho đội phát triển **Flutter** (Android & iOS): lấy cấu hình ở đâu, ký & giải mã thế nào, thứ tự gọi API và chi tiết tham số truyền vào.

---

## 1. Các Thông Tin Cấu Hình Lấy Ở Đâu?

### 1.1. 3 Thông số gắn cố định trong App (lấy trên CMS ➔ Quản Lý Ứng Dụng)
| Biến trong Flutter | Lấy ở đâu | Ví dụ |
|---|---|---|
| `packageName` | `applicationId` (Android) / `PRODUCT_BUNDLE_IDENTIFIER` (iOS) | `com.dramareels.shorttv` |
| `versionCode` | `buildNumber` trong `pubspec.yaml` (`package_info_plus`) | `"1"` |
| `appNativeSecret` | CMS ➔ **Tab 5 (Bảo Mật)** ➔ `App Native Secret` (nên cất trong Dart `--dart-define` hoặc C++ FFI) | `"32_char_hex_secret..."` |

### 1.2. 9 Key phẳng lấy từ Firebase Remote Config (Không dùng JSON)
Copy nguyên 9 key từ CMS ➔ **Tab 6 (Firebase Remote Config)** lên Firebase Console:

| Key trên Firebase RC | Kiểu lưu | Ý nghĩa |
|---|---|---|
| `rc_app_code` | Plaintext | Mã định danh App (VD: `default_app`). Đọc key này đầu tiên để làm khoá giải mã 5 key `enc_v2:` bên dưới. |
| `rc_api_url_primary` | `enc_v2:...` | Domain API chính (`https://api.dramota.com`). |
| `rc_api_url_fallback` | `enc_v2:...` / `""` | Domain API dự phòng phân tách dấu phẩy (chuyển sang khi domain chính lỗi mạng/5xx). |
| `rc_media_cdn` | `enc_v2:...` | Domain CDN phát video/ảnh (`https://cdn.dramota.com`). |
| `rc_crypto_salt` | `enc_v2:...` | Chuỗi salt động dùng để ký `X-Sign` và giải mã response `v2.`. |
| `rc_ssl_pins` | `enc_v2:...` / `""` | Danh sách SHA-256 SSL Pin phân tách dấu phẩy (để trống `""` = tắt pinning). |
| `rc_review_ver` | Plaintext | Build number đang gửi Apple/Google duyệt (VD `"0"`). |
| `rc_maintenance_enabled` | Plaintext | `"true"` = bật màn hình bảo trì; `"false"` = hoạt động bình thường. |
| `rc_maintenance_msg` | Plaintext | Nội dung thông báo bảo trì hiển thị cho user. |

### 1.3. Thông tin phiên động lấy từ `POST /v1/app/init`
- `device_id`: App tự sinh UUID v4 lần đầu cài đặt và lưu vào `FlutterSecureStorage` (không xin quyền nhạy cảm).
- `session_token` & `ephemeral_seed`: Server cấp khi gọi `POST /v1/app/init` (hoặc sau `register` / `login` / `logout`), hiệu lực **2 giờ** (7200s).

### 1.4. Bộ HTTP Headers đính kèm vào mọi API `/v1/*`
> **Lưu ý:** Trên HTTP Header bắt buộc dùng dấu gạch ngang `-` (Cloudflare chặn header chứa dấu `_`).

| Header | Giá trị | Ghi chú |
|---|---|---|
| `X-App-Code` | Giá trị từ `rc_app_code` | Bắt buộc |
| `X-Package-Name` | `packageName` | Bắt buộc |
| `X-Version-Code` | `versionCode` | Bắt buộc |
| `X-Device-Id` | UUID thiết bị lưu trong SecureStorage | Bắt buộc |
| `X-Platform` | `android` hoặc `ios` | Bắt buộc |
| `X-App-Lang` | Mã ngôn ngữ UI hiện tại (`en`, `vi`, `es`, `id`, `th`...) | Mặc định `en` |
| `X-Timezone-Offset` | Số phút lệch UTC (VD Việt Nam = `420`) | Dùng tính ngày điểm danh |
| `X-Crypto-Ver` | `"v2"` | Bắt buộc bật mã hoá động V2 |
| `X-Session-Token` | `session_token` (lúc gọi `/v1/app/init` lần đầu truyền `""`) | Bắt buộc |
| `X-Timestamp` | Unix timestamp giây hiện tại (sai lệch tối đa ±120s) | Sinh mới mỗi request |
| `X-Nonce` | Chuỗi hex ngẫu nhiên >= 16 ký tự (chống replay 150s) | Sinh mới mỗi request |
| `X-Sign` | Chữ ký `HMAC-SHA256` của request | Sinh mới mỗi request |

---

## 2. Cơ Chế Mã Hoá, Ký Request & Giải Mã Response

*(Mặc định CMS tắt `enforce_apk_cert`, nên `certPart = ""`. Nếu bật trên CMS thì truyền SHA-256 cert chữ thường bỏ dấu `:`).*

1. **Giải mã các key `enc_v2:<base64>` trên Firebase Remote Config (AES-256-GCM):**
   - `rcKey = SHA256("RC_V2|{appCode}|{packageName}|{appNativeSecret}|{certPart}")` *(32 bytes)*
   - Tách `raw = Base64Decode(str.substring(7))`: `iv = raw[0..12]`, `cipherText = raw[12..end-16]`, `macTag = raw[end-16..end]`.
   - Giải mã AES-256-GCM với **`AAD = utf8.encode(rcKeyName)`** (VD: `utf8.encode("rc_api_url_primary")`).

2. **Tạo chữ ký `X-Sign` cho mỗi Request (HMAC-SHA256):**
   - `signKey = SHA256("SIGN_V2|{appCode}|{packageName}|{appNativeSecret}|{cryptoSalt}|{certPart}")`
   - `bodySha256 = SHA256_HEX(rawBodyBytes)` *(nếu `GET` không có body thì `rawBodyBytes = []`, mã băm là `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)*.
   - `canonical = "{METHOD_UPPER}\n{PATH_ONLY}\n{timestamp}\n{nonce}\n{deviceId}\n{bodySha256}"`
     *(Chú ý: `PATH_ONLY` chỉ lấy đường dẫn như `/v1/dramas`, **không** bao gồm chuỗi `?page=1...`)*.
   - `X-Sign = HMAC_SHA256_HEX(signKey, canonical)`

3. **Giải mã trường `data` (`"v2.<base64>"`) trong Response (AES-256-GCM):**
   - Mọi API trả về vỏ JSON: `{"code": 200, "message": "", "data": "v2.<base64>"}`.
   - `respKey = SHA256("RESP_V2|{appCode}|{packageName}|{versionCode}|{appNativeSecret}|{cryptoSalt}|{sessionSeed}|{reqTimestamp}|{reqNonce}|{certPart}")`
     *(Lúc gọi `/v1/app/init` chưa có session thì `sessionSeed = ""`; các API sau truyền `ephemeral_seed` đã nhận)*.
   - Bỏ tiền tố `"v2."`, Base64 decode: `12 bytes IV` + `cipherText` + `16 bytes GCM Tag` (`AAD` = rỗng `const <int>[]`) ➔ Giải mã ra chuỗi JSON UTF-8 rồi `jsonDecode`.

4. **Phát Video `.mp4` & Phụ Đề `.vtt`:**
   - API trả về đường dẫn tương đối dạng `/v1/stream/{opaque_token}.mp4` và `/v1/stream/{opaque_token}.vtt`.
   - Ghép với `apiBaseUrl`: `https://api.dramota.com/v1/stream/{opaque_token}.mp4` rồi truyền thẳng vào `video_player` / `better_player` (**không** gắn `X-Sign` vào URL stream để Player tự theo `302 Redirect` sang CDN Cloudflare R2 `https://cdn.dramota.com`).

---

## 3. Code Mẫu Flutter Dùng Ngay (`pubspec.yaml` & Client)

Thêm các package chuẩn vào `pubspec.yaml`:
```yaml
dependencies:
  dio: ^5.7.0
  crypto: ^3.0.5
  cryptography: ^2.7.0
  firebase_remote_config: ^5.1.3
  flutter_secure_storage: ^9.2.2
  uuid: ^4.5.1
```

### 3.1. `lib/core/drama_api_client.dart` (Giải mã RC + Ký Request + Giải mã Response + Tự làm mới Session)
```dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class DramaApiException implements Exception {
  final int code;
  final String message;
  final Map<String, dynamic>? data; // Có dữ liệu khi code == 402 (Paywall mở khoá tập)
  DramaApiException(this.code, this.message, [this.data]);
  @override
  String toString() => 'DramaApiException($code): $message';
}

class DramaApiClient {
  final String packageName;
  final String versionCode;
  final String appNativeSecret;
  final String platform; // 'android' | 'ios'
  final String certSha256; // Để '' nếu CMS tắt enforce_apk_cert

  late final Dio _dio;
  final AesGcm _aesGcm = AesGcm.with256bits();

  String appCode = 'default_app';
  String apiBaseUrl = '';
  List<String> fallbackUrls = [];
  String mediaCdnUrl = '';
  String cryptoSalt = '';
  String deviceId = '';
  String appLang = 'en';

  String _sessionToken = '';
  String _ephemeralSeed = '';
  DateTime? _sessionExpiresAt;

  DramaApiClient({
    required this.packageName,
    required this.versionCode,
    required this.appNativeSecret,
    required this.platform,
    required this.deviceId,
    this.appLang = 'en',
    this.certSha256 = '',
  }) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ));
  }

  List<int> _sha256Bytes(String input) => crypto.sha256.convert(utf8.encode(input)).bytes;
  String _sha256Hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

  String _randomNonce([int byteLen = 12]) {
    final rnd = Random.secure();
    return List.generate(byteLen, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Bước 0: Nạp & giải mã 9 key phẳng từ Firebase Remote Config
  Future<void> loadRemoteConfig(FirebaseRemoteConfig rc) async {
    await rc.fetchAndActivate();
    appCode = rc.getString('rc_app_code').trim();
    if (appCode.isEmpty) appCode = 'default_app';

    if (rc.getString('rc_maintenance_enabled').toLowerCase() == 'true') {
      throw DramaApiException(503, rc.getString('rc_maintenance_msg'));
    }

    apiBaseUrl = await _decryptRcKey('rc_api_url_primary', rc.getString('rc_api_url_primary'));
    final fbRaw = await _decryptRcKey('rc_api_url_fallback', rc.getString('rc_api_url_fallback'));
    fallbackUrls = fbRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    mediaCdnUrl = await _decryptRcKey('rc_media_cdn', rc.getString('rc_media_cdn'));
    cryptoSalt = await _decryptRcKey('rc_crypto_salt', rc.getString('rc_crypto_salt'));
  }

  Future<String> _decryptRcKey(String rcKeyName, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('enc_v2:')) return trimmed;
    final cleanCert = certSha256.toLowerCase().replaceAll(':', '').trim();
    final keyBytes = _sha256Bytes('RC_V2|$appCode|$packageName|$appNativeSecret|$cleanCert');

    final raw = base64Decode(trimmed.substring(7));
    final box = SecretBox(
      raw.sublist(12, raw.length - 16),
      nonce: raw.sublist(0, 12),
      mac: Mac(raw.sublist(raw.length - 16)),
    );
    final clear = await _aesGcm.decrypt(box, secretKey: SecretKey(keyBytes), aad: utf8.encode(rcKeyName));
    return utf8.decode(clear);
  }

  /// Bước 1: Khởi tạo phiên làm việc bắt buộc khi mở App
  Future<Map<String, dynamic>> initSession({Map<String, dynamic>? deviceInfo}) async {
    _sessionToken = '';
    _ephemeralSeed = '';
    final payload = {
      'device_id': deviceId,
      'platform': platform,
      'app_language': appLang,
      'app_version_code': int.tryParse(versionCode) ?? 1,
      'timezone_offset_min': DateTime.now().timeZoneOffset.inMinutes,
      ...?deviceInfo,
    };
    final data = await request('POST', '/v1/app/init', body: payload, skipSessionCheck: true);
    applySessionBundle(data['session'] as Map<String, dynamic>?);
    return data;
  }

  /// Cập nhật lại session sau init / register / login / social-login / logout
  void applySessionBundle(Map<String, dynamic>? session) {
    if (session == null) return;
    _sessionToken = (session['session_token'] ?? '').toString();
    _ephemeralSeed = (session['ephemeral_seed'] ?? '').toString();
    final ttl = int.tryParse('${session['expires_in'] ?? 7200}') ?? 7200;
    _sessionExpiresAt = DateTime.now().add(Duration(seconds: ttl - 120));
  }

  /// Ghép URL đầy đủ để truyền vào VideoPlayer / Subtitle Track
  String resolveMediaUrl(String urlOrPath) {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) return urlOrPath;
    final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    return '$base${urlOrPath.startsWith('/') ? '' : '/'}$urlOrPath';
  }

  /// Hàm gọi API dùng chung cho toàn bộ GET / POST / PUT / DELETE
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool skipSessionCheck = false,
  }) async {
    if (!skipSessionCheck && (_sessionToken.isEmpty || (_sessionExpiresAt != null && DateTime.now().isAfter(_sessionExpiresAt!)))) {
      await initSession();
    }

    final upperMethod = method.toUpperCase();
    final bodyStr = (body != null && upperMethod != 'GET') ? jsonEncode(body) : '';
    final bodyBytes = bodyStr.isEmpty ? Uint8List(0) : Uint8List.fromList(utf8.encode(bodyStr));

    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = _randomNonce(12);
    final cleanCert = certSha256.toLowerCase().replaceAll(':', '').trim();

    // 1. Ký X-Sign
    final signKey = _sha256Bytes('SIGN_V2|$appCode|$packageName|$appNativeSecret|$cryptoSalt|$cleanCert');
    final canonical = '$upperMethod\n$path\n$ts\n$nonce\n$deviceId\n${_sha256Hex(bodyBytes)}';
    final signHex = crypto.Hmac(crypto.sha256, signKey).convert(utf8.encode(canonical)).toString();

    final headers = <String, String>{
      'X-App-Code': appCode,
      'X-Package-Name': packageName,
      'X-Version-Code': versionCode,
      'X-Device-Id': deviceId,
      'X-Platform': platform,
      'X-App-Lang': appLang,
      'X-Timezone-Offset': DateTime.now().timeZoneOffset.inMinutes.toString(),
      'X-Crypto-Ver': 'v2',
      'X-Session-Token': _sessionToken,
      'X-Timestamp': ts,
      'X-Nonce': nonce,
      'X-Sign': signHex,
      if (bodyStr.isNotEmpty) 'Content-Type': 'application/json',
    };

    final resp = await _dio.request(
      '${apiBaseUrl.replaceAll(RegExp(r'/$'), '')}$path',
      queryParameters: query,
      data: bodyStr.isEmpty ? null : bodyStr,
      options: Options(method: upperMethod, headers: headers),
    );

    final envelope = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
    final code = int.tryParse('${envelope['code'] ?? resp.statusCode ?? 500}') ?? 500;
    final msg = (envelope['message'] ?? '').toString();

    Map<String, dynamic> decodedData = {};
    final rawData = envelope['data'];
    if (rawData is String && rawData.startsWith('v2.')) {
      final rawBytes = base64Decode(rawData.substring(3));
      final box = SecretBox(
        rawBytes.sublist(12, rawBytes.length - 16),
        nonce: rawBytes.sublist(0, 12),
        mac: Mac(rawBytes.sublist(rawBytes.length - 16)),
      );
      List<int> clear;
      try {
        final respKey = _sha256Bytes(
          'RESP_V2|$appCode|$packageName|$versionCode|$appNativeSecret|$cryptoSalt|$_ephemeralSeed|$ts|$nonce|$cleanCert',
        );
        clear = await _aesGcm.decrypt(box, secretKey: SecretKey(respKey));
      } on SecretBoxAuthenticationError {
        // Phòng trường hợp Redis trên server vừa xoá session sớm -> giải mã fallback với seed rỗng & làm mới session ngầm
        final emptyKey = _sha256Bytes(
          'RESP_V2|$appCode|$packageName|$versionCode|$appNativeSecret|$cryptoSalt||$ts|$nonce|$cleanCert',
        );
        clear = await _aesGcm.decrypt(box, secretKey: SecretKey(emptyKey));
        if (!skipSessionCheck) unawaited(initSession());
      }
      final parsed = jsonDecode(utf8.decode(clear));
      decodedData = parsed is Map ? Map<String, dynamic>.from(parsed) : {'items': parsed};
    } else if (rawData is Map) {
      decodedData = Map<String, dynamic>.from(rawData);
    }

    if (code != 200) {
      throw DramaApiException(code, msg.isEmpty ? 'Request failed ($code)' : msg, decodedData.isEmpty ? null : decodedData);
    }
    return decodedData;
  }
}
```

### 3.2. `lib/core/drama_event_tracker.dart` (Gom lô Event Tracking tối ưu tải Server)
```dart
import 'dart:async';
import 'drama_api_client.dart';

class DramaEventTracker {
  final DramaApiClient api;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;

  DramaEventTracker(this.api) {
    _flushTimer = Timer.periodic(const Duration(seconds: 10), (_) => flush());
  }

  void track(
    String event, {
    String dramaId = '',
    int episodeNumber = 0,
    int positionSec = 0,
    int watchedSec = 0,
    String sourceScreen = '',
    Map<String, dynamic>? props,
  }) {
    _queue.add({
      'event': event,
      if (dramaId.isNotEmpty) 'drama_id': dramaId,
      if (episodeNumber > 0) 'episode_number': episodeNumber,
      if (positionSec > 0) 'position_sec': positionSec,
      if (watchedSec > 0) 'watched_sec': watchedSec,
      if (sourceScreen.isNotEmpty) 'source_screen': sourceScreen,
      if (props != null && props.isNotEmpty) 'props': props,
    });
    if (_queue.length >= 15) flush();
  }

  Future<void> flush() async {
    if (_queue.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_queue.take(50));
    _queue.removeRange(0, batch.length);
    try {
      await api.request('POST', '/v1/events/track', body: {'events': batch});
    } catch (_) {
      // Không chặn luồng UI nếu mất mạng tạm thời
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    flush();
  }
}
```

---

## 4. Thứ Tự Gọi API Chuẩn Từ Lúc Mở App

1. **Splash (Khởi động):** `loadRemoteConfig()` ➔ gọi `POST /v1/app/init` nhận `session`, `taxonomy.facets` (bộ đếm Quốc gia / Châu lục / Thể loại / #Tag), `paywall`, `ads`, `user` (ví Xu, trạng thái VIP).
2. **Vào màn Home:** Gọi `GET /v1/home?lang=en` (1 request duy nhất trả đủ: `banners`, `continue_watching`, `trending`, `most_viewed`, `most_favorited`, `recommended` 20 phim trang 1, `category_sections`). Cuộn xuống đáy Home mới gọi `GET /v1/dramas/recommend?page=2&page_size=20`.
3. **Vào Tab For You (Vuốt dọc kiểu TikTok):**
   - Mở tab: `GET /v1/feed/for-you?cursor=0&lang=en` (mặc định nhận **20 phim**, mỗi phim gắn sẵn `preview.video_url` + `preview.subtitles` Tập 1 để phát ngay).
   - Khi user vuốt còn cách cuối danh sách **5 phim**: gọi ngầm `GET /v1/feed/for-you?cursor={next_cursor}&lang=en` (0% trùng lặp).
   - Chỉ preload `Range: bytes=0-1500000` (1.5 MB đầu) cho 2 phim kế tiếp (`i+1`, `i+2`).
4. **Lọc phim / Tìm kiếm / Bảng xếp hạng:**
   - Lọc đa chiều ở tab All Dramas: `GET /v1/dramas?country=cn&region=asia&audio_mode=subtitles&sort=popular&page=1&page_size=20`.
   - Bảng xếp hạng Top Xem nhiều / Top Yêu thích: `GET /v1/dramas/ranking?type=most_viewed&period=week` hoặc `type=most_favorited`.
   - Tìm kiếm: `GET /v1/search/hot` (khi chạm ô search) ➔ `GET /v1/search?q=...` (debounce 350ms).
5. **Xem trọn bộ & Mở khoá tập (Khi bấm thẻ phim hoặc nút `"Watch Full Series"`):**
   - Gọi song song `GET /v1/dramas/{drama_id}` và `GET /v1/dramas/{drama_id}/episodes?page=1&page_size=100`.
   - Khi phát Tập `N`: gọi `GET /v1/dramas/{drama_id}/episodes/{ep_num}/play`.
     - Nếu `code == 200`: phát `video_url` + nạp `subtitles[]` (server tự cộng `view_count` chống trùng 5 phút).
     - Nếu `code == 402` (`DramaApiException.data` chứa `unlock_options`): hiện popup mở khoá bằng Quảng cáo hoặc Xu ➔ gọi `POST /v1/episodes/unlock` (trả kèm luôn `video_url` để phát ngay, không cần gọi lại `/play`).
6. **Ghi nhận hành vi & Tiến độ xem (Trong lúc dùng App):**
   - Mọi sự kiện xem phim, vuốt nhanh, bấm lọc, tìm kiếm, xem quảng cáo đẩy vào `tracker.track(...)` (`POST /v1/events/track`).
   - Định kỳ mỗi 45–60s khi đang phát video: gọi `POST /v1/app/heartbeat` (hoặc `POST /v1/me/history` khi chuyển tập / thoát trình phát) để lưu vị trí giây đang xem và cộng phút xem cho nhiệm vụ nhận Xu.
7. **Tương tác cá nhân (Hoạt động ngay cả khi chưa tạo tài khoản - Guest-First):**
   - Yêu thích phim (❤️): `POST /v1/me/favorites` (`GET /v1/me/favorites` để mở danh sách Yêu thích).
   - Thêm vào Xem sau (🔖): `POST /v1/me/watch-later` (`GET /v1/me/watch-later` để mở danh sách Xem sau).
   - Thả tim / Chia sẻ trên Player: `POST /v1/dramas/{id}/like` và `POST /v1/dramas/{id}/share`.
8. **Tài khoản & Đồng bộ đa thiết bị (Khi user muốn tạo tài khoản / đăng nhập):**
   - Đăng ký Email: `POST /v1/auth/register` ➔ toàn bộ Yêu thích, Xem sau, Lịch sử, Tập đã mở khoá & Xu của Guest tự động gắn vào tài khoản.
   - Đăng nhập Email (`POST /v1/auth/login`) hoặc Google/Apple (`POST /v1/auth/social-login`) trên máy mới ➔ tự động khôi phục & hợp nhất toàn bộ dữ liệu về máy hiện tại. **Lưu ý:** Sau `register` / `login` / `social-login` / `logout`, nhớ gọi `api.applySessionBundle(res['session'])`.

---

## 5. Danh Mục Toàn Bộ API & Tham Số Truyền Vào

*(Mặc định mọi API danh sách đều nhận `page=1`, `page_size=20` (tối đa 60) và `lang=en`. Truyền `page_size` hoặc `count` bằng bao nhiêu server trả đúng bấy nhiêu).*

### 5.1. Khởi tạo, Cấu hình & Heartbeat
| Method & Endpoint | Ý nghĩa | Tham số truyền vào (Body / Query) |
|---|---|---|
| `POST /v1/app/init` | Khởi tạo phiên, nhận `session_token` + `ephemeral_seed`, bộ lọc `taxonomy.facets`, cấu hình Paywall/Ads & ví user. | **Body:** `device_id` *(bắt buộc)*, `platform` (`android`/`ios`), `app_language` (`en`), `app_version_code` (`int`), `app_version_name`, `device_brand`, `device_model`, `os_version`, `timezone_offset_min`, `fcm_token` *(tuỳ chọn)*. |
| `POST /v1/app/push-token` | Cập nhật Firebase FCM Token khi user cấp quyền thông báo. | **Body:** `fcm_token` *(bắt buộc)*, `push_enabled` (`bool`, mặc định `true`). |
| `POST /v1/app/heartbeat` | Gọi mỗi 45–60s khi đang xem phim: cộng giây xem nhiệm vụ Xu & tự lưu vị trí tập đang phát. | **Body:** `watched_delta_sec` (`int`, `0..180`), `drama_id` *(tuỳ chọn)*, `episode_number` (`int`), `position_sec` (`int`), `duration_sec` (`int`). |
| `GET /v1/languages` | Danh sách 17 ngôn ngữ hỗ trợ (`en`, `vi`, `id`, `es`, `pt`, `th`, `ar`, `ko`, `ja`, `zh-Hans`...). | Không cần tham số. |

### 5.2. Trang Chủ, Khám Phá, Lọc Phim, Tìm Kiếm & Bảng Xếp Hạng
| Method & Endpoint | Ý nghĩa | Tham số truyền vào (Query) |
|---|---|---|
| `GET /v1/home` | Dữ liệu trọn gói màn Home: `banners`, `continue_watching`, `trending`, `most_viewed` (Xem nhiều), `most_favorited` (Yêu thích nhiều), `recommended` (20 phim trang 1), `category_sections`. | `lang` (`en`). |
| `GET /v1/dramas/recommend` | Phân trang kệ *"Recommended for You"* theo tệp sở thích Cohort của user. | `page` (`>=1`), `page_size` (`20`), `refresh` (`true` để trộn bộ bài mới), `lang`. |
| `GET /v1/dramas/filters` | Lấy toàn bộ danh mục bộ lọc kèm số lượng phim thực tế (`count`) cho BottomSheet Filter. | `lang` (`en`). Trả về: `countries`, `regions`, `audio_modes`, `audiences`, `categories`, `tags`, `statuses`, `ep_lengths`, `sorts`. |
| `GET /v1/dramas` | Lọc & duyệt kho phim đa chiều tốc độ cao. Hỗ trợ truyền nhiều mã cách nhau dấu phẩy (VD `country=cn,kr`). | `country` (`all` \| `cn`, `kr`, `us`, `jp`, `th`, `vn`, `other`...), `region` (`all` \| `asia` \| `western` \| `other`), `audio_mode` (`all` \| `subtitles` \| `dubbed` \| `hardsub`), `sub_lang` (`vi,en`), `has_sub_lang` (`bool`), `audience` (`all` \| `female` \| `male` \| `general`), `category` (slug), `tag` (slug VD `mafia,reversal`), `status` (`all` \| `completed` \| `ongoing`), `ep_length` (`all` \| `short` \| `medium` \| `long`), `is_vip` (`all` \| `free` \| `vip`), `sort` (`popular` \| `latest` \| `trending` \| `views` \| `favorites` \| `likes` \| `saved` \| `rating`), `page`, `page_size` (`20`), `lang`. |
| `GET /v1/dramas/ranking` | **Bảng xếp hạng Top Phim:** Top Xem nhiều, Top Yêu thích, Top Thả tim, Top Xem sau, Thịnh hành, Đánh giá cao (trả kèm `rank: 1, 2, 3...`). | `type` (`most_viewed` \| `most_favorited` \| `most_liked` \| `most_saved` \| `trending` \| `top_rated` \| `new`), `period` (`day` \| `week` \| `all`), `country`, `region`, `category`, `page`, `page_size` (`20`), `lang`. |
| `GET /v1/dramas/new` | Danh sách Phim Mới xoay vòng hàng ngày. | `page`, `page_size` (`20`), `lang`. |
| `GET /v1/dramas/trending` | Danh sách Phim Thịnh Hành kèm `trending_rank`. | `page`, `page_size` (`20`), `lang`. |
| `GET /v1/search/hot` | Top 10 từ khoá `#Tag` hot & Top 10 phim xu hướng ở màn chờ tìm kiếm. | `lang`. |
| `GET /v1/search` | Tìm kiếm theo Tên phim, Mô tả, `#Tag` đa ngôn ngữ. | `q` *(bắt buộc, từ khoá)*, `category`, `country`, `region`, `page`, `page_size` (`20`), `lang`. |
| `GET /v1/categories` | Danh sách 12 Thể loại & 40 `#Tag` chuẩn (kèm `count`). | `lang`, `include_tags` (`true`), `include_facets` (`false`/`true`). |

### 5.3. Tab Vuốt Dọc "For You"
| Method & Endpoint | Ý nghĩa | Tham số truyền vào (Query) |
|---|---|---|
| `GET /v1/feed/for-you` | Luồng video dọc phát ngay Tập 1 (`preview.video_url` + `preview.subtitles` + `preview.watch_full_drama_target_episode`). | `cursor` (lần đầu `"0"`, nạp thêm truyền nguyên chuỗi `data.next_cursor`), `count` (`20`), `refresh` (`true` khi kéo làm mới), `exclude_ids` (danh sách ID cách dấu phẩy), `lang`. |

### 5.4. Event Tracking — Theo Dõi Hành Vi Sử Dụng App & Xem Phim
| Method & Endpoint | Ý nghĩa | Tham số truyền vào (Body JSON) |
|---|---|---|
| `POST /v1/events/track` *(Alias: `/v1/feed/events`)* | Nhận 1 sự kiện lẻ hoặc mảng tối đa **50 sự kiện/lần**. Tự động lưu log phân tích, cập nhật bộ đếm phim & huấn luyện gợi ý cá nhân hoá 5 chiều (Thể loại, `#Tag`, Quốc gia, Châu lục, Giới tính khán giả). | `{"events": [{"event": "...", "drama_id": "...", "episode_number": 1, "position_sec": 30, "watched_sec": 15, "source_screen": "for_you", "props": {...}}]}` |

**Bảng mã `event` chuẩn nên bắn từ Flutter App:**
- **Vòng đời & Khám phá:** `app_open`, `screen_view` (`props: {"screen": "home"}`), `search_query` (`props: {"q": "ceo"}`), `filter_apply` (`props: {"country": "cn", "tag": "mafia", "region": "asia"}` ➔ Server tự học gu lọc của user!), `drama_impression`, `drama_click`.
- **Tab For You:** `preview_start` (bắt đầu phát Tập 1), `skip_fast` (vuốt bỏ < 2s ➔ giảm gợi ý thể loại đó), `watch_3s`, `finish_preview` (xem hết Tập 1), `click_full_drama` (bấm nút *"Watch Full Series"*).
- **Trình phát Video:** `episode_play_start` (cộng `view_count` chống trùng 5 phút), `episode_progress` (truyền `watched_sec` để cộng thời gian xem thực tế), `episode_complete` (hoàn thành tập), `subtitle_change` (`props: {"lang": "vi"}`), `playback_error`.
- **Tương tác & Doanh thu:** `favorite_add`, `favorite_remove`, `watch_later_add`, `like`, `share` (`props: {"channel": "copy_link"}`), `paywall_show`, `ad_reward_start`, `ad_reward_complete`, `unlock_success`, `iap_open`, `iap_success`.

### 5.5. Chi Tiết Phim, Phát Video, Mở Khoá Tập, Thả Tim & Chia Sẻ
| Method & Endpoint | Ý nghĩa | Tham số truyền vào |
|---|---|---|
| `GET /v1/dramas/{drama_id}` | Chi tiết phim, các bộ đếm (`view_count`, `favorite_count`, `watch_later_count`, `like_count`, `share_count`), cờ trạng thái của user (`is_favorited`, `is_in_watch_later`, `is_liked`, `watch_progress`) & 12 phim liên quan (`related`). | **Query:** `lang` (`en`). |
| `GET /v1/dramas/{drama_id}/episodes` | Danh sách tập kèm trạng thái khoá/mở (`is_free_tier`, `is_unlocked`, `is_locked`, `unlock_coin_cost`). | **Query:** `page` (`1`), `page_size` (`100`, tối đa `350`), `lang`. |
| `GET /v1/dramas/{drama_id}/episodes/{ep_num}/play` | Kiểm tra quyền xem & lấy `video_url` + `subtitles[]` (TTL 15 phút). Nếu tập đang khoá trả `code = 402` kèm `unlock_options`. | **Query:** `lang`. |
| `POST /v1/episodes/unlock` | Mở khoá 1 tập (hoặc trọn bộ) bằng Quảng cáo hoặc Xu, trả kèm luôn `video_url` & `subtitles[]`. | **Body:** `drama_id` *(bắt buộc)*, `episode_number` (`int`), `method` (`"ad"` \| `"coins"`), `unlock_full_drama` (`bool`, mặc định `false`). |
| `POST /v1/dramas/{drama_id}/like` | Thả tim / Bỏ thả tim phim (cập nhật `like_count` tức thì). | **Body:** `episode_number` (`0` = toàn bộ phim, hoặc số tập), `action` (`"toggle"` \| `"like"` \| `"unlike"`). Trả về `is_liked`, `like_count`. |
| `POST /v1/dramas/{drama_id}/share` | Ghi nhận lượt chia sẻ phim (cộng `share_count`). | **Body:** `episode_number` (`1`), `channel` (`"copy_link"`, `"facebook"`, `"tiktok"`, `"system_share"`). Trả về `share_count`. |

### 5.6. Yêu Thích (`Favorites`), Xem Sau (`Watch Later`) & Lịch Sử Đã Xem (`History`)
| Method & Endpoint | Ý nghĩa | Tham số truyền vào |
|---|---|---|
| `GET /v1/me/favorites` *(Alias: `/v1/me/my-list`)* | Lấy danh sách phim Yêu thích (mỗi phim có `favorite_meta.favorited_at`). | **Query:** `page` (`1`), `page_size` (`20`), `lang`. |
| `POST /v1/me/favorites` | Yêu thích / Bỏ yêu thích phim (tự cộng/trừ `favorite_count` của phim). | **Body:** `drama_id` *(bắt buộc)*, `action` (`"toggle"` mặc định \| `"add"` \| `"remove"`), `episode_number` (`1`). Trả về `is_favorited`, `favorite_count`. |
| `DELETE /v1/me/favorites` *(hoặc `/v1/me/favorites/{id}`)* | Xoá 1 phim, nhiều phim hoặc xoá sạch danh sách Yêu thích. | **Body:** `drama_ids` (`List<String>`) hoặc `clear_all: true` (hoặc truyền `drama_id` trên Path/Query). |
| `GET /v1/me/watch-later` | Lấy Danh sách Xem sau (tách biệt với Yêu thích, có `watch_later_meta`). | **Query:** `page` (`1`), `page_size` (`20`), `lang`. |
| `POST /v1/me/watch-later` | Thêm / Gỡ phim khỏi Danh sách Xem sau (tự cộng/trừ `watch_later_count`). | **Body:** `drama_id` *(bắt buộc)*, `action` (`"toggle"` \| `"add"` \| `"remove"`), `episode_number` (`1`), `note` *(ghi chú tuỳ chọn)*. Trả về `is_in_watch_later`, `watch_later_count`. |
| `DELETE /v1/me/watch-later` *(hoặc `/v1/me/watch-later/{id}`)* | Xoá 1 phim, nhiều phim hoặc xoá sạch Danh sách Xem sau. | **Body:** `drama_ids` (`List<String>`) hoặc `clear_all: true`. |
| `GET /v1/me/history` | Lấy Lịch sử các phim đã xem mới nhất lên đầu. | **Query:** `page` (`1`), `page_size` (`20`), `lang`. |
| `POST /v1/me/history` | Lưu tiến độ tập & giây đang xem (`>=85%` tự tính hoàn thành tập). | **Body:** `drama_id` *(bắt buộc)*, `episode_number` (`int`), `position_sec` (`int`), `duration_sec` (`int`), `watched_delta_sec` (`int`, số giây vừa xem thêm `0..600`). |
| `DELETE /v1/me/history` | Xoá lẻ hoặc xoá toàn bộ Lịch sử xem. | **Body:** `drama_ids` (`List<String>`) hoặc `clear_all: true`. |

### 5.7. Tài Khoản, Hồ Sơ Cá Nhân, Điểm Danh Nhận Xu & Nạp IAP / VIP
| Method & Endpoint | Ý nghĩa | Tham số truyền vào |
|---|---|---|
| `POST /v1/auth/register` | Tạo tài khoản bằng Email & Mật khẩu (gộp toàn bộ dữ liệu Guest hiện tại vào tài khoản). | **Body:** `email` *(bắt buộc)*, `password` *(bắt buộc, >= 6 ký tự)*, `display_name`, `gender` (`"female"` \| `"male"` \| `"other"`), `birth_year` (`int`). Trả về `access_token`, `session`, `profile`. |
| `POST /v1/auth/login` | Đăng nhập bằng Email & Mật khẩu, tự động hợp nhất Yêu thích, Xem sau, Lịch sử, Mở khoá, VIP & Xu về máy hiện tại. | **Body:** `email` *(bắt buộc)*, `password` *(bắt buộc)*. Trả về `access_token`, `session`, `profile`. |
| `POST /v1/auth/social-login` | Đăng nhập Google / Apple / Facebook kèm hợp nhất dữ liệu đa thiết bị. | **Body:** `provider` (`"google"` \| `"apple"` \| `"facebook"`), `provider_user_id` *(bắt buộc)*, `email`, `display_name`, `avatar_url`. Trả về `access_token`, `session`, `profile`. |
| `POST /v1/auth/logout` | Đăng xuất khỏi thiết bị hiện tại (dữ liệu tài khoản được bảo toàn trên server để đăng nhập lại bất kỳ lúc nào; máy nhận phiên Guest mới). | **Body:** `{}`. Trả về `logged_out: true`, `session`, `profile`. |
| `GET /v1/me/profile` | Lấy thông tin tài khoản (`is_guest`, `email`, `gender`...), ví `wallet` (`coin_balance`, `bonus_coin_balance`, `total_coins`), VIP & `stats` (`favorites_count`, `watch_later_count`, `watched_dramas_count`, `total_watch_minutes`). | Không cần tham số. |
| `PUT /v1/me/profile` | Cập nhật hồ sơ hoặc đổi mật khẩu (chọn `gender` sẽ tối ưu ngay gợi ý phim Nam/Nữ). | **Body:** `display_name`, `avatar_url`, `gender` (`"female"` \| `"male"` \| `"other"`), `birth_year`, `current_password`, `new_password`. |
| `PUT /v1/me/settings` | Lưu cài đặt trình phát & ngôn ngữ App. | **Body:** `app_language`, `subtitle_language`, `auto_play_next` (`bool`), `video_quality`, `wifi_only` (`bool`). |
| `DELETE /v1/me/account` | Xoá vĩnh viễn tài khoản & toàn bộ dữ liệu người dùng (chuẩn duyệt Apple App Store / Google Play). | Không cần tham số. |
| `GET /v1/rewards/overview` | Trạng thái Điểm danh 7 ngày & danh sách Nhiệm vụ nhận Xu (`watch_10m`, `watch_15m`, `watch_20m`, `watch_ad_bonus`...). | **Query:** `lang`. |
| `POST /v1/rewards/check-in` | Nhận Xu điểm danh hàng ngày (hoặc nhận thêm thưởng quảng cáo). | **Body:** `ad_bonus` (`false` = điểm danh chuẩn; `true` = thưởng thêm sau Rewarded Ad). |
| `POST /v1/rewards/tasks/{task_code}/claim` | Nhận Xu khi nhiệm vụ có `can_claim == true`. | **Path:** `task_code`. **Body:** `{}`. |
| `GET /v1/iap/catalog` | Danh sách gói VIP (`subscriptions[]`) & gói Xu (`coin_packages[]`) khớp SKU Store. | **Query:** `lang`. |
| `POST /v1/iap/verify` | Xác thực biên lai mua hàng Google Play / App Store để cộng Xu hoặc kích hoạt VIP. | **Body:** `product_id` *(bắt buộc)*, `purchase_token` *(Android purchaseToken hoặc iOS transactionId/receipt)*. |

---

## 6. Cấu Trúc Thẻ Phim (`DramaCard`) Trả Về Đồng Nhất Ở Mọi API

Mọi danh sách phim (`/v1/home`, `/v1/dramas`, `/v1/dramas/ranking`, `/v1/feed/for-you`, `/v1/search`, `/v1/me/favorites`, `/v1/me/watch-later`, `/v1/me/history`) đều trả chung cấu trúc thẻ phim dưới đây để Flutter tái sử dụng 1 Model duy nhất:

```json
{
  "id": "2040371867346186242",
  "drama_id": "2040371867346186242",
  "title": "A Billionaire's Love: The Missing Child",
  "description": "To save her mother she sacrificed her name...",
  "thumbnail": "https://cdn.dramota.com/thumbnails/2040371867346186242.jpg",
  "language": "en",
  "category": "Billionaire & CEO",
  "category_slug": "billionaire_ceo",
  "categories": [{"slug": "billionaire_ceo", "name": "Billionaire & CEO"}],
  "tags": [{"slug": "mafia", "name": "#Mafia"}, {"slug": "reversal", "name": "#Reversal"}],
  "origin_country": "cn",
  "country_name": "China",
  "country_flag": "🇨🇳",
  "region": "asia",
  "audio_mode": "subtitles",
  "audience": "female",
  "available_sub_langs": ["en", "vi", "es", "id", "th"],
  "total_episodes": 48,
  "ready_episodes": 48,
  "free_episodes": 5,
  "unlock_coin_cost": 20,
  "is_vip_exclusive": false,
  "complete": true,
  "rating": 9.6,
  "popularity": 8500,
  "view_count": 12840,
  "favorite_count": 942,
  "watch_later_count": 315,
  "like_count": 2180,
  "share_count": 164,
  "is_favorited": true,
  "is_in_my_list": true,
  "is_in_watch_later": false,
  "is_liked": true,
  "watch_progress": {
    "episode_number": 4,
    "position_sec": 38,
    "duration_sec": 92,
    "percent_watched": 41.3
  }
}
```
*(Riêng trên `GET /v1/feed/for-you`, mỗi thẻ phim có thêm object `preview: {"episode_number": 1, "video_url": "/v1/stream/....mp4", "subtitles": [...], "watch_full_drama_target_episode": 4}` để phát ngay Tập 1 và điều hướng nút xem trọn bộ tới đúng tập đang xem dở).*
