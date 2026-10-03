import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_repository.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:fitbuddy/features/snaps/utils/time_format.dart';
import 'package:fitbuddy/features/snaps/widgets/snap_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/snaps/view/:id`: view a snap, react with an emoji or a preset reply.
class SnapViewScreen extends ConsumerStatefulWidget {
  const SnapViewScreen({super.key, required this.snapId});

  final String snapId;

  @override
  ConsumerState<SnapViewScreen> createState() => _SnapViewScreenState();
}

class _SnapViewScreenState extends ConsumerState<SnapViewScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(snapRepositoryProvider).markViewed(widget.snapId);
      if (mounted) ref.invalidate(inboxProvider);
    });
  }

  Future<void> _react(String reaction) async {
    await ref.read(snapRepositoryProvider).react(widget.snapId, reaction);
    ref
      ..invalidate(receivedSnapProvider(widget.snapId))
      ..invalidate(inboxProvider);
  }

  Future<void> _report() async {
    const reasons = [
      'Inappropriate content',
      'Not exercise related',
      'Bullying or harassment',
      'Something else',
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Report this snap'),
        children: [
          for (final r in reasons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(r),
              ),
            ),
        ],
      ),
    );
    if (reason == null) return;
    await ref.read(snapRepositoryProvider).reportSnap(widget.snapId, reason);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for letting us know.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(receivedSnapProvider(widget.snapId));
    return Scaffold(
      appBar: AppBar(
        title: Text(value.valueOrNull?.senderName ?? 'Snap'),
        actions: [
          IconButton(
            tooltip: 'Report snap',
            icon: const Icon(Icons.flag_outlined),
            onPressed: value.valueOrNull == null ? null : _report,
          ),
        ],
      ),
      body: AsyncBody<ReceivedSnap?>(
        value: value,
        onRetry: () => ref.invalidate(receivedSnapProvider(widget.snapId)),
        isEmpty: (d) => d == null,
        emptyIcon: Icons.timer_off_outlined,
        emptyTitle: 'This snap has expired',
        emptyMessage: 'Snaps disappear after 24 hours.',
        emptyActionLabel: 'Back to inbox',
        onEmptyAction: () => context.go(AppRoutes.snapsInbox),
        data: (item) => _Body(item: item!, onReact: _react),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item, required this.onReact});

  final ReceivedSnap item;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)().toUtc();
    final caption = item.snap.caption;
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              SnapImage(snap: item.snap),
              if (caption != null && caption.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(caption, style: text.bodyLarge),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(expiresIn(item.snap.expiresAt, now),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final e in kSnapReactions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  button: true,
                  selected: item.reaction == e,
                  label: 'React with $e',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => onReact(e),
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.reaction == e ? scheme.primaryContainer : null,
                      ),
                      child: ExcludeSemantics(child: Text(e, style: text.headlineSmall)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final r in kSnapPresetReplies)
                  ChoiceChip(
                    label: Text(r),
                    selected: item.reaction == r,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => onReact(r),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
