import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitbuddy/features/friends/data/invite_link.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Shows the user's personal QR code with avatar, name, handle, and actions
/// for sharing, copying link, saving to device, and full-screen expansion.
class MyQrCard extends StatefulWidget {
  const MyQrCard({
    super.key,
    this.profile,
    this.username,
    this.name,
    this.userId,
    this.avatarUrl,
  });

  final Profile? profile;
  final String? username;
  final String? name;
  final String? userId;
  final String? avatarUrl;

  @override
  State<MyQrCard> createState() => _MyQrCardState();
}

class _MyQrCardState extends State<MyQrCard> {
  final GlobalKey _qrBoundaryKey = GlobalKey();
  bool _isProcessing = false;

  String get _identifier {
    final p = widget.profile;
    if (p?.username != null && p!.username!.isNotEmpty) {
      return p.username!;
    }
    if (widget.username != null && widget.username!.isNotEmpty) {
      return widget.username!;
    }
    if (p?.id != null && p!.id.isNotEmpty) {
      return p.id;
    }
    return widget.userId ?? 'vyayama';
  }

  String get _displayName {
    final n = widget.profile?.displayName ?? widget.name;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    if (_handle.isNotEmpty) return _handle;
    return 'Vyayama Athlete';
  }

  String get _handle {
    final u = widget.profile?.username ?? widget.username;
    return (u != null && u.isNotEmpty) ? u : '';
  }

  String get _inviteLink => buildProfileLink(_identifier);

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied to clipboard! 📋'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<Uint8List?> _captureQrPng() async {
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareQr() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final shareText =
          'Add me on Vyayama and let\'s build a fitness streak together! 💪\n$_inviteLink';

      if (!kIsWeb) {
        final pngBytes = await _captureQrPng();
        if (pngBytes != null) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/vyayama_qr_$_identifier.png');
          await file.writeAsBytes(pngBytes, flush: true);
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'image/png', name: 'vyayama_qr.png')],
            text: shareText,
            subject: 'Connect with me on Vyayama',
          );
          return;
        }
      }
      await Share.share(shareText);
    } catch (_) {
      if (mounted) {
        await Share.share('Join me on Vyayama: $_inviteLink');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveQr() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final pngBytes = await _captureQrPng();
      if (pngBytes == null) {
        throw Exception('Could not render QR code');
      }

      if (!kIsWeb) {
        final docsDir = await getApplicationDocumentsDirectory();
        final savePath = '${docsDir.path}/vyayama_qr_$_identifier.png';
        final file = File(savePath);
        await file.writeAsBytes(pngBytes, flush: true);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code saved successfully! 📸'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save QR code. You can copy the link instead.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openFullScreenQr() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My QR Code',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
                QrImageView(
                data: _inviteLink,
                size: 260,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _displayName,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_handle.isNotEmpty)
                Text(
                  '@$_handle',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.primary,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _shareQr();
                },
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? theme.colorScheme.surfaceContainer : Colors.white;
    final brandForest = theme.colorScheme.primary;

    return Card(
      elevation: 1,
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header: User Info
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.tertiary.withValues(alpha: 0.25),
                  child: Text(
                    _displayName.isNotEmpty
                        ? _displayName[0].toUpperCase()
                        : 'V',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: brandForest,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _handle.isNotEmpty ? '@$_handle' : 'Permanent QR',
                        style: text.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Full screen QR',
                  icon: const Icon(Icons.fullscreen_rounded),
                  onPressed: _openFullScreenQr,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Captured QR Container
            RepaintBoundary(
              key: _qrBoundaryKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.transparent
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Semantics(
                      image: true,
                      label: 'QR code to add $_displayName as friend',
                      child: GestureDetector(
                        onTap: _openFullScreenQr,
                        child: QrImageView(
                          data: _inviteLink,
                          size: 180,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: brandForest,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scan to add on Vyayama',
                      style: text.labelSmall?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Action Row: Share, Save, Copy Link
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy link'),
                    onPressed: _copyLink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Save'),
                    onPressed: _saveQr,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share'),
                    onPressed: _shareQr,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
