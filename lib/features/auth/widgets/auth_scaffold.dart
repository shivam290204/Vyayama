import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/auth/widgets/brand_mark.dart';

/// Shared page layout for login, sign-up and forgot password.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.withAppBar = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool withAppBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: withAppBar ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandMark()),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
