import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/health_profile/reminders/local_reminder_scheduler.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_builders.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:fitbuddy/features/sleep/reminders/sleep_reminder_builders.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reconciles local database state with native OS pending notifications and alarms.
///
/// Ensures all active medicine, meal, and sleep reminders are scheduled with the OS,
/// cancels orphaned or obsolete notifications, and survives device reboots, app updates,
/// and timezone shifts.
class ReminderReconciliationService {
  ReminderReconciliationService._();
  static final ReminderReconciliationService instance =
      ReminderReconciliationService._();

  DateTime? _lastReconciledAt;
  DateTime? get lastReconciledAt => _lastReconciledAt;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isReconciling = false;
  bool get isReconciling => _isReconciling;

  /// Reconciles all reminders using Riverpod ref.
  Future<bool> reconcile(WidgetRef ref) async {
    return _doReconcile(
      healthRepo: ref.read(healthRepositoryProvider),
      sleepRepo: ref.read(sleepRepositoryProvider),
      profileSnapshot: ref.read(profileSnapshotProvider).valueOrNull,
    );
  }

  /// Reconciles all reminders using a Riverpod ProviderContainer (e.g. at app startup).
  Future<bool> reconcileWithContainer(ProviderContainer container) async {
    return _doReconcile(
      healthRepo: container.read(healthRepositoryProvider),
      sleepRepo: container.read(sleepRepositoryProvider),
      profileSnapshot: container.read(profileSnapshotProvider).valueOrNull,
    );
  }

  Future<bool> _doReconcile({
    required dynamic healthRepo,
    required dynamic sleepRepo,
    required dynamic profileSnapshot,
  }) async {
    if (_isReconciling) return true;
    _isReconciling = true;
    _lastError = null;

    try {
      debugPrint('[Reconciliation] Starting reminder reconciliation...');
      final notifService = NotificationService.instance;
      await notifService.initialize();

      final pending = await notifService.getPendingNotifications();
      final pendingIds = pending.map((p) => p.id).toSet();
      debugPrint('[Reconciliation] Found ${pendingIds.length} pending notification(s) in OS');

      final scheduler = LocalReminderScheduler(service: notifService);
      final Set<int> expectedActiveIds = <int>{};

      // 1. Reconcile Medicines
      try {
        final medicines = await healthRepo.listMedicines();
        for (final med in medicines) {
          if (med.isActive) {
            final requests = buildMedicineReminders(med);
            for (final req in requests) {
              final intId = stableNotificationId(req.id);
              expectedActiveIds.add(intId);
              if (!pendingIds.contains(intId)) {
                debugPrint('[Reconciliation] Rescheduling missing medicine alarm: ${req.title} (${req.id})');
                final res = await scheduler.schedule(req);
                if (!res.isSuccess) {
                  debugPrint('[Reconciliation] Failed to schedule medicine ${req.id}: ${res.userFriendlyMessage}');
                }
              }
            }
          } else {
            // Cancel any orphaned notifications for inactive medicine
            for (var i = 0; i < med.reminderTimes.length; i++) {
              final idStr = medicineReminderId(med.id, i);
              final intId = stableNotificationId(idStr);
              if (pendingIds.contains(intId)) {
                debugPrint('[Reconciliation] Canceling orphaned medicine reminder: $idStr');
                await scheduler.cancel(idStr);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[Reconciliation] Error reconciling medicines: $e');
      }

      // 2. Reconcile Meal Reminders
      try {
        final meals = await healthRepo.getMealReminders();
        for (final slot in MealSlot.values) {
          final reminder = meals.of(slot);
          final idStr = mealReminderId(slot);
          final intId = stableNotificationId(idStr);
          if (reminder.enabled) {
            expectedActiveIds.add(intId);
            if (!pendingIds.contains(intId)) {
              debugPrint('[Reconciliation] Rescheduling missing meal reminder: $idStr');
              await scheduler.schedule(buildMealReminder(slot, reminder));
            }
          } else {
            if (pendingIds.contains(intId)) {
              debugPrint('[Reconciliation] Canceling disabled meal reminder: $idStr');
              await scheduler.cancel(idStr);
            }
          }
        }
      } catch (e) {
        debugPrint('[Reconciliation] Error reconciling meals: $e');
      }

      // 3. Reconcile Sleep & Wake Alarms
      try {
        final sleepSettings = await sleepRepo.loadSettings();
        final inputs = buildSleepInputs(
          settings: sleepSettings,
          profile: profileSnapshot,
        );
        final plan = buildSleepPlan(inputs);

        // Bedtime reminder
        final bedtimeIntId = stableNotificationId(bedtimeReminderId);
        if (sleepSettings.bedtimeReminderOn) {
          expectedActiveIds.add(bedtimeIntId);
          if (!pendingIds.contains(bedtimeIntId)) {
            debugPrint('[Reconciliation] Rescheduling missing bedtime reminder');
            await scheduler.schedule(
              buildBedtimeReminder(plan, days: sleepSettings.alarmDays),
            );
          }
        } else {
          if (pendingIds.contains(bedtimeIntId)) {
            debugPrint('[Reconciliation] Canceling disabled bedtime reminder');
            await scheduler.cancel(bedtimeReminderId);
          }
        }

        // Wake-up alarm
        final wakeIntId = stableNotificationId(wakeAlarmReminderId);
        if (sleepSettings.wakeAlarmOn == true) {
          final List<int> days =
              List<int>.from((sleepSettings.alarmDays as Iterable?) ?? const <int>[]);
          final bool useDays = days.isNotEmpty && days.length < 7;
          bool wakeMissing = false;

          if (useDays) {
            for (final int day in days) {
              final int subId = ((wakeIntId * 10) + day) & 0x7FFFFFFF;
              expectedActiveIds.add(subId);
              if (!pendingIds.contains(subId)) {
                wakeMissing = true;
              }
            }
          } else {
            expectedActiveIds.add(wakeIntId);
            if (!pendingIds.contains(wakeIntId)) {
              wakeMissing = true;
            }
          }

          if (wakeMissing) {
            debugPrint('[Reconciliation] Rescheduling missing wake alarm');
            final res = await scheduler.schedule(
              buildWakeAlarm(plan, days: sleepSettings.alarmDays),
            );
            if (!res.isSuccess) {
              debugPrint('[Reconciliation] Wake alarm scheduling returned: ${res.userFriendlyMessage}');
            }
          }
        } else {
          if (pendingIds.contains(wakeIntId)) {
            debugPrint('[Reconciliation] Canceling disabled wake alarm');
            await scheduler.cancel(wakeAlarmReminderId);
          }
        }
      } catch (e) {
        debugPrint('[Reconciliation] Error reconciling sleep reminders: $e');
      }

      _lastReconciledAt = DateTime.now();
      notifService.lastReconciliationResult = true;
      debugPrint('[Reconciliation] Reminder reconciliation completed successfully at $_lastReconciledAt');
      return true;
    } catch (e, stack) {
      _lastError = e.toString();
      NotificationService.instance.lastReconciliationResult = false;
      debugPrint('[Reconciliation] Reconciliation failed: $e\n$stack');
      return false;
    } finally {
      _isReconciling = false;
    }
  }
}
