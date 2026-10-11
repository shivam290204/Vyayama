import 'package:flutter/material.dart';

typedef DesignFrameDimensionsBuilder = Widget Function(
  BuildContext context,
  double width,
  double height,
);

class _DesignFrameLayout {
  const _DesignFrameLayout({
    required this.w,
    required this.h,
    required this.x,
    required this.y,
  });

  final double w;
  final double h;
  final double x;
  final double y;
}

/// Shared with [AutoSizeText] for ConstraintLayout fixed slots (bias / margin / percent).
DesignFrameLayout computeDesignFrameLayout({
  required double parentWidth,
  required double parentHeight,
  double? width,
  double? height,
  double? minHeight,
  double? widthPercent,
  double? heightPercent,
  double? left,
  double? top,
  bool centerXInParent = false,
  bool centerYInParent = false,
  double? horizontalBias,
  double? verticalBias,
  String? ratioString,
}) {
  final layout = _computeDesignFrameLayout(
    parentWidth: parentWidth,
    parentHeight: parentHeight,
    width: width ?? (widthPercent == null && ratioString == null ? parentWidth : null),
    height: height ?? (heightPercent == null && ratioString == null ? parentHeight : null),
    minHeight: minHeight,
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
  return DesignFrameLayout(w: layout.w, h: layout.h, x: layout.x, y: layout.y);
}

class DesignFrameLayout {
  const DesignFrameLayout({
    required this.w,
    required this.h,
    required this.x,
    required this.y,
  });

  final double w;
  final double h;
  final double x;
  final double y;
}

_DesignFrameLayout _computeDesignFrameLayout({
  required double parentWidth,
  required double parentHeight,
  double? width,
  double? height,
  double? minHeight,
  double? widthPercent,
  double? heightPercent,
  double? left,
  double? top,
  bool centerXInParent = false,
  bool centerYInParent = false,
  double? horizontalBias,
  double? verticalBias,
  String? ratioString,
}) {
  var w = 0.0;
  var h = 0.0;

  if (height != null) {
    h = height;
  } else if (heightPercent != null) {
    h = parentHeight * heightPercent;
  }
  if (width != null) {
    w = width;
  } else if (widthPercent != null) {
    w = parentWidth * widthPercent;
  }

  if (ratioString != null && ratioString.isNotEmpty) {
    final trimmed = ratioString.trim();
    var body = trimmed;
    var isHeightBased = false;
    if (trimmed.length >= 2) {
      final prefix = trimmed.substring(0, 2).toUpperCase();
      if (prefix == 'H,') {
        isHeightBased = true;
        body = trimmed.substring(2);
      } else if (prefix == 'W,') {
        body = trimmed.substring(2);
      }
    }
    final parts = body.split(':').map((e) => double.tryParse(e.trim()) ?? 0.0).toList();
    if (parts.length == 2 && parts[0] > 0 && parts[1] > 0) {
      if (isHeightBased) {
        if (h == 0 && w > 0) {
          h = w * parts[1] / parts[0];
        } else if (w == 0 && h > 0) {
          w = h * parts[1] / parts[0];
        }
      } else {
        final ratioValue = parts[0] / parts[1];
        if (ratioValue > 0) {
          if (h == 0) {
            h = w * ratioValue;
          } else if (w == 0) {
            w = h * ratioValue;
          }
        }
      }
    }
  }

  if (minHeight != null && h < minHeight) {
    h = minHeight;
  }

  var x = 0.0;
  var y = 0.0;
  if (centerXInParent) {
    x = (parentWidth - w) / 2;
  } else if (left != null) {
    x = left;
  } else if (horizontalBias != null) {
    x = (parentWidth - w) * horizontalBias;
  }
  if (centerYInParent) {
    y = (parentHeight - h) / 2;
  } else if (top != null) {
    y = top;
  } else if (verticalBias != null) {
    y = (parentHeight - h) * verticalBias;
  }

  return _DesignFrameLayout(w: w, h: h, x: x, y: y);
}

Widget _designFrameShellWrap({
  Color? color,
  Decoration? decoration,
  required Widget child,
}) {
  if (color != null) {
    return ColoredBox(color: color, child: child);
  }
  if (decoration != null) {
    return Container(decoration: decoration, child: child);
  }
  return child;
}

Widget _designFrameStackOrChild({
  Key? stackKey,
  List<Widget>? stack,
  Widget? child,
}) {
  assert(stack != null || child != null);
  if (stack != null && stack.length > 1) {
    return Stack(
      key: stackKey,
      children: stack,
    );
  }
  if (child != null) {
    return child;
  }
  return stack!.single;
}

/// Place [child] or [stack] using design-frame left/top/width/height (aligned with SwiftUI designFrame).
///
/// Optional [color] / [decoration] replace an outer ColoredBox / Container shell.
/// Multiple layout children use [stack]; a single leaf uses [child].
class DesignFrameWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final double? minHeight;
  final bool wrapContentHeight;
  final double? widthPercent;
  final double? heightPercent;
  final double? left;
  final double? top;
  final bool centerXInParent;
  final bool centerYInParent;
  final double? horizontalBias;
  final double? verticalBias;
  final String? ratioString;
  final Color? color;
  final Decoration? decoration;
  final Key? stackKey;
  final List<Widget>? stack;
  final Widget? child;

  const DesignFrameWidget({
    super.key,
    this.width,
    this.height,
    double? minHeight,
    @Deprecated('Use minHeight instead') double? minHeigth,
    this.wrapContentHeight = false,
    this.widthPercent,
    this.heightPercent,
    this.left,
    this.top,
    this.centerXInParent = false,
    this.centerYInParent = false,
    this.horizontalBias,
    this.verticalBias,
    this.ratioString,
    this.color,
    this.decoration,
    this.stackKey,
    this.stack,
    this.child,
  }) : minHeight = minHeight ?? minHeigth,
       assert(
         !wrapContentHeight || (!centerYInParent && verticalBias == null),
         'wrapContentHeight does not support centerYInParent or verticalBias.',
       ),
       assert(stack != null || child != null);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _computeDesignFrameLayout(
            parentWidth: constraints.maxWidth,
            parentHeight: constraints.maxHeight,
            width: width ?? (widthPercent == null && ratioString == null ? constraints.maxWidth : null),
            height: height ?? (heightPercent == null && ratioString == null ? constraints.maxHeight : null),
            minHeight: minHeight,
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
          Widget core = _designFrameStackOrChild(
            stackKey: stackKey ?? key,
            stack: stack,
            child: child,
          );
          if (wrapContentHeight && minHeight != null) {
            core = ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight!),
              child: core,
            );
          }
          return Stack(
            children: [
              Positioned(
                left: layout.x,
                top: layout.y,
                width: layout.w,
                height: wrapContentHeight ? null : layout.h,
                child: _designFrameShellWrap(
                  color: color,
                  decoration: decoration,
                  child: core,
                ),
              ),
                ],
            );
        },
      ),
    );
  }
}

