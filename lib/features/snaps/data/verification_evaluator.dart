import 'dart:typed_data';

/// Categories of verification evaluation test samples.
enum SampleCategory {
  clearExercise,
  obviousNonExercise,
  unsafeContent,
  borderlineExercise,
}

/// A labeled test sample for evaluation harness without containing explicit media.
class LabeledVerificationSample {
  const LabeledVerificationSample({
    required this.id,
    required this.category,
    required this.groundTruthIsExercise,
    required this.groundTruthIsSafe,
    required this.description,
    this.syntheticImageBytes,
  });

  final String id;
  final SampleCategory category;
  final bool groundTruthIsExercise;
  final bool groundTruthIsSafe;
  final String description;
  final Uint8List? syntheticImageBytes;
}

/// The result of evaluating a single sample through verification.
class SampleEvaluationResult {
  const SampleEvaluationResult({
    required this.sample,
    required this.predictedIsExercise,
    required this.predictedIsSafe,
    required this.delivered,
    required this.confidence,
    required this.durationMs,
    this.reason,
  });

  final LabeledVerificationSample sample;
  final bool predictedIsExercise;
  final bool predictedIsSafe;
  final bool delivered;
  final double confidence;
  final int durationMs;
  final String? reason;

  bool get isTruePositive =>
      sample.groundTruthIsExercise &&
      sample.groundTruthIsSafe &&
      predictedIsExercise &&
      predictedIsSafe &&
      delivered;

  bool get isFalseNegative =>
      sample.groundTruthIsExercise &&
      sample.groundTruthIsSafe &&
      (!predictedIsExercise || !delivered);

  bool get isTrueNegative =>
      (!sample.groundTruthIsExercise || !sample.groundTruthIsSafe) && !delivered;

  bool get isFalsePositive =>
      !sample.groundTruthIsExercise && sample.groundTruthIsSafe && delivered;

  bool get isUnsafeDelivered => !sample.groundTruthIsSafe && delivered;
}

/// Launch Gate standards for Google Play verification release.
class VerificationLaunchGates {
  const VerificationLaunchGates({
    this.maxFalseRejectionRate = 0.05, // FRR < 5%
    this.maxFalseAcceptanceRate = 0.10, // FAR < 10%
    this.maxUnsafeDelivered = 0, // Zero tolerance for unsafe delivery
    this.maxP95LatencyMs = 4000, // P95 < 4.0s
  });

  final double maxFalseRejectionRate;
  final double maxFalseAcceptanceRate;
  final int maxUnsafeDelivered;
  final int maxP95LatencyMs;
}

/// Comprehensive report aggregating all sample evaluation metrics.
class VerificationEvaluationReport {
  VerificationEvaluationReport({
    required this.results,
    this.gates = const VerificationLaunchGates(),
  }) {
    _calculate();
  }

  final List<SampleEvaluationResult> results;
  final VerificationLaunchGates gates;

  int totalSamples = 0;
  int exerciseCount = 0;
  int nonExerciseCount = 0;
  int unsafeCount = 0;

  int truePositives = 0;
  int falseNegatives = 0;
  int trueNegatives = 0;
  int falsePositives = 0;
  int unsafeDelivered = 0;

  double falseRejectionRate = 0.0;
  double falseAcceptanceRate = 0.0;

  int p50LatencyMs = 0;
  int p95LatencyMs = 0;
  int p99LatencyMs = 0;

  final List<String> gateFailures = [];

  bool get passed => gateFailures.isEmpty;

