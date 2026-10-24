import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/settings/widgets/account_section.dart';
import 'package:fitbuddy/features/settings/widgets/notifications_section.dart';
import 'package:fitbuddy/features/settings/widgets/privacy_section.dart';
import 'package:fitbuddy/features/settings/widgets/sound_section.dart';
import 'package:fitbuddy/features/settings/widgets/theme_section.dart';
import 'package:fitbuddy/features/settings/widgets/units_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Theme, units, notifications, privacy, disclaimer and account actions.
/// All state is local, so there are no loading or error states here.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSpacing.xl);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.streak.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.colors.streak.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.colors.streak.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.healing_rounded,
                        color: context.colors.streak,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Alarm & Notification Diagnostics',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'Check system permissions, channels, pending alarms & tests',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: context.colors.streak,
                    ),
                    onTap: () => context.push(AppRoutes.notificationDiagnostics),
                  ),
                ),
                gap,
                const ThemeSection(),
                gap,
                SoundSection(),
                gap,
                UnitsSection(),
                gap,
                NotificationsSection(),
                gap,
                PrivacySection(),
                gap,
                DisclaimerSection(),
                gap,
                AccountSection(),
                gap,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
