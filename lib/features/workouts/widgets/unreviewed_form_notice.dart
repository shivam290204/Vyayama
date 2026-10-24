import 'package:flutter/material.dart';

/// A small, calm notice displayed when an exercise has not yet been reviewed
/// by a qualified fitness professional or physiotherapist.
class UnreviewedFormNotice extends StatelessWidget {
  const UnreviewedFormNotice({
    super.key,
    this.compact = false,
  });

  final bool compact;

  static const String noticeText =
      'Form guidance is general and has not yet been reviewed by a fitness professional.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: compact ? 15 : 17,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              noticeText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: compact ? 11 : 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
