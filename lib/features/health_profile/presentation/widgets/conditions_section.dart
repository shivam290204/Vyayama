import 'package:fitbuddy/features/health_profile/data/condition_rule.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/condition_details_card.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/consult_doctor_banner.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Conditions picker with the "consult your doctor" banner.
class ConditionsSection extends ConsumerWidget {
  /// Creates the section.
  const ConditionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final rules = ref.watch(conditionRulesProvider);
    final selected = ref.watch(selectedConditionKeysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Health conditions', style: text.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Pick anything that applies so we can suggest gentler exercise '
          'options. You can change this anytime.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        AsyncValueView<List<ConditionRule>>(
          value: rules,
          onRetry: () => ref.invalidate(conditionRulesProvider),
          builder: (ruleList) => AsyncValueView<List<String>>(
            value: selected,
            onRetry: () => ref.invalidate(selectedConditionKeysProvider),
            builder: (keys) => _ConditionsBody(rules: ruleList, keys: keys),
          ),
        ),
      ],
    );
  }
}

class _ConditionsBody extends ConsumerWidget {
  const _ConditionsBody({required this.rules, required this.keys});

  final List<ConditionRule> rules;
  final List<String> keys;

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    String key,
  ) async {
    try {
      await ref.read(selectedConditionKeysProvider.notifier).toggle(key);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCondition = keys.any((k) => k != 'none');
    final chosen = rules
        .where((r) => keys.contains(r.key) && r.key != 'none')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final rule in rules)
              FilterChip(
                avatar: Icon(_iconFor(rule.key), size: 18),
                label: Text(rule.label),
                tooltip: rule.description,
                selected: keys.contains(rule.key),
                onSelected: (_) => _toggle(context, ref, rule.key),
              ),
          ],
        ),
        if (hasCondition) ...<Widget>[
          const SizedBox(height: 16),
          const ConsultDoctorBanner(),
        ],
        for (final rule in chosen) ...<Widget>[
          const SizedBox(height: 12),
          ConditionDetailsCard(rule: rule),
        ],
      ],
    );
  }
}

IconData _iconFor(String key) => switch (key) {
      'knee_pain' => Icons.directions_walk,
      'back_pain' => Icons.accessibility_new,
      'neck_shoulder_pain' => Icons.self_improvement,
      'diabetes' => Icons.bloodtype_outlined,
      'high_blood_pressure' => Icons.monitor_heart_outlined,
      'asthma' => Icons.air,
      'heart_condition' => Icons.favorite_border,
      'none' => Icons.check_circle_outline,
      _ => Icons.health_and_safety_outlined,
    };
