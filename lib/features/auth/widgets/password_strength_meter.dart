import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/auth/auth_validators.dart';

/// Strength bar plus a text hint (never relies on colour alone).
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strength = AuthValidators.strength(password);

    if (strength == PasswordStrength.empty) {
      return Text(
        'Use 8+ characters with letters, numbers and a symbol.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final (label, value, color) = switch (strength) {
      PasswordStrength.weak => ('Weak', 0.33, scheme.error),
      PasswordStrength.fair => ('Fair', 0.66, scheme.tertiary),
      _ => ('Strong', 1.0, scheme.primary),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Password strength: $label',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
