import 'package:flutter/material.dart';

/// Shows the daily streak with a flame icon.
class StreakFlame extends StatelessWidget {
  /// Creates the widget.
  const StreakFlame({
    super.key,
    required this.days,
    required this.longest,
    required this.activeToday,
  });

  /// Current streak in days.
  final int days;

  /// Best streak ever.
  final int longest;

  /// Whether a workout or challenge was already done today.
  final bool activeToday;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = days == 0
        ? 'No streak yet'
        : '$days-day streak';
    final subtitle = days == 0
        ? "Complete today's challenge to start one."
        : activeToday
            ? 'Done for today. Best: $longest ${longest == 1 ? 'day' : 'days'}.'
            : "Complete today's challenge to keep it going. "
                'Best: $longest ${longest == 1 ? 'day' : 'days'}.';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          label: title,
          value: subtitle,
          excludeSemantics: true,
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 56,
                color: days > 0 ? scheme.tertiary : scheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
