import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:fitbuddy/features/snaps/utils/time_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/snaps/inbox`: snaps received from friends.
class SnapInboxScreen extends ConsumerWidget {
  const SnapInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(inboxProvider);
    final now = ref.watch(clockProvider)().toUtc();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Snap inbox')),
      body: AsyncBody<List<ReceivedSnap>>(
        value: value,
        onRetry: () => ref.invalidate(inboxProvider),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.mark_email_unread_outlined,
        emptyTitle: 'No snaps yet',
        emptyMessage: 'When a friend sends you an exercise snap, it shows up here.',
        emptyActionLabel: 'Open camera',
        onEmptyAction: () => context.push(AppRoutes.snapsCamera),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(inboxProvider);
            await ref.read(inboxProvider.future);
          },
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = list[i];
              final unviewed = item.isUnviewed;
              return ListTile(
                minVerticalPadding: 12,
                leading: Semantics(
                  label: item.snap.activityType.label,
                  child: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(item.snap.activityType.icon,
                        color: scheme.onPrimaryContainer),
                  ),
                ),
                title: Text(
                  '${item.senderName} shared a ${item.snap.activityType.label.toLowerCase()} snap',
                  style: unviewed
                      ? const TextStyle(fontWeight: FontWeight.w700)
                      : null,
                ),
                subtitle: Text(
                    '${timeAgo(item.snap.createdAt, now)} · ${expiresIn(item.snap.expiresAt, now)}'),
                trailing: unviewed
                    ? Semantics(
                        label: 'New',
                        child: Icon(Icons.circle, size: 12, color: scheme.primary),
                      )
                    : (item.reaction != null ? Text(item.reaction!) : null),
                onTap: () => context.push(AppRoutes.snapViewPath(item.snap.id)),
              );
            },
          ),
        ),
      ),
    );
  }
}
