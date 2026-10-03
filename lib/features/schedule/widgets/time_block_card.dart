import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/widgets/block_type_ui.dart';
import 'package:flutter/material.dart';

/// A card for one schedule block, reused by Home and the Schedule screen.
///
/// Shows the type icon, title, time and a status (upcoming, done, missed).
/// Status is conveyed by icon and text as well as colour.
class TimeBlockCard extends StatelessWidget {
  /// Creates the card. Provide [onToggleDone] to show the done button.
  const TimeBlockCard({
    super.key,
    required this.block,
    required this.status,
    this.onTap,
    this.onToggleDone,
    this.compact = false,
  });

  /// The block to show.
  final TimeBlock block;

  /// Its status today.
  final BlockStatus status;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Called when the done/undo button is pressed. Null hides the button.
  final VoidCallback? onToggleDone;

  /// Tighter vertical padding for lists on Home.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final time = TimeOfDay(
      hour: block.startMinutes ~/ 60,
      minute: block.startMinutes % 60,
    ).format(context);
    final isDone = status == BlockStatus.done;

    Color? background;
    var foreground = scheme.onSurface;
    if (isDone) {
      background = scheme.primaryContainer;
      foreground = scheme.onPrimaryContainer;
    } else if (status == BlockStatus.missed) {
      background = scheme.surfaceContainerHigh;
      foreground = scheme.onSurfaceVariant;
    }

    final shape = Theme.of(context).cardTheme.shape as RoundedRectangleBorder? ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final borderShape = status == BlockStatus.missed
        ? shape.copyWith(side: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 1))
        : shape;

    return Card(
      color: background,
      margin: EdgeInsets.zero,
      shape: borderShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: compact ? 4 : 8,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(
                    block.type.icon,
                    color: scheme.onSecondaryContainer,
                    semanticLabel: block.type.label,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        block.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          color: foreground,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(status.icon, size: 16, color: foreground),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '$time · ${status.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onToggleDone != null)
                  IconButton(
                    tooltip: isDone ? 'Undo done' : 'Mark done',
                    color: foreground,
                    icon: Icon(
                      isDone ? Icons.undo : Icons.check_circle_outline,
                      semanticLabel: isDone ? 'Undo done' : 'Mark done',
                    ),
                    onPressed: onToggleDone,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
