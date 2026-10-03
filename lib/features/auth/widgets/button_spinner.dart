import 'package:flutter/material.dart';

/// Small progress indicator for use inside buttons.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}
