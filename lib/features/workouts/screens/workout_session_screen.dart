import 'dart:async';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/services/system_features_service.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/widgets/session_controls.dart';
import 'package:fitbuddy/features/workouts/widgets/session_exercise_view.dart';
import 'package:fitbuddy/features/workouts/widgets/session_rest_view.dart';
import 'package:fitbuddy/features/workouts/widgets/session_summary_view.dart';
import 'package:fitbuddy/features/workouts/widgets/state_views.dart';
import 'package:fitbuddy/features/workouts/widgets/workout_pip_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/workouts/session/:dayId`: full-screen guided workout.
class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key, required this.dayId});

  final String dayId;

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  Timer? _timer;
  bool _started = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<SessionPlan?>>(
      sessionPlanProvider(widget.dayId),
      (previous, next) => next.whenData(_startIfNeeded),
      fireImmediately: true,
    );
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => ref.read(workoutSessionProvider.notifier).tick(),
    );
  }

  Future<void> _startIfNeeded(SessionPlan? plan) async {
    if (_started || plan == null || plan.items.isEmpty) return;
    _started = true;
    final weight = await ref.read(weightKgProvider.future);
    if (!mounted) return;
    ref.read(workoutSessionProvider.notifier).start(
          plan.items,
          planDayId: widget.dayId,
          weightKg: weight,
        );
    setState(() => _ready = true);
    await SystemFeaturesService.instance.setAutoEnterPip(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemFeaturesService.instance.setAutoEnterPip(false);
    super.dispose();
  }

  void _leave() {
    SystemFeaturesService.instance.setAutoEnterPip(false);
    ref.read(workoutSessionProvider.notifier).reset();
    context.go(AppRoutes.workouts);
  }

  Future<void> _confirmExit() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this workout?'),
        content: const Text('You can save what you have done so far.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('keep'),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('quit'),
            child: const Text('Quit without saving'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('finish'),
            child: const Text('Finish & save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'finish') {
      ref.read(workoutSessionProvider.notifier).finishNow();
    } else if (choice == 'quit') {
      _leave();
    }
  }

  Widget _shell(Widget child) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(child: child),
      );

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(sessionPlanProvider(widget.dayId));
    return planAsync.when(
      loading: () => _shell(const WorkoutLoading()),
      error: (e, _) => _shell(
        WorkoutErrorView(
          onRetry: () => ref.invalidate(sessionPlanProvider(widget.dayId)),
        ),
      ),
      data: (plan) {
        if (plan == null) {
          return _shell(
            const WorkoutMessageView(
              icon: Icons.search_off_rounded,
              title: 'Workout not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        if (plan.items.isEmpty) {
          return _shell(
            WorkoutMessageView(
              icon: Icons.healing_outlined,
              title: 'Nothing to do here',
              message: plan.notes.isEmpty
                  ? 'This day has no exercises yet.'
                  : 'Every exercise on this day was removed to suit your '
                      'selected conditions. Please consult your doctor.',
            ),
          );
        }
        return _buildSession(plan);
      },
    );
  }

  Widget _buildSession(SessionPlan plan) {
    final s = ref.watch(workoutSessionProvider);
    if (!_ready || s.items.isEmpty) return _shell(const WorkoutLoading());

    final notifier = ref.read(workoutSessionProvider.notifier);
    final finished = s.isFinished;
    final inPip = ref.watch(pipModeProvider);

    // When the user enters Android Picture-in-Picture mode, render the purpose-built compact view!
    if (inPip && !finished) {
      return WorkoutPipView(
        state: s,
        onTogglePause: notifier.togglePause,
        onNext: notifier.next,
        onDoneSet: notifier.completeSet,
      );
    }

    return PopScope(
      canPop: finished,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: finished ? 'Close' : 'End workout',
            icon: const Icon(Icons.close),
            onPressed: finished ? _leave : _confirmExit,
          ),
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                plan.day.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (!finished)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatClock(s.elapsedSeconds),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            if (!finished) ...[
              IconButton(
                tooltip: 'Picture-in-Picture',
                icon: const Icon(Icons.picture_in_picture_alt_rounded),
                onPressed: () async {
                  final entered = await SystemFeaturesService.instance.enterPip();
                  if (!entered && mounted) {
                    final allowed =
                        await SystemFeaturesService.instance.isPipAllowed();
                    if (!allowed && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'Picture-in-picture is disabled in App Info.'),
                          action: SnackBarAction(
                            label: 'Settings',
                            onPressed:
                                SystemFeaturesService.instance.openPipSettings,
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              TextButton(
                onPressed: notifier.finishNow,
                child: const Text('Finish'),
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(value: finished ? 1 : s.progress),
              Expanded(
                child: switch (s.phase) {
                  SessionPhase.work => SessionExerciseView(
                      state: s,
                      planDayId: widget.dayId,
                      onDoneSet: notifier.completeSet,
                    ),
                  SessionPhase.rest => SessionRestView(
                      state: s,
                      planDayId: widget.dayId,
                      onSkip: notifier.skipRest,
                      onAddTime: notifier.addRestTime,
                    ),
                  SessionPhase.finished => SessionSummaryView(
                      summary: s.summary ?? SessionEngine.summarize(s, 70),
                      onDone: _leave,
                      planDayId: widget.dayId,
                    ),
                },
              ),
              if (!finished)
                SessionControls(
                  paused: s.paused,
                  onPrevious: notifier.previous,
                  onTogglePause: notifier.togglePause,
                  onNext: notifier.next,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
