import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_verification_service.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:fitbuddy/features/snaps/send_snap_controller.dart';
import 'package:fitbuddy/features/snaps/widgets/activity_chips.dart';
import 'package:fitbuddy/features/snaps/widgets/recipient_picker.dart';
import 'package:fitbuddy/features/snaps/widgets/sticker_overlay.dart';
import 'package:fitbuddy/features/snaps/widgets/verification_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/snaps/preview`: tag, caption, stickers, recipients, then send.
class SnapPreviewScreen extends ConsumerStatefulWidget {
  const SnapPreviewScreen({super.key, this.toFriendId});

  final String? toFriendId;

  @override
  ConsumerState<SnapPreviewScreen> createState() => _SnapPreviewScreenState();
}

class _SnapPreviewScreenState extends ConsumerState<SnapPreviewScreen> {
  final _boundaryKey = GlobalKey();
  final _caption = TextEditingController();
  ActivityType? _activity;
  final Set<String> _recipients = {};
  bool _feed = false;
  bool _stActivity = true;
  bool _stTime = false;
  bool _stSteps = false;

  @override
  void initState() {
    super.initState();
    final to = widget.toFriendId;
    if (to != null) _recipients.add(to);
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  bool get _canSend => _activity != null && (_recipients.isNotEmpty || _feed);

  void _retake() {
    ref.read(sendSnapControllerProvider.notifier).reset();
    context.canPop() ? context.pop() : context.go(AppRoutes.snapsCamera);
  }

  Future<Uint8List?> _composeStickers() async {
    if (!(_stActivity || _stTime || _stSteps)) return null;
    final boundary =
        _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _send() async {
    final photo = ref.read(capturedPhotoProvider);
    final activity = _activity;
    if (photo == null || activity == null) return;
    final hint = await ref.read(snapPreCheckProvider).check(photo.path);
    if (!mounted) return;
    if (hint.outcome == PreCheckOutcome.noExerciseFound) {
      final sendAnyway = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Try again?'),
          content: const Text(
              'This doesn\'t look like exercise. A photo of your workout, run, mat or gym spot works best.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Retake')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send anyway')),
          ],
        ),
      );
      if (!mounted) return;
      if (sendAnyway != true) {
        _retake();
        return;
      }
    }
    final composed = await _composeStickers();
    final caption = _caption.text.trim();
    await ref.read(sendSnapControllerProvider.notifier).send(
          photo: photo,
          composedBytes: composed,
          draft: SnapDraft(
            activity: activity,
            caption: caption.isEmpty ? null : caption,
            recipientIds: _recipients.toList(),
            postToFeed: _feed,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(capturedPhotoProvider);
    final send = ref.watch(sendSnapControllerProvider);
    final steps = ref.watch(snapStepsTodayProvider);
    final text = Theme.of(context).textTheme;

    if (photo == null && send.phase == SendPhase.idle) {
      return Scaffold(
        appBar: AppBar(),
        body: StateMessage(
          icon: Icons.photo_camera_outlined,
          title: 'No photo yet',
          message: 'Take a photo with the camera first.',
          actionLabel: 'Open camera',
          onAction: () => context.go(AppRoutes.snapsCamera),
        ),
      );
    }

    final sending = send.phase != SendPhase.idle;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Send a snap'),
            leading: IconButton(
              tooltip: 'Back to camera',
              icon: const Icon(Icons.arrow_back),
              onPressed: _retake,
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.send),
                label: Text(_activity == null ? 'Pick an activity' : 'Send'),
                onPressed: _canSend && !sending ? _send : null,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              if (photo != null)
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Semantics(
                            image: true,
                            label: 'Your photo',
                            child: Image.memory(photo.bytes, fit: BoxFit.cover),
                          ),
                          StickerOverlay(
                            activity: _activity,
                            showActivity: _stActivity,
                            showTime: _stTime,
                            showSteps: _stSteps,
                            steps: steps,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('What did you do?', style: text.titleMedium),
              const SizedBox(height: 8),
              ActivityChips(
                selected: _activity,
                onSelected: (a) => setState(() => _activity = a),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _caption,
                maxLength: kMaxCaptionLength,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              Text('Stickers', style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Activity'),
                    selected: _stActivity,
                    onSelected: (v) => setState(() => _stActivity = v),
                  ),
                  FilterChip(
                    label: const Text('Time'),
                    selected: _stTime,
                    onSelected: (v) => setState(() => _stTime = v),
                  ),
                  if (steps != null)
                    FilterChip(
                      label: const Text('Steps'),
                      selected: _stSteps,
                      onSelected: (v) => setState(() => _stSteps = v),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Send to', style: text.titleMedium),
              RecipientPicker(
                selected: _recipients,
                onToggle: (id) => setState(() {
                  _recipients.contains(id) ? _recipients.remove(id) : _recipients.add(id);
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Post to Friends Feed'),
                subtitle: const Text('Visible to friends for 24 hours. Feed posts don\'t count for streaks.'),
                value: _feed,
                onChanged: (v) => setState(() => _feed = v),
              ),
            ],
          ),
        ),
        if (sending)
          VerificationOverlay(
            state: send,
            onDone: () {
              ref.read(sendSnapControllerProvider.notifier).reset();
              context.go(AppRoutes.friends);
            },
            onRetake: _retake,
            onRetry: () => ref.read(sendSnapControllerProvider.notifier).retry(),
            onCancel: () => ref.read(sendSnapControllerProvider.notifier).reset(),
          ),
      ],
    );
  }
}
