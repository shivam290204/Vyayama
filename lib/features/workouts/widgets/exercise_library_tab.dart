import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/logic/exercise_filter.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_tile.dart';
import 'package:fitbuddy/features/workouts/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Exercises" tab: search, muscle group and equipment filters, and a
/// "safe for my conditions" toggle.
class ExerciseLibraryTab extends ConsumerStatefulWidget {
  const ExerciseLibraryTab({super.key});

  @override
  ConsumerState<ExerciseLibraryTab> createState() => _ExerciseLibraryTabState();
}

class _ExerciseLibraryTabState extends ConsumerState<ExerciseLibraryTab>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  String _query = '';
  String? _muscle;
  String? _equipment;
  bool _safeOnly = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tags = ref.watch(selectedConditionTagsProvider);
    return ref.watch(exerciseLibraryProvider).when(
          loading: () => const WorkoutLoading(),
          error: (e, _) => WorkoutErrorView(
            onRetry: () => ref.invalidate(exerciseLibraryProvider),
          ),
          data: (all) {
            final filtered = filterExercises(
              all,
              query: _query,
              muscleGroup: _muscle,
              equipment: _equipment,
              avoidTags: _safeOnly ? tags.toSet() : const <String>{},
            );
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _header(context, all, tags);
                if (filtered.isEmpty) {
                  return const WorkoutMessageView(
                    icon: Icons.search_off_rounded,
                    title: 'No exercises found',
                    message: 'Try a different search or clear a filter.',
                  );
                }
                return ExerciseTile(exercise: filtered[i - 1], userTags: tags);
              },
            );
          },
        );
  }

  Widget _header(BuildContext context, List<Exercise> all, List<String> tags) {
    final groups = {for (final e in all) e.muscleGroup}.toList()..sort();
    final gear = {for (final e in all) e.equipment}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search exercises',
            border: const OutlineInputBorder(),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        _FilterRow(
          options: groups,
          selected: _muscle,
          onSelected: (v) => setState(() => _muscle = v),
        ),
        _FilterRow(
          options: gear,
          selected: _equipment,
          onSelected: (v) => setState(() => _equipment = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Safe for my conditions'),
          subtitle: Text(
            tags.isEmpty
                ? 'Add conditions in Health to use this filter.'
                : 'Hiding moves that may not suit: '
                    '${tags.map((t) => prettyLabel(t).toLowerCase()).join(', ')}.',
          ),
          value: _safeOnly,
          onChanged: (v) => setState(() => _safeOnly = v),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(prettyLabel(o)),
                selected: selected == o,
                onSelected: (_) => onSelected(selected == o ? null : o),
              ),
            ),
        ],
      ),
    );
  }
}
