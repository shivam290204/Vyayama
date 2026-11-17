import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/services/system_features_service.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/settings/providers.dart';
import 'package:fitbuddy/features/settings/widgets/settings_section.dart';

/// Quote/meme times and per-category notification switches.
class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  Future<TimeOfDay?> _pick(BuildContext context, TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);
    final theme = Theme.of(context);

    return SettingsSection(
      title: 'Notifications',
      subtitle: 'Choose when and what your buddy can remind you about. '
          "Your phone's system settings can also limit notifications.",
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Morning quote time'),
            trailing: Text(
              prefs.morningQuoteTime.format(context),
              style: theme.textTheme.titleSmall,
            ),
            onTap: () async {
              final picked = await _pick(context, prefs.morningQuoteTime);
              if (picked != null) await notifier.setMorningQuoteTime(picked);
            },
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.nights_stay_outlined),
            title: const Text('Evening meme time'),
            trailing: Text(
              prefs.eveningMemeTime.format(context),
              style: theme.textTheme.titleSmall,
            ),
            onTap: () async {
              final picked = await _pick(context, prefs.eveningMemeTime);
              if (picked != null) await notifier.setEveningMemeTime(picked);
            },
          ),
          const Divider(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Notify me about',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          for (final category in NotificationCategory.values)
            SwitchListTile(
              title: Text(category.label),
              subtitle: Text(category.description),
              value: !prefs.isMuted(category),
              onChanged: (on) => notifier.setMuted(category, !on),
            ),
          const Divider(height: AppSpacing.lg),
          ListTile(
            minTileHeight: 52,
            leading: Icon(Icons.alarm_on_rounded, color: context.colors.streak),
            title: const Text(
              'Alarms & Reminders (App Info)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Allow exact alarms in system settings for timely alerts',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () =>
                SystemFeaturesService.instance.openAlarmsAndRemindersSettings(),
          ),
          ListTile(
            minTileHeight: 52,
            leading: Icon(Icons.picture_in_picture_alt_rounded,
                color: context.colors.pill),
            title: const Text(
              'Picture-in-Picture (App Info)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Allow floating workout timer and live reminders',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => SystemFeaturesService.instance.openPipSettings(),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
