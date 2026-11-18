import 'package:flutter/material.dart';

/// Displays [text] clamped to [maxLines] with an inline [moreSuffix]
/// (e.g. `... Thêm`) guaranteed to remain visible without being ellipsized.
class InlineMoreText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextStyle actionStyle;
  final String moreSuffix;
  final int maxLines;
  final VoidCallback? onTap;

  const InlineMoreText({
    super.key,
    required this.text,
    required this.style,
    required this.actionStyle,
    required this.moreSuffix,
    this.maxLines = 2,
    this.onTap,
  });

  static int _safeCutIndex(String source, int index) {
    var safe = index.clamp(0, source.length);
    if (safe > 0 && safe < source.length) {
      final prevUnit = source.codeUnitAt(safe - 1);
      // Avoid splitting a UTF-16 surrogate pair.
      if (prevUnit >= 0xD800 && prevUnit <= 0xDBFF) {
        safe--;
      }
    }
    return safe;
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          return Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }

        final fullPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: maxLines,
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout(maxWidth: maxW);

        if (!fullPainter.didExceedMaxLines) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Text(text, style: style),
          );
        }

        var lo = 0;
        var hi = text.length;
        var best = 0;
        while (lo <= hi) {
          final mid = (lo + hi) >> 1;
          final safeMid = _safeCutIndex(text, mid);
          final candidate = text.substring(0, safeMid).trimRight();
          final testPainter = TextPainter(
            text: TextSpan(
              children: [
                TextSpan(text: candidate, style: style),
                TextSpan(text: moreSuffix, style: actionStyle),
              ],
            ),
            maxLines: maxLines,
            textDirection: textDirection,
            textScaler: textScaler,
          )..layout(maxWidth: maxW);

          if (!testPainter.didExceedMaxLines) {
            best = safeMid;
            lo = mid + 1;
          } else {
            hi = mid - 1;
          }
        }

        final clipped = text.substring(0, best).trimRight();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: clipped, style: style),
                TextSpan(text: moreSuffix, style: actionStyle),
              ],
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
