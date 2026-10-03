import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Bottom sheet that scans a friend's QR code and pops the raw value.
class QrScanSheet extends StatefulWidget {
  const QrScanSheet({super.key});

  @override
  State<QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<QrScanSheet> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _done = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                    child: Text('Scan a friend\'s QR code', style: text.titleMedium)),
                IconButton(
                  tooltip: 'Close scanner',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                onDetect: _onDetect,
                errorBuilder: (context, error, child) => const StateMessage(
                  icon: Icons.no_photography_outlined,
                  title: 'Camera not available',
                  message:
                      'Allow camera access in your settings, or type your friend\'s username instead.',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
