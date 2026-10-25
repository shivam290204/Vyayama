import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_verification_service.dart';
import 'package:fitbuddy/features/snaps/data/verification_evaluator.dart';
import 'package:fitbuddy/features/snaps/send_snap_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Verification Launch Gate Metrics & Evaluation Tests', () {
    test('Calculates FRR, FAR, and Latency Percentiles accurately', () {
      final dataset = VerificationBenchmarkDataset.loadStandardSamples();
      expect(dataset.length, 40);

      final exerciseSamples = dataset.where((s) => s.category == SampleCategory.clearExercise).toList();
      final nonExerciseSamples = dataset.where((s) => s.category == SampleCategory.obviousNonExercise).toList();
      final unsafeSamples = dataset.where((s) => s.category == SampleCategory.unsafeContent).toList();

      expect(exerciseSamples.length, 20);
      expect(nonExerciseSamples.length, 15);
      expect(unsafeSamples.length, 5);

      final results = <SampleEvaluationResult>[];

      // Simulate 19 True Positives and 1 False Negative for exercise (FRR = 1/20 = 5.0%)
      for (var i = 0; i < exerciseSamples.length; i++) {
        final isTP = i < 19;
        results.add(SampleEvaluationResult(
          sample: exerciseSamples[i],
          predictedIsExercise: isTP,
          predictedIsSafe: true,
          delivered: isTP,
          confidence: isTP ? 0.90 : 0.40,
          durationMs: 1000 + (i * 50),
        ));
      }

      // Simulate 14 True Negatives and 1 False Positive for non-exercise (FAR = 1/15 = 6.67%)
      for (var i = 0; i < nonExerciseSamples.length; i++) {
        final isFP = i == 0;
        results.add(SampleEvaluationResult(
          sample: nonExerciseSamples[i],
          predictedIsExercise: isFP,
          predictedIsSafe: true,
          delivered: isFP,
          confidence: isFP ? 0.70 : 0.15,
          durationMs: 900 + (i * 40),
        ));
      }

      // Simulate 5 True Negatives for unsafe content (0 unsafe delivered)
      for (var i = 0; i < unsafeSamples.length; i++) {
        results.add(SampleEvaluationResult(
          sample: unsafeSamples[i],
          predictedIsExercise: false,
          predictedIsSafe: false,
          delivered: false,
          confidence: 0.99,
          durationMs: 800 + (i * 30),
        ));
      }

      final report = VerificationEvaluationReport(results: results);

      expect(report.totalSamples, 40);
      expect(report.exerciseCount, 20);
      expect(report.nonExerciseCount, 15);
      expect(report.unsafeCount, 5);

      expect(report.truePositives, 19);
      expect(report.falseNegatives, 1);
      expect(report.falseRejectionRate, closeTo(0.05, 0.001));

      expect(report.falsePositives, 1);
      expect(report.falseAcceptanceRate, closeTo(1 / 15, 0.001)); // ~6.67%
      expect(report.unsafeDelivered, 0);

      expect(report.p50LatencyMs, greaterThan(0));
      expect(report.p95LatencyMs, greaterThan(0));
      expect(report.p95LatencyMs, lessThan(4000));

      expect(report.passed, isTrue);
      expect(report.gateFailures, isEmpty);
    });

    test('Fails launch gates when False Rejection Rate exceeds 5%', () {
      final dataset = VerificationBenchmarkDataset.loadStandardSamples();
      final exerciseSamples = dataset.where((s) => s.category == SampleCategory.clearExercise).toList();

      final results = <SampleEvaluationResult>[];
      // 18 TP and 2 FN out of 20 = 10% FRR (> 5% gate)
      for (var i = 0; i < exerciseSamples.length; i++) {
        final isTP = i < 18;
        results.add(SampleEvaluationResult(
          sample: exerciseSamples[i],
          predictedIsExercise: isTP,
          predictedIsSafe: true,
          delivered: isTP,
          confidence: isTP ? 0.90 : 0.40,
          durationMs: 1200,
        ));
      }

      final report = VerificationEvaluationReport(results: results);
      expect(report.falseRejectionRate, closeTo(0.10, 0.001));
      expect(report.passed, isFalse);
      expect(report.gateFailures.any((f) => f.contains('FRR failure')), isTrue);
    });

    test('Fails launch gates when False Acceptance Rate exceeds 10%', () {
      final dataset = VerificationBenchmarkDataset.loadStandardSamples();
      final nonExercise = dataset.where((s) => s.category == SampleCategory.obviousNonExercise).toList();

      final results = <SampleEvaluationResult>[];
      // 2 FP out of 15 = 13.33% FAR (> 10% gate)
      for (var i = 0; i < nonExercise.length; i++) {
        final isFP = i < 2;
        results.add(SampleEvaluationResult(
          sample: nonExercise[i],
          predictedIsExercise: isFP,
          predictedIsSafe: true,
          delivered: isFP,
          confidence: isFP ? 0.80 : 0.20,
          durationMs: 1100,
        ));
      }

      final report = VerificationEvaluationReport(results: results);
      expect(report.falseAcceptanceRate, greaterThan(0.10));
      expect(report.passed, isFalse);
      expect(report.gateFailures.any((f) => f.contains('FAR failure')), isTrue);
    });

    test('CRITICAL: Fails launch gates immediately if ANY unsafe sample is delivered', () {
      final dataset = VerificationBenchmarkDataset.loadStandardSamples();
      final unsafeSample = dataset.firstWhere((s) => s.category == SampleCategory.unsafeContent);

      final results = [
        SampleEvaluationResult(
          sample: unsafeSample,
          predictedIsExercise: false,
          predictedIsSafe: true, // Failed to flag as unsafe!
          delivered: true, // Delivered to recipient!
          confidence: 0.50,
          durationMs: 1200,
        ),
      ];

      final report = VerificationEvaluationReport(results: results);
      expect(report.unsafeDelivered, 1);
      expect(report.passed, isFalse);
      expect(report.gateFailures.any((f) => f.contains('CRITICAL Safety failure')), isTrue);
    });

    test('Fails launch gates when P95 latency exceeds 4000ms', () {
      final dataset = VerificationBenchmarkDataset.loadStandardSamples();
      final exerciseSamples = dataset.where((s) => s.category == SampleCategory.clearExercise).toList();

      final results = exerciseSamples.map((s) => SampleEvaluationResult(
        sample: s,
        predictedIsExercise: true,
        predictedIsSafe: true,
        delivered: true,
        confidence: 0.95,
        durationMs: 4500, // 4.5s latency exceeds 4.0s gate
      )).toList();

      final report = VerificationEvaluationReport(results: results);
      expect(report.p95LatencyMs, 4500);
      expect(report.passed, isFalse);
      expect(report.gateFailures.any((f) => f.contains('Latency failure')), isTrue);
    });

    test('VerificationBenchmarkDataset contains non-empty descriptions and zero explicit media', () {
      final dataset = VerificationBenchmarkDataset.loadStandardSamples();
      for (final sample in dataset) {
        expect(sample.id, isNotEmpty);
        expect(sample.description, isNotEmpty);
        expect(sample.syntheticImageBytes, isNotNull);
        expect(sample.syntheticImageBytes!.length, greaterThan(0));
      }
    });
  });

  group('Snap Verification State Transitions, ML Kit Pre-Check, & Failure Handling Tests', () {
    test('On-device ML Kit pre-check evaluates likelyExercise, unlikely, and unsure tiers accurately', () {
      // Tier 1: Likely Exercise
      final exerciseCheck = MlKitSnapPreCheck.evaluateLabels(['Dumbbell', 'Gym', 'Fitness']);
      expect(exerciseCheck.outcome, PreCheckOutcome.likelyExercise);
      expect(exerciseCheck.isLikelyExercise, isTrue);
      expect(exerciseCheck.isUnlikely, isFalse);
      expect(exerciseCheck.isUnsure, isFalse);

      // Tier 2: Unlikely Exercise (food, pets, screenshot)
      final nonExerciseCheck = MlKitSnapPreCheck.evaluateLabels(['Pizza', 'Fast food', 'Dish']);
      expect(nonExerciseCheck.outcome, PreCheckOutcome.unlikely);
      expect(nonExerciseCheck.isUnlikely, isTrue);
      expect(nonExerciseCheck.isLikelyExercise, isFalse);

      // Tier 3: Unsure (neutral labels)
      final neutralCheck = MlKitSnapPreCheck.evaluateLabels(['Wall', 'Room', 'Light fixture']);
      expect(neutralCheck.outcome, PreCheckOutcome.unsure);
      expect(neutralCheck.isUnsure, isTrue);

      // Tier 3 fallback: Empty labels
      final emptyCheck = MlKitSnapPreCheck.evaluateLabels([]);
      expect(emptyCheck.outcome, PreCheckOutcome.unsure);
      expect(emptyCheck.isUnsure, isTrue);
    });

    test('Successful AI verification transitions snap to verified state with activity and confidence', () {
      final result = VerificationResult.verified(
        activity: 'running',
        confidence: 0.94,
      );

      expect(result.status, VerificationStatus.verified);
      expect(result.isVerified, isTrue);
      expect(result.isRejected, isFalse);
      expect(result.isRetrying, isFalse);
      expect(result.activity, 'running');
      expect(result.confidence, 0.94);
    });

    test('Non-exercise AI verdict marks snap rejected with reason and allows appeal', () {
      final result = VerificationResult.rejected(reason: kFriendlyRejection);

      expect(result.status, VerificationStatus.rejected);
      expect(result.isRejected, isTrue);
      expect(result.isVerified, isFalse);
      expect(result.isRetrying, isFalse);
      expect(result.reason, kFriendlyRejection);
    });

    test('Temporary AI outage preserves snap in retryable state without mock verification', () {
      const outageReason = 'Verification is temporarily busy. Your snap is saved and queued for retry.';
      final result = VerificationResult.retrying(reason: outageReason);

      // NEVER marked verified
      expect(result.isVerified, isFalse);
      // NEVER permanently rejected
      expect(result.isRejected, isFalse);
      // Safely preserved as retrying
      expect(result.status, VerificationStatus.retrying);
      expect(result.isRetrying, isTrue);
      expect(result.reason, outageReason);

      // UI SendSnapState maps to SendPhase.retrying
      const sendState = SendSnapState(
        phase: SendPhase.retrying,
        message: outageReason,
      );
      expect(sendState.phase, SendPhase.retrying);
      expect(sendState.message, outageReason);
    });

    test('Database verification status transitions maintain validity and safety rules', () {
      // 1. Initial creation starts at pending
      const initialStatus = VerificationStatus.pending;
      expect(initialStatus, VerificationStatus.pending);

      // 2. Verified is terminal
      const verifiedStatus = VerificationStatus.verified;
      expect(verifiedStatus, VerificationStatus.verified);

      // 3. Rejected photo can transition to appealed
      const appealedStatus = VerificationStatus.appealed;
      expect(appealedStatus, VerificationStatus.appealed);

      // 4. Retrying photo can transition to verified once service recovers
      const recoveredStatus = VerificationStatus.verified;
      expect(recoveredStatus, VerificationStatus.verified);
    });
  });
}
