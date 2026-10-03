import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:flutter/material.dart';

/// Seven-day strip showing which weekdays have a workout.
class WeeklyStrip extends StatelessWidget {
  const WeeklyStrip({super.key, required this.plan, this.today});

  final WorkoutPlan plan;

  /// Weekday to mark as today (defaults to now).
  final int? today;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final todayNumber = today ?? DateTime.now().weekday;
    return Row(
      children: [
        for (var n = 1; n <= 7; n++)
          Expanded(
            child: Builder(builder: (context) {
              final hasWorkout = plan.dayForWeekday(n) != null;
              final isToday = n == todayNumber;
              return Semantics(
                container: true,
                label: '${weekdayName(n)}: '
                    '${hasWorkout ? 'workout' : 'rest day'}'
                    '${isToday ? ', today' : ''}',
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasWorkout
                              ? cs.primary
                              : cs.surfaceContainerHighest,
                          border: isToday
                              ? Border.all(color: cs.tertiary, width: 2)
                              : null,
                        ),
                        child: Text(
                          weekdayInitial(n),
                          style: textTheme.labelLarge?.copyWith(
                            color: hasWorkout
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(weekdayShort(n), style: textTheme.labelSmall),
                    ],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}
