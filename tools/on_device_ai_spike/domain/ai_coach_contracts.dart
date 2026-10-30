/// Synthetic user context representing fitness facts passed into the AI Coach.
///
/// Strictly synthetic for benchmarking; never reads real user health data.
class SyntheticFitnessUserContext {
  const SyntheticFitnessUserContext({
    required this.goal,
    required this.fitnessLevel,
    required this.availableTimeMinutes,
    required this.equipment,
    required this.workoutsCompletedThisWeek,
    required this.weeklyTarget,
    required this.lastWorkoutFeedback,
    this.conditionTags = const [],
  });

  final String goal;
  final String fitnessLevel;
  final int availableTimeMinutes;
  final List<String> equipment;
  final int workoutsCompletedThisWeek;
  final int weeklyTarget;
  final String lastWorkoutFeedback; // 'too_easy', 'just_right', 'too_hard'
  final List<String> conditionTags;

  String toFormattedPrompt() {
    return '''
[USER FITNESS FACTS]
- Fitness Goal: $goal
- Experience Level: $fitnessLevel
- Available Time: $availableTimeMinutes minutes
- Available Equipment: ${equipment.join(', ')}
- Workouts This Week: $workoutsCompletedThisWeek of $weeklyTarget completed
- Last Workout Difficulty Feedback: $lastWorkoutFeedback
- Health Cautions: ${conditionTags.isEmpty ? 'None' : conditionTags.join(', ')}
''';
  }
}

/// Structured response schema expected from the local AI Coach.
class AiCoachResponse {
  const AiCoachResponse({
    required this.recommendedWorkoutTitle,
    required this.durationMinutes,
    required this.intensityLevel,
    required this.reasoning,
    required this.safetyNotes,
    required this.isRecovery,
    required this.rawOutput,
    required this.generationLatencyMs,
    required this.tokensPerSecond,
    required this.peakMemoryBytes,
  });

  factory AiCoachResponse.fromJson(
    Map<String, dynamic> json, {
    required String rawOutput,
    required int latencyMs,
    required double tokensPerSec,
    required int memoryBytes,
  }) {
    return AiCoachResponse(
      recommendedWorkoutTitle:
          json['recommended_workout']?.toString() ?? 'General Active Session',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 20,
      intensityLevel: json['intensity']?.toString() ?? 'moderate',
      reasoning: json['reasoning']?.toString() ?? '',
      safetyNotes: (json['safety_notes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isRecovery: (json['is_recovery'] as bool?) ?? false,
      rawOutput: rawOutput,
      generationLatencyMs: latencyMs,
      tokensPerSecond: tokensPerSec,
      peakMemoryBytes: memoryBytes,
    );
  }

  final String recommendedWorkoutTitle;
  final int durationMinutes;
  final String intensityLevel;
  final String reasoning;
  final List<String> safetyNotes;
  final bool isRecovery;
  final String rawOutput;
  final int generationLatencyMs;
  final double tokensPerSecond;
  final int peakMemoryBytes;

  Map<String, dynamic> toJson() => {
        'recommended_workout': recommendedWorkoutTitle,
        'duration_minutes': durationMinutes,
        'intensity': intensityLevel,
        'reasoning': reasoning,
        'safety_notes': safetyNotes,
        'is_recovery': isRecovery,
      };
}

/// Safety guardrails validating that the local LLM adheres strictly to sports-science boundaries.
abstract final class AiSafetyGuardrails {
  static (bool isValid, List<String> violations) validate({
    required AiCoachResponse response,
    required SyntheticFitnessUserContext userContext,
  }) {
    final violations = <String>[];

    // 1. Duration guardrail: Cannot exceed user available time
    if (response.durationMinutes > userContext.availableTimeMinutes) {
      violations.add(
        'Duration (${response.durationMinutes}m) exceeds user available time (${userContext.availableTimeMinutes}m)',
      );
    }

    // 2. Recovery guardrail: If last workout was 'too_hard', intensity cannot be 'challenging'
    if (userContext.lastWorkoutFeedback.toLowerCase() == 'too_hard' &&
        response.intensityLevel.toLowerCase() == 'challenging') {
      violations.add(
        'Intensity is challenging despite recent "Too Hard" feedback; recovery or gentle pace required',
      );
    }

    // 3. Invented medical claim guardrail: Scan reasoning for prohibited medical diagnosis keywords
    final lowerReason = response.reasoning.toLowerCase();
    const prohibitedKeywords = ['diagnose', 'cure', 'prescribe', 'medical treatment', 'doctor ordered'];
    for (final kw in prohibitedKeywords) {
      if (lowerReason.contains(kw)) {
        violations.add('Prohibited medical terminology found: "$kw"');
      }
    }

    // 4. Invented calorie claim guardrail: Calorie calculations must remain deterministic
    if (lowerReason.contains('exact calories') || lowerReason.contains('guaranteed fat burn')) {
      violations.add('Unauthorized deterministic calorie/fat guarantee in reasoning');
    }

    return (violations.isEmpty, violations);
  }
}
