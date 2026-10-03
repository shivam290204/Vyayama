import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';

/// Titled card used by every Settings section.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}
