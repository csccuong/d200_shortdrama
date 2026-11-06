import '../models/drama_models.dart';

class SrtParser {
  static final RegExp _timeRegExp = RegExp(
    r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})',
  );

  static List<SubtitleCue> parse(String srtContent) {
    final cues = <SubtitleCue>[];
    final normalized =
        srtContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block
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
        match.group(1)!,
        match.group(2)!,
        match.group(3)!,
        match.group(4)!,
      );
      final end = _parseDuration(
        match.group(5)!,
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
