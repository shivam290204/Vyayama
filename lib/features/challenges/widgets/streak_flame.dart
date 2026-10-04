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
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.2 : 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          label: title,
          value: subtitle,
          excludeSemantics: true,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: days > 0 ? scheme.tertiary.withValues(alpha: 0.2) : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department,
                  size: 40,
                  color: days > 0 ? scheme.tertiary : scheme.outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle, 
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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
