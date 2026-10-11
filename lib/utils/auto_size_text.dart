import 'package:flutter/widgets.dart';

import 'design_frame_widget.dart';

const TextHeightBehavior _kAutoSizeTextHeightBehavior = TextHeightBehavior(
  applyHeightToFirstAscent: true,
  applyHeightToLastDescent: true,
);

const double _kLayoutHeightFudge = 0.1;

bool _layoutFits({
  required String text,
  required double fontSize,
  required TextStyle base,
  required BoxConstraints constraints,
  required TextDirection direction,
  required TextAlign align,
  required int? maxLines,
  required StrutStyle? strutStyle,
  required TextScaler textScaler,
  required bool softWrap,
  required TextWidthBasis textWidthBasis,
  required TextHeightBehavior textHeightBehavior,
  Locale? locale,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: base.copyWith(fontSize: fontSize, letterSpacing: 0, height: 1.2),
    ),
    textAlign: align,
    textDirection: direction,
    maxLines: maxLines,
    strutStyle: strutStyle,
    textScaler: textScaler,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    locale: locale,
  );
  final minW = constraints.minWidth;
  final maxW = constraints.maxWidth;
  if (softWrap) {
    painter.layout(minWidth: minW, maxWidth: maxW);
  } else {
    painter.layout(minWidth: 0, maxWidth: maxW);
    if (maxW.isFinite && painter.size.width - maxW > _kLayoutHeightFudge) {
      return false;
    }
  }
  if (painter.didExceedMaxLines) return false;
  if (constraints.hasBoundedHeight) {
    if (painter.height > constraints.maxHeight - _kLayoutHeightFudge) {
      return false;
    }
  }
  return true;
}

const double _kAutoSizeStepGranularity = 1.0;

class AutoSizeText extends StatelessWidget {
  const AutoSizeText({
    super.key,
    required this.text,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.maxLines,
    this.semanticsLabel,
    required this.fontSize,
    this.maxWidth,
    this.maxHeight,
    this.alignment,
    this.width,
    this.height,
    this.widthPercent,
    this.heightPercent,
    this.left,
    this.top,
    this.centerXInParent = false,
    this.centerYInParent = false,
    this.horizontalBias,
    this.verticalBias,
    this.ratioString,
  });

  final String text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool softWrap;
  final TextOverflow overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final double fontSize;
  final double? maxWidth;
  final double? maxHeight;
  final AlignmentGeometry? alignment;
  /// ConstraintLayout slot (same semantics as [DesignFrameWidget]).
  final double? width;
  final double? height;
  final double? widthPercent;
  final double? heightPercent;
  final double? left;
  final double? top;
  final bool centerXInParent;
  final bool centerYInParent;
  final double? horizontalBias;
  final double? verticalBias;
  final String? ratioString;

  bool get _hasClSlot =>
      width != null ||
      height != null ||
      widthPercent != null ||
      heightPercent != null ||
      left != null ||
      top != null ||
      centerXInParent ||
      centerYInParent ||
      horizontalBias != null ||
      verticalBias != null ||
      (ratioString != null && ratioString!.isNotEmpty);

  Widget _buildCore(BuildContext context, {double? slotW, double? slotH}) {
    final dir = textDirection ?? Directionality.of(context);
    final align = textAlign ?? TextAlign.start;
    final base = style ?? const TextStyle();
    final resolvedLocale = locale ?? Localizations.maybeLocaleOf(context);
    final resolvedMaxW = slotW ?? maxWidth;
    final resolvedMaxH = slotH ?? maxHeight;

    final core = LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final defText = DefaultTextStyle.of(context);
        final thb = defText.textHeightBehavior ?? _kAutoSizeTextHeightBehavior;
        final twb = defText.textWidthBasis;
        final maxFontSize = fontSize;
        final double scaleFactor = scaler.scale(1.0);
        final double minFontSize = scaleFactor > 1.0
            ? (maxFontSize * 0.5 / scaleFactor).clamp(1.0, maxFontSize * 0.5)
            : maxFontSize * 0.5;
        final maxWb = resolvedMaxW ?? constraints.maxWidth;
        final maxHb = resolvedMaxH ?? constraints.maxHeight;
        final fitConstraints = BoxConstraints(
          minWidth: constraints.minWidth,
          maxWidth: maxWb,
          minHeight: constraints.minHeight,
          maxHeight: maxHb,
        );

        var current = maxFontSize;
        while (true) {
          if (_layoutFits(
            text: text,
            fontSize: current,
            base: base,
            constraints: fitConstraints,
            direction: dir,
            align: align,
            maxLines: maxLines,
            strutStyle: strutStyle,
            textScaler: scaler,
            softWrap: softWrap,
            textWidthBasis: twb,
            textHeightBehavior: thb,
            locale: resolvedLocale,
          )) {
            break;
          }
          if (current <= minFontSize) {
            current = minFontSize;
            break;
          }
          final next = current - _kAutoSizeStepGranularity;
          current = next < minFontSize ? minFontSize : next;
        }

        return Text(
          text,
          textWidthBasis: twb,
          textHeightBehavior: thb,
          style: base.copyWith(fontSize: current, letterSpacing: 0, height: 1.2),
          strutStyle: strutStyle,
          textAlign: align,
          textDirection: dir,
          locale: resolvedLocale,
          softWrap: softWrap,
          overflow: overflow,
          maxLines: maxLines,
          semanticsLabel: semanticsLabel,
          textScaler: scaler,
        );
      },
    );
    final resolvedAlignment = alignment;
    if (resolvedAlignment == null || resolvedAlignment == Alignment.topLeft) {
      return core;
    }
    return Align(alignment: resolvedAlignment, child: core);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasClSlot) {
      return _buildCore(context);
    }
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = computeDesignFrameLayout(
            parentWidth: constraints.maxWidth,
            parentHeight: constraints.maxHeight,
            width: width,
            height: height,
            widthPercent: widthPercent,
            heightPercent: heightPercent,
            left: left,
            top: top,
            centerXInParent: centerXInParent,
            centerYInParent: centerYInParent,
            horizontalBias: horizontalBias,
            verticalBias: verticalBias,
            ratioString: ratioString,
          );
          return Stack(
            children: [
              Positioned(
                left: layout.x,
                top: layout.y,
                width: layout.w,
                height: layout.h,
                child: _buildCore(context, slotW: layout.w, slotH: layout.h),
              ),
                ],
            );
        },
      ),
    );
  }
}
