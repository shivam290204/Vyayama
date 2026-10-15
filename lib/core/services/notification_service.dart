import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for configuring and scheduling native notifications and alarms.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String wakeAlarmChannelId = 'vyayama_alarm_v3';
  static const String medicineChannelId = 'vyayama_medicine_v3';
  static const String mealsChannelId = 'vyayama_meals_v3';
  static const String sleepChannelId = 'vyayama_sleep_v3';
  static const String remindersChannelId = 'vyayama_reminders_v3';

  static final Int64List _alarmVibrationPattern =
      Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

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
        },
      );

      // 3. Pre-create Android Notification Channels with sound and priority
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Clean up legacy channels to prevent Android caching old silent/low priority settings
        for (final oldId in [
          'vyayama_alarm',
          'vyayama_alarm_v2',
          'vyayama_medicine',
          'vyayama_medicine_v2',
          'vyayama_meals',
          'vyayama_sleep',
          'vyayama_reminders',
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

  /// Schedules a repeating daily notification at the given [hour] and [minute].
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? channelId,
    String? channelName,
    bool exact = false,
    bool alarmStyle = false,
  }) async {
    if (!isSupportedPlatform) return;
    await initialize();
    if (!_isInitialized) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

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
      channelDescription: 'Daily health, sleep, and meal reminders',
      importance: alarmStyle ? Importance.max : Importance.high,
      priority: alarmStyle ? Priority.max : Priority.high,
      fullScreenIntent: alarmStyle,
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

    final scheduleMode = exact
        ? (alarmStyle
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.exactAllowWhileIdle)
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint(
        'ZonedSchedule with $scheduleMode failed ($e), falling back to exactAllowWhileIdle...',
      );
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (fallbackError) {
        debugPrint('Fallback scheduling error for notification $id: $fallbackError');
      }
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
      importance: alarmStyle ? Importance.max : Importance.high,
      priority: alarmStyle ? Priority.max : Priority.high,
      fullScreenIntent: alarmStyle,
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
      await _plugin.show(id, title, body, details);
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
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: soundResource,
      enableVibration: true,
      vibrationPattern: _alarmVibrationPattern,
      audioAttributesUsage: AudioAttributesUsage.alarm,
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
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Schedule test alarm failed with alarmClock: $e, trying exactAllowWhileIdle...');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (fallbackError) {
        debugPrint('Fallback test schedule error: $fallbackError');
      }
    }
  }

  /// Cancels a notification by integer ID.
  Future<void> cancel(int id) async {
    if (!isSupportedPlatform || !_isInitialized) return;
    try {
      await _plugin.cancel(id);
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
}
