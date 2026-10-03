import 'package:fitbuddy/features/challenges/level_logic.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';

/// Level number, XP bar and XP needed for the next level.
class XpLevelBar extends StatelessWidget {
  /// Creates the bar.
  const XpLevelBar({super.key, required this.level, required this.totalXp});

  /// Level and progress.
  final LevelInfo level;

  /// Total XP earned.
  final int totalXp;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          label: 'Level ${level.level}',
          value: '${level.xpIntoLevel} of ${level.xpForLevel} XP in this '
              'level, $totalXp XP total',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Level ${level.level}', style: text.titleLarge),
                  ),
                  Text('${formatInt(totalXp)} XP', style: text.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: level.progress,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${level.xpToNext} XP to level ${level.level + 1}',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
