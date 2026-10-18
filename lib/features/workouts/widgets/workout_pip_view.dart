import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:flutter/material.dart';

/// Compact, ultra-clean UI shown when the app is shrunk into
/// Android Picture-in-Picture mode during a workout session.
class WorkoutPipView extends StatelessWidget {
  const WorkoutPipView({
    super.key,
    required this.state,
    required this.onTogglePause,
    required this.onNext,
    required this.onDoneSet,
  });

  final SessionState state;
  final VoidCallback onTogglePause;
  final VoidCallback onNext;
  final VoidCallback onDoneSet;

  @override
  Widget build(BuildContext context) {
    final item = state.items.isNotEmpty && state.index < state.items.length
        ? state.current
        : null;
    final isRest = state.phase == SessionPhase.rest;
    final isFinished = state.isFinished;

    final title = isFinished
        ? 'Workout Complete!'
        : isRest
            ? 'Resting'
            : (item?.exercise.name ?? 'Exercise');

    final subtitle = isFinished
        ? 'Great job!'
        : isRest
            ? 'Next: ${state.nextIndex < state.items.length ? state.items[state.nextIndex].exercise.name : "Finish"}'
            : 'Set ${state.setIndex + 1} of ${item?.sets ?? 1}';

    final timerOrReps = isFinished
        ? formatClock(state.elapsedSeconds)
        : isRest
            ? formatClock(state.secondsLeft)
            : (item?.timed == true
                ? formatClock(state.secondsLeft)
                : '${item?.prescription.reps ?? 10} reps');

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101216),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF101216),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top status bar with indicator and elapsed time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isRest
                            ? const Color(0xFF2196F3).withValues(alpha: 0.25)
                            : isFinished
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
                                : AppPalette.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRest
                                ? Icons.snooze_rounded
                                : isFinished
                                    ? Icons.check_circle_rounded
                                    : Icons.fitness_center_rounded,
                            size: 11,
                            color: isRest
                                ? const Color(0xFF64B5F6)
                                : isFinished
                                    ? const Color(0xFF81C784)
                                    : AppPalette.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isFinished
                                ? 'DONE'
                                : isRest
                                    ? 'REST'
                                    : 'WORKOUT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isRest
                                  ? const Color(0xFF64B5F6)
                                  : isFinished
                                      ? const Color(0xFF81C784)
                                      : AppPalette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatClock(state.elapsedSeconds),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Center main info: Exercise & Giant Counter
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timerOrReps,
                        style: TextStyle(
                          color: isRest
                              ? const Color(0xFF64B5F6)
                              : AppPalette.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Bottom Controls & Progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: isFinished ? 1.0 : state.progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFinished ? const Color(0xFF4CAF50) : AppPalette.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (!isFinished)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: onTogglePause,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            state.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: isRest ? onNext : onDoneSet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppPalette.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isRest ? 'Skip' : 'Done',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
