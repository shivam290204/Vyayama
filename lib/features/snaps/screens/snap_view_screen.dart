import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/providers.dart';
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

  Future<void> _report(ReceivedSnap item) async {
    final result = await showDialog<_ReportDialogResult>(
      context: context,
      builder: (ctx) => _ReportDialog(senderName: item.senderName),
    );
    if (result == null) return;

    await ref.read(snapRepositoryProvider).reportSnap(widget.snapId, result.reason);

    if (result.blockUser) {
      await ref.read(friendRepositoryProvider).blockUser(item.snap.senderId);
      invalidateFriendData(ref);
      ref.invalidate(inboxProvider);
      ref.invalidate(feedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report submitted. ${item.senderName} has been blocked.')),
        );
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          router.go(AppRoutes.snapsInbox);
        } else {
          Navigator.maybePop(context);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for letting us know. Our moderation team will review this photo.'),
          ),
        );
      }
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
            onPressed: value.valueOrNull == null ? null : () => _report(value.valueOrNull!),
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

class _ReportDialogResult {
  const _ReportDialogResult({required this.reason, required this.blockUser});
  final String reason;
  final bool blockUser;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.senderName});
  final String senderName;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  static const _reasons = [
    'Inappropriate or adult content',
    'Violence or dangerous activity',
    'Bullying or harassment',
    'Not exercise related',
    'Spam or misleading',
    'Something else',
  ];

  String? _selectedReason;
  bool _blockUser = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report this snap'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a reason for this report:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            for (final r in _reasons)
              ListTile(
                title: Text(r),
                leading: Icon(
                  _selectedReason == r
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _selectedReason == r
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onTap: () => setState(() => _selectedReason = r),
              ),
            const Divider(height: 24),
            CheckboxListTile(
              title: Text('Also block ${widget.senderName}'),
              subtitle: const Text("They won't be able to send you snaps or view your profile."),
              value: _blockUser,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) => setState(() => _blockUser = val ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedReason == null
              ? null
              : () => Navigator.pop(
                    context,
                    _ReportDialogResult(
                      reason: _selectedReason!,
                      blockUser: _blockUser,
                    ),
                  ),
          child: const Text('Submit Report'),
        ),
      ],
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
