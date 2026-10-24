import 'package:flutter/material.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';

/// Root app shown in release builds when required environment configuration
/// (such as SUPABASE_URL and SUPABASE_ANON_KEY) is missing.
class AppNotConfiguredApp extends StatelessWidget {
  const AppNotConfiguredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vyayama - Setup Required',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppNotConfiguredScreen(),
    );
  }
}

/// A clean, accessible fallback screen displayed instead of crashing when
/// backend credentials are not provided in release builds.
class AppNotConfiguredScreen extends StatelessWidget {
  const AppNotConfiguredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppPalette.darkBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppPalette.softCoral.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppPalette.softCoral.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      size: 42,
                      color: AppPalette.softCoral,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Application Not Configured',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppPalette.darkText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This release build requires backend service configuration before it can connect and launch.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppPalette.darkTextMuted,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppPalette.darkSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppPalette.darkOutline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: AppPalette.softCoral,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Missing Configuration Keys',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppPalette.darkText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _KeyRow(label: 'SUPABASE_URL', status: 'Not provided'),
                        const SizedBox(height: 6),
                        const _KeyRow(label: 'SUPABASE_ANON_KEY', status: 'Not provided'),
                        const SizedBox(height: 16),
                        const Divider(color: AppPalette.darkOutline),
                        const SizedBox(height: 12),
                        Text(
                          'How to resolve:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppPalette.darkText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Build the app with compile-time dart-define flags:\n'
                          'flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\n\n'
                          'Or supply a valid .env configuration before compiling.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: AppPalette.darkTextMuted,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  final String label;
  final String status;

  const _KeyRow({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppPalette.darkText,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppPalette.softCoral.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppPalette.softCoral,
            ),
          ),
        ),
      ],
    );
  }
}
