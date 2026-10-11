import 'package:flutter/widgets.dart';

MediaQueryData _platformMediaQuery(BuildContext context) {
  return MediaQueryData.fromView(View.of(context));
}

/// Full logical screen height (aligns with iOS UIScreen.main.bounds.height).
double _fullLogicalScreenHeight(BuildContext context) {
  final view = View.of(context);
  final dpr = _platformMediaQuery(context).devicePixelRatio;
  return view.physicalSize.height / dpr;
}

/// Full logical screen width (aligns with iOS UIScreen.main.bounds.width).
double _fullLogicalScreenWidth(BuildContext context) {
  final view = View.of(context);
  final dpr = _platformMediaQuery(context).devicePixelRatio;
  return view.physicalSize.width / dpr;
}

/// Device-level insets (unaffected by ancestor SafeArea); aligns with Swift UIWindow.safeAreaInsets / Compose LocalConfiguration.
double screenHeightExcludingStatusBarAndHomeIndicator(BuildContext context) {
  final platformMq = _platformMediaQuery(context);
  return _fullLogicalScreenHeight(context) -
      platformMq.viewPadding.top -
      platformMq.viewPadding.bottom;
}

double screenWidthExcludingSafeAreaInsets(BuildContext context) {
  final platformMq = _platformMediaQuery(context);
  return _fullLogicalScreenWidth(context) -
      platformMq.viewPadding.left -
      platformMq.viewPadding.right;
}

class DesignScale {
  const DesignScale({
    required this.designWidth,
    required this.designHeight,
    required this.screenWidth,
    required this.screenHeight,
    required this.devicePixelRatio,
    required this.contentWidth,
    required this.isLetterboxed,
  });

  static const double largeScreenSmallestWidth = 600;
  static const double defaultWideWidthFactor = 1.2;
  static const bool defaultFillDeviceWidth = false;

  final double designWidth;
  final double designHeight;
  final double screenWidth;
  final double screenHeight;
  final double devicePixelRatio;
  final double contentWidth;
  final bool isLetterboxed;

  /// Nested stack; N.wdp / N.hdp read stack.last (aligns with iOS DesignScale / Compose with(scale)).
  static final List<DesignScale> _stack = <DesignScale>[];
  static DesignScale? _active;
  static DesignScale? get current => _stack.isEmpty ? _active : _stack.last;

  double get _scaleW => screenWidth / designWidth;
  double get _scaleH => screenHeight / designHeight;

  factory DesignScale.of(
    BuildContext context, {
        required double width,
        required double height,
  }) {
    final platformMq = _platformMediaQuery(context);
    final dpr = platformMq.devicePixelRatio;
    final availableWidthPx = screenWidthExcludingSafeAreaInsets(context) * dpr;
    final availableHeightPx = screenHeightExcludingStatusBarAndHomeIndicator(context) * dpr;
    final fullW = _fullLogicalScreenWidth(context);
    final fullH = _fullLogicalScreenHeight(context);
    final smallestScreenWidth = fullW < fullH ? fullW : fullH;
    final phoneDevice = smallestScreenWidth < largeScreenSmallestWidth;
    final fillWidth = phoneDevice || defaultFillDeviceWidth;
    final wideFactor = phoneDevice ? 1.0 : defaultWideWidthFactor;
    final rawScaleW = availableWidthPx / width;
    final rawScaleH = availableHeightPx / height;
    double targetWidthPx = availableWidthPx;
    var letterboxed = false;
    if (rawScaleW > rawScaleH) {
      final phoneContentWidthPx = width * rawScaleH;
      targetWidthPx = fillWidth
          ? availableWidthPx
          : (availableWidthPx < phoneContentWidthPx * wideFactor
              ? availableWidthPx
              : phoneContentWidthPx * wideFactor);
      letterboxed = !fillWidth;
    }
    return DesignScale(
      designWidth: width,
      designHeight: height,
      screenWidth: targetWidthPx,
      screenHeight: availableHeightPx,
      devicePixelRatio: dpr,
      contentWidth: targetWidthPx / dpr,
      isLetterboxed: letterboxed,
    );
  }

  static DesignScale push(
    BuildContext context, {
        required double width,
        required double height,
  }) {
    final value = DesignScale.of(context, width: width, height: height);
    _active = value;
    _stack.add(value);
    return value;
  }

  static DesignScale? pop() {
    if (_stack.isEmpty) return null;
    final removed = _stack.removeLast();
    _active = _stack.isEmpty ? removed : _stack.last;
    return removed;
  }

  /// Push for the duration of [body], then pop (nesting-safe; re-enter in ListenableBuilder etc.).
  static T using<T>(
    BuildContext context, {
        required double width,
        required double height,
        required T Function() body,
  }) {
    push(context, width: width, height: height);
    try {
      return body();
    } finally {
      pop();
    }
  }

  /// Legacy API: replace the whole stack with one value. Prefer [using].
  static DesignScale activate(
    BuildContext context, {
        required double width,
        required double height,
  }) {
    final value = DesignScale.of(context, width: width, height: height);
    _stack
      ..clear()
      ..add(value);
    _active = value;
    return value;
  }

  static double hdp(num designPx) {
    final scale = current;
    if (scale == null) return designPx.toDouble();
    return designPx.toDouble() * scale._scaleH / scale.devicePixelRatio;
  }

  static double wdp(num designPx) {
    final scale = current;
    if (scale == null) return designPx.toDouble();
    return designPx.toDouble() * scale._scaleW / scale.devicePixelRatio;
  }

  static double hsp(num designPx) => hdp(designPx);
  static double wsp(num designPx) => wdp(designPx);
}

extension DesignScaleNum on num {
  double get hdp => DesignScale.hdp(this);
  double get wdp => DesignScale.wdp(this);
  double get hsp => DesignScale.hsp(this);
  double get wsp => DesignScale.wsp(this);
}
