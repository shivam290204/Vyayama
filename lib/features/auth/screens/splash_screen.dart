import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/auth/widgets/brand_mark.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';

/// Shown while auth and the profile load. The router redirects away from it.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider);
    final failed = profile.hasError && !profile.isLoading;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 120),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Vyayama',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Every effort counts.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (failed) ...[
                Builder(
                  builder: (context) {
                    final errStr = profile.error?.toString() ?? '';
                    final isSchemaMissing = errStr.contains('PGRST205') ||
                        errStr.contains('schema cache') ||
                        errStr.contains('profiles');

                    if (isSchemaMissing) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storage_rounded,
                            size: 40,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Database Setup Required',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            "The 'profiles' table was not found in your Supabase project. Run the SQL schema in your Supabase SQL Editor.",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      );
                    }

                    return Text(
                      "We couldn't load your profile. Check your connection and try again.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out & return to login'),
                ),
              ] else
                Semantics(
                  label: 'Loading',
                  child: const CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
