import 'package:flutter/material.dart';

/// The medical disclaimer required by the project spec (Section 12).
const String kMedicalDisclaimer =
    'This app provides general wellness information and reminders. It is not '
    'medical advice and does not diagnose, treat, or prevent any condition. '
    'Consult a qualified doctor before starting any exercise or diet program, '
    'especially if you have a health condition or take medication.';

/// Card that shows [kMedicalDisclaimer].
class MedicalDisclaimerCard extends StatelessWidget {
  /// Creates the card.
  const MedicalDisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: 'Medical disclaimer',
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline,
                color: scheme.onSecondaryContainer,
                semanticLabel: 'Information',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  kMedicalDisclaimer,
                  style: text.bodySmall
                      ?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
