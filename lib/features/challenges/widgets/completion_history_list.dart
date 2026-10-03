import 'package:fitbuddy/features/challenges/challenges_state.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/material.dart';

/// List of previously completed daily challenges.
class CompletionHistoryList extends StatelessWidget {
  /// Creates the list, showing at most [limit] entries.
  const CompletionHistoryList({
    super.key,
    required this.entries,
    this.limit = 20,
  });

  /// Completions, newest first.
  final List<CompletionEntry> entries;

  /// Maximum entries to show.
  final int limit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          "No completions yet. Finish today's challenge to start your history.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      children: [
        for (final e in entries.take(limit))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.check_circle,
              color: scheme.primary,
              semanticLabel: 'Completed',
            ),
            title: Text(e.challenge?.title ?? 'Daily challenge'),
            subtitle: Text(formatLongDate(e.completion.date)),
            trailing: e.challenge == null
                ? null
                : Text(
                    '+${e.challenge!.xp} XP',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
          ),
      ],
    );
  }
}
