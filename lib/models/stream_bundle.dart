import 'play_response.dart';

/// Cached video stream + subtitle bundle with local safety-buffered expiration.
class StreamBundle {
  static const int defaultTtlSec = 7200;
  static const int defaultForYouTtlSec = 14400;
  static const int safetyBufferSec = 120;
  static const int minBufferedTtlSec = 180;

  final String videoUrl;
  final List<SubtitleTrack> subtitles;
  final int expiresInSec;
  final int? expiresAt;
  final DateTime expireAt;

  const StreamBundle({
    required this.videoUrl,
    required this.subtitles,
    required this.expiresInSec,
    this.expiresAt,
    required this.expireAt,
  });

  bool get isExpired => DateTime.now().isAfter(expireAt);

  /// Parses `expires_in_sec` (with legacy `stream_expires_in` fallback).
  static int parseTtlSec(
    Map<String, dynamic> json, {
    int defaultTtlSec = StreamBundle.defaultTtlSec,
  }) {
    final raw = json['expires_in_sec'] ?? json['stream_expires_in'];
    if (raw == null) return defaultTtlSec;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? defaultTtlSec;
  }

  /// Parses optional Unix timestamp `expires_at` (UTC seconds).
  static int? parseExpiresAtUnix(Map<String, dynamic> json) {
    final raw = json['expires_at'];
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }

  /// Computes local expiration deadline with a 120s safety buffer for TTL > 180s.
  static DateTime computeSafeExpireAt(int ttlSec, {DateTime? now}) {
    final safeSeconds = ttlSec > minBufferedTtlSec
        ? ttlSec - safetyBufferSec
        : (ttlSec < 0 ? 0 : ttlSec);
    return (now ?? DateTime.now()).add(Duration(seconds: safeSeconds));
  }

  factory StreamBundle.fromJson(
    Map<String, dynamic> json, {
    int defaultTtlSec = StreamBundle.defaultTtlSec,
    String Function(String)? resolveUrl,
    DateTime? now,
  }) {
    final ttl = parseTtlSec(json, defaultTtlSec: defaultTtlSec);
    final rawVideoUrl = json['video_url']?.toString() ?? '';
    final resolvedVideoUrl =
        resolveUrl != null ? resolveUrl(rawVideoUrl) : rawVideoUrl;

    final rawSubs = (json['subtitles'] as List<dynamic>?)
            ?.whereType<Map<dynamic, dynamic>>()
            .map((e) {
              final track = SubtitleTrack.fromJson(
                Map<String, dynamic>.from(e),
              );
              if (resolveUrl == null) return track;
              return SubtitleTrack(
                language: track.language,
                label: track.label,
                format: track.format,
                isDefault: track.isDefault,
                url: resolveUrl(track.url),
              );
            })
            .toList() ??
        const <SubtitleTrack>[];

    return StreamBundle(
      videoUrl: resolvedVideoUrl,
      subtitles: rawSubs,
      expiresInSec: ttl,
      expiresAt: parseExpiresAtUnix(json),
      expireAt: computeSafeExpireAt(ttl, now: now),
    );
  }
}
