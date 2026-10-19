import 'dart:async';
import 'dart:convert';
import 'package:fitbuddy/core/router/app_router.dart';
import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/services/background_sync_service.dart';
import 'package:fitbuddy/core/services/deep_link_service.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/core/services/reminder_reconciliation_service.dart';
import 'package:fitbuddy/core/services/step_tracking_service.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/theme/theme_provider.dart';
import 'package:fitbuddy/features/schedule/widgets/medicine_alert_dialog.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: wires the theme, the theme mode, the router, and deep links.
class VyayamaApp extends ConsumerStatefulWidget {
  const VyayamaApp({super.key});

  @override
  ConsumerState<VyayamaApp> createState() => _VyayamaAppState();
}

class _VyayamaAppState extends ConsumerState<VyayamaApp>
    with WidgetsBindingObserver {
  StreamSubscription<NotificationResponse>? _notifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = ref.read(goRouterProvider);
      DeepLinkService.instance.init(router);
      StepTrackingService.instance.start();

      // Reconcile and recover active alarms & reminders on startup
      ReminderReconciliationService.instance.reconcile(ref);

      // Check if app was launched via clicking a notification from killed state
      NotificationService.instance
          .getLaunchNotificationPayload()
          .then((payload) {
        if (payload != null) {
          _handleNotificationPayload(payload);
        }
      });
    });

    _notifSub = NotificationService.instance.onNotificationResponse.stream
        .listen((response) {
      _handleNotificationPayload(response.payload);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-verify alarms and permissions when app returns to foreground
      ReminderReconciliationService.instance.reconcile(ref);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      final currentId = ref.read(currentUserIdProvider);
      if (currentId.isNotEmpty && currentId != 'u-me') {
        BackgroundSyncService.instance.syncCurrentUserId(currentId);
      }
      BackgroundSyncService.instance.scheduleOnAppClosed();
    }
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null) return;
    debugPrint('Notification clicked with payload: $payload');
    try {
      if (payload.startsWith('{') && payload.endsWith('}')) {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final type = data['type'] as String?;
        if (type == 'friend_request') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(goRouterProvider).push(AppRoutes.friendsRequests);
          });
          return;
        } else if (type == 'snap') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(goRouterProvider).push(AppRoutes.snapsInbox);
          });
          return;
        } else if (type == 'step_tracker') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(goRouterProvider).push(AppRoutes.dashboard);
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
    if (payload.startsWith('medicine') ||
        payload.contains('Medicine') ||
        payload.contains('medicine')) {
      _showMedicineDialogWithRetry(payload);
    }
  }

  void _showMedicineDialogWithRetry(String payload, [int attempt = 0]) {
    final navState = rootNavigatorKey.currentState;
    if (navState != null && navState.mounted) {
      String medicineName = 'Medication';
      if (payload.contains('|')) {
        final parts = payload.split('|');
        if (parts.length >= 4) {
          medicineName = parts[3].replaceAll('Reminder:', '').trim();
        } else if (parts.length >= 3) {
          medicineName = parts[2].trim();
        }
      } else {
        final parts = payload.split(':');
        medicineName = parts.last.replaceAll('Reminder:', '').trim();
      }
      if (medicineName.isEmpty) medicineName = 'Medication';

      MedicineAlertDialog.show(
        navState.context,
        medicineName: medicineName,
        time: 'Now',
      );
    } else if (attempt < 10) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _showMedicineDialogWithRetry(payload, attempt + 1);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifSub?.cancel();
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Vyayama',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
