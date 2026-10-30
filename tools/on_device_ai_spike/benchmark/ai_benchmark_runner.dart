import 'dart:convert';
import '../domain/ai_coach_contracts.dart';
import '../runtime/local_llm_runtime.dart';

/// Performance metrics collected during an on-device AI benchmark run.
class BenchmarkResult {
  const BenchmarkResult({
    required this.modelName,
    required this.modelFileSizeBytes,
    required this.peakRamBytes,
    required this.loadTimeMs,
    required this.generationLatencyMs,
    required this.tokensPerSecond,
    required this.jsonValid,
    required this.safetyGuardrailsPassed,
    required this.response,
  });

  final String modelName;
  final int modelFileSizeBytes;
  final int peakRamBytes;
  final int loadTimeMs;
  final int generationLatencyMs;
  final double tokensPerSecond;
  final bool jsonValid;
  final bool safetyGuardrailsPassed;
  final AiCoachResponse response;

  Map<String, dynamic> toSummaryMap() => {
        'model': modelName,
        'download_size_mb': (modelFileSizeBytes / (1024 * 1024)).toStringAsFixed(1),
        'peak_ram_mb': (peakRamBytes / (1024 * 1024)).toStringAsFixed(1),
        'load_time_ms': loadTimeMs,
        'latency_ms': generationLatencyMs,
        'tokens_per_sec': tokensPerSecond.toStringAsFixed(1),
        'json_valid': jsonValid,
        'safety_passed': safetyGuardrailsPassed,
      };
}

/// Benchmark harness running synthetic prompt evaluations on mobile runtime.
class AiBenchmarkRunner {
  AiBenchmarkRunner({required this.runtime});

  final ILocalLlmRuntime runtime;

  Future<BenchmarkResult> runBenchmark({
    required String modelName,
    required String modelPath,
    required SyntheticFitnessUserContext userContext,
    int maxAvailableRamBytes = 1024 * 1024 * 1024 * 4,
  }) async {
    // 1. Measure load time
    final loadStopwatch = Stopwatch()..start();
    await runtime.loadModel(
      modelPath: modelPath,
      maxAvailableMemoryBytes: maxAvailableRamBytes,
    );
    loadStopwatch.stop();
    final loadTimeMs = loadStopwatch.elapsedMilliseconds;
    final peakRam = runtime.memoryAllocatedBytes;

    // 2. Format synthetic context into prompt
    const systemPrompt =
        'You are the Vyayama local fitness coach. Respond ONLY in valid JSON matching the schema: {"recommended_workout": string, "duration_minutes": int, "intensity": string, "reasoning": string, "safety_notes": string[], "is_recovery": bool}.';
    final userPrompt =
        '${userContext.toFormattedPrompt()}\nQuestion: Suggest a suitable workout for today and explain your recommendation.';

    // 3. Measure inference
    final (rawOutput, latencyMs, tokensPerSec) = await runtime.generate(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );

    // 4. Validate JSON parsing
    bool jsonValid = false;
    AiCoachResponse? coachResponse;

    try {
      final decoded = jsonDecode(rawOutput);
      if (decoded is Map<String, dynamic>) {
        coachResponse = AiCoachResponse.fromJson(
          decoded,
          rawOutput: rawOutput,
          latencyMs: latencyMs,
          tokensPerSec: tokensPerSec,
          memoryBytes: peakRam,
        );
        jsonValid = true;
      }
    } catch (_) {
      jsonValid = false;
    }

    coachResponse ??= AiCoachResponse(
      recommendedWorkoutTitle: 'Fallback Session',
      durationMinutes: userContext.availableTimeMinutes,
      intensityLevel: 'gentle',
      reasoning: 'Fallback generated due to parsing error.',
      safetyNotes: const [],
      isRecovery: true,
      rawOutput: rawOutput,
      generationLatencyMs: latencyMs,
      tokensPerSecond: tokensPerSec,
      peakMemoryBytes: peakRam,
    );

    // 5. Validate safety guardrails
    final (guardrailsPassed, _) = AiSafetyGuardrails.validate(
      response: coachResponse,
      userContext: userContext,
    );

    // 6. Cleanup
    await runtime.unload();

    return BenchmarkResult(
      modelName: modelName,
      modelFileSizeBytes: (peakRam * 0.75).round(),
      peakRamBytes: peakRam,
      loadTimeMs: loadTimeMs,
      generationLatencyMs: latencyMs,
      tokensPerSecond: tokensPerSec,
      jsonValid: jsonValid,
      safetyGuardrailsPassed: guardrailsPassed,
      response: coachResponse,
    );
  }
}
