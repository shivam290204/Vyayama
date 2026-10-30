import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/intelligence/domain/models/user_fitness_preferences.dart';
import 'package:fitbuddy/features/intelligence/providers.dart';

/// Screen allowing the user to configure available equipment, daily time, and preferred workout time.
class FitnessPreferencesScreen extends ConsumerStatefulWidget {
  const FitnessPreferencesScreen({super.key});

  @override
  ConsumerState<FitnessPreferencesScreen> createState() =>
      _FitnessPreferencesScreenState();
}

class _FitnessPreferencesScreenState
    extends ConsumerState<FitnessPreferencesScreen> {
  List<String>? _selectedEquipment;
  int? _selectedDuration;
  String? _selectedTime;
  bool _saving = false;

  void _initFromPreferences(UserFitnessPreferences prefs) {
    _selectedEquipment ??= List<String>.from(prefs.availableEquipment);
    _selectedDuration ??= prefs.dailyWorkoutMinutes;
    _selectedTime ??= prefs.preferredWorkoutTime;
  }

  Future<void> _save(UserFitnessPreferences currentPrefs) async {
    setState(() => _saving = true);
    final eq = (_selectedEquipment != null && _selectedEquipment!.isNotEmpty)
        ? _selectedEquipment!
        : ['none'];

    final updated = currentPrefs.copyWith(
      availableEquipment: eq,
      dailyWorkoutMinutes: _selectedDuration ?? 30,
      preferredWorkoutTime: _selectedTime ?? 'flexible',
      updatedAt: DateTime.now(),
    );

    await ref.read(userFitnessPreferencesProvider.notifier).save(updated);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fitness preferences updated successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final prefsAsync = ref.watch(userFitnessPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Preferences'),
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Unable to load preferences: $e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(userFitnessPreferencesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (prefs) {
          _initFromPreferences(prefs);
          final currentEq = _selectedEquipment ?? prefs.availableEquipment;
          final currentDuration = _selectedDuration ?? prefs.dailyWorkoutMinutes;
          final currentTime = _selectedTime ?? prefs.preferredWorkoutTime;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Customize Your Training Journey',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vyayama adapts workout recommendations to fit the gear you have, '
                'your schedule, and your lifestyle.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 1. Available Equipment Section
              _SectionTitle(
                icon: Icons.fitness_center_rounded,
                title: 'Available Equipment',
                subtitle: 'Select all gear you have access to:',
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final eq in WorkoutEquipment.values)
                    FilterChip(
                      selected: currentEq.contains(eq.id),
                      label: Text(eq.label),
                      onSelected: (selected) {
                        setState(() {
                          final list = List<String>.from(currentEq);
                          if (selected) {
                            if (!list.contains(eq.id)) list.add(eq.id);
                          } else {
                            list.remove(eq.id);
                            if (list.isEmpty) list.add('none');
                          }
                          _selectedEquipment = list;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // 2. Daily Workout Duration
              _SectionTitle(
                icon: Icons.schedule_rounded,
                title: 'Daily Workout Time Available',
                subtitle: 'How long do you want your training sessions to be?',
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opt in WorkoutDurationOption.values)
                    ChoiceChip(
                      selected: currentDuration == opt.minutes,
                      label: Text(opt.label),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedDuration = opt.minutes);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // 3. Preferred Workout Time
              _SectionTitle(
                icon: Icons.wb_sunny_outlined,
                title: 'Preferred Workout Time',
                subtitle: 'When during the day do you prefer working out?',
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in PreferredWorkoutTime.values)
                    ChoiceChip(
                      selected: currentTime == t.id,
                      label: Text(t.label),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedTime = t.id);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Save Action Button
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(prefs),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_saving ? 'Saving...' : 'Save Preferences'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

