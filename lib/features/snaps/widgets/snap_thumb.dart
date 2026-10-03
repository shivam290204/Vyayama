import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/utils/time_format.dart';
import 'package:fitbuddy/features/snaps/widgets/snap_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tappable square thumbnail used by the Friends Feed.
class SnapThumb extends ConsumerWidget {
  const SnapThumb({super.key, required this.item, this.size = 120});

  final ReceivedSnap item;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final now = ref.watch(clockProvider)().toUtc();
    return Semantics(
      button: true,
      label:
          '${item.snap.activityType.label} snap from ${item.senderName}, ${timeAgo(item.snap.createdAt, now)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.snapViewPath(item.snap.id)),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: item.isUnviewed
                ? Border.all(color: scheme.primary, width: 3)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: ExcludeSemantics(child: SnapImage(snap: item.snap)),
        ),
      ),
    );
  }
}
