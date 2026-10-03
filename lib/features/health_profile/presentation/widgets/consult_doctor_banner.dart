import 'package:flutter/material.dart';

/// Banner shown whenever the user has selected any condition.
class ConsultDoctorBanner extends StatelessWidget {
  /// Creates the banner.
  const ConsultDoctorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.medical_services_outlined,
              color: scheme.onTertiaryContainer,
              semanticLabel: 'Doctor advice',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Please consult your doctor before starting a program',
                    style: text.titleSmall
                        ?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We use your answers only to suggest gentler options. '
                    'They are not a substitute for professional advice.',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onTertiaryContainer),
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
