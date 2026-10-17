import 'dart:async';
import 'package:fitbuddy/core/router/app_router.dart';
import 'package:fitbuddy/core/services/deep_link_service.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/core/services/step_tracking_service.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/theme/theme_provider.dart';
import 'package:fitbuddy/features/schedule/widgets/medicine_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: wires the theme, the theme mode, the router, and deep links.
class VyayamaApp extends ConsumerStatefulWidget {
  const VyayamaApp({super.key});

  @override
  ConsumerState<VyayamaApp> createState() => _VyayamaAppState();
}

class _VyayamaAppState extends ConsumerState<VyayamaApp> {
  StreamSubscription<NotificationResponse>? _notifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = ref.read(goRouterProvider);
      DeepLinkService.instance.init(router);
      StepTrackingService.instance.start();
    });

    _notifSub = NotificationService.instance.onNotificationResponse.stream
        .listen((response) {
      final payload = response.payload;
      debugPrint('Notification clicked with payload: $payload');
      if (payload != null &&
          (payload.startsWith('medicine') || payload.contains('Medicine'))) {
        final navState = rootNavigatorKey.currentState;
        if (navState != null && navState.mounted) {
          final parts = payload.split(':');
          String medicineName = 'Medication';
          if (parts.length >= 4) {
            medicineName = parts[3].replaceAll('Reminder:', '').trim();
          } else if (parts.length >= 3) {
            medicineName = parts[2].trim();
          }
          if (medicineName.isEmpty) medicineName = 'Medication';

          MedicineAlertDialog.show(
            navState.context,
            medicineName: medicineName,
            time: 'Now',
          );
        }
      }
    });
  }

  @override
  void dispose() {
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