class ScrollContentStack extends StatelessWidget {
  final double? designHeight;
  final double? designWidth;
  final Axis scrollAxis;
  final List<Widget> children;

  const ScrollContentStack({
    super.key,
    this.designHeight,
    this.designWidth,
    this.scrollAxis = Axis.vertical,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (designWidth ?? MediaQuery.sizeOf(context).width);
        final refH = designHeight ?? designWidth ?? parentW;
        var maxExtent = 0.0;
        final positioned = <Widget>[];

        for (final child in children) {
          if (child is! ScrollContentSlot) {
            throw FlutterError(
              'ScrollContentStack children must be ScrollContentSlot widgets.',
            );
          }
          final layout = child.resolveLayout(parentW, refH);
          if (scrollAxis == Axis.horizontal) {
            maxExtent = maxExtent < layout.x + layout.w
                ? layout.x + layout.w
                : maxExtent;
          } else {
            maxExtent = maxExtent < layout.y + layout.h
                ? layout.y + layout.h
                : maxExtent;
          }
          positioned.add(
            Positioned(
              left: layout.x,
              top: layout.y,
              width: layout.w,
              height: layout.h,
              child: child.buildSlotContent(),
            ),
          );
        }

        if (scrollAxis == Axis.horizontal) {
          final boxH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
              : refH;
          return SizedBox(
            width: maxExtent,
            height: boxH,
            child: Stack(
              clipBehavior: Clip.none,
              children: positioned,
            ),
          );
        }

        return SizedBox(
          width: parentW,
          height: maxExtent,
          child: Stack(
            clipBehavior: Clip.none,
            children: positioned,
          ),
        );
      },
    );
  }
}

