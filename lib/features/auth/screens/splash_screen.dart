import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
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
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (failed) ...[
                Text(
                  "We couldn't load your profile. Check your connection and try again.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  child: const Text('Try again'),
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
