import 'package:flutter/material.dart';

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

class _ConnectedHealthSectionState extends State<ConnectedHealthSection> {
  bool _isLoading = true;
  bool _isConnected = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await HealthService.instance.isSyncEnabled();
    if (mounted) {
      setState(() {
        _isConnected = enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSync(bool value) async {
    setState(() => _isLoading = true);
    final service = HealthService.instance;

    if (value) {
      final granted = await service.connect();
      if (!mounted) return;
      if (granted) {
        setState(() {
          _isConnected = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Connected to ${service.serviceName}. Steps and calories can now sync when available.'),
          ),
        );
      } else {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not connect to ${service.serviceName}. Please grant permissions in system settings.'),
          ),
        );
      }
    } else {
      await service.disconnect();
      if (!mounted) return;
      setState(() {
        _isConnected = false;
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
      final synced = await StepTrackingService.instance.syncWithHealthService();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'Steps and active calories synchronized successfully.'
                : 'No health data found. Check app permissions in ${HealthService.instance.serviceName}.',
          ),
        ),
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
      subtitle:
          'Connect Health Connect or Apple Health to sync steps and active calories.',
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
                            : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.health_and_safety_rounded,
                        color: _isConnected
                            ? context.colors.success
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
                                ? 'Connected • Steps and active calories can sync'
                                : 'Sync steps and calories from your health apps',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _isConnected
                                  ? context.colors.success
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: _isConnected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
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
                Icon(Icons.info_outline,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Health Connect on Android and Apple Health on iOS are supported.',
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
