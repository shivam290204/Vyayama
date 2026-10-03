import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/profile/widgets/edit_profile_form.dart';

/// Edit name, age, gender, body stats, goal and fitness level.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: profile.when(
          loading: () => Center(
            child: Semantics(
              label: 'Loading profile',
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("We couldn't load your profile."),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (value) {
            if (value == null) {
              return const Center(child: Text('No profile found yet.'));
            }
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: EditProfileForm(profile: value),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
