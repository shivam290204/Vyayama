import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/logic/exercise_filter.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:flutter/material.dart';

/// Searchable exercise list shown in a bottom sheet. Pops with the chosen
/// [Exercise].
class ExercisePickerSheet extends StatefulWidget {
  const ExercisePickerSheet({
    super.key,
    required this.exercises,
    this.userTags = const <String>[],
  });

  final List<Exercise> exercises;
  final List<String> userTags;

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  String _query = '';
  bool _safeOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final results = filterExercises(
      widget.exercises,
      query: _query,
      avoidTags: _safeOnly ? widget.userTags.toSet() : const <String>{},
    );
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search exercises',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SwitchListTile(
              title: const Text('Safe for my conditions'),
              value: _safeOnly,
              onChanged: (v) => setState(() => _safeOnly = v),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text('No exercises found',
                          style: theme.textTheme.bodyMedium),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final e = results[i];
                        return ListTile(
                          title: Text(e.name),
                          subtitle: Text(
                            '${prettyLabel(e.muscleGroup)} · ${prettyLabel(e.equipment)}',
                          ),
                          trailing: const Icon(Icons.add_circle_outline,
                              semanticLabel: 'Add exercise'),
                          onTap: () => Navigator.of(context).pop(e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
