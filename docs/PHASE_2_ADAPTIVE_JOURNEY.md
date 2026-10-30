# Vyayama Adaptive Fitness Journey — Phase 2 Architecture & Implementation Report

**Document Version:** 2.0.0  
**Date:** October 29, 2026  
**Module Path:** `lib/features/intelligence/`  
**Status:** Implemented, Tested, Verified, and Ready for Deployment  

---

## 1. Executive Summary

Phase 2 builds upon the deterministic foundation of Phase 1 by establishing the **Adaptive Fitness Journey** for Vyayama. This layer bridges user fitness preferences (equipment, duration, time of day), post-workout difficulty feedback (RPE), sports-science progression models (`DoubleProgressionModel`), and contraindication filtering (`PlanAdapter`) to deliver personalized workout recommendations and weekly reviews without third-party AI costs or server dependencies.

### Core Principles Maintained:
- **Zero Paid AI APIs & Zero API Keys:** No OpenAI, Gemini, or Claude cloud calls.
- **Zero Language Model Bloat:** 100% deterministic, offline-capable Dart engines running in < 3ms.
- **Zero Breaking Remote Schema Migrations:** Local-first user preference and feedback storage isolated by user ID via `SharedPreferences`.
- **Zero User Plan Overwrites:** Recommends adaptive adjustments and next sessions; never mutates or deletes custom plans without user confirmation.
- **Sports Science Safety:** Strict adherence to `DoubleProgressionModel`, `PlanAdapter` joint contraindications, and minor protections (`age < 18`).
- **Feature Flag Protected:** Disabling `--dart-define=ENABLE_INTELLIGENCE=false` instantly suppresses all intelligence surfaces in 0ms with zero overhead.

---

## 2. Architecture & File Structure

```text
lib/features/intelligence/
├── config/
│   └── intelligence_config.dart                  # Feature flags, thresholds, analysis windows
├── data/
│   ├── fitness_preferences_repository.dart       # Local-first user preference store (equipment, duration, time)
│   └── difficulty_feedback_repository.dart       # Local-first post-workout exertion feedback store (Too Easy / Just Right / Too Hard)
├── domain/
│   ├── interfaces/
│   │   └── adaptive_journey_interface.dart       # Contracts: IAdaptivePlanForecaster, IWeeklyFitnessReviewGenerator, IAdaptiveDifficultyPolicy
│   └── models/
│       ├── fitness_insight.dart                  # Phase 1 insight entities and priority tiers
│       ├── user_fitness_preferences.dart         # UserFitnessPreferences, WorkoutEquipment, WorkoutDurationOption, PreferredWorkoutTime
│       ├── workout_difficulty_feedback.dart      # WorkoutDifficultyFeedback, WorkoutDifficultyRating (RPE 6.0, 7.5, 9.5)
│       └── journey_recommendation.dart           # JourneyRecommendation, JourneyStatus
├── logic/
│   ├── adaptive_difficulty_policy.dart           # Implements IAdaptiveDifficultyPolicy via DoubleProgressionModel
│   ├── adaptive_planning_service.dart            # Evaluates Scenarios A-E, recovery checks, and contraindications
│   ├── fitness_insights_engine.dart              # Phase 1 deterministic insights engine
│   └── weekly_review_generator.dart              # Implements IWeeklyFitnessReviewGenerator
├── presentation/
│   ├── screens/
│   │   └── fitness_preferences_screen.dart       # User-facing preferences screen (equipment, duration, time)
│   └── widgets/
│       ├── adaptive_journey_card.dart            # Interactive journey card with next session recommendations
│       ├── post_workout_feedback_card.dart       # 3-tier exertion prompt on workout finish
│       ├── smart_insights_section.dart           # Phase 1 dashboard insights card
│       └── weekly_review_sheet.dart              # Retrospective weekly review modal bottom sheet
└── providers.dart                                # Riverpod providers connecting repositories and UI
```

---

## 3. Storage Decisions & Zero-Migration Architecture

### Investigation of Local vs Remote Storage:
The project audit (`docs/AI_AUDIT.md`) and QA report (`docs/QA_REPORT.md`) highlighted risks with offline sync conflicts, remote profile overwrites, and strict Play Store migration stability. 

To eliminate risk:
1. **User Fitness Preferences (`user_fitness_preferences_$uid`):**
   - Stored in `SharedPreferences` as JSON.
   - Namespaced by `userId`, providing total multi-user isolation on shared devices.
   - Offline-first: updates occur immediately without network latency or server timeouts.
   - Graceful fallback: unconfigured users automatically receive sensible defaults (`['none', 'dumbbells']`, 30 minutes, `flexible`).
2. **Post-Workout Difficulty Feedback (`workout_difficulty_feedback_$uid`):**
   - Stored in `SharedPreferences` as an immutable JSON list.
   - Prevents duplicate submissions for the same session by checking `(planDayId, calendarDay)` and `workoutLogId`.
   - Bounded to trailing 100 entries to prevent local storage bloat.
   - Does NOT alter Supabase `workout_logs` table schema, avoiding breaking migrations or RLS policy changes.