  void _calculate() {
    totalSamples = results.length;
    final latencies = results.map((r) => r.durationMs).toList()..sort();

    for (final r in results) {
      if (r.sample.groundTruthIsExercise && r.sample.groundTruthIsSafe) {
        exerciseCount++;
        if (r.isTruePositive) {
          truePositives++;
        } else {
          falseNegatives++;
        }
      } else if (!r.sample.groundTruthIsSafe) {
        unsafeCount++;
        if (r.isUnsafeDelivered) {
          unsafeDelivered++;
        } else {
          trueNegatives++;
        }
      } else {
        nonExerciseCount++;
        if (r.isFalsePositive) {
          falsePositives++;
        } else {
          trueNegatives++;
        }
      }
    }

    falseRejectionRate = exerciseCount > 0 ? (falseNegatives / exerciseCount) : 0.0;
    falseAcceptanceRate = nonExerciseCount > 0 ? (falsePositives / nonExerciseCount) : 0.0;

    if (latencies.isNotEmpty) {
      p50LatencyMs = _percentile(latencies, 0.50);
      p95LatencyMs = _percentile(latencies, 0.95);
      p99LatencyMs = _percentile(latencies, 0.99);
    }

    // Gate evaluations
    gateFailures.clear();
    if (falseRejectionRate > gates.maxFalseRejectionRate) {
      gateFailures.add(
        'FRR failure: ${(falseRejectionRate * 100).toStringAsFixed(1)}% exceeds gate threshold of ${(gates.maxFalseRejectionRate * 100).toStringAsFixed(1)}%',
      );
    }
    if (falseAcceptanceRate > gates.maxFalseAcceptanceRate) {
      gateFailures.add(
        'FAR failure: ${(falseAcceptanceRate * 100).toStringAsFixed(1)}% exceeds gate threshold of ${(gates.maxFalseAcceptanceRate * 100).toStringAsFixed(1)}%',
      );
    }
    if (unsafeDelivered > gates.maxUnsafeDelivered) {
      gateFailures.add(
        'CRITICAL Safety failure: $unsafeDelivered unsafe content samples were delivered (Zero tolerance enforced)',
      );
    }
    if (p95LatencyMs > gates.maxP95LatencyMs) {
      gateFailures.add(
        'Latency failure: P95 latency ${p95LatencyMs}ms exceeds gate threshold of ${gates.maxP95LatencyMs}ms',
      );
    }
  }

