import 'package:fitbuddy/core/services/notification_diagnostic_logger.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/core/services/reminder_reconciliation_service.dart';
import 'package:fitbuddy/core/services/system_features_service.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

/// Screen providing diagnostics and manual tests for local notifications and alarms.
class NotificationDiagnosticsScreen extends ConsumerStatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  ConsumerState<NotificationDiagnosticsScreen> createState() =>
      _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState
    extends ConsumerState<NotificationDiagnosticsScreen> {
  bool _isLoading = true;
  bool _notifEnabled = false;
  bool _exactAlarmsAllowed = false;
  bool _audioPermissionGranted = true;
  bool _batteryOptIgnored = true;
  bool _pipSupported = false;
  bool _pipAllowed = false;
  bool _wakeChannelEnabled = true;
  bool _bedtimeChannelEnabled = true;
  bool _medicineChannelEnabled = true;
  bool _mealsChannelEnabled = true;
  String _timezoneName = 'Unknown';
  String _timezoneOffset = '';
  List<PendingNotificationRequest> _pendingNotifications = [];
  List<NotificationDiagnosticRecord> _diagnosticLogs = [];
  String? _lastError;
  bool? _reconciliationSuccess;
  DateTime? _reconciliationTime;
  String? _testStatusMessage;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    final service = NotificationService.instance;
    await service.initialize();

    final notifEnabled = await service.areNotificationsEnabled();
    final exactAllowed = await service.canScheduleExactAlarms();
    final audioGranted = await service.isAudioPermissionGranted();
    final batteryIgnored = await service.isBatteryOptimizationIgnored();
    final pipSupported = await SystemFeaturesService.instance.isPipSupported();
    final pipAllowed = await SystemFeaturesService.instance.isPipAllowed();
    final wakeChannel =
        await service.isChannelEnabled(NotificationService.wakeAlarmChannelId);
    final bedtimeChannel =
        await service.isChannelEnabled(NotificationService.sleepChannelId);
    final medicineChannel =
        await service.isChannelEnabled(NotificationService.medicineChannelId);
    final mealsChannel =
        await service.isChannelEnabled(NotificationService.mealsChannelId);
    final pending = await service.getPendingNotifications();
    final diagnosticLogs =
        await NotificationDiagnosticLogger.instance.getRecentRecords();

    String tzName = 'Unknown';
    String tzOffset = '';
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tzName = info.identifier;
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final hours = offset.inHours.abs().toString().padLeft(2, '0');
      final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      tzOffset = 'UTC$sign$hours:$minutes';
    } catch (_) {
      tzName = tz.local.name;
    }

    final recon = ReminderReconciliationService.instance;

    if (!mounted) return;
    setState(() {
      _notifEnabled = notifEnabled;
      _exactAlarmsAllowed = exactAllowed;
      _audioPermissionGranted = audioGranted;
      _batteryOptIgnored = batteryIgnored;
      _pipSupported = pipSupported;
      _pipAllowed = pipAllowed;
      _wakeChannelEnabled = wakeChannel;
      _bedtimeChannelEnabled = bedtimeChannel;
      _medicineChannelEnabled = medicineChannel;
      _mealsChannelEnabled = mealsChannel;
      _pendingNotifications = pending;
      _diagnosticLogs = diagnosticLogs;
      _timezoneName = tzName;
      _timezoneOffset = tzOffset;
      _lastError = service.lastSchedulingError ?? recon.lastError;
      _reconciliationSuccess = service.lastReconciliationResult;
      _reconciliationTime = recon.lastReconciledAt;
      _isLoading = false;
    });
  }

  Future<void> _runReconciliation() async {
    setState(() => _testStatusMessage = 'Running alarm reconciliation...');
    final ok = await ReminderReconciliationService.instance.reconcile(ref);
    if (!mounted) return;
    setState(() {
      _testStatusMessage = ok
          ? 'Reconciliation completed successfully! Alarms synced.'
          : 'Reconciliation encountered an issue.';
    });
    await _loadDiagnostics();
  }

  Future<void> _testImmediate() async {
    setState(() => _testStatusMessage = 'Firing immediate alert test...');
    try {
      await NotificationService.instance.showImmediateNotification(
        id: 9999,
        title: '⏰ Alarm Diagnostic Test',
        body: 'Immediate notification alert! Sound and popup verified.',
        channelId: NotificationService.wakeAlarmChannelId,
        channelName: 'Wake Alarms',
        alarmStyle: true,
        payload: 'test:immediate',
      );
      setState(() => _testStatusMessage = 'Immediate alert sent to system!');
    } catch (e) {
      setState(() => _testStatusMessage = 'Immediate test error: $e');
    }
  }

  Future<void> _testTwoMinuteWakeAlarm() async {
    setState(() => _testStatusMessage = 'Scheduling 2-min exact wake alarm...');
    final res = await NotificationService.instance.scheduleDiagnosticTest(
      id: 9998,
      delayMinutes: 2,
      exact: true,
      isWakeAlarm: true,
      title: '⏰ 2-Min Exact Wake Alarm Test',
      body: 'This exact alarm was scheduled via AlarmManager and triggered on time!',
    );
    if (!mounted) return;
    setState(() {
      _testStatusMessage = res.isSuccess
          ? '2-Min exact wake alarm scheduled! Close the app to test background firing.'
          : 'Failed to schedule: ${res.userFriendlyMessage}';
    });
    await _loadDiagnostics();
  }

  Future<void> _testTwoMinuteNormal() async {
    setState(() => _testStatusMessage = 'Scheduling 2-min normal notification...');
    final res = await NotificationService.instance.scheduleDiagnosticTest(
      id: 9997,
      delayMinutes: 2,
      exact: false,
      isWakeAlarm: false,
      title: '🌙 2-Min Bedtime Reminder Test',
      body: 'Standard notification reminder delivered successfully!',
    );
    if (!mounted) return;
    setState(() {
      _testStatusMessage = res.isSuccess
          ? '2-Min reminder scheduled!'
          : 'Failed to schedule: ${res.userFriendlyMessage}';
    });
    await _loadDiagnostics();
  }

  Future<void> _testFiveSecondMedicineAlarm() async {
    setState(() => _testStatusMessage = 'Scheduling 5s Clock-style Medicine Alarm...');
    try {
      await NotificationService.instance.scheduleTestAlarmInSeconds(
        id: 9993,
        seconds: 5,
        title: '💊 Medicine Alarm (Clock Style Test)',
        body: 'Time to take Aspirin (Diagnostic Test)',
        channelId: NotificationService.medicineChannelId,
        channelName: 'Medicine Reminders',
        alarmStyle: true,
        payload: 'medicine:test:Medicine reminder:Reminder: Aspirin',
      );
      if (!mounted) return;
      setState(() => _testStatusMessage =
          '5s Clock Alarm scheduled! Lock your phone immediately to test background alarm ringing.');
      await _loadDiagnostics();
    } catch (e) {
      if (!mounted) return;
      setState(() => _testStatusMessage = 'Test error: $e');
    }
  }

  Future<void> _cancelTestAlarms() async {
    setState(() => _testStatusMessage = 'Canceling diagnostic test alarms...');
    await NotificationService.instance.cancelDiagnosticTest(9999);
    await NotificationService.instance.cancelDiagnosticTest(9998);
    await NotificationService.instance.cancelDiagnosticTest(9997);
    await NotificationService.instance.cancelDiagnosticTest(9993);
    if (!mounted) return;
    setState(() => _testStatusMessage = 'Diagnostic tests canceled.');
    await _loadDiagnostics();
  }

  Future<void> _testPictureInPicture() async {
    setState(() => _testStatusMessage = 'Entering Picture-in-Picture mode...');
    final supported = await SystemFeaturesService.instance.isPipSupported();
    if (!supported) {
      if (!mounted) return;
      setState(() => _testStatusMessage =
          'Picture-in-picture is not supported on this device/Android version.');
      return;
    }
    final entered = await SystemFeaturesService.instance.enterPip();
    if (!entered && mounted) {
      final allowed = await SystemFeaturesService.instance.isPipAllowed();
      setState(() {
        _testStatusMessage = allowed
            ? 'Failed to enter Picture-in-Picture.'
            : 'Picture-in-picture permission is disabled in App Info! Tap "Allow in App Info" above.';
      });
    } else if (mounted) {
      setState(() => _testStatusMessage =
          'Entered Picture-in-Picture mode successfully!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final inPip = ref.watch(pipModeProvider);

    if (inPip) {
      return Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppPalette.pipBackground,
        ),
        child: Scaffold(
          backgroundColor: AppPalette.pipBackground,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppPalette.primary.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.picture_in_picture_alt_rounded,
                          size: 16,
                          color: AppPalette.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Vyayama PiP Active',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppPalette.pipBadgeBackground.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.pipBadgeText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Alarms & Reminders: Ready\nTap window to return to full app',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm & Notification Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDiagnostics,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Status summary banner
                  _buildSummaryBanner(isDark),
                  const SizedBox(height: AppSpacing.md),

                  // OS Permission Card
                  _buildPermissionsCard(scheme, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // Channels Card
                  _buildChannelsCard(scheme, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // Timezone & Recovery Card
                  _buildEnvironmentCard(scheme, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // Pending Notifications Card
                  _buildPendingCard(scheme, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // Timing & Delay Diagnostics Card
                  _buildTimingDiagnosticsCard(scheme, isDark),
                  const SizedBox(height: AppSpacing.md),

                  // Manual Testing Suite
                  _buildTestingSuiteCard(scheme, isDark),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryBanner(bool isDark) {
    final allHealthy = _notifEnabled &&
        _exactAlarmsAllowed &&
        _wakeChannelEnabled &&
        _bedtimeChannelEnabled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: allHealthy
            ? context.colors.diagnosticHealthy
            : context.colors.streakContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allHealthy ? Colors.green.shade400 : Colors.orange.shade400,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            allHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: allHealthy ? Colors.green : Colors.orange,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allHealthy
                      ? 'Alarm Subsystem Fully Operational'
                      : 'Alarm Permissions Need Attention',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  allHealthy
                      ? 'Exact alarms, notification channels, and recovery are configured properly.'
                      : 'Some notifications or exact alarms might be blocked by system settings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard(ColorScheme scheme, bool isDark) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Permissions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              icon: Icons.notifications_active_rounded,
              label: 'Notifications Enabled',
              status: _notifEnabled,
              actionLabel: _notifEnabled ? null : 'Request',
              onAction: () async {
                await NotificationService.instance.requestNotificationPermission();
                await _loadDiagnostics();
              },
            ),
            const Divider(height: 16),
            _buildStatusRow(
              icon: Icons.alarm_rounded,
              label: 'Alarms & Reminders (App Info)',
              subtitle: 'SCHEDULE_EXACT_ALARM • Allows medicine alarms to ring on time',
              status: _exactAlarmsAllowed,
              actionLabel: _exactAlarmsAllowed ? 'Configure' : 'Allow in App Info',
              onAction: () async {
                await SystemFeaturesService.instance.openAlarmsAndRemindersSettings();
                await _loadDiagnostics();
              },
            ),
            const Divider(height: 16),
            _buildStatusRow(
              icon: Icons.picture_in_picture_alt_rounded,
              label: 'Picture-in-Picture (App Info)',
              subtitle: _pipSupported
                  ? 'Allows floating workout timer and live reminders over other apps'
                  : 'Picture-in-picture is not supported on this Android OS version',
              status: _pipAllowed,
              actionLabel: _pipSupported
                  ? (_pipAllowed ? 'Configure' : 'Allow in App Info')
                  : null,
              onAction: () async {
                await SystemFeaturesService.instance.openPipSettings();
                await _loadDiagnostics();
              },
            ),
            const Divider(height: 16),
            _buildStatusRow(
              icon: Icons.music_note_rounded,
              label: 'Music & Audio (READ_MEDIA_AUDIO)',
              subtitle: 'Allows playback of custom alarm audio files',
              status: _audioPermissionGranted,
              actionLabel: _audioPermissionGranted ? null : 'Request Audio',
              onAction: () async {
                await NotificationService.instance.requestAudioPermission();
                await _loadDiagnostics();
              },
            ),
            const Divider(height: 16),
            _buildStatusRow(
              icon: Icons.battery_charging_full_rounded,
              label: 'Battery Optimization (Unrestricted)',
              subtitle: 'Ensures background alarms ring even in deep sleep/Doze',
              status: _batteryOptIgnored,
              actionLabel: _batteryOptIgnored ? null : 'Exempt / Fix',
              onAction: () async {
                await NotificationService.instance.requestIgnoreBatteryOptimizations();
                await _loadDiagnostics();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsCard(ColorScheme scheme, bool isDark) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Channels (Android 8+)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              icon: Icons.alarm_on_rounded,
              label: 'Wake Alarms Channel',
              subtitle: 'Sound: wakeup_alarm.wav | High Priority',
              status: _wakeChannelEnabled,
            ),
            const Divider(height: 16),
            _buildStatusRow(
              icon: Icons.bedtime_rounded,
              label: 'Bedtime Guidance Channel',
              subtitle: 'Gentle wind-down reminder',
              status: _bedtimeChannelEnabled,
            ),
            const Divider(height: 16),
            _buildStatusRow(
              icon: Icons.medication_rounded,
              label: 'Medicine Reminders Channel',
              subtitle: 'Sound: warning_alarm.wav | High Priority',
              status: _medicineChannelEnabled,
            ),
            const Divider(height: 16),
            _buildStatusRow(
              icon: Icons.restaurant_rounded,
              label: 'Meal Reminders Channel',
              subtitle: 'Daily meal timing nudges',
              status: _mealsChannelEnabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentCard(ColorScheme scheme, bool isDark) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Environment & Recovery',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Device Timezone',
              '$_timezoneName ($_timezoneOffset)',
              Icons.schedule_rounded,
            ),
            const Divider(height: 16),
            _buildInfoRow(
              'Startup Reconciliation',
              _reconciliationTime != null
                  ? '${_reconciliationSuccess == true ? "Healthy" : (_reconciliationSuccess == false ? "Failed" : "Unknown")} • Last run: ${_reconciliationTime!.hour.toString().padLeft(2, '0')}:${_reconciliationTime!.minute.toString().padLeft(2, '0')}:${_reconciliationTime!.second.toString().padLeft(2, '0')}'
                  : 'Pending first check',
              Icons.sync_rounded,
              trailingWidget: TextButton(
                onPressed: _runReconciliation,
                child: const Text('Re-sync Now'),
              ),
            ),
            if (_lastError != null) ...[
              const Divider(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last native error: $_lastError',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(ColorScheme scheme, bool isDark) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending System Alarms',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.limeGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_pendingNotifications.length} Active',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppPalette.deepGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_pendingNotifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No alarms currently registered in the Android system. Enable Wake-up alarm or Medicine reminders in their respective tabs to register alarms.',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...List.generate(_pendingNotifications.length, (index) {
                final item = _pendingNotifications[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.alarm_rounded,
                            size: 18, color: context.colors.streak),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title ?? 'Alarm #${item.id}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (item.body != null)
                                Text(
                                  item.body!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          'ID: ${item.id}',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingDiagnosticsCard(ColorScheme scheme, bool isDark) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Alarm Timing & Delivery Logs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (_diagnosticLogs.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.redAccent,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await NotificationDiagnosticLogger.instance.clear();
                      await _loadDiagnostics();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tracks scheduled target time vs actual delivery time to detect Android Doze delays in seconds.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (_diagnosticLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No alarm timing events recorded yet. Run a diagnostic test below or schedule a reminder to record real delivery delays.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              )
            else
              ..._diagnosticLogs.take(10).map((log) {
                final targetStr =
                    '${log.scheduledTime.hour.toString().padLeft(2, '0')}:${log.scheduledTime.minute.toString().padLeft(2, '0')}:${log.scheduledTime.second.toString().padLeft(2, '0')}';
                final isDelivered = log.firedTime != null;
                final delaySec = log.delaySeconds ?? 0;
                final isLate = delaySec.abs() > 30;

                final statusColor = !isDelivered
                    ? Colors.blueGrey
                    : (isLate ? Colors.orange : Colors.green);

                final statusText = !isDelivered
                    ? 'Pending delivery'
                    : (delaySec == 0
                        ? 'Fired on time'
                        : '${delaySec > 0 ? "+" : ""}${delaySec}s delay${isLate ? " (Doze delay)" : ""}');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              log.isExact ? Icons.alarm_on_rounded : Icons.access_time_rounded,
                              size: 16,
                              color: log.isExact ? AppPalette.limeGreen : Colors.blueGrey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Target: $targetStr (${log.isExact ? "Exact Alarm" : "Inexact"})',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'ID: ${log.id}',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTestingSuiteCard(ColorScheme scheme, bool isDark) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diagnostic Test Suite',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Validate that alarms ring and appear properly when the app is in the background or killed.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (_testStatusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppPalette.limeGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.limeGreen, width: 1),
                ),
                child: Text(
                  _testStatusMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.streak,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.notifications_active_rounded),
                label: const Text(
                  'Test Immediate Notification Alert',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _testImmediate,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.amberWarning,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.medication_rounded),
                label: const Text(
                  'Test 5s Medicine Alarm (Clock Style)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _testFiveSecondMedicineAlarm,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.pill,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.picture_in_picture_alt_rounded),
                label: const Text(
                  'Test Picture-in-Picture (PiP) Window',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _testPictureInPicture,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.timer_outlined, size: 18),
                    label: const Text(
                      '2m Wake Alarm',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _testTwoMinuteWakeAlarm,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.bedtime_outlined, size: 18),
                    label: const Text(
                      '2m Bedtime Nudge',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _testTwoMinuteNormal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel Test Alarms'),
                onPressed: _cancelTestAlarms,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool status,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: status ? Colors.green : Colors.redAccent,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {Widget? trailingWidget}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(value,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        if (trailingWidget != null) trailingWidget,
      ],
    );
  }
}
