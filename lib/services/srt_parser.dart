import 'package:dio/dio.dart';

import '../core/di/injection.dart';
import '../core/startup/app_startup_coordinator.dart';
import '../models/drama_models.dart';

class SrtParser {
  static final RegExp _timeRegExp = RegExp(
    r'(?:(\d{1,2}):)?(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(?:(\d{1,2}):)?(\d{2}):(\d{2})[,.](\d{3})',
  );

  static final Map<String, List<SubtitleCue>> _urlCache = {};

  /// Plain Dio without X-Sign headers for public CDN/stream WebVTT/SRT URLs.
  static final Dio _mediaDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.plain,
    ),
  );

  /// Loads and parses a remote `.vtt` or `.srt` subtitle URL.
  static Future<List<SubtitleCue>> loadSubtitleUrl(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return const [];

    final coordinator = getIt.isRegistered<AppStartupCoordinator>()
        ? getIt<AppStartupCoordinator>()
        : null;
    final resolved = coordinator != null
        ? coordinator.resolveMediaUrl(trimmed)
        : (trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://api.dramota.com${trimmed.startsWith('/') ? trimmed : '/$trimmed'}');

    final cached = _urlCache[resolved];
    if (cached != null) return cached;

    final resp = await _mediaDio.get<String>(resolved);
    final body = resp.data ?? '';
    final cues = parse(body);
    if (cues.isNotEmpty) {
      _urlCache[resolved] = cues;
    }
    return cues;
  }

  /// Parses both `.srt` and `.vtt` (WebVTT) subtitle content.
  static List<SubtitleCue> parse(String srtContent) {
    final cues = <SubtitleCue>[];
    final normalized = srtContent
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final trimmedBlock = block.trim();
      if (trimmedBlock.isEmpty) continue;
      if (trimmedBlock.startsWith('WEBVTT') ||
          trimmedBlock.startsWith('NOTE') ||
          trimmedBlock.startsWith('STYLE') ||
          trimmedBlock.startsWith('REGION')) {
        continue;
      }

      final lines = trimmedBlock
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 2) continue;

      int timeLineIdx = -1;
      RegExpMatch? match;
      for (int i = 0; i < lines.length; i++) {
        final m = _timeRegExp.firstMatch(lines[i]);
        if (m != null) {
          timeLineIdx = i;
          match = m;
          break;
        }
      }

      if (timeLineIdx == -1 ||
          match == null ||
          timeLineIdx + 1 >= lines.length) {
        continue;
      }

      final start = _parseDuration(
        match.group(1) ?? '0',
        match.group(2)!,
        match.group(3)!,
        match.group(4)!,
      );
      final end = _parseDuration(
        match.group(5) ?? '0',
        match.group(6)!,
        match.group(7)!,
        match.group(8)!,
      );

      final textLines = lines
          .sublist(timeLineIdx + 1)
          .map((l) => l.replaceAll(RegExp(r'<[^>]*>'), '').trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (textLines.isNotEmpty) {
        cues.add(
          SubtitleCue(
            start: start,
            end: end,
            text: textLines.join('\n'),
          ),
        );
      }
    }
    return cues;
  }

  static Duration _parseDuration(String h, String m, String s, String ms) {
    return Duration(
      hours: int.parse(h),
      minutes: int.parse(m),
      seconds: int.parse(s),
      milliseconds: int.parse(ms),
    );
  }

  static String? findActiveText(List<SubtitleCue> cues, Duration position) {
    if (cues.isEmpty) return null;
    int low = 0;
    int high = cues.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final cue = cues[mid];
      if (position < cue.start) {
        high = mid - 1;
      } else if (position > cue.end) {
        low = mid + 1;
      } else {
        return cue.text;
      }
    }
    return null;
  }
}
