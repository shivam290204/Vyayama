import 'dart:async';
import 'dart:convert';
import 'package:fitbuddy/core/services/schedule_result.dart';
import 'package:fitbuddy/core/services/system_features_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for configuring and scheduling native notifications and alarms.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String wakeAlarmChannelId = 'vyayama_alarm_v5';
  static const String medicineChannelId = 'vyayama_medicine_v5';
  static const String mealsChannelId = 'vyayama_meals_v5';
  static const String sleepChannelId = 'vyayama_sleep_v5';
  static const String remindersChannelId = 'vyayama_reminders_v5';
  static const String socialNotificationChannelId = 'vyayama_social_v1';
  static const String stepTrackerChannelId = 'vyayama_steps_v1';

  static final Int64List _alarmVibrationPattern =
      Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  String? _lastSchedulingError;
  String? get lastSchedulingError => _lastSchedulingError;

  bool? lastReconciliationResult;

  /// Broadcasts notification response taps so screens/dialogs can react.
  final StreamController<NotificationResponse> onNotificationResponse =
      StreamController<NotificationResponse>.broadcast();

  NotificationResponse? _launchNotificationResponse;

  /// Consumes and returns any notification payload that launched the app from a killed state.
  Future<String?> getLaunchNotificationPayload() async {
    if (_launchNotificationResponse != null) {
      final p = _launchNotificationResponse!.payload;
      _launchNotificationResponse = null;
      return p;
    }
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        return details.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  /// Whether local notifications are supported on the current platform.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Initializes timezone data, notification channels, and native plugin.
  Future<void> initialize() async {
    if (!isSupportedPlatform || _isInitialized) return;

    try {
      // 1. Initialize timezone database
      tz.initializeTimeZones();
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        final String currentTimeZone = timezoneInfo.identifier;
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
        debugPrint('System local timezone set: $currentTimeZone');
      } catch (e) {
        debugPrint('FlutterTimezone failed ($e), attempting offset matching...');
        try {
          final now = DateTime.now();
          final offsetMs = now.timeZoneOffset.inMilliseconds;
          final nowMs = now.millisecondsSinceEpoch;
          tz.Location? matched;
          for (final loc in tz.timeZoneDatabase.locations.values) {
            if (loc.timeZone(nowMs).offset == offsetMs) {
              matched = loc;
              break;
            }
          }
          if (matched != null) {
            tz.setLocalLocation(matched);
            debugPrint('Local timezone matched by offset: ${matched.name}');
          } else {
            tz.setLocalLocation(tz.getLocation('UTC'));
          }
        } catch (_) {
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
      }

      // 2. Setup initialization settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
          onNotificationResponse.add(response);
        },
      );

      // Check if app was launched via notification click from killed state
      try {
        final launchDetails = await _plugin.getNotificationAppLaunchDetails();
        if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
          _launchNotificationResponse = launchDetails.notificationResponse;
          final response = launchDetails.notificationResponse;
          if (response != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onNotificationResponse.add(response);
            });
          }
        }
      } catch (e) {
        debugPrint('Error checking notification launch details: $e');
      }

      // 3. Pre-create Android Notification Channels with sound and priority
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Clean up legacy channels to prevent Android caching old silent/low priority settings
        for (final oldId in [
          'vyayama_alarm',
          'vyayama_alarm_v2',
          'vyayama_alarm_v3',
          'vyayama_alarm_v4',
          'vyayama_medicine',
          'vyayama_medicine_v2',
          'vyayama_medicine_v3',
          'vyayama_medicine_v4',
          'vyayama_meals',
          'vyayama_meals_v2',
          'vyayama_meals_v3',
          'vyayama_meals_v4',
          'vyayama_sleep',
          'vyayama_sleep_v2',
          'vyayama_sleep_v3',
          'vyayama_sleep_v4',
          'vyayama_reminders',
          'vyayama_reminders_v2',
          'vyayama_reminders_v3',
          'vyayama_reminders_v4',
        ]) {
          try {
            await android.deleteNotificationChannel(oldId);
          } catch (_) {}
        }

        // Wake Alarms channel (max priority, alarm sound, vibration)
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            wakeAlarmChannelId,
            'Wake Alarms',
            description: 'Urgent morning wake-up alarms',
            importance: Importance.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('wakeup_alarm'),
            enableVibration: true,
            vibrationPattern: _alarmVibrationPattern,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableLights: true,
            ledColor: const Color.fromARGB(255, 255, 0, 0),
          ),
        );

        // Medicine Reminders channel (max priority, warning sound, vibration)
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            medicineChannelId,
            'Medicine Reminders',
            description: 'Timely reminders for medications',
            importance: Importance.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('warning_alarm'),
            enableVibration: true,
            vibrationPattern: _alarmVibrationPattern,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableLights: true,
            ledColor: const Color.fromARGB(255, 255, 160, 0),
          ),
        );

        // Meal Reminders channel
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            mealsChannelId,
            'Meal Reminders',
            description:
                'Daily reminders for breakfast, lunch, snacks, and dinner',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
          ),
        );

        // Bedtime Guidance channel
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            sleepChannelId,
            'Bedtime Guidance',
            description: 'Calming wind-down and bedtime nudges',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
          ),
        );

        // General Reminders channel
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            remindersChannelId,
            'Reminders',
            description: 'Daily health, sleep, and meal reminders',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
          ),
        );

        // Social & Snaps channel with custom notification.mp3 sound
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            socialNotificationChannelId,
            'Social & Snaps',
            description: 'Notifications for incoming friend requests and snaps',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('notification'),
            enableVibration: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
            enableLights: true,
            ledColor: Color.fromARGB(255, 46, 125, 50),
            showBadge: true,
          ),
        );

        // Ongoing Step Tracker channel (low priority, silent, persistent)
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            stepTrackerChannelId,
            'Step Tracker',
            description: 'Live step counting and active fitness tracker',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      if (!e.toString().contains('LateInitializationError')) {
        debugPrint('NotificationService initialization failed: $e');
      }
    }
  }

  /// Requests notification permissions on iOS/macOS and Android 13+.
  /// Also checks/requests exact alarm permission on Android 12+.
  /// Requests notification permissions on iOS/macOS and Android 13+.
  Future<bool> requestPermissions() async {
    if (!isSupportedPlatform) return false;
    await initialize();
    if (!_isInitialized) return false;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission() ?? false;
        try {
          await android.requestExactAlarmsPermission();
        } catch (e) {
          debugPrint('Exact alarms permission request: $e');
        }
        try {
          await requestAudioPermission();
        } catch (e) {
          debugPrint('Audio permission request: $e');
        }
        return granted;
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return false;
  }

  /// Requests notification display permission (POST_NOTIFICATIONS on Android 13+).
  Future<bool> requestNotificationPermission() async {
    if (!isSupportedPlatform) return false;
    await initialize();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('requestNotificationPermission error: $e');
    }
    return false;
  }

  /// Opens the system settings for exact alarms (SCHEDULE_EXACT_ALARM on Android 12+).
  Future<void> openExactAlarmSettings() async {
    if (!isSupportedPlatform) return;
    try {
      await SystemFeaturesService.instance.openAlarmsAndRemindersSettings();
    } catch (e) {
      debugPrint('openExactAlarmSettings error: $e');
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestExactAlarmsPermission();
      }
    }
  }

  /// Whether exact alarms are permitted by the OS (Android 12+).
  /// Returns false on failure or revocation (never pretends true).
  Future<bool> canScheduleExactAlarms() async {
    if (!isSupportedPlatform) return false;
    await initialize();
    try {
      final nativeCheck =
          await SystemFeaturesService.instance.canScheduleExactAlarms();
      if (!nativeCheck) return false;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final can = await android.canScheduleExactNotifications();
        return can ?? nativeCheck;
      }
      return nativeCheck;
    } catch (e) {
      debugPrint('canScheduleExactAlarms error: $e');
      return false;
    }
  }

  /// Checks whether music & audio permission is granted (READ_MEDIA_AUDIO on Android 13+ or storage on older Android).
  Future<bool> isAudioPermissionGranted() async {
    if (!isSupportedPlatform) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.audio.status;
        if (status.isGranted) return true;
        final storage = await Permission.storage.status;
        return storage.isGranted;
      }
    } catch (e) {
      debugPrint('isAudioPermissionGranted error: $e');
    }
    return true;
  }

  /// Requests music & audio permission at runtime.
  Future<bool> requestAudioPermission() async {
    if (!isSupportedPlatform) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final res = await Permission.audio.request();
        if (res.isGranted) return true;
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    } catch (e) {
      debugPrint('requestAudioPermission error: $e');
    }
    return false;
  }

  /// Checks whether background alarms can run reliably.
  /// Vyayama relies on Android's exact alarm scheduling rather than requesting invasive Doze exemption.
  Future<bool> isBatteryOptimizationIgnored() async {
    return true;
  }

  /// Compliant no-op that avoids requesting restricted Doze mode exemption on Google Play.
  Future<bool> requestIgnoreBatteryOptimizations() async {
    return true;
  }

  /// Whether notifications are enabled system-wide for this app.
  Future<bool> areNotificationsEnabled() async {
    if (!isSupportedPlatform) return false;
    await initialize();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final status = await ios.checkPermissions();
        return status?.isEnabled ?? false;
      }
    } catch (e) {
      debugPrint('areNotificationsEnabled error: $e');
    }
    return false;
  }

  /// Checks whether a specific notification channel is enabled and not blocked.
  Future<bool> isChannelEnabled(String channelId) async {
    if (!isSupportedPlatform) return true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final channels = await android.getNotificationChannels();
        if (channels != null) {
          final matched = channels.where((c) => c.id == channelId).firstOrNull;
          if (matched != null) {
            return matched.importance != Importance.none;
          }
        }
      }
    } catch (e) {
      debugPrint('isChannelEnabled error: $e');
    }
    return true;
  }

  /// Retrieves all currently pending/scheduled notifications from the system.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!isSupportedPlatform) return const [];
    await initialize();
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('getPendingNotifications error: $e');
      return const [];
    }
  }

  /// Cancels only a diagnostic test notification without canceling real user reminders.
  Future<void> cancelDiagnosticTest([int testId = 9999]) async {
    if (!isSupportedPlatform) return;
    try {
      await _plugin.cancel(testId);
    } catch (e) {
      debugPrint('cancelDiagnosticTest error: $e');
    }
  }

  /// Schedules a repeating notification at the given [hour] and [minute].
  /// Supports optional [weekdays] (1 = Mon ... 7 = Sun).
  ///
  /// Distinguishes between exact wake-up/medicine alarms (which require exact scheduling
  /// and are NEVER silently converted to inexact) and gentle reminders (bedtime guidance/meals).
  Future<ScheduleResult> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    List<int>? weekdays,
    String? channelId,
    String? channelName,
    bool exact = false,
    bool alarmStyle = false,
    String? payload,
  }) async {
    if (!isSupportedPlatform) {
      return const ScheduleResult.failure(
        ScheduleStatus.initializationFailed,
        errorMessage: 'Unsupported platform',
      );
    }
    await initialize();
    if (!_isInitialized) {
      return const ScheduleResult.failure(
        ScheduleStatus.initializationFailed,
        errorMessage: 'Notification service not initialized',
      );
    }

    // 1. Verify notification permission
    final allowed = await areNotificationsEnabled();
    if (!allowed) {
      return ScheduleResult.failure(
        ScheduleStatus.notificationPermissionDenied,
        notificationId: id,
        errorMessage: 'Notification permission is disabled',
      );
    }

    final bool isWakeAlarm = (channelId == wakeAlarmChannelId) ||
        (channelName != null && channelName.toLowerCase().contains('wake'));
    final bool isMedicine = (channelId == medicineChannelId) ||
        (channelName != null && channelName.toLowerCase().contains('medicine'));
    final bool isBedtime = (channelId == sleepChannelId) ||
        (channelName != null && channelName.toLowerCase().contains('bedtime'));

    final targetChannelId = channelId ??
        (isWakeAlarm
            ? wakeAlarmChannelId
            : (isBedtime
                ? sleepChannelId
                : (isMedicine ? medicineChannelId : remindersChannelId)));
    final targetChannelName = channelName ??
        (isWakeAlarm
            ? 'Wake Alarms'
            : (isBedtime
                ? 'Bedtime Guidance'
                : (isMedicine ? 'Medicine Reminders' : 'Reminders')));

    // 2. Verify target notification channel is enabled
    final channelActive = await isChannelEnabled(targetChannelId);
    if (!channelActive) {
      return ScheduleResult.failure(
        ScheduleStatus.channelDisabled,
        notificationId: id,
        errorMessage: 'Notification channel $targetChannelName is disabled',
      );
    }

    // 3. For exact wake alarms and medicines, verify exact alarm permission
    final bool requiresExact = exact || isWakeAlarm || isMedicine;
    if (requiresExact) {
      final exactAllowed = await canScheduleExactAlarms();
      if (!exactAllowed) {
        if (isWakeAlarm || isMedicine) {
          // Never silently downgrade a wake alarm or medicine reminder!
          debugPrint('Exact alarm required for $id but SCHEDULE_EXACT_ALARM is not granted.');
          return ScheduleResult.failure(
            ScheduleStatus.exactAlarmPermissionDenied,
            notificationId: id,
            errorMessage: 'SCHEDULE_EXACT_ALARM permission not granted',
          );
        }
      }
    }

    // Wake alarms and medicines use alarm sound & high priority; Bedtime guidance uses standard notification
    final AndroidNotificationSound? soundResource = isWakeAlarm
        ? const RawResourceAndroidNotificationSound('wakeup_alarm')
        : (isMedicine
            ? const RawResourceAndroidNotificationSound('warning_alarm')
            : null);

    final androidDetails = AndroidNotificationDetails(
      targetChannelId,
      targetChannelName,
      channelDescription: isWakeAlarm
          ? 'Urgent morning wake-up alarms'
          : (isBedtime
              ? 'Calming wind-down and bedtime nudges'
              : (isMedicine ? 'Timely reminders for medications' : 'Daily reminders')),
      importance: (isWakeAlarm || isMedicine) ? Importance.max : Importance.high,
      priority: (isWakeAlarm || isMedicine) ? Priority.max : Priority.high,
      fullScreenIntent: (isWakeAlarm || isMedicine) && alarmStyle,
      visibility: NotificationVisibility.public,
      category: (isWakeAlarm || isMedicine)
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      playSound: true,
      sound: soundResource,
      enableVibration: true,
      vibrationPattern: (isWakeAlarm || isMedicine) ? _alarmVibrationPattern : null,
      audioAttributesUsage: (isWakeAlarm || isMedicine)
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      ticker: title,
      color: const Color(0xFF2E7D32),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    // Wake alarms and medicines use AndroidScheduleMode.alarmClock for native clock-level priority,
    // waking the screen, and bypassing OEM battery limits.
    // Bedtime guidance uses inexact scheduling; other exact reminders use exactAllowWhileIdle.
    final effectiveExact = requiresExact && !isBedtime;
    final scheduleMode = (isWakeAlarm || isMedicine)
        ? AndroidScheduleMode.alarmClock
        : (effectiveExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle);

    final deviceNow = DateTime.now();
    final isSameMinute = deviceNow.hour == hour && deviceNow.minute == minute;

    final selectedDays = weekdays != null && weekdays.isNotEmpty && weekdays.length < 7
        ? weekdays
        : null;

    if (selectedDays != null) {
      for (final day in selectedDays) {
        var target = DateTime(
          deviceNow.year,
          deviceNow.month,
          deviceNow.day,
          hour,
          minute,
        );
        while (target.weekday != day || target.isBefore(deviceNow)) {
          target = target.add(const Duration(days: 1));
        }

        final scheduledDate = tz.TZDateTime.from(target, tz.local);
        final subId = (id * 10 + day) & 0x7FFFFFFF;
        final res = await _scheduleSingle(
          id: subId,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          details: details,
          mode: scheduleMode,
          matchComponents: DateTimeComponents.dayOfWeekAndTime,
          isWakeAlarm: isWakeAlarm || isMedicine,
          payload: payload,
        );
        if (!res.isSuccess) {
          return res;
        }
      }
      return ScheduleResult.success(exact: effectiveExact, notificationId: id);
    } else {
      var target = DateTime(
        deviceNow.year,
        deviceNow.month,
        deviceNow.day,
        hour,
        minute,
      );
      if (target.isBefore(deviceNow) || isSameMinute) {
        target = target.add(const Duration(days: 1));
      }

      final scheduledDate = tz.TZDateTime.from(target, tz.local);

      final result = await _scheduleSingle(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        details: details,
        mode: scheduleMode,
        matchComponents: DateTimeComponents.time,
        isWakeAlarm: isWakeAlarm || isMedicine,
        payload: payload,
      );

      // If user scheduled for the exact current minute (e.g. testing Aspirin at 18:05 right now),
      // also schedule a 5-second one-shot alarm trigger so they immediately get the alarm popup & sound today!
      if (isSameMinute && (isWakeAlarm || isMedicine)) {
        try {
          final immediateTarget =
              tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
          final oneShotId = (id + 50000) & 0x7FFFFFFF;
          await _plugin.zonedSchedule(
            oneShotId,
            title,
            body,
            immediateTarget,
            details,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint('Scheduled immediate same-minute alarm trigger for $id in 5s');
        } catch (e) {
          debugPrint('Immediate same-minute trigger fallback: $e');
        }
      }

      return result;
    }
  }

  Future<ScheduleResult> _scheduleSingle({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required AndroidScheduleMode mode,
    required DateTimeComponents matchComponents,
    required bool isWakeAlarm,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
      );
      debugPrint('Scheduled notification $id at $scheduledDate (mode: $mode)');
      return ScheduleResult.success(
        exact: mode == AndroidScheduleMode.exactAllowWhileIdle ||
            mode == AndroidScheduleMode.alarmClock,
        notificationId: id,
      );
    } catch (e) {
      _lastSchedulingError = e.toString();
      debugPrint('ZonedSchedule with $mode failed for $id: $e');

      // If alarmClock failed, try exactAllowWhileIdle as fallback
      if (mode == AndroidScheduleMode.alarmClock) {
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            details,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: matchComponents,
          );
          debugPrint('Fallback to exactAllowWhileIdle succeeded for $id');
          return ScheduleResult.success(
            exact: true,
            notificationId: id,
          );
        } catch (fallbackError) {
          _lastSchedulingError = fallbackError.toString();
          debugPrint('Fallback exactAllowWhileIdle failed: $fallbackError');
        }
      }

      // WAKE ALARMS AND MEDICINES MUST NEVER BE SILENTLY CONVERTED TO INEXACT!
      if (isWakeAlarm) {
        return ScheduleResult.failure(
          ScheduleStatus.nativeException,
          notificationId: id,
          errorMessage: e.toString(),
        );
      }

      // Gentle/inexact reminders can fall back to inexact if not already inexact
      if (mode != AndroidScheduleMode.inexactAllowWhileIdle) {
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            details,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: matchComponents,
          );
          return ScheduleResult.success(
            exact: false,
            notificationId: id,
          );
        } catch (fallbackError) {
          _lastSchedulingError = fallbackError.toString();
          return ScheduleResult.failure(
            ScheduleStatus.nativeException,
            notificationId: id,
            errorMessage: fallbackError.toString(),
          );
        }
      }

      return ScheduleResult.failure(
        ScheduleStatus.nativeException,
        notificationId: id,
        errorMessage: e.toString(),
      );
    }
  }

  /// Displays a notification immediately (useful for testing sound, vibration & channels).
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? channelId,
    String? channelName,
    bool alarmStyle = false,
    String? payload,
  }) async {
    if (!isSupportedPlatform) return;
    await initialize();
    if (!_isInitialized) return;

    final targetChannelId = channelId ??
        (alarmStyle ? wakeAlarmChannelId : remindersChannelId);
    final targetChannelName = channelName ??
        (alarmStyle ? 'Wake Alarms' : 'Reminders');

    final AndroidNotificationSound? soundResource =
        (targetChannelId == wakeAlarmChannelId || targetChannelId.contains('alarm'))
            ? const RawResourceAndroidNotificationSound('wakeup_alarm')
            : ((targetChannelId == medicineChannelId || targetChannelId.contains('medicine'))
                ? const RawResourceAndroidNotificationSound('warning_alarm')
                : null);

    final androidDetails = AndroidNotificationDetails(
      targetChannelId,
      targetChannelName,
      channelDescription: 'Immediate alerts and tests',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: alarmStyle
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      playSound: true,
      sound: soundResource,
      enableVibration: true,
      vibrationPattern: alarmStyle ? _alarmVibrationPattern : null,
      audioAttributesUsage: alarmStyle
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
      ticker: title,
      color: const Color(0xFF2E7D32),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('Error showing immediate notification $id: $e');
    }
  }

  /// Schedules a test alarm [seconds] from now to verify system AlarmManager delivery.
  Future<void> scheduleTestAlarmInSeconds({
    required int id,
    required int seconds,
    required String title,
    required String body,
    String? channelId,
    String? channelName,
    bool alarmStyle = true,
    String? payload,
  }) async {
    if (!isSupportedPlatform) return;
    await initialize();
    if (!_isInitialized) return;

    final targetChannelId = channelId ?? wakeAlarmChannelId;
    final targetChannelName = channelName ?? 'Wake Alarms';

    final scheduledDate =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    final AndroidNotificationSound? soundResource =
        (targetChannelId == wakeAlarmChannelId || targetChannelId.contains('alarm'))
            ? const RawResourceAndroidNotificationSound('wakeup_alarm')
            : ((targetChannelId == medicineChannelId || targetChannelId.contains('medicine'))
                ? const RawResourceAndroidNotificationSound('warning_alarm')
                : null);

    final androidDetails = AndroidNotificationDetails(
      targetChannelId,
      targetChannelName,
      channelDescription: 'Test Alarms',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: soundResource,
      enableVibration: true,
      vibrationPattern: _alarmVibrationPattern,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ticker: title,
      color: const Color(0xFF2E7D32),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: alarmStyle
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Schedule test alarm failed with primary mode ($e), trying exactAllowWhileIdle...');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (fallbackError) {
        debugPrint('Fallback exactAllowWhileIdle test error ($fallbackError), trying inexact...');
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            details,
            payload: payload,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (inexactError) {
          debugPrint('Final fallback test schedule error: $inexactError');
        }
      }
    }
  }

  /// Schedules a diagnostic test notification using Android's native AlarmManager mechanism.
  /// Does NOT touch real user alarms.
  Future<ScheduleResult> scheduleDiagnosticTest({
    required int id,
    int delayMinutes = 2,
    required bool exact,
    required bool isWakeAlarm,
    String? title,
    String? body,
  }) async {
    if (!isSupportedPlatform) {
      return const ScheduleResult.failure(
        ScheduleStatus.initializationFailed,
        errorMessage: 'Unsupported platform',
      );
    }
    await initialize();

    final allowed = await areNotificationsEnabled();
    if (!allowed) {
      return const ScheduleResult.failure(
        ScheduleStatus.notificationPermissionDenied,
      );
    }

    if (exact) {
      final canExact = await canScheduleExactAlarms();
      if (!canExact) {
        return const ScheduleResult.failure(
          ScheduleStatus.exactAlarmPermissionDenied,
        );
      }
    }

    final targetChannelId = isWakeAlarm ? wakeAlarmChannelId : sleepChannelId;
    final targetChannelName = isWakeAlarm ? 'Wake Alarms' : 'Bedtime Guidance';

    final scheduledDate =
        tz.TZDateTime.now(tz.local).add(Duration(minutes: delayMinutes));

    final AndroidNotificationSound? soundResource = isWakeAlarm
        ? const RawResourceAndroidNotificationSound('wakeup_alarm')
        : null;

    final androidDetails = AndroidNotificationDetails(
      targetChannelId,
      targetChannelName,
      channelDescription: 'Diagnostic test notification',
      importance: isWakeAlarm ? Importance.max : Importance.high,
      priority: isWakeAlarm ? Priority.max : Priority.high,
      fullScreenIntent: isWakeAlarm,
      visibility: NotificationVisibility.public,
      category: isWakeAlarm
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      playSound: true,
      sound: soundResource,
      enableVibration: true,
      vibrationPattern: isWakeAlarm ? _alarmVibrationPattern : null,
      audioAttributesUsage: isWakeAlarm
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    final targetMode = (exact && isWakeAlarm)
        ? AndroidScheduleMode.alarmClock
        : (exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle);

    try {
      await _plugin.zonedSchedule(
        id,
        title ?? (isWakeAlarm ? '⏰ Diagnostic Wake Alarm Test' : '🌙 Diagnostic Bedtime Test'),
        body ??
            (isWakeAlarm
                ? 'Exact wake alarm delivered via AlarmManager in ${delayMinutes}m!'
                : 'Bedtime test notification delivered in ${delayMinutes}m!'),
        scheduledDate,
        details,
        payload: 'test:${isWakeAlarm ? "wake" : "bedtime"}',
        androidScheduleMode: targetMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return ScheduleResult.success(exact: exact, notificationId: id);
    } catch (e) {
      if (targetMode == AndroidScheduleMode.alarmClock) {
        try {
          await _plugin.zonedSchedule(
            id,
            title ?? '⏰ Diagnostic Wake Alarm Test',
            body ?? 'Exact wake alarm delivered via AlarmManager in ${delayMinutes}m!',
            scheduledDate,
            details,
            payload: 'test:${isWakeAlarm ? "wake" : "bedtime"}',
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          return ScheduleResult.success(exact: true, notificationId: id);
        } catch (_) {}
      }
      _lastSchedulingError = e.toString();
      return ScheduleResult.failure(
        ScheduleStatus.nativeException,
        errorMessage: e.toString(),
        notificationId: id,
      );
    }
  }

  /// Cancels a notification by integer ID (and any weekday sub-IDs).
  Future<void> cancel(int id) async {
    if (!isSupportedPlatform || !_isInitialized) return;
    try {
      await _plugin.cancel(id);
      // Also cancel any weekday sub-IDs
      for (var day = 1; day <= 7; day++) {
        await _plugin.cancel((id * 10 + day) & 0x7FFFFFFF);
      }
    } catch (e) {
      debugPrint('Error canceling notification $id: $e');
    }
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAll() async {
    if (!isSupportedPlatform || !_isInitialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }

  /// Displays an immediate high-priority notification with custom audio for a new friend request.
  Future<void> showFriendRequestNotification({
    required String senderName,
    required String requestId,
  }) async {
    if (!isSupportedPlatform) return;
    await initialize();
    if (!_isInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      socialNotificationChannelId,
      'Social & Snaps',
      channelDescription: 'Notifications for incoming friend requests and snaps',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
      category: AndroidNotificationCategory.social,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      ticker: 'New friend request',
      color: Color(0xFF2E7D32),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.mp3',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final id = 800000 + (requestId.hashCode.abs() % 10000);
    final payload = jsonEncode({
      'type': 'friend_request',
      'requestId': requestId,
    });

    try {
      await _plugin.show(
        id,
        'Friend Request',
        '$senderName sent you a friend request!',
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing friend request notification: $e');
    }
  }

  /// Displays an immediate high-priority notification with custom audio for a new direct snap.
  Future<void> showSnapNotification({
    required String senderName,
    required String snapId,
    String? activityType,
  }) async {
    if (!isSupportedPlatform) return;
    await initialize();
    if (!_isInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      socialNotificationChannelId,
      'Social & Snaps',
      channelDescription: 'Notifications for incoming friend requests and snaps',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
      category: AndroidNotificationCategory.social,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      ticker: 'New snap received',
      color: Color(0xFF2E7D32),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.mp3',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final id = 810000 + (snapId.hashCode.abs() % 10000);
    final payload = jsonEncode({
      'type': 'snap',
      'snapId': snapId,
    });

    final activityLabel = (activityType != null && activityType.isNotEmpty)
        ? ' ($activityType)'
        : '';

    try {
      await _plugin.show(
        id,
        'New Snap',
        '$senderName sent you a snap$activityLabel!',
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing snap notification: $e');
    }
  }

  static const int stepNotificationId = 999999;

  /// Updates or displays live step progress notification.
  Future<void> updateStepTrackingNotification({
    required int steps,
    required int target,
    required int calories,
    required int activeMinutes,
  }) async {
    if (!isSupportedPlatform || !_isInitialized) return;
    try {
      final safeTarget = target > 0 ? target : 10000;
      final percent = ((steps / safeTarget) * 100).clamp(0, 100).toInt();
      const androidDetails = AndroidNotificationDetails(
        stepTrackerChannelId,
        'Step Tracker',
        channelDescription: 'Live step counting and active fitness tracker',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.status,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _plugin.show(
        stepNotificationId,
        '🏃 $steps steps today ($percent%)',
        '$calories kcal burned · $activeMinutes min active',
        details,
        payload: '{"type":"step_tracker"}',
      );
    } catch (e) {
      debugPrint('[NotificationService] updateStepTrackingNotification error: $e');
    }
  }
}
