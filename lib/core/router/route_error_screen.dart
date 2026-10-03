import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';

/// Shown when go_router cannot match a location.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_off_rounded,
                size: 64,
                color: theme.colorScheme.primary,
                semanticLabel: 'Page not found',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "We couldn't find that page.",
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
