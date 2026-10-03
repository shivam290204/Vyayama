import 'package:flutter/material.dart';

/// Explains exact-alarm permission, battery optimisation and OS limits.
class AlarmGuidanceCard extends StatelessWidget {
  /// Creates the card.
  const AlarmGuidanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          Icons.settings_suggest_outlined,
          color: scheme.primary,
          semanticLabel: 'Alarm tips',
        ),
        title: Text('Help your alarm ring on time', style: text.titleMedium),
        subtitle: const Text('Permissions and battery settings'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          _Step(
            icon: Icons.notifications_active_outlined,
            title: 'Allow notifications',
            body: 'Turn on notifications for Vyayama so reminders can '
                'appear.',
          ),
          _Step(
            icon: Icons.alarm_on,
            title: 'Allow exact alarms (Android)',
            body: 'On Android 12 and newer, open Settings, then Apps, then '
                'Vyayama, and allow "Alarms & reminders". Without it, '
                'reminders may arrive a few minutes late.',
          ),
          _Step(
            icon: Icons.battery_saver_outlined,
            title: 'Relax battery optimisation',
            body: 'Set Vyayama\'s battery usage to "Unrestricted" or '
                '"Not optimised". Some phone makers stop background apps '
                'to save power, which can delay or skip reminders.',
          ),
          _Step(
            icon: Icons.do_not_disturb_on_outlined,
            title: 'Check Do Not Disturb and Focus',
            body: 'Allow alarms in Do Not Disturb. On iPhone, Focus modes '
                'and the silent switch can quiet notifications.',
          ),
          _Step(
            icon: Icons.info_outline,
            title: 'A friendly heads-up',
            body: 'Phones sometimes limit what apps can do. Treat this as a '
                'helpful reminder, and keep a backup alarm in your phone\'s '
                'Clock app for important mornings.',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
