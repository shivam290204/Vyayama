import 'package:flutter/material.dart';

class FillRangeSpec {
  final int start;
  final int end;
  final Color color;

  const FillRangeSpec({
    required this.start,
    required this.end,
    required this.color,
  });
}

class FillRangesText {
  static int designLengthFrom(List<FillRangeSpec> ranges) {
    if (ranges.isEmpty) return 0;
    return ranges.map((r) => r.end).reduce((a, b) => a > b ? a : b);
  }

  static bool rangesApply(String text, List<FillRangeSpec> ranges) {
    if (ranges.isEmpty) return false;
    final designLength = designLengthFrom(ranges);
    if (text.length != designLength) return false;
    for (final r in ranges) {
      if (r.start < 0 || r.end <= r.start || r.end > text.length) return false;
    }
    return designLength == text.length;
  }

  static Alignment fittedAlignment(TextAlign? textAlign) {
    switch (textAlign) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.end:
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.start:
      case TextAlign.left:
      case TextAlign.justify:
        return Alignment.centerLeft;
      default:
        return Alignment.center;
    }
  }

  static Text richText({
    required String text,
    required List<FillRangeSpec> ranges,
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
    bool? softWrap,
  }) {
    final baseStyle = style ?? const TextStyle();
    final fallback = ranges.isNotEmpty ? ranges.first.color : Colors.black;
    if (!rangesApply(text, ranges)) {
      return Text(
        text,
        style: baseStyle.copyWith(color: fallback),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }
    try {
      return Text.rich(
        TextSpan(
          children: [
            for (final r in ranges)
              TextSpan(
                text: text.substring(r.start, r.end),
                style: baseStyle.copyWith(color: r.color),
              ),
              ],
        ),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    } catch (_) {
      return Text(
        text,
        style: baseStyle.copyWith(color: fallback),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }
  }

  static Widget richTextFitted({
    required String text,
    required List<FillRangeSpec> ranges,
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
    bool? softWrap,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: fittedAlignment(textAlign),
      child: richText(
        text: text,
        ranges: ranges,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      ),
    );
  }
}
