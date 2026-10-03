import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/profile/widgets/profile_avatar.dart';
import 'package:fitbuddy/features/profile/widgets/profile_links.dart';
import 'package:fitbuddy/features/profile/widgets/profile_stats.dart';

/// Profile tab: avatar, stats, edit button and links to other features.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: profile.when(
          loading: () => Center(
            child: Semantics(
              label: 'Loading profile',
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => _Message(
            icon: Icons.cloud_off_rounded,
            text: "We couldn't load your profile.",
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(currentProfileProvider),
          ),
          data: (value) => value == null
              ? _Message(
                  icon: Icons.person_search_outlined,
                  text: 'No profile found yet.',
                  actionLabel: 'Reload',
                  onAction: () => ref.invalidate(currentProfileProvider),
                )
              : _ProfileBody(profile: value),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = profile.username;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(child: ProfileAvatar(profile: profile)),
            const SizedBox(height: AppSpacing.md),
            Text(
              profile.displayName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              (username == null || username.isEmpty)
                  ? 'No username yet'
                  : '@$username',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.profileEdit),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ProfileStats(profile: profile),
            const SizedBox(height: AppSpacing.xl),
            const ProfileLinks(),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary, semanticLabel: text),
            const SizedBox(height: AppSpacing.lg),
            Text(text, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
