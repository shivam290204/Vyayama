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
    final rules = ref.watch(conditionRulesProvider);
    final selected = ref.watch(selectedConditionKeysProvider);

    return AsyncValueView<List<ConditionRule>>(
      value: rules,
      onRetry: () => ref.invalidate(conditionRulesProvider),
      builder: (ruleList) => AsyncValueView<List<String>>(
        value: selected,
        onRetry: () => ref.invalidate(selectedConditionKeysProvider),
        builder: (keys) => _ConditionsBody(rules: ruleList, keys: keys),
      ),
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
    final scheme = Theme.of(context).colorScheme;
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
              _AnimatedChip(
                rule: rule,
                selected: keys.contains(rule.key),
                onToggle: () => _toggle(context, ref, rule.key),
                scheme: scheme,
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

/// A condition chip with animated selection state, gradient when selected.
class _AnimatedChip extends StatelessWidget {
  const _AnimatedChip({
    required this.rule,
    required this.selected,
    required this.onToggle,
    required this.scheme,
  });

  final ConditionRule rule;
  final bool selected;
  final VoidCallback onToggle;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 1.0, end: selected ? 1.05 : 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: FilterChip(
        avatar: Icon(
          _iconFor(rule.key),
          size: 18,
          color: selected ? scheme.onPrimary : scheme.primary,
        ),
        label: Text(
          rule.label,
          style: TextStyle(
            color: selected ? scheme.onPrimary : null,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        tooltip: rule.description,
        selected: selected,
        selectedColor: scheme.primary,
        checkmarkColor: scheme.onPrimary,
        onSelected: (_) => onToggle(),
        backgroundColor: scheme.surface.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? scheme.primary
                : scheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
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
