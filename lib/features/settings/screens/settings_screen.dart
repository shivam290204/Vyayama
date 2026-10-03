import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/settings/widgets/account_section.dart';
import 'package:fitbuddy/features/settings/widgets/notifications_section.dart';
import 'package:fitbuddy/features/settings/widgets/privacy_section.dart';
import 'package:fitbuddy/features/settings/widgets/sound_section.dart';
import 'package:fitbuddy/features/settings/widgets/theme_section.dart';
import 'package:fitbuddy/features/settings/widgets/units_section.dart';

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
              children: const [
                ThemeSection(),
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
