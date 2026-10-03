import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows a snap image through a signed URL. Mock URLs render a placeholder.
class SnapImage extends ConsumerWidget {
  const SnapImage({super.key, required this.snap, this.fit = BoxFit.cover});

  final Snap snap;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final url = ref.watch(signedUrlProvider(snap.imagePath));
    final label = '${snap.activityType.label} photo';
    Widget placeholder(Widget child) => ColoredBox(
          color: scheme.primaryContainer,
          child: Center(child: child),
        );
    return Semantics(
      image: true,
      label: label,
      child: url.when(
        loading: () => placeholder(const CircularProgressIndicator()),
        error: (_, __) => placeholder(
            Icon(Icons.broken_image_outlined, color: scheme.onPrimaryContainer)),
        data: (u) {
          if (u.startsWith('mock://')) {
            return placeholder(Icon(snap.activityType.icon,
                size: 64, color: scheme.onPrimaryContainer));
          }
          return Image.network(
            u,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (c, child, p) =>
                p == null ? child : placeholder(const CircularProgressIndicator()),
            errorBuilder: (c, e, s) => placeholder(
                Icon(Icons.broken_image_outlined, color: scheme.onPrimaryContainer)),
          );
        },
      ),
    );
  }
}
