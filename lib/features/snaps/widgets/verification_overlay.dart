import 'package:fitbuddy/features/snaps/send_snap_controller.dart';
import 'package:flutter/material.dart';

/// Full-screen overlay for sending, verifying, verified, rejected and failed.
class VerificationOverlay extends StatelessWidget {
  const VerificationOverlay({
    super.key,
    required this.state,
    required this.onDone,
    required this.onRetake,
    required this.onRetry,
    required this.onCancel,
  });

  final SendSnapState state;
  final VoidCallback onDone;
  final VoidCallback onRetake;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (Widget icon, String title, String? body, List<Widget> actions) =
        switch (state.phase) {
      SendPhase.sending || SendPhase.idle => (
          const CircularProgressIndicator(),
          'Sending your snap…',
          null,
          <Widget>[],
        ),
      SendPhase.verifying => (
          const CircularProgressIndicator(),
          'Checking it looks like exercise…',
          'This is a quick "looks like exercise" check, not proof of effort.',
          <Widget>[],
        ),
      SendPhase.verified => (
          Icon(Icons.check_circle, size: 72, color: scheme.primary),
          'Delivered! 🔥',
          'Your friends can see it for 24 hours.',
          <Widget>[FilledButton(onPressed: onDone, child: const Text('Done'))],
        ),
      SendPhase.rejected => (
          Icon(Icons.refresh, size: 72, color: scheme.tertiary),
          'Hmm, that one didn\'t pass',
          state.message,
          <Widget>[
            FilledButton(onPressed: onRetake, child: const Text('Retake')),
            TextButton(onPressed: onCancel, child: const Text('Close')),
          ],
        ),
      SendPhase.failed => (
          Icon(Icons.cloud_off, size: 72, color: scheme.error),
          'Couldn\'t send',
          state.message,
          <Widget>[
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
            TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
    };
    return Positioned.fill(
      child: Material(
        color: scheme.surface,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: 24),
                    Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
                    if (body != null) ...[
                      const SizedBox(height: 12),
                      Text(body,
                          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    for (final a in actions)
                      Padding(padding: const EdgeInsets.only(top: 8), child: a),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
