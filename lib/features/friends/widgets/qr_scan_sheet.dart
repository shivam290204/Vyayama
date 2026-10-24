import 'dart:ui' as ui;

import 'package:fitbuddy/features/friends/data/invite_link.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Full-featured, production-ready QR scanner sheet with camera permissions,
/// branded scanning frame, torch control, camera flip, and validation.
class QrScanSheet extends StatefulWidget {
  const QrScanSheet({super.key});

  @override
  State<QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<QrScanSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MobileScannerController? _controller;
  late final AnimationController _animController;
  bool _done = false;
  String? _errorMessage;
  bool _torchEnabled = false;
  bool _checkingPermission = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _initCameraFlow();
  }

  Future<void> _initCameraFlow() async {
    if (mounted) {
      setState(() => _checkingPermission = true);
    }
    final status = await Permission.camera.status;
    if (status.isGranted) {
      await _startFreshController();
    } else {
      final requested = await Permission.camera.request();
      if (requested.isGranted) {
        await _startFreshController();
      } else {
        if (mounted) {
          setState(() {
            _checkingPermission = false;
            _hasPermission = false;
          });
        }
      }
    }
  }

  Future<void> _startFreshController() async {
    final old = _controller;
    _controller = null;
    if (old != null) {
      try {
        await old.stop();
      } catch (_) {}
      try {
        await old.dispose();
      } catch (_) {}
      // Brief hardware settling delay for CameraX release
      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (!mounted) return;

    final newController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 250,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const [BarcodeFormat.qrCode],
    );

    if (mounted) {
      setState(() {
        _controller = newController;
        _checkingPermission = false;
        _hasPermission = true;
        _errorMessage = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller?.stop();
    } else if (state == AppLifecycleState.resumed) {
      Permission.camera.isGranted.then((granted) {
        if (granted && mounted) {
          if (_controller != null && _controller!.value.isInitialized) {
            _controller?.start();
          } else {
            _startFreshController();
          }
        }
      });
    }
  }

  Future<void> _handlePermissionButton() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _startFreshController();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _checkingPermission = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        final identifier = parseProfileIdentifier(raw);
        if (identifier != null && identifier.isNotEmpty) {
          _done = true;
          Navigator.of(context).pop(identifier);
          return;
        } else {
          // Unsupported / invalid QR code format
          setState(() {
            _errorMessage =
                'Unsupported QR code. Please scan a valid Vyayama friend code.';
          });
          return;
        }
      }
    }
  }

  void _resumeScanning() {
    setState(() {
      _errorMessage = null;
      _done = false;
    });
  }

  Widget _buildErrorState(
    BuildContext context, {
    required String title,
    required String message,
    required bool isPermissionError,
  }) {
    final forestGreen = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermissionError
                  ? Icons.no_photography_outlined
                  : Icons.videocam_off_outlined,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: forestGreen,
              ),
              onPressed: () async {
                if (isPermissionError) {
                  await _handlePermissionButton();
                } else {
                  _startFreshController();
                }
              },
              icon: Icon(isPermissionError
                  ? Icons.camera_alt_outlined
                  : Icons.refresh_rounded),
              label: Text(isPermissionError
                  ? 'Grant Camera Access / Try Again'
                  : 'Restart Camera'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open Settings'),
            ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Search by Username Instead'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limeAccent = theme.colorScheme.tertiary;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Scan Friend QR',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Flashlight',
            icon: Icon(
              _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchEnabled ? limeAccent : Colors.white,
            ),
            onPressed: _controller == null
                ? null
                : () async {
                    await _controller!.toggleTorch();
                    setState(() => _torchEnabled = !_torchEnabled);
                  },
          ),
          IconButton(
            tooltip: 'Flip Camera',
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: _controller == null
                ? null
                : () => _controller!.switchCamera(),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Mobile Camera View or Permission / Loading State
          if (_checkingPermission)
            Center(
              child: CircularProgressIndicator(color: limeAccent),
            )
          else if (!_hasPermission || _controller == null)
            _buildErrorState(
              context,
              title: 'Camera Access Needed',
              message:
                  'Please grant camera permission to scan your friend\'s QR code, or search by their exact username.',
              isPermissionError: true,
            )
          else
            MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                final isPerm = error.errorCode ==
                    MobileScannerErrorCode.permissionDenied;
                final detail = error.errorDetails?.message ?? error.errorCode.name;
                return _buildErrorState(
                  context,
                  title: isPerm ? 'Camera Access Needed' : 'Camera Unavailable',
                  message: isPerm
                      ? 'Please grant camera permission to scan your friend\'s QR code, or search by their exact username.'
                      : 'Unable to start camera preview ($detail). Please tap Restart Camera.',
                  isPermissionError: isPerm,
                );
              },
            ),

          // 2. Custom Viewfinder Overlay (active only when scanner is running)
          if (!_checkingPermission && _hasPermission && _controller != null)
            AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ViewfinderPainter(
                    scanProgress: _animController.value,
                    hasError: _errorMessage != null,
                    accentColor: limeAccent,
                  ),
                );
              },
            ),

          // 3. Instructions & Error Banners
          if (!_checkingPermission && _hasPermission && _controller != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _resumeScanning,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, color: limeAccent, size: 20),
                        const SizedBox(width: 10),
                        const Text(
                          'Align QR code inside the frame',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({
    required this.scanProgress,
    required this.hasError,
    required this.accentColor,
  });

  final double scanProgress;
  final bool hasError;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const boxSize = 260.0;
    final left = (size.width - boxSize) / 2;
    final top = (size.height - boxSize) / 2 - 40;
    final boxRect = Rect.fromLTWH(left, top, boxSize, boxSize);
    final rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(24));

    // Dark background mask with transparent window
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // Border corners
    final cornerColor = hasError ? Colors.redAccent : accentColor;
    final cornerPaint = Paint()
      ..color = cornerColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top + 16)
        ..quadraticBezierTo(left, top, left + 16, top)
        ..lineTo(left + cornerLength, top),
      cornerPaint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(left + boxSize - cornerLength, top)
        ..lineTo(left + boxSize - 16, top)
        ..quadraticBezierTo(left + boxSize, top, left + boxSize, top + 16)
        ..lineTo(left + boxSize, top + cornerLength),
      cornerPaint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + boxSize - cornerLength)
        ..lineTo(left, top + boxSize - 16)
        ..quadraticBezierTo(left, top + boxSize, left + 16, top + boxSize)
        ..lineTo(left + cornerLength, top + boxSize),
      cornerPaint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(left + boxSize - cornerLength, top + boxSize)
        ..lineTo(left + boxSize - 16, top + boxSize)
        ..quadraticBezierTo(
            left + boxSize, top + boxSize, left + boxSize, top + boxSize - 16)
        ..lineTo(left + boxSize, top + boxSize - cornerLength),
      cornerPaint,
    );

    // Animated scanning line
    if (!hasError) {
      final lineY = top + 10 + (boxSize - 20) * scanProgress;
      final linePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(left + 20, lineY),
          Offset(left + boxSize - 20, lineY),
          [
            Colors.transparent,
            accentColor,
            Colors.transparent,
          ],
        )
        ..strokeWidth = 2.5;
      canvas.drawLine(
        Offset(left + 20, lineY),
        Offset(left + boxSize - 20, lineY),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) =>
      oldDelegate.scanProgress != scanProgress || oldDelegate.hasError != hasError;
}
