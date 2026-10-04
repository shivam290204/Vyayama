import 'package:fitbuddy/features/challenges/badge_catalog.dart';
import 'package:flutter/material.dart';

IconData _iconFor(String id) {
  if (id.startsWith('streak_')) return Icons.local_fire_department;
  if (id.startsWith('challenges_')) return Icons.emoji_events;
  if (id.startsWith('level_')) return Icons.military_tech;
  return Icons.flag;
}

/// Grid of all badges. Earned ones are coloured, the rest show a lock.
/// Tap a badge to see how to earn it.
class BadgeGrid extends StatelessWidget {
  /// Creates the grid. [earned] holds the ids of earned badges.
  const BadgeGrid({super.key, required this.earned});

  /// Ids of earned badges.
  final Set<String> earned;

  @override
  Widget build(BuildContext context) {
    final badges = BadgeCatalog.all;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 112,
        mainAxisExtent: 124,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: badges.length,
      itemBuilder: (context, i) => _BadgeTile(
        badge: badges[i],
        isEarned: earned.contains(badges[i].id),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.isEarned});

  final ChallengeBadge badge;
  final bool isEarned;

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(isEarned ? _iconFor(badge.id) : Icons.lock_outline),
        title: Text(badge.title),
        content: Text(
          '${badge.description}\n\n${isEarned ? 'Earned!' : 'Not earned yet.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: '${badge.title}, ${isEarned ? 'earned' : 'locked'}. '
          '${badge.description}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _showDetails(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEarned 
                  ? scheme.primary.withValues(alpha: 0.2) 
                  : scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.8),
                border: Border.all(
                  color: isEarned
                      ? scheme.primary.withValues(alpha: 0.5)
                      : scheme.outline.withValues(alpha: isDark ? 0.2 : 0.5),
                  width: isEarned ? 2 : 1,
                ),
                boxShadow: isEarned ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ] : [],
              ),
              child: Icon(
                isEarned ? _iconFor(badge.id) : Icons.lock_outline,
                color: isEarned
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(
                fontWeight: isEarned ? FontWeight.bold : FontWeight.normal,
                color: isEarned ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
