import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/widgets/glass_card.dart';
import 'package:flutter/material.dart';

/// Banner shown whenever the user has selected any condition.
class ConsultDoctorBanner extends StatelessWidget {
  /// Creates the banner.
  const ConsultDoctorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Semantics(
      container: true,
      liveRegion: true,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppPalette.softCoral.withValues(alpha: 0.15),
                  AppPalette.charcoalGreen.withValues(alpha: 0.5),
                ]
              : [
                  AppPalette.softCoral.withValues(alpha: 0.35),
                  AppPalette.softCoral.withValues(alpha: 0.15),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.medical_services_outlined,
              color: context.colors.warning,
              semanticLabel: 'Doctor advice',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Please consult your doctor before starting a program',
                    style: text.titleSmall?.copyWith(
                      color: context.colors.onWarning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We use your answers only to suggest gentler options. '
                    'They are not a substitute for professional advice.',
                    style: text.bodySmall?.copyWith(
                      color: isDark
                          ? AppPalette.darkTextMuted
                          : context.colors.onWarning.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