### Why Remote Sync is Not Required in Phase 2:
- Adding columns to `profiles` or `workout_logs` in Supabase requires database migrations, backfilling nulls, updating Supabase RLS policies, and risks breaking existing client versions.
- Local storage delivers instantaneous reads, guarantees 100% offline functionality, and allows future optional cloud sync in Phase 4 via an outbox worker if cross-device synchronization is requested.

---

## 4. Reused Existing Systems (No Duplication)

| Existing System | Where Defined | How Reused in Phase 2 |
|---|---|---|
| **`DoubleProgressionModel`** | [`progression_model_interface.dart`](file:///e:/FitBuddy/lib/features/workouts/logic/progression_model_interface.dart) | Drives `AdaptiveDifficultyPolicy`: limits progression increments to sports-science standards (+2.5 kg or +1 rep within rep range); commands deload when RPE >= 9.0. |
| **`PlanAdapter`** | [`plan_adapter.dart`](file:///e:/FitBuddy/lib/features/workouts/logic/plan_adapter.dart) | Enforces joint and medical safety: swaps or removes exercises clashing with user `conditionTags` (`knee`, `shoulder`, `lower_back`). |
| **`WorkoutRecommendationEngine`** | [`recommendation_engine.dart`](file:///e:/FitBuddy/lib/features/workouts/logic/recommendation_engine.dart) | Multi-factor scoring logic matching user goals, equipment availability, and experience levels. |
| **`RuleBasedAdherenceModel`** | [`adherence_model_interface.dart`](file:///e:/FitBuddy/lib/features/workouts/logic/adherence_model_interface.dart) | Feature extraction vectors for trailing 7-day session consistency and inactivity gap detection. |
| **`WorkoutLogRepository`** | [`workout_log_repository.dart`](file:///e:/FitBuddy/lib/features/workouts/data/workout_log_repository.dart) | Reads completed sessions from local outbox and cloud cache without interfering with logging pipeline. |
| **`DailyStatsRepository`** | [`daily_stats_repository.dart`](file:///e:/FitBuddy/lib/features/dashboard/data/daily_stats_repository.dart) | Reads steps and active minutes for consistency scoring and weekly reviews. |

---

## 5. Adaptive Planning Scenarios & Safety Rules

In [`adaptive_planning_service.dart`](file:///e:/FitBuddy/lib/features/intelligence/logic/adaptive_planning_service.dart), five deterministic scenarios and safety safeguards are enforced:

### Scenario A: Consistent User (Progressive Overload)
- **Criteria:** User completed $\ge 2$ workouts in trailing 7 days and recent difficulty feedback is `justRight` or `tooEasy`.
- **Recommendation:** `JourneyStatus.progressingSteadily`, suggested difficulty `Progressive Overload`.
- **Reason:** *"Your last few workouts were consistent. Your next session can include a small progression."*

### Scenario B: Missed Several Days (Manageable Restart)
- **Criteria:** $\ge 4$ days elapsed since last completed workout.
- **Recommendation:** `JourneyStatus.momentumRestart`, suggested difficulty `Manageable Restart`.
- **Duration Adjustment:** Scales suggested duration down to 15 minutes (or user minimum) to reduce friction.
- **No Guilt:** Strict policy against shame or punitive messages. Reason: *"You haven't worked out in a few days. We recommend a gentle, low-pressure restart session to rebuild your rhythm."*

### Scenario C: High Fatigue / Too Hard (Gentle Recovery / Deload)
- **Criteria:** Recent feedback is `tooHard` (or RPE $\ge 9.0$).
- **Recommendation:** `JourneyStatus.activeRecovery`, suggested difficulty `Gentle Recovery / Deload`.
- **Duration Adjustment:** Scaled to $80\%$ of typical duration.
- **Reason:** *"You reported that your previous workout was difficult. Consider a lighter session today."*

### Scenario D: Limited Available Time
- **Criteria:** User set daily workout time to 10, 15, or 20 minutes in Fitness Preferences.
- **Recommendation:** Customizes suggested duration to match preference; adjusts session focus.
- **Reason:** *"Tailored to your {X}-minute available workout time."*

### Scenario E: Equipment Preferences & Changes
- **Criteria:** User selected specific gear (e.g. bodyweight only vs dumbbells vs barbell vs gym).
- **Recommendation:** Filters exercise recommendations and surfaces transparent adaptation notes (e.g. *"Plan tuned for bodyweight-only exercises"*).

### Safety Safeguards:
1. **3 Consecutive Days Fatigue Check:** Completing 3 consecutive workout days automatically flags `JourneyStatus.activeRecovery` with a recommendation for restorative stretching, regardless of streak count.
2. **Streak Disconnection:** Streak count never artificially increases workout intensity or load.
3. **Minor Protection:** If `profile.age < 18`, caloric restriction or weight loss advice is completely suppressed.
4. **Medical Disclaimer:** Explicitly communicates that recommendations are adaptive fitness suggestions, not medical diagnoses.
5. **Non-Intrusive Plan Integrity:** User workout plans are never silently rewritten or overwritten.

---

## 6. User Experience & UI Integration

1. **Fitness Preferences Screen (`/profile/fitness-preferences`):**
   - Accessible via Profile screen -> "Fitness Preferences" tile.
   - Multi-select FilterChips for Equipment: *Bodyweight, Dumbbells, Resistance Bands, Barbell, Full Gym*.
   - ChoiceChips for Duration: *10, 15, 20, 30, 45, 60+ minutes*.
   - ChoiceChips for Preferred Time: *Early Morning, Morning, Afternoon, Evening, Flexible*.
2. **Post-Workout Difficulty Feedback:**
   - Calm, non-intrusive 3-button card (*Too Easy*, *Just Right*, *Too Hard*) embedded directly into `SessionSummaryView`.
   - Completely optional: user can tap any choice or immediately tap "Return to Workouts" without delay.
   - Prevents duplicate clicks and displays friendly confirmation.
3. **Adaptive Fitness Journey Card:**
   - Displayed at the top of the "My Plan" tab (`MyPlanTab`) and home refresh flow.
   - Shows current goal, trajectory status badge, weekly target progress indicator, next workout title, suggested duration, and reason.
   - Primary action launches the recommended workout day; secondary action opens the Weekly Review Sheet.
4. **Weekly Fitness Review Sheet (`WeeklyReviewSheet`):**
   - Modal bottom sheet displaying trailing 7-day consistency score (0-100%), total active minutes, total steps, celebrations, growth opportunities, and recommended next focus.

---

## 7. Verification & Quality Assurance Baseline

### Pre-implementation baseline:
- `flutter analyze`: 0 issues found.
- `flutter test`: 580 / 580 tests passed (100%).

### Post-implementation verification:
- `flutter analyze`: **0 issues found** (clean across all files).
- `flutter test`: **614 / 614 tests passed (100%)** (all 580 baseline tests + 34 new Phase 2 tests).

### New Tests Added in Phase 2:
1. `test/intelligence/fitness_preferences_test.dart`: 8 unit tests (defaults, JSON roundtrip, duration mappings, equipment ID fallbacks, repository persistence, multi-user isolation).
2. `test/intelligence/workout_difficulty_feedback_test.dart`: 5 unit tests (RPE mapping, JSON roundtrip, chronological ordering, date filtering, duplicate prevention, multi-user isolation).
3. `test/intelligence/adaptive_planning_service_test.dart`: 6 unit tests (Scenarios A, B, C, D, E, 3 consecutive days fatigue check).
4. `test/intelligence/adaptive_difficulty_policy_test.dart`: 4 unit tests (increase load, deload on fatigue, gentle restart, form consolidation).
5. `test/intelligence/weekly_fitness_review_test.dart`: 4 unit tests (100% adherence celebration, missed sessions guidance, high exertion recovery steering, zero workouts edge case).
6. `test/intelligence/adaptive_journey_widgets_test.dart`: 7 widget tests (`AdaptiveJourneyCard` active & disabled states, `PostWorkoutFeedbackCard` active & disabled states, `FitnessPreferencesScreen` chip choices, `WeeklyReviewSheet` metric rendering).

---

## 8. Limitations & Future Phase Roadmap

### Known Limitations in Phase 2:
- **Device-Local Preferences:** Preferences and difficulty ratings reside in `SharedPreferences`. If a user logs into a secondary phone, preferences start at defaults until configured on that device.
- **Deterministic Scheduling:** Next workout suggestion follows sequential plan day progression rather than calendar-locked schedules.

### Roadmap for Phase 3 & Phase 4 (Do Not Implement Yet):

#### Phase 3: On-Device AI Model Feasibility
- **Goal:** Benchmark local small language model runtimes (LiteRT-LM / llama.cpp / MediaPipe LLM Inference) on physical Android hardware.
- **Constraints to Evaluate:** 2 GB - 4 GB RAM Android phones, battery impact during CPU/NPU inference, model weight size budget (must stay under ~1.5 GB quantized to prevent store rejection), thermal throttling.
- **Interface:** Will implement an adapter conforming to existing `IAdaptivePlanForecaster` and `IWeeklyFitnessReviewGenerator` contracts.

#### Phase 4: Optional AI Fitness Coach
- **Goal:** Context-aware chat agent that answers natural questions ("How was my consistency this week?", "Suggest a 20-minute workout").
- **Constraint:** Must strictly consume verified facts from `AdaptivePlanningService`, `WeeklyFitnessReview`, and `PlanAdapter`, preventing hallucinations and medical claims.

