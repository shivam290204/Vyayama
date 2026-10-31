import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/services/gps_filter_service.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_recording_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_summary_screen.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Centralized controller and dialog for crash/interrupted workout recovery.
///
/// Prompts at the first appropriate application entry point on startup without
/// requiring manual navigation to [OutdoorRecordingScreen], prevents duplicate prompts,
/// and restores sessions in paused state without starting GPS recording automatically.
class OutdoorSessionRecoveryDialog {
  const OutdoorSessionRecoveryDialog._();

  /// Checks for an active unfinished workout checkpoint and presents the recovery dialog if found.
  ///
  /// Returns `true` if a recovery dialog was presented and handled, `false` otherwise.
  static Future<bool> promptIfNeeded(
    BuildContext context,
    WidgetRef ref, {
    void Function()? onNavigateToRecord,
    void Function(OutdoorActivity activity)? onNavigateToSummary,
  }) async {
    final recoveryService = ref.read(outdoorSessionRecoveryServiceProvider);
    if (recoveryService.hasPromptedThisLaunch) {
      return false;
    }

    final trackingService = ref.read(locationTrackingServiceProvider);
    if (trackingService.value.status == OutdoorActivityStatus.active ||
        trackingService.value.status == OutdoorActivityStatus.paused) {
      return false;
    }

    final checkpoint = await recoveryService.getActiveCheckpoint();
    if (checkpoint == null || !context.mounted) {
      return false;
    }

    // Mark prompted for this launch session immediately to prevent duplicate dialogs
    recoveryService.markPromptedThisLaunch();

    final durationMins = checkpoint.durationSeconds ~/ 60;
    final durationSecs = checkpoint.durationSeconds % 60;
    final timeStr =
        '${durationMins.toString().padLeft(2, '0')}:${durationSecs.toString().padLeft(2, '0')}';
    final distKm = (checkpoint.distanceMeters / 1000.0).toStringAsFixed(2);

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Unfinished Workout Detected'),
        content: Text(
          'Vyayama recovered an unfinished ${checkpoint.activityType.label} workout ($distKm km, $timeStr) from your last session.\n\nWould you like to resume, save, or discard it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            style: TextButton.styleFrom(foregroundColor: AppPalette.deepCoral),
            child: const Text('Discard'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Save Portion'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('resume'),
            style: FilledButton.styleFrom(backgroundColor: AppPalette.forestGreen),
            child: const Text('Resume'),
          ),
        ],
      ),
    );

    if (!context.mounted || action == null) return true;

    if (action == 'resume') {
      // 1. Restore session into memory in PAUSED state (clock stopped, GPS not active)
      await trackingService.restoreSession(checkpoint);

      if (context.mounted) {
        if (onNavigateToRecord != null) {
          onNavigateToRecord();
        } else {
          // Navigate directly to OutdoorRecordingScreen if not already there
          final currentModal = ModalRoute.of(context)?.settings.name;
          if (currentModal != AppRoutes.mapsRecord) {
            try {
              context.push(AppRoutes.mapsRecord);
            } catch (_) {
              try {
                Navigator.of(context).pushNamed(AppRoutes.mapsRecord);
              } catch (_) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OutdoorRecordingScreen(),
                  ),
                );
              }
            }
          }
        }
      }
    } else if (action == 'save') {
      // 2. Save portion as completed activity and navigate to summary
      final repo = ref.read(outdoorActivityRepositoryProvider);
      final activity = OutdoorActivity(
        id: checkpoint.activityId,
        userId: 'local_user',
        activityType: checkpoint.activityType,
        startTime: checkpoint.startTime,
        endTime: DateTime.now(),
        durationSeconds: checkpoint.durationSeconds,
        distanceMeters: checkpoint.distanceMeters,
        averagePaceSecondsPerKm: GpsFilterService.forActivity(checkpoint.activityType)
            .calculateAveragePaceSeconds(
                checkpoint.distanceMeters, checkpoint.durationSeconds),
        averageSpeedKmh: GpsFilterService.forActivity(checkpoint.activityType)
            .calculateAverageSpeedKmh(
                checkpoint.distanceMeters, checkpoint.durationSeconds),
        points: checkpoint.points,
        elevationGainMeters: checkpoint.elevationGainMeters,
        caloriesBurned: (checkpoint.activityType.met *
                70.0 *
                (checkpoint.durationSeconds / 3600.0))
            .round(),
        status: OutdoorActivityStatus.completed,
        title: '${checkpoint.activityType.label} Workout',
        isSynced: false,
      );

      await repo.saveActivity(activity);
      await recoveryService.clearCheckpoint();

      if (context.mounted) {
        if (onNavigateToSummary != null) {
          onNavigateToSummary(activity);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OutdoorSummaryScreen(activity: activity),
            ),
          );
        }
      }
    } else if (action == 'discard') {
      // 3. Confirm before permanent discard
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Discard'),
          content: const Text(
            'Are you sure you want to discard this recovered workout? All tracked data will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppPalette.deepCoral),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard Permanently'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await recoveryService.clearCheckpoint();
      }
    }

    return true;
  }
}

