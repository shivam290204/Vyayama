import 'package:fitbuddy/features/snap_streaks/data/snap_streak_repository.dart';
import 'package:fitbuddy/features/snaps/data/mock_snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Result of the quick on-device check.
///
/// It is never authoritative; the server decides.
enum PreCheckOutcome {
  likelyExercise,
  unlikely,
  unsure;

  // Backward compatibility aliases
  static const PreCheckOutcome looksLikeExercise = PreCheckOutcome.likelyExercise;
  static const PreCheckOutcome noExerciseFound = PreCheckOutcome.unlikely;
  static const PreCheckOutcome unknown = PreCheckOutcome.unsure;
}

/// On-device hint. It is never authoritative; the server decides.
@immutable
class PreCheckResult {
  const PreCheckResult(this.outcome, {this.topLabel});

  final PreCheckOutcome outcome;
  final String? topLabel;

  bool get isLikelyExercise => outcome == PreCheckOutcome.likelyExercise;
  bool get isUnlikely => outcome == PreCheckOutcome.unlikely;
  bool get isUnsure => outcome == PreCheckOutcome.unsure;
}

/// Quick local check before sending.
abstract class SnapPreCheck {
  Future<PreCheckResult> check(String imagePath);
}

/// ML Kit image labeling wrapper.
///
/// Returns `unsure` on web or on any error.
/// Warns before upload only on `unlikely`. Never blocks on `unsure`.
class MlKitSnapPreCheck implements SnapPreCheck {
  static const allowHints = [
    'exercise', 'fitness', 'gym', 'sport', 'running', 'jogging', 'yoga',
    'cycling', 'bicycle', 'walking', 'muscle', 'dumbbell', 'barbell', 'weight',
    'stretch', 'athlet', 'workout', 'pilates', 'trail', 'track', 'marathon',
    'hiking', 'swimming', 'sneaker', 'jersey', 'treadmill', 'kettlebell',
    'activewear', 'sportswear', 'rowing', 'elliptical', 'calisthenics',
    'aerobics', 'bodybuilding', 'boxing', 'climbing', 'crossfit', 'triathlon',
  ];

  static const Map<ActivityType, List<String>> activityKeywords = {
    ActivityType.gym: [
      'dumbbell', 'barbell', 'weight', 'gym', 'bench', 'kettlebell',
      'exercise equipment', 'weight training', 'fitness center',
    ],
    ActivityType.running: [
      'running', 'jogging', 'track', 'marathon', 'treadmill', 'athletics',
      'running shoe', 'cross country', 'sport venue',
    ],
    ActivityType.walking: [
      'walking', 'pedestrian', 'footwear', 'trail', 'hiking', 'park',
      'footpath',
    ],
    ActivityType.cycling: [
      'cycling', 'bicycle', 'bicycle wheel', 'mountain bike', 'road bicycle',
      'bicycle helmet', 'bike',
    ],
    ActivityType.yoga: [
      'yoga', 'pilates', 'meditation', 'barefoot', 'asana',
    ],
    ActivityType.stretching: [
      'stretching', 'flexibility', 'exercise mat', 'physical fitness',
      'foam roller',
    ],
    ActivityType.sports: [
      'sport', 'sports equipment', 'ball', 'racket', 'football', 'soccer',
      'basketball', 'tennis', 'cricket', 'badminton', 'volleyball', 'stadium',
      'boxing',
    ],
    ActivityType.workout: [
      'workout', 'exercise', 'fitness', 'calisthenics', 'bodybuilding',
      'muscle', 'activewear', 'sportswear',
    ],
    ActivityType.otherExercise: [
      'exercise', 'fitness', 'workout', 'physical fitness', 'sport',
    ],
  };

  /// Detects whether [labels] corroborate [targetActivity] or another fitness category.
  static ActivityType detectActivity(List<String> labels, {ActivityType? targetActivity}) {
    if (labels.isEmpty) return targetActivity ?? ActivityType.workout;

    if (targetActivity != null) {
      final targetKeywords = activityKeywords[targetActivity] ?? const [];
      for (final l in labels) {
        final lower = l.toLowerCase();
        if (targetKeywords.any(lower.contains)) {
          return targetActivity;
        }
      }
    }

    for (final entry in activityKeywords.entries) {
      for (final l in labels) {
        final lower = l.toLowerCase();
        if (entry.value.any(lower.contains)) {
          return entry.key;
        }
      }
    }

    return targetActivity ?? ActivityType.workout;
  }

  static const denyHints = [
    'food', 'dish', 'cuisine', 'meal', 'snack', 'pizza', 'burger', 'dessert',
    'beverage', 'coffee', 'fast food', 'tableware', 'cutlery',
    'cat', 'dog', 'pet', 'kitten', 'puppy', 'animal', 'bird',
    'screenshot', 'text', 'document', 'paper', 'book', 'bed', 'bedroom',
    'couch', 'sofa', 'furniture', 'desk', 'computer keyboard', 'laptop', 'television',
    'car', 'automobile', 'truck', 'motorcycle', 'bus', 'airplane', 'train',
  ];

  /// Pure label evaluator for unit tests and local classification.
  static PreCheckResult evaluateLabels(List<String> labels) {
    if (labels.isEmpty) return const PreCheckResult(PreCheckOutcome.unsure);

    // 1. Check Allow List (Likely Exercise)
    for (final l in labels) {
      final lower = l.toLowerCase();
      if (allowHints.any(lower.contains)) {
        return PreCheckResult(PreCheckOutcome.likelyExercise, topLabel: l);
      }
    }

    // 2. Check Deny List (Unlikely Exercise)
    for (final l in labels) {
      final lower = l.toLowerCase();
      if (denyHints.any(lower.contains)) {
        return PreCheckResult(PreCheckOutcome.unlikely, topLabel: l);
      }
    }

    // 3. Fallback to Unsure (neutral / neither matched)
    return PreCheckResult(PreCheckOutcome.unsure, topLabel: labels.first);
  }

  @override
  Future<PreCheckResult> check(String imagePath) async {
    if (kIsWeb) return const PreCheckResult(PreCheckOutcome.unsure);
    ImageLabeler? labeler;
    try {
      labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
      final labels = await labeler.processImage(InputImage.fromFilePath(imagePath));
      if (labels.isEmpty) return const PreCheckResult(PreCheckOutcome.unsure);
      return evaluateLabels(labels.map((l) => l.label).toList());
    } catch (_) {
      return const PreCheckResult(PreCheckOutcome.unsure);
    } finally {
      await labeler?.close();
    }
  }
}

/// Authoritative check. Real impl: invoke the `verify-snap` Edge Function with
/// `{ "snap_id": id }` and map its JSON to a [VerificationResult].
abstract class SnapVerificationService {
  Future<VerificationResult> verify(String snapId);

  /// Appeals a rejected photo. Waives the exercise check if content is safe.
  /// Delivered to friends without streak credit.
  Future<VerificationResult> appeal(String snapId);
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

  @override
  Future<VerificationResult> appeal(String snapId) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final snap = _snaps.sentSnap(snapId);
    if (snap == null) throw StateError('Unknown snap $snapId');
    // Content safety must still pass. Unsafe content cannot be appealed.
    final text = (snap.caption ?? '').toLowerCase();
    if (text.contains('unsafe')) {
      return VerificationResult.rejected(
        reason: 'This photo cannot be delivered as it was flagged by content safety.',
      );
    }
    final result = VerificationResult.appealed(activity: snap.activityType.dbValue);
    _snaps.markVerification(snapId, result);
    // Appealed snaps deliver to friends but do NOT award streak credit.
    return result;
  }
}
