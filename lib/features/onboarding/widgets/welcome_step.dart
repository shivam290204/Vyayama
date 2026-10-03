import 'package:flutter/material.dart';

import 'package:fitbuddy/core/constants/disclaimer.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/auth/widgets/brand_mark.dart';
import 'package:fitbuddy/features/onboarding/widgets/step_scaffold.dart';

/// Welcome page with the medical disclaimer.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return StepScaffold(
      title: 'Welcome to Vyayama',
      subtitle: "A few quick questions so your buddy can cheer for the right things.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandMark(size: 96)),
          const SizedBox(height: AppSpacing.xl),
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: scheme.onSecondaryContainer,
                    semanticLabel: 'Important',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      kMedicalDisclaimer,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