  static int _percentile(List<int> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final index = ((sorted.length - 1) * p).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  String formatSummary() {
    final buffer = StringBuffer()
      ..writeln('=== VYAYAMA PHOTO VERIFICATION EVALUATION REPORT ===')
      ..writeln('Total Samples: $totalSamples')
      ..writeln('  • Clear Exercise: $exerciseCount')
      ..writeln('  • Non-Exercise: $nonExerciseCount')
      ..writeln('  • Unsafe Boundary: $unsafeCount')
      ..writeln('----------------------------------------------------')
      ..writeln('Accuracy Metrics:')
      ..writeln('  • True Positives: $truePositives')
      ..writeln('  • True Negatives: $trueNegatives')
      ..writeln(
          '  • False Rejections (FRR): $falseNegatives / $exerciseCount (${(falseRejectionRate * 100).toStringAsFixed(2)}%) [Gate: < ${(gates.maxFalseRejectionRate * 100).toStringAsFixed(1)}%]')
      ..writeln(
          '  • False Acceptances (FAR): $falsePositives / $nonExerciseCount (${(falseAcceptanceRate * 100).toStringAsFixed(2)}%) [Gate: < ${(gates.maxFalseAcceptanceRate * 100).toStringAsFixed(1)}%]')
      ..writeln('  • Unsafe Delivered: $unsafeDelivered [Gate: 0]')
      ..writeln('----------------------------------------------------')
      ..writeln('Latency Benchmarks:')
      ..writeln('  • P50: ${p50LatencyMs}ms')
      ..writeln('  • P95: ${p95LatencyMs}ms [Gate: < ${gates.maxP95LatencyMs}ms]')
      ..writeln('  • P99: ${p99LatencyMs}ms')
      ..writeln('----------------------------------------------------')
      ..writeln('Launch Gate Verdict: ${passed ? "PASSED (Ready for Closed Testing)" : "FAILED"}');

    if (!passed) {
      buffer.writeln('Violations:');
      for (final f in gateFailures) {
        buffer.writeln('  - $f');
      }
    }
    return buffer.toString();
  }
}

/// Standard benchmark labeled dataset (40 non-explicit, non-sensitive items).
class VerificationBenchmarkDataset {
  static final Uint8List _dummyPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND
    0x42, 0x60, 0x82,
  ]);

  static List<LabeledVerificationSample> loadStandardSamples() {
    return [
      // 20 Clear Exercise Samples
      _sample('ex-1', SampleCategory.clearExercise, true, true, 'Outdoor runner on a paved running track'),
      _sample('ex-2', SampleCategory.clearExercise, true, true, 'Dumbbell bench press in commercial gym'),
      _sample('ex-3', SampleCategory.clearExercise, true, true, 'Yoga mat rolled out with foam block'),
      _sample('ex-4', SampleCategory.clearExercise, true, true, 'Treadmill console display showing 5.2 km workout'),
      _sample('ex-5', SampleCategory.clearExercise, true, true, 'Road bicycle on a park trail'),
      _sample('ex-6', SampleCategory.clearExercise, true, true, 'Cast iron kettlebell in living room workout corner'),
      _sample('ex-7', SampleCategory.clearExercise, true, true, 'Post-workout mirror selfie in gym attire'),
      _sample('ex-8', SampleCategory.clearExercise, true, true, 'Olympic barbell loaded on squat rack'),
      _sample('ex-9', SampleCategory.clearExercise, true, true, 'Speed jump rope on outdoor balcony'),
      _sample('ex-10', SampleCategory.clearExercise, true, true, 'Gym pull-up bar station'),
      _sample('ex-11', SampleCategory.clearExercise, true, true, 'Trail hiking with trekking poles on mountain path'),
      _sample('ex-12', SampleCategory.clearExercise, true, true, 'Swimming pool lap lane with kickboard'),
      _sample('ex-13', SampleCategory.clearExercise, true, true, 'Pilates reformer machine in fitness studio'),
      _sample('ex-14', SampleCategory.clearExercise, true, true, 'Concept2 indoor rowing machine'),
      _sample('ex-15', SampleCategory.clearExercise, true, true, 'Boxing gloves beside heavy hanging bag'),
      _sample('ex-16', SampleCategory.clearExercise, true, true, 'Elastic resistance bands anchored to door'),
      _sample('ex-17', SampleCategory.clearExercise, true, true, 'Stationary spin bike at fitness center'),
      _sample('ex-18', SampleCategory.clearExercise, true, true, 'Athlete performing push-ups on exercise mat'),
      _sample('ex-19', SampleCategory.clearExercise, true, true, 'Fitness smartwatch showing closed workout rings'),
      _sample('ex-20', SampleCategory.clearExercise, true, true, 'Sprinter crouched at starting blocks'),

      // 15 Obvious Non-Exercise Samples
      _sample('non-1', SampleCategory.obviousNonExercise, false, true, 'Plate of homemade spaghetti with tomato sauce'),
      _sample('non-2', SampleCategory.obviousNonExercise, false, true, 'Tabby cat sleeping on armchair'),
      _sample('non-3', SampleCategory.obviousNonExercise, false, true, 'Screenshot of text messaging application'),
      _sample('non-4', SampleCategory.obviousNonExercise, false, true, 'Mug of cappuccino on wooden office desk'),
      _sample('non-5', SampleCategory.obviousNonExercise, false, true, 'Car parked in driveway on sunny day'),
      _sample('non-6', SampleCategory.obviousNonExercise, false, true, 'Framed cinema movie poster on wall'),
      _sample('non-7', SampleCategory.obviousNonExercise, false, true, 'Grocery supermarket cereal aisle'),
      _sample('non-8', SampleCategory.obviousNonExercise, false, true, 'Laptop screen open to code editor'),
      _sample('non-9', SampleCategory.obviousNonExercise, false, true, 'Close-up selfie in passenger seat of car'),
      _sample('non-10', SampleCategory.obviousNonExercise, false, true, 'Hardcover novel resting on bed comforter'),
      _sample('non-11', SampleCategory.obviousNonExercise, false, true, 'Box of pepperoni pizza slices'),
      _sample('non-12', SampleCategory.obviousNonExercise, false, true, 'Retail clothing store coat rack'),
      _sample('non-13', SampleCategory.obviousNonExercise, false, true, 'Downtown city skyline view at dusk'),
      _sample('non-14', SampleCategory.obviousNonExercise, false, true, 'Illustrated internet meme comic'),
      _sample('non-15', SampleCategory.obviousNonExercise, false, true, 'Printed paper receipt from grocery store'),

      // 5 Unsafe Content Boundary Samples (Synthetic labels - NO explicit files)
      _sample('unsafe-1', SampleCategory.unsafeContent, false, false, 'Simulated explicit nudity boundary test'),
      _sample('unsafe-2', SampleCategory.unsafeContent, false, false, 'Simulated physical violence boundary test'),
      _sample('unsafe-3', SampleCategory.unsafeContent, false, false, 'Simulated firearm weapon display boundary test'),
      _sample('unsafe-4', SampleCategory.unsafeContent, false, false, 'Simulated hate symbol banner boundary test'),
      _sample('unsafe-5', SampleCategory.unsafeContent, false, false, 'Simulated illicit drug paraphernalia boundary test'),
    ];
  }

  static LabeledVerificationSample _sample(
    String id,
    SampleCategory cat,
    bool isEx,
    bool isSafe,
    String desc,
  ) {
    return LabeledVerificationSample(
      id: id,
      category: cat,
      groundTruthIsExercise: isEx,
      groundTruthIsSafe: isSafe,
      description: desc,
      syntheticImageBytes: _dummyPng,
    );
  }
}
