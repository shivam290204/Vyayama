import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:flutter/material.dart';

/// Bottom sheet to edit sets, reps or duration, and rest for one exercise.
/// Pops with the updated [PlanExercise].
class PrescriptionSheet extends StatefulWidget {
  const PrescriptionSheet({
    super.key,
    required this.exerciseName,
    required this.initial,
  });

  final String exerciseName;
  final PlanExercise initial;

  @override
  State<PrescriptionSheet> createState() => _PrescriptionSheetState();
}

class _PrescriptionSheetState extends State<PrescriptionSheet> {
  late int _sets;
  late int _reps;
  late int _duration;
  late int _rest;
  late bool _timed;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _sets = p.setCount;
    _timed = p.isTimed;
    _reps = p.reps ?? 10;
    _duration = p.durationSec ?? 30;
    _rest = p.restSec;
  }

  void _apply() {
    Navigator.of(context).pop(
      widget.initial.copyWith(
        sets: _sets,
        reps: _timed ? null : _reps,
        durationSec: _timed ? _duration : null,
        clearReps: _timed,
        clearDuration: !_timed,
        restSec: _rest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.exerciseName, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _StepperRow(
            label: 'Sets',
            value: _sets,
            min: 1,
            max: 10,
            onChanged: (v) => setState(() => _sets = v),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Reps')),
              ButtonSegment(value: true, label: Text('Timed')),
            ],
            selected: {_timed},
            onSelectionChanged: (s) => setState(() => _timed = s.first),
          ),
          const SizedBox(height: 8),
          if (_timed)
            _StepperRow(
              label: 'Duration',
              value: _duration,
              min: 5,
              max: 3600,
              step: 5,
              suffix: ' s',
              onChanged: (v) => setState(() => _duration = v),
            )
          else
            _StepperRow(
              label: 'Reps',
              value: _reps,
              min: 1,
              max: 100,
              onChanged: (v) => setState(() => _reps = v),
            ),
          _StepperRow(
            label: 'Rest',
            value: _rest,
            min: 0,
            max: 300,
            step: 15,
            suffix: ' s',
            onChanged: (v) => setState(() => _rest = v),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _apply, child: const Text('Apply')),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.suffix = '',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
        IconButton(
          tooltip: 'Decrease $label',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChanged(value - step < min ? min : value - step) : null,
        ),
        SizedBox(
          width: 72,
          child: Text('$value$suffix',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          tooltip: 'Increase $label',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + step > max ? max : value + step) : null,
        ),
      ],
    );
  }
}
