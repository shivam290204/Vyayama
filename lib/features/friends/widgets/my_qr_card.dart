import 'package:fitbuddy/features/friends/data/invite_link.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Shows the user's invite QR code and a share button.
class MyQrCard extends StatelessWidget {
  const MyQrCard({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // QR codes need dark modules on a light background to scan reliably, even
    // in dark mode, so we borrow the light scheme's tokens for the code only.
    const qrScheme = ColorScheme.light();
    final link = buildInviteLink(username);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('My QR code', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('@$username',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Semantics(
              image: true,
              label: 'QR code that adds you as a friend',
              child: QrImageView(
                data: link,
                size: 180,
                backgroundColor: qrScheme.surface,
                eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: qrScheme.onSurface),
                dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: qrScheme.onSurface),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share invite link'),
              onPressed: () => Share.share(
                'Join me on Vyayama and let\'s build a snap streak! $link',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
