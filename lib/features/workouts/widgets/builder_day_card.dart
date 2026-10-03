import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:flutter/material.dart';

/// One editable day in the plan builder: name, weekday, drag-to-reorder
/// exercises, add and remove.
class BuilderDayCard extends StatelessWidget {
  const BuilderDayCard({
    super.key,
    required this.day,
    required this.exercisesById,
    required this.selectableWeekdays,
    required this.onRename,
    required this.onWeekday,
    required this.onDelete,
    required this.onAddExercise,
    required this.onReorder,
    required this.onEditExercise,
    required this.onRemoveExercise,
  });

  final PlanDay day;
  final Map<String, Exercise> exercisesById;
  final List<int> selectableWeekdays;
  final ValueChanged<String> onRename;
  final ValueChanged<int> onWeekday;
  final VoidCallback onDelete;
  final VoidCallback onAddExercise;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<PlanExercise> onEditExercise;
  final ValueChanged<PlanExercise> onRemoveExercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('name_${day.id}'),
                    initialValue: day.name,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      labelText: 'Day name',
                      counterText: '',
                    ),
                    onChanged: onRename,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete day',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
            PopupMenuButton<int>(
              tooltip: 'Change weekday',
              onSelected: onWeekday,
              itemBuilder: (context) => [
                for (final n in selectableWeekdays)
                  PopupMenuItem<int>(value: n, child: Text(weekdayName(n))),
              ],
              child: SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.calendar_today, size: 18),
                    label: Text(weekdayName(day.dayNumber)),
                  ),
                ),
              ),
            ),
            if (day.exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No exercises yet.', style: theme.textTheme.bodyMedium),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: day.exercises.length,
                onReorderItem: onReorder,
                itemBuilder: (context, i) {
                  final pe = day.exercises[i];
                  return ListTile(
                    key: ValueKey(pe.id),
                    contentPadding: EdgeInsets.zero,
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.drag_handle,
                            semanticLabel: 'Drag to reorder'),
                      ),
                    ),
                    title: Text(exercisesById[pe.exerciseId]?.name ?? 'Exercise'),
                    subtitle: Text(
                        '${prescriptionLabel(pe)} · rest ${pe.restSec} s'),
                    trailing: IconButton(
                      tooltip: 'Remove exercise',
                      icon: const Icon(Icons.close),
                      onPressed: () => onRemoveExercise(pe),
                    ),
                    onTap: () => onEditExercise(pe),
                  );
                },
              ),
            TextButton.icon(
              onPressed: onAddExercise,
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
          ],
        ),
      ),
    );
  }
}
