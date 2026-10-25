import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a send is in its life.
enum SendPhase { idle, sending, verifying, verified, retrying, rejected, failed }

/// State shown by the verification overlay.
@immutable
class SendSnapState {
  const SendSnapState({this.phase = SendPhase.idle, this.message});

  final SendPhase phase;

  /// Friendly reason for `rejected`, `retrying`, or `failed`.
  final String? message;
}

/// Runs compress, upload and server verification, and exposes progress.
class SendSnapController extends Notifier<SendSnapState> {
  Future<void> Function()? _last;

  @override
  SendSnapState build() => const SendSnapState();

  Future<void> send({
    required CapturedPhoto photo,
    Uint8List? composedBytes,
    required SnapDraft draft,
  }) {
    _last = () => _run(composedBytes ?? photo.bytes, draft);
    return _last!();
  }

  /// Runs the last send again after a failure.
  Future<void> retry() => _last?.call() ?? Future<void>.value();

  void reset() {
    _last = null;
    state = const SendSnapState();
  }

  Future<void> _run(Uint8List raw, SnapDraft draft) async {
    try {
      state = const SendSnapState(phase: SendPhase.sending);
      final bytes = await ref.read(snapImageProcessorProvider).prepare(raw);
      final snaps = await ref
          .read(snapRepositoryProvider)
          .submitSnap(draft: draft, imageBytes: bytes);
      state = const SendSnapState(phase: SendPhase.verifying);
      final service = ref.read(snapVerificationServiceProvider);
      final results = <VerificationResult>[];
      for (final s in snaps) {
        results.add(await service.verify(s.id));
      }
      final rejected = results.where((r) => r.isRejected).toList();
      final retrying = results.where((r) => r.isRetrying || r.isPending).toList();

      if (rejected.isNotEmpty) {
        state = SendSnapState(
          phase: SendPhase.rejected,
          message: rejected.first.reason ?? kFriendlyRejection,
        );
      } else if (retrying.isNotEmpty) {
        state = SendSnapState(
          phase: SendPhase.retrying,
          message: retrying.first.reason ?? 'Photo uploaded. Verification queued and will complete shortly.',
        );
        ref.read(capturedPhotoProvider.notifier).set(null);
      } else {
        state = const SendSnapState(phase: SendPhase.verified);
        ref.read(capturedPhotoProvider.notifier).set(null);
      }
      ref
        ..invalidate(snapStreaksProvider)
        ..invalidate(friendsWithStreakProvider)
        ..invalidate(feedProvider)
        ..invalidate(inboxProvider);
    } catch (e, st) {
      debugPrint('Failed to send snap: $e\n$st');
      state = const SendSnapState(
        phase: SendPhase.failed,
        message: 'We could not send your snap. Check your connection and try again.',
      );
    }
  }
}

final sendSnapControllerProvider =
    NotifierProvider<SendSnapController, SendSnapState>(SendSnapController.new);
