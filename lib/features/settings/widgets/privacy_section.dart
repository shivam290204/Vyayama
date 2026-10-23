import 'package:fitbuddy/features/settings/widgets/privacy_policy_sheet.dart';
import 'package:flutter/material.dart';

import 'package:fitbuddy/core/constants/disclaimer.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/settings/widgets/settings_section.dart';

/// Plain-language privacy summary.
class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});

  static const List<(IconData, String)> _points = [
    (
      Icons.lock_outline_rounded,
      'Your health, weight and medicine details are sensitive. We only collect what the app needs.',
    ),
    (
      Icons.visibility_off_outlined,
      'Snaps are private to your accepted friends and are deleted after 24 hours.',
    ),
    (
      Icons.location_off_outlined,
      'Photo location and camera details are removed before upload.',
    ),
    (
      Icons.delete_outline_rounded,
      'You can delete your account and all of your data at any time below.',
    ),
    (
      Icons.shield_outlined,
      'We never sell or rent your personal, workout or health information to third parties.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SettingsSection(
      title: 'Privacy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final point in _points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(point.$1, size: 22, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(point.$2, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => PrivacyPolicySheet.show(context),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Read Full Privacy Policy'),
          ),
        ],
      ),
    );
  }
}

/// The medical disclaimer from spec Section 12.
class DisclaimerSection extends StatelessWidget {
  const DisclaimerSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Medical disclaimer',
      child: Text(
        kMedicalDisclaimer,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
