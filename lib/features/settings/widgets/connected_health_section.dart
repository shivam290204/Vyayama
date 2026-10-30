import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:fitbuddy/core/services/health_service.dart';
import 'package:fitbuddy/core/services/step_tracking_service.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/settings/widgets/settings_section.dart';

/// Settings section for connecting Apple HealthKit or Google Health Connect.
class ConnectedHealthSection extends StatefulWidget {
  const ConnectedHealthSection({super.key});

  @override
  State<ConnectedHealthSection> createState() => _ConnectedHealthSectionState();
}

class _ConnectedHealthSectionState extends State<ConnectedHealthSection> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isPermissionRequired = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadState();
    }
  }

  Future<void> _loadState() async {
    final service = HealthService.instance;
    if (!service.isSupported) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isPermissionRequired = false;
          _isLoading = false;
        });
      }
      return;
    }

    final syncEnabled = await service.isSyncEnabled();
    final hasPerm = await service.hasPermissions();

    if (mounted) {
      setState(() {
        if (syncEnabled && hasPerm) {
          _isConnected = true;
          _isPermissionRequired = false;
        } else if (syncEnabled && !hasPerm) {
          // Permissions were revoked or missing in system settings after sync was enabled
          _isConnected = false;
          _isPermissionRequired = true;
        } else {
          _isConnected = false;
          _isPermissionRequired = false;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSync(bool value) async {
    setState(() => _isLoading = true);
    final service = HealthService.instance;

    if (value) {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final isAvailable = await service.isHealthConnectAvailable();
        if (!isAvailable) {
          if (!mounted) return;
          setState(() {
            _isConnected = false;
            _isPermissionRequired = false;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Google Health Connect is not installed or requires an update.',
              ),
              action: SnackBarAction(
                label: 'Install',
                onPressed: service.installHealthConnect,
              ),
            ),
          );
          return;
        }
      }

      final granted = await service.connect();
      if (!mounted) return;
      if (granted) {
        setState(() {
          _isConnected = true;
          _isPermissionRequired = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${service.serviceName}! Steps and calories are now synchronized.'),
          ),
        );
      } else {
        setState(() {
          _isConnected = false;
          _isPermissionRequired = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not connect to ${service.serviceName}. Please grant permissions in system settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
    } else {
      await service.disconnect();
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _isPermissionRequired = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disconnected from ${service.serviceName}.'),
        ),
      );
    }
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    try {
      await StepTrackingService.instance.syncWithHealthService();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health data synchronized successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = HealthService.instance;
    final isSupported = service.isSupported;

    return SettingsSection(
      title: 'Connected Health Services',
      subtitle: 'Sync smartwatch steps and activity data with your device.',
      child: isSupported
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? context.colors.success.withValues(alpha: 0.15)
                            : _isPermissionRequired
                                ? theme.colorScheme.error.withValues(alpha: 0.15)
                                : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.health_and_safety_rounded,
                        color: _isConnected
                            ? context.colors.success
                            : _isPermissionRequired
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.serviceName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isConnected
                                ? 'Active • Synced with Wear OS, Apple Watch & health apps'
                                : _isPermissionRequired
                                    ? 'Permission required • Grant access in system settings'
                                    : 'Sync steps from smartwatches & health apps',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _isConnected
                                  ? context.colors.success
                                  : _isPermissionRequired
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant,
                              fontWeight: _isConnected || _isPermissionRequired ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Switch.adaptive(
                        value: _isConnected,
                        onChanged: _toggleSync,
                      ),
                  ],
                ),
                if (_isConnected) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _isSyncing ? null : _manualSync,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                    ),
                  ),
                ],
              ],
            )
          : Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Health Connect / Apple Health sync is supported on Android and iOS devices.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
