import 'package:fitbuddy/features/snap_streaks/data/snap_streak_repository.dart';
import 'package:fitbuddy/features/snaps/data/mock_snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Result of the quick on-device check.
enum PreCheckOutcome { looksLikeExercise, noExerciseFound, unknown }

/// On-device hint. It is never authoritative; the server decides.
@immutable
class PreCheckResult {
  const PreCheckResult(this.outcome, {this.topLabel});

  final PreCheckOutcome outcome;
  final String? topLabel;
}

/// Quick local check before sending.
abstract class SnapPreCheck {
  Future<PreCheckResult> check(String imagePath);
}

/// ML Kit image labeling wrapper. Returns `unknown` on web or on any error.
class MlKitSnapPreCheck implements SnapPreCheck {
  static const _hints = [
    'exercise', 'fitness', 'gym', 'sport', 'running', 'jogging', 'yoga',
    'cycling', 'bicycle', 'walking', 'muscle', 'dumbbell', 'barbell', 'weight',
    'stretch', 'athlet', 'workout', 'pilates', 'trail', 'track', 'marathon',
    'hiking', 'swimming', 'sneaker', 'jersey', 'treadmill', 'kettlebell',
  ];

  @override
  Future<PreCheckResult> check(String imagePath) async {
    if (kIsWeb) return const PreCheckResult(PreCheckOutcome.unknown);
    ImageLabeler? labeler;
    try {
      labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
      final labels = await labeler.processImage(InputImage.fromFilePath(imagePath));
      if (labels.isEmpty) return const PreCheckResult(PreCheckOutcome.unknown);
      for (final l in labels) {
        final name = l.label.toLowerCase();
        if (_hints.any(name.contains)) {
          return PreCheckResult(PreCheckOutcome.looksLikeExercise, topLabel: l.label);
        }
      }
      return PreCheckResult(PreCheckOutcome.noExerciseFound,
          topLabel: labels.first.label);
    } catch (_) {
      return const PreCheckResult(PreCheckOutcome.unknown);
    } finally {
      await labeler?.close();
    }
  }
}

/// Authoritative check. Real impl: invoke the `verify-snap` Edge Function with
/// `{ "snap_id": id }` and map its JSON to a [VerificationResult].
abstract class SnapVerificationService {
  Future<VerificationResult> verify(String snapId);
}

/// Mock: accepts everything unless the caption mentions "pizza" or "meme".
/// It also simulates the server-side streak update for the demo.
class MockSnapVerificationService implements SnapVerificationService {
  MockSnapVerificationService(this._snaps, this._streaks, this._userId);

  final MockSnapRepository _snaps;
  final SnapStreakRepository _streaks;
  final String _userId;

  @override
  Future<VerificationResult> verify(String snapId) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    final snap = _snaps.sentSnap(snapId);
    if (snap == null) throw StateError('Unknown snap $snapId');
    final text = (snap.caption ?? '').toLowerCase();
    final reject = text.contains('pizza') || text.contains('meme');
    final result = reject
        ? VerificationResult.rejected(reason: kFriendlyRejection)
        : VerificationResult.verified(
            activity: snap.activityType.dbValue, confidence: 0.92);
    _snaps.markVerification(snapId, result);
    final streaks = _streaks;
    if (result.isVerified && !snap.isStory && streaks is MockSnapStreakRepository) {
      for (final r in _snaps.recipientsOf(snapId)) {
        streaks.simulateServerUpdate(senderId: _userId, recipientId: r);
      }
    }
    return result;
  }
}
