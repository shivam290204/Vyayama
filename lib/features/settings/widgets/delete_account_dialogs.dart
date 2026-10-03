import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';

/// Two-step confirmation for account deletion.
/// Returns true only if the user confirmed both steps.
Future<bool> confirmDeleteAccount(BuildContext context) async {
  final understood = await showDialog<bool>(
    context: context,
    builder: (context) => const _ExplainDialog(),
  );
  if (understood != true || !context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => const _TypeToConfirmDialog(),
  );
  return confirmed == true;
}

class _ExplainDialog extends StatelessWidget {
  const _ExplainDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      icon: const Icon(Icons.warning_amber_rounded),
      title: const Text('Delete your account?'),
      content: const Text(
        'This permanently deletes your profile, workouts, stats, friends, '
        'streaks and snaps. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog();

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  static const String _word = 'DELETE';
  final TextEditingController _controller = TextEditingController();

  bool get _matches => _controller.text.trim().toUpperCase() == _word;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      title: const Text('Type DELETE to confirm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This is your last chance to change your mind.'),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Type DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep my account'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete my account'),
        ),
      ],
    );
  }
}
