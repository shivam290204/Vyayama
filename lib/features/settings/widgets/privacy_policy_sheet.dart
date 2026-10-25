import 'package:flutter/material.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';

/// In-app Privacy Policy modal sheet presenting full data practices and rights.
class PrivacyPolicySheet extends StatelessWidget {
  const PrivacyPolicySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const PrivacyPolicySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Privacy Policy',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'Last Updated: October 23, 2026',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _section(
                  theme,
                  '1. What We Collect',
                  '• Profile: Name, email address, username, avatar.\n'
                  '• Fitness & Health: Daily step counts, active calories, workout logs, height, weight, BMI history, and optional user-entered health tags.\n'
                  '• Snaps: Camera workout verification photos. Location metadata is stripped prior to upload.\n'
                  '• Reminders: Local alarm schedules and notification settings.',
                ),
                _section(
                  theme,
                  '2. How Your Data is Used',
                  '• Adapting workout plans to your level and physical cautions.\n'
                  '• Tracking step and calorie trends over time.\n'
                  '• Verifying exercise photos via privacy-conscious server vision.\n'
                  '• Triggering exact wake-up and bedtime alarms on your device.\n'
                  'We NEVER sell, rent, or trade your data to third-party advertisers.',
                ),
                _section(
                  theme,
                  '3. Storage, Retention & Third-Party AI',
                  '• Auth tokens and sensitive credentials are encrypted using hardware-backed Android KeyStore / iOS Keychain.\n'
                  '• Cloud data is protected by Supabase Row Level Security (RLS) so only you can access your private records.\n'
                  '• Snaps are automatically deleted from Vyayama within 24 hours.\n'
                  '• AI vision models (e.g. Anthropic API) process photos solely for real-time exercise verification, are never trained on your images, and may retain API requests for up to 30 days solely for safety and abuse prevention before deletion.',
                ),
                _section(
                  theme,
                  '4. Community Standards & Moderation',
                  '• Photos must comply with Community Standards (no nudity, violence, weapons, hate speech, or harassment).\n'
                  '• You can report objectionable content or block users directly from any snap or profile.\n'
                  '• Reports are reviewed by human moderators in accordance with community standards. Blocking immediately sequesters the user from contacting you.',
                ),
                _section(
                  theme,
                  '5. Your Rights & Account Deletion',
                  '• You can permanently delete your account and all associated personal and health data at any time under Settings → Account → Delete Account.\n'
                  '• Deletion permanently removes all database rows, workout logs, and uploaded files from our servers.',
                ),
                _section(
                  theme,
                  '6. Contact & Inquiries',
                  'For questions about our data practices or to request external account deletion, reach out to privacy@vyayama.app.',
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
