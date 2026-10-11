import 'package:flutter/material.dart';

String appImage(BuildContext context, String lightPath, String darkPath) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? darkPath : lightPath;
}

String itemBoundString(dynamic item, String value) {
  if (item == null) return '';
  return value;
}

Widget itemModelImage(
  BuildContext context,
  String src, {
      Key? key,
      BoxFit fit = BoxFit.contain,
      double? width,
      double? height,
      BorderRadius? borderRadius,
      String? placeholderLightPath,
      String? placeholderDarkPath,
}) {
  final trimmed = src.trim();
  final placeholderPath = placeholderLightPath == null
      ? ''
      : (placeholderDarkPath != null && placeholderDarkPath.trim().isNotEmpty
          ? appImage(context, placeholderLightPath, placeholderDarkPath)
          : placeholderLightPath);
  Widget placeholderWidget() {
    final candidate = placeholderPath.trim();
    if (candidate.isNotEmpty) {
      return Image.asset(
        candidate,
        key: key,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) =>
            ColoredBox(color: Colors.grey.shade300),
        );
    }
    return ColoredBox(color: Colors.grey.shade300);
  }
  Widget result;
  if (trimmed.isEmpty) {
    result = placeholderWidget();
  } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    result = Image.network(
      trimmed,
      key: key,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) =>
          placeholderWidget(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholderWidget();
      },
    );
  } else {
    result = Image.asset(
      trimmed,
      key: key,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) =>
          ColoredBox(color: Colors.grey.shade300),
    );
  }

  final effectiveRadius = borderRadius ?? BorderRadius.circular(16);
  return ClipRRect(borderRadius: effectiveRadius, child: result);
}
