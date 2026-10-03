import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/plan_editing.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/widgets/builder_day_card.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_picker_sheet.dart';
import 'package:fitbuddy/features/workouts/widgets/prescription_sheet.dart';
import 'package:fitbuddy/features/workouts/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/workouts/builder`: create, edit and delete a custom plan.
/// Pass `?planId=...` to edit an existing custom plan.
class PlanBuilderScreen extends ConsumerStatefulWidget {
  const PlanBuilderScreen({super.key, this.planId});

  final String? planId;

  @override
  ConsumerState<PlanBuilderScreen> createState() => _PlanBuilderScreenState();
}

class _PlanBuilderScreenState extends ConsumerState<PlanBuilderScreen> {
  final _titleController = TextEditingController();
  WorkoutPlan? _plan;
  bool _dirty = false;
  bool _saving = false;

  bool get _isEditing => widget.planId != null;

  @override
  void initState() {
    super.initState();
    if (widget.planId == null) _plan = WorkoutPlan.draft();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _edit(WorkoutPlan Function(WorkoutPlan p) change) {
    setState(() {
      _plan = change(_plan!);
      _dirty = true;
    });
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _addExercise(
    String dayId,
    List<Exercise> library,
    List<String> tags,
  ) async {
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          ExercisePickerSheet(exercises: library, userTags: tags),
    );
    if (picked != null && mounted) _edit((p) => p.addExercise(dayId, picked));
  }

  Future<void> _editExercise(
    String dayId,
    PlanExercise pe,
    String name,
  ) async {
    final updated = await showModalBottomSheet<PlanExercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => PrescriptionSheet(exerciseName: name, initial: pe),
    );
    if (updated != null && mounted) {
      _edit((p) => p.updateExercise(dayId, updated));
    }
  }

  Future<void> _save() async {
    final plan = _plan!;
    final error = plan.validationError;
    if (error != null) {
      _snack(error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(myPlansProvider.notifier)
          .save(plan.copyWith(title: plan.title.trim()));
      if (!mounted) return;
      _dirty = false;
      _snack('Plan saved');
      context.go(AppRoutes.workouts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save the plan. Please try again.');
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits to this plan have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _dirty = false;
      context.go(AppRoutes.workouts);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(myPlansProvider.notifier).delete(widget.planId!);
    if (!mounted) return;
    _dirty = false;
    context.go(AppRoutes.workouts);
  }

  Widget _shell(Widget child) => Scaffold(
        appBar: AppBar(title: const Text('Plan builder')),
        body: child,
      );

  @override
  Widget build(BuildContext context) {
    if (_plan == null) {
      final loaded = ref.watch(planByIdProvider(widget.planId!));
      return loaded.when(
        loading: () => _shell(const WorkoutLoading()),
        error: (e, _) => _shell(
          WorkoutErrorView(
            onRetry: () => ref.invalidate(planByIdProvider(widget.planId!)),
          ),
        ),
        data: (p) {
          if (p == null || p.isSystem) {
            return _shell(
              const WorkoutMessageView(
                icon: Icons.lock_outline,
                title: 'This plan cannot be edited',
                message: 'Only your own custom plans can be edited.',
              ),
            );
          }
          _plan = p;
          _titleController.text = p.title;
          return _editor(context);
        },
      );
    }
    return _editor(context);
  }

  Widget _editor(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan!;
    final library = ref.watch(exerciseLibraryProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const <Exercise>[],
        );
    final byId = {for (final e in library) e.id: e};
    final tags = ref.watch(selectedConditionTagsProvider);
    final used = plan.days.map((d) => d.dayNumber).toSet();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit plan' : 'New plan'),
          actions: [
            if (_isEditing)
              IconButton(
                tooltip: 'Delete plan',
                icon: const Icon(Icons.delete_outline),
                onPressed: _confirmDelete,
              ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextField(
              controller: _titleController,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Plan name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _edit((p) => p.copyWith(title: v)),
            ),
            const SizedBox(height: 8),
            Text('Goal', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'lose', label: Text('Lose')),
                  ButtonSegment(value: 'gain', label: Text('Gain')),
                  ButtonSegment(value: 'maintain', label: Text('Maintain')),
                ],
                selected: {plan.goal ?? 'maintain'},
                onSelectionChanged: (s) =>
                    _edit((p) => p.copyWith(goal: s.first)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Level', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'beginner', label: Text('Beginner')),
                  ButtonSegment(
                      value: 'intermediate', label: Text('Intermediate')),
                ],
                selected: {plan.level ?? 'beginner'},
                onSelectionChanged: (s) =>
                    _edit((p) => p.copyWith(level: s.first)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Workout days', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (plan.days.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Add your first workout day to get started.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            for (final d in plan.days)
              BuilderDayCard(
                key: ValueKey(d.id),
                day: d,
                exercisesById: byId,
                selectableWeekdays: [
                  for (var n = 1; n <= 7; n++)
                    if (n == d.dayNumber || !used.contains(n)) n,
                ],
                onRename: (v) => _edit((p) => p.renameDay(d.id, v)),
                onWeekday: (n) => _edit((p) => p.setDayNumber(d.id, n)),
                onDelete: () => _edit((p) => p.removeDay(d.id)),
                onAddExercise: () => _addExercise(d.id, library, tags),
                onReorder: (o, n) => _edit((p) => p.reorderExercise(d.id, o, n)),
                onEditExercise: (pe) => _editExercise(
                  d.id,
                  pe,
                  byId[pe.exerciseId]?.name ?? 'Exercise',
                ),
                onRemoveExercise: (pe) =>
                    _edit((p) => p.removeExercise(d.id, pe.id)),
              ),
            if (plan.days.length < kMaxPlanDays)
              OutlinedButton.icon(
                onPressed: () => _edit((p) => p.addDay()),
                icon: const Icon(Icons.add),
                label: const Text('Add day'),
              ),
            const SizedBox(height: 16),
            Text(
              'General wellness information, not medical advice. Check with a '
              'doctor before starting a new exercise program.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
