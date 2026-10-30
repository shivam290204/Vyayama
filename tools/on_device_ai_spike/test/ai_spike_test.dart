import 'package:flutter_test/flutter_test.dart';

import '../benchmark/ai_benchmark_runner.dart';
import '../domain/ai_coach_contracts.dart';
import '../runtime/llama_cpp_runtime.dart';
import '../runtime/local_llm_runtime.dart';

void main() {
  group('On-Device AI Spike — Runtime Lifecycle Tests', () {
    late LlamaCppRuntime runtime;

    setUp(() {
      runtime = LlamaCppRuntime();
    });

    test('Loads local GGUF model and tracks memory allocation correctly', () async {
      expect(runtime.isLoaded, isFalse);
      expect(runtime.memoryAllocatedBytes, 0);

      await runtime.loadModel(
        modelPath: 'models/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        contextSize: 2048,
        threadCount: 4,
      );

      expect(runtime.isLoaded, isTrue);
      expect(runtime.memoryAllocatedBytes, greaterThan(350 * 1024 * 1024)); // >350 MB
    });

    test('Throws ModelLoadException when file header is corrupted or invalid', () async {
      expect(
        () => runtime.loadModel(modelPath: 'models/corrupted_weights.gguf'),
        throwsA(isA<ModelLoadException>()),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('Throws InsufficientMemoryException when RAM budget is exceeded', () async {
      // Simulate low-memory device where available RAM is only 200 MB
      const lowMemoryBudget = 200 * 1024 * 1024;

      expect(
        () => runtime.loadModel(
          modelPath: 'models/qwen2.5-0.5b-instruct-q4_k_m.gguf',
          maxAvailableMemoryBytes: lowMemoryBudget,
        ),
        throwsA(isA<InsufficientMemoryException>()),
      );
      expect(runtime.isLoaded, isFalse);
    });

    test('Properly unloads and frees all allocated memory', () async {
      await runtime.loadModel(modelPath: 'models/qwen2.5-0.5b-instruct-q4_k_m.gguf');
      expect(runtime.isLoaded, isTrue);

      await runtime.unload();
      expect(runtime.isLoaded, isFalse);
      expect(runtime.memoryAllocatedBytes, 0);
    });
  });

  group('On-Device AI Spike — Offline Inference & Structured JSON Tests', () {
    late LlamaCppRuntime runtime;

    setUp(() async {
      runtime = LlamaCppRuntime();
      await runtime.loadModel(modelPath: 'models/qwen2.5-0.5b-instruct-q4_k_m.gguf');
    });

    tearDown(() async {
      await runtime.unload();
    });

    test('Generates valid structured JSON using only synthetic context', () async {
      const syntheticContext = SyntheticFitnessUserContext(
        goal: 'General Fitness',
        fitnessLevel: 'Beginner',
        availableTimeMinutes: 20,
        equipment: ['Dumbbells'],
        workoutsCompletedThisWeek: 2,
        weeklyTarget: 3,
        lastWorkoutFeedback: 'too_hard',
      );

      final runner = AiBenchmarkRunner(runtime: runtime);
      final result = await runner.runBenchmark(
        modelName: 'Qwen2.5-0.5B-Instruct-Q4_K_M',
        modelPath: 'models/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        userContext: syntheticContext,
      );

      expect(result.jsonValid, isTrue);
      expect(result.safetyGuardrailsPassed, isTrue);
      expect(result.response.durationMinutes, 20);
      expect(result.response.intensityLevel, 'gentle');
      expect(result.response.isRecovery, isTrue);
      expect(result.response.recommendedWorkoutTitle, contains('Gentle Mobility'));
      expect(result.response.reasoning, contains('difficult'));
    });

    test('Steers to progressive overload when previous session was too_easy', () async {
      const easyContext = SyntheticFitnessUserContext(
        goal: 'Muscle Growth',
        fitnessLevel: 'Intermediate',
        availableTimeMinutes: 30,
        equipment: ['Dumbbells'],
        workoutsCompletedThisWeek: 2,
        weeklyTarget: 3,
        lastWorkoutFeedback: 'too_easy',
      );

      final runner = AiBenchmarkRunner(runtime: runtime);
      final result = await runner.runBenchmark(
        modelName: 'Qwen2.5-0.5B-Instruct-Q4_K_M',
        modelPath: 'models/qwen2.5-0.5b-instruct-q4_k_m.gguf',
        userContext: easyContext,
      );

      expect(result.jsonValid, isTrue);
      expect(result.response.intensityLevel, 'challenging');
      expect(result.response.isRecovery, isFalse);
      expect(result.response.recommendedWorkoutTitle, contains('Overload'));
    });
  });

  group('On-Device AI Spike — Safety Guardrail Tests', () {
    test('Catches duration violation when AI exceeds user available time', () {
      const userContext = SyntheticFitnessUserContext(
        goal: 'Stay Fit',
        fitnessLevel: 'Beginner',
        availableTimeMinutes: 15,
        equipment: ['Bodyweight'],
        workoutsCompletedThisWeek: 1,
        weeklyTarget: 3,
        lastWorkoutFeedback: 'just_right',
      );

      const invalidResponse = AiCoachResponse(
        recommendedWorkoutTitle: 'Long Circuit',
        durationMinutes: 45, // Exceeds 15 minutes!
        intensityLevel: 'moderate',
        reasoning: 'Standard workout',
        safetyNotes: [],
        isRecovery: false,
        rawOutput: '{}',
        generationLatencyMs: 200,
        tokensPerSecond: 15.0,
        peakMemoryBytes: 400000000,
      );

      final (isValid, violations) = AiSafetyGuardrails.validate(
        response: invalidResponse,
        userContext: userContext,
      );

      expect(isValid, isFalse);
      expect(violations.first, contains('exceeds user available time'));
    });

    test('Catches prohibited medical diagnosis claims', () {
      const userContext = SyntheticFitnessUserContext(
        goal: 'Rehab',
        fitnessLevel: 'Beginner',
        availableTimeMinutes: 20,
        equipment: ['Bodyweight'],
        workoutsCompletedThisWeek: 0,
        weeklyTarget: 3,
        lastWorkoutFeedback: 'just_right',
      );

      const unverifiedResponse = AiCoachResponse(
        recommendedWorkoutTitle: 'Back Session',
        durationMinutes: 20,
        intensityLevel: 'gentle',
        reasoning: 'This exercise will diagnose and cure your scoliosis.',
        safetyNotes: [],
        isRecovery: true,
        rawOutput: '{}',
        generationLatencyMs: 200,
        tokensPerSecond: 15.0,
        peakMemoryBytes: 400000000,
      );

      final (isValid, violations) = AiSafetyGuardrails.validate(
        response: unverifiedResponse,
        userContext: userContext,
      );

      expect(isValid, isFalse);
      expect(violations.any((v) => v.contains('Prohibited medical terminology')), isTrue);
    });
  });
}