class ScrollContentSlot extends StatelessWidget {
  final double? width;
  final double? height;
  final double? minHeight;
  final double? widthPercent;
  final double? heightPercent;
  final double? top;
  final double? left;
  final bool centerXInParent;
  final bool centerYInParent;
  final double? horizontalBias;
  final double? verticalBias;
  final String? ratioString;
  final Color? color;
  final Decoration? decoration;
  final Key? stackKey;
  final List<Widget>? stack;
  final Widget? child;

  const ScrollContentSlot({
    super.key,
    this.width,
    this.height,
    double? minHeight,
    @Deprecated('Use minHeight instead') double? minHeigth,
    this.widthPercent,
    this.heightPercent,
    this.top,
    this.left,
    this.centerXInParent = false,
    this.centerYInParent = false,
    this.horizontalBias,
    this.verticalBias,
    this.ratioString,
    this.color,
    this.decoration,
    this.stackKey,
    this.stack,
    this.child,
  }) : minHeight = minHeight ?? minHeigth,
       assert(stack != null || child != null);

  DesignFrameLayout resolveLayout(double parentWidth, double parentHeight) {
    if (left != null || top != null || centerXInParent || centerYInParent) {
      final w = width ??
          (widthPercent != null ? parentWidth * widthPercent! : parentWidth);
      final hValue = height ??
          (heightPercent != null ? parentHeight * heightPercent! : 0.0);
      final h = minHeight != null && hValue < minHeight! ? minHeight! : hValue;
      final x = centerXInParent
          ? (parentWidth - w) / 2
          : left ??
          (horizontalBias != null ? (parentWidth - w) * horizontalBias! : 0.0);
      final y = centerYInParent
          ? (parentHeight - h) / 2
          : top ??
          (verticalBias != null ? (parentHeight - h) * verticalBias! : 0.0);
      return DesignFrameLayout(
        w: w,
        h: h,
        x: x,
        y: y,
      );
    }
    return computeDesignFrameLayout(
      parentWidth: parentWidth,
      parentHeight: parentHeight,
      width: width,
      height: height,
      minHeight: minHeight,
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
  }

  Widget buildSlotContent() {
    return _designFrameShellWrap(
      color: color,
      decoration: decoration,
      child: _designFrameStackOrChild(
        stackKey: stackKey ?? key,
        stack: stack,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    throw FlutterError(
      'ScrollContentSlot must be a direct child of ScrollContentStack.',
    );
  }
}

/// Same layout algorithm as [DesignFrameWidget], but passes computed `width` and `height` to [builder]
/// for ListView items and other cases that need explicit dimensions.
class DesignFrameBuilder extends StatelessWidget {
  final double? width;
  final double? height;
  final double? minHeight;
  final double? widthPercent;
  final double? heightPercent;
  final double? left;
  final double? top;
  final bool centerXInParent;
  final bool centerYInParent;
  final double? horizontalBias;
  final double? verticalBias;
  final String? ratioString;
  final Color? color;
  final Decoration? decoration;
  final DesignFrameDimensionsBuilder builder;

  const DesignFrameBuilder({
    super.key,
    this.width,
    this.height,
    double? minHeight,
    @Deprecated('Use minHeight instead') double? minHeigth,
    this.widthPercent,
    this.heightPercent,
    this.left,
    this.top,
    this.centerXInParent = false,
    this.centerYInParent = false,
    this.horizontalBias,
    this.verticalBias,
    this.ratioString,
    this.color,
    this.decoration,
    required this.builder,
  }) : minHeight = minHeight ?? minHeigth;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _computeDesignFrameLayout(
            parentWidth: constraints.maxWidth,
            parentHeight: constraints.maxHeight,
            width: width ?? (widthPercent == null && ratioString == null ? constraints.maxWidth : null),
            height: height ?? (heightPercent == null && ratioString == null ? constraints.maxHeight : null),
            minHeight: minHeight,
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
                child: _designFrameShellWrap(
                  color: color,
                  decoration: decoration,
                  child: builder(context, layout.w, layout.h),
                ),
              ),
                ],
            );
        },
      ),
    );
  }
}
