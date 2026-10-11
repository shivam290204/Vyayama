import 'package:flutter/widgets.dart';

const double kMaxContentWidth = 600;

double rvSpacingFromDesignDp(BuildContext context, double designDp) {
  if (designDp == 0) return 0;
  final d = MediaQuery.of(context).devicePixelRatio;
  final px = (designDp * d).truncate();
  return px / d;
}

double rvSpacingFromScreenWidthPercent(BuildContext context, double percentOfScreenWidth) {
  if (percentOfScreenWidth <= 0) return 0;
  final mq = MediaQuery.of(context);
  final d = mq.devicePixelRatio;
  final wPx = (mq.size.width * d).truncate();
  final px = (wPx * percentOfScreenWidth / 100.0).truncate();
  return px / d;
}

/// Horizontal list item outer symmetric padding (same as EdgeInsets.symmetric(horizontal: rvSpacingFromScreenWidthPercent(...))).
EdgeInsets hInsetsFromWidthPct(BuildContext context, double percentOfScreenWidth) {
  return EdgeInsets.symmetric(
    horizontal: rvSpacingFromScreenWidthPercent(context, percentOfScreenWidth),
  );
}

/// Symmetric horizontal padding from design dp (half main-axis spacing).
EdgeInsets horizontalInsetsFromDesignDp(BuildContext context, double halfDesignDp) {
  return EdgeInsets.symmetric(
    horizontal: rvSpacingFromDesignDp(context, halfDesignDp),
  );
}
