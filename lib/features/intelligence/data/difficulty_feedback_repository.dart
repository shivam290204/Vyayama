import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/intelligence/domain/models/workout_difficulty_feedback.dart';

/// Contract for recording and querying post-workout difficulty ratings.
abstract interface class DifficultyFeedbackRepository {
  /// Records a difficulty rating. Prevents duplicate submissions for the same session.
  Future<void> recordFeedback(WorkoutDifficultyFeedback feedback);

  /// Lists difficulty feedback entries for [userId], newest first, optionally filtered by [since].
  Future<List<WorkoutDifficultyFeedback>> getFeedback(
    String userId, {
    DateTime? since,
  });

  /// Checks if feedback has already been submitted for this workout session.
  Future<WorkoutDifficultyFeedback?> getFeedbackForSession({
    required String userId,
    String? workoutLogId,
    required String planDayId,
    required DateTime sessionDate,
  });
}

/// SharedPreferences-backed local-first implementation of [DifficultyFeedbackRepository].
class SharedPrefsDifficultyFeedbackRepository
    implements DifficultyFeedbackRepository {
  SharedPrefsDifficultyFeedbackRepository({SharedPreferences? prefs})
      : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _asyncPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  String _key(String userId) => 'workout_difficulty_feedback_$userId';

  @override
  Future<void> recordFeedback(WorkoutDifficultyFeedback feedback) async {
    final cleanUid =
        feedback.userId.trim().isEmpty ? 'local_user' : feedback.userId.trim();
    try {
      final p = await _asyncPrefs;
      final existing = await getFeedback(cleanUid);

      // Check for duplicate submission
      final isDuplicate = existing.any((item) {
        if (feedback.workoutLogId != null &&
            item.workoutLogId != null &&
            feedback.workoutLogId == item.workoutLogId) {
          return true;
        }
        final d1 = item.completedAt.toLocal();
        final d2 = feedback.completedAt.toLocal();
        return item.planDayId == feedback.planDayId &&
            d1.year == d2.year &&
            d1.month == d2.month &&
            d1.day == d2.day;
      });

      if (isDuplicate) {
        debugPrint('[DifficultyFeedbackRepo] Duplicate feedback ignored for ${feedback.planDayId}');
        return;
      }

      final updated = [feedback, ...existing];
      // Keep trailing 100 entries to prevent unbounded local growth
      final trimmed = updated.take(100).toList();

      await p.setString(
        _key(cleanUid),
        jsonEncode([for (final f in trimmed) f.toJson()]),
      );
    } catch (e) {
      debugPrint('[DifficultyFeedbackRepo] Error recording feedback: $e');
    }
  }

  @override
  Future<List<WorkoutDifficultyFeedback>> getFeedback(
    String userId, {
    DateTime? since,
  }) async {
    final cleanUid = userId.trim().isEmpty ? 'local_user' : userId.trim();
    try {
      final p = await _asyncPrefs;
      final raw = p.getString(_key(cleanUid));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = decoded
              .map((item) => WorkoutDifficultyFeedback.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList();

          list.sort((a, b) => b.completedAt.compareTo(a.completedAt));

          if (since != null) {
            return list
                .where((f) =>
                    f.completedAt.isAfter(since) ||
                    f.completedAt.isAtSameMomentAs(since))
                .toList();
          }
          return list;
        }
      }
    } catch (e) {
      debugPrint('[DifficultyFeedbackRepo] Error loading feedback: $e');
    }
    return [];
  }

  @override
  Future<WorkoutDifficultyFeedback?> getFeedbackForSession({
    required String userId,
    String? workoutLogId,
    required String planDayId,
    required DateTime sessionDate,
  }) async {
    final list = await getFeedback(userId);
    final targetDay = sessionDate.toLocal();

    for (final item in list) {
      if (workoutLogId != null &&
          item.workoutLogId != null &&
          workoutLogId == item.workoutLogId) {
        return item;
      }
      final itemDay = item.completedAt.toLocal();
      if (item.planDayId == planDayId &&
          itemDay.year == targetDay.year &&
          itemDay.month == targetDay.month &&
          itemDay.day == targetDay.day) {
        return item;
      }
    }
    return null;
  }
}

