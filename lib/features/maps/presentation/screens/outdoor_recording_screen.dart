import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/services/gps_filter_service.dart';
import 'package:fitbuddy/features/maps/domain/services/location_tracking_service.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_summary_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/outdoor_recovery_dialog.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/map_tile_layer.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen live GPS outdoor activity recording.
class OutdoorRecordingScreen extends ConsumerStatefulWidget {
  const OutdoorRecordingScreen({super.key, this.initialType});

  final OutdoorActivityType? initialType;

  @override
  ConsumerState<OutdoorRecordingScreen> createState() =>
      _OutdoorRecordingScreenState();
}

class _OutdoorRecordingScreenState
    extends ConsumerState<OutdoorRecordingScreen> {
  late OutdoorActivityType _selectedType;
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? OutdoorActivityType.walking;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForCrashRecovery();
    });
  }

  Future<void> _checkForCrashRecovery() async {
    if (!mounted) return;
    await OutdoorSessionRecoveryDialog.promptIfNeeded(context, ref);
  }

  void _onStart() async {
    final service = ref.read(locationTrackingServiceProvider);

    // Display plain-language rationale dialog before system prompt if not yet granted
    final permCheck =
        await service.checkPermissionDetailed(requestIfNeeded: false);
    if (permCheck == LocationPermissionResult.denied && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Location Access for Outdoor Tracking'),
          content: const Text(
            'Vyayama needs access to your GPS location while recording to map your path, measure distance, and track pace and speed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppPalette.forestGreen),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final started = await service.startRecording(_selectedType);
    if (!started && mounted) {
      final errorMsg = service.value.initializationError ??
          'Location permission or GPS is required to record outdoor activities.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _onPause() {
    ref.read(locationTrackingServiceProvider).pauseRecording();
  }

  void _onResume() {
    ref.read(locationTrackingServiceProvider).resumeRecording();
  }

  void _onFinish() async {
    final service = ref.read(locationTrackingServiceProvider);
    final activity = await service.finishRecording();
    if (activity != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OutdoorSummaryScreen(activity: activity),
        ),
      );
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onDiscard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Workout?'),
        content: const Text(
          'Are you sure you want to discard this outdoor workout? Tracked route data will not be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Recording'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.deepCoral),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ref.read(locationTrackingServiceProvider).discardRecording();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final trackingState =
        ref.watch(trackingStateProvider).asData?.value;

    final status = trackingState?.status ?? OutdoorActivityStatus.discarded;
    final isRecording = status == OutdoorActivityStatus.active;
    final isPaused = status == OutdoorActivityStatus.paused;
    final hasStarted = isRecording || isPaused;

    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;
    final cardBg =
        isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final borderColor =
        isDark ? AppPalette.darkOutline : AppPalette.lightOutline;

    // Follow live coordinates with map camera safely when map is ready
    final currentPos = trackingState?.currentPosition;
    if (currentPos != null && hasStarted && _isMapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(currentPos, _mapController.camera.zoom);
        } catch (_) {}
      });
    }

    final filter = GpsFilterService.forActivity(_selectedType);
    final segments = filter.splitIntoSegments(trackingState?.points ?? []);
    final polylinePoints =
        trackingState?.points.map((p) => p.toLatLng()).toList() ?? [];

    return PopScope(
      canPop: !hasStarted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && hasStarted) {
          _onDiscard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: hasStarted ? _onDiscard : () => Navigator.of(context).pop(),
          ),
          title: Text(hasStarted ? '${_selectedType.label} Workout' : 'Record Activity'),
          actions: [
            if (hasStarted)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRecording
                          ? AppPalette.limeGreen.withValues(alpha: 0.16)
                          : AppPalette.softCoral.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: isRecording ? AppPalette.limeGreen : AppPalette.deepCoral,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isRecording ? 'LIVE GPS' : 'PAUSED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isRecording ? AppPalette.limeGreen : AppPalette.deepCoral,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // 1. Live Map Viewport or Acquiring Signal View
            Expanded(
              flex: 4,
              child: (currentPos == null && polylinePoints.isEmpty)
                  ? Container(
                      color: cardBg,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppPalette.forestGreen,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Acquiring GPS Signal...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Stand in an open area for best accuracy.',
                              style: TextStyle(fontSize: 13, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: currentPos ?? polylinePoints.last,
                            initialZoom: 15.5,
                            minZoom: 3.0,
                            maxZoom: 18.0,
                            onMapReady: () {
                              if (mounted) {
                                setState(() => _isMapReady = true);
                              }
                            },
                          ),
                          children: [
                            const AppMapTileLayer(),
                            const AppMapAttribution(),
                            if (segments.isNotEmpty)
                              PolylineLayer(
                                polylines: segments
                                    .where((s) => s.length >= 2)
                                    .map((s) => Polyline(
                                          points: s.map((p) => p.toLatLng()).toList(),
                                          strokeWidth: 5.0,
                                          color: AppPalette.limeGreen,
                                        ))
                                    .toList(),
                              ),
                            if (currentPos != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: currentPos,
                                    width: 36,
                                    height: 36,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppPalette.limeGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppPalette.offWhite, width: 3.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppPalette.darkSurface.withValues(alpha: 0.38),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
            ),

            // 2. Metrics & Controls Dashboard
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor, width: 1.0)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Activity Type Chips (if not started)
                    if (!hasStarted)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: OutdoorActivityType.values.map((type) {
                          final isSelected = _selectedType == type;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: FilterChip(
                              avatar: Icon(type.icon, size: 18),
                              label: Text(type.label),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedType = type),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      const SizedBox.shrink(),

                    // Big Distance Hero Metric
                    Column(
                      children: [
                        Text(
                          trackingState?.formattedDistance ?? '0.00',
                          style: TextStyle(
                            fontSize: 58,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'KILOMETERS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),

                    // Secondary Metrics Row: Duration, Avg Pace, Speed
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _LiveMetricColumn(
                          label: 'TIME',
                          value: trackingState?.formattedDuration ?? '00:00',
                          color: AppPalette.activityMinutes,
                        ),
                        _LiveMetricColumn(
                          label: 'AVG PACE',
                          value: trackingState != null && trackingState.currentPaceSecondsPerKm > 0
                              ? '${trackingState.formattedPace} /km'
                              : '--:--',
                          color: AppPalette.activitySteps,
                        ),
                        _LiveMetricColumn(
                          label: 'SPEED',
                          value: '${(trackingState?.currentSpeedKmh ?? 0.0).toStringAsFixed(1)} km/h',
                          color: AppPalette.activityCalories,
                        ),
                      ],
                    ),

                    // Action Controls
                    if (!hasStarted)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.forestGreen,
                            foregroundColor: AppPalette.limeGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: trackingState?.isInitializingGps == true
                              ? null
                              : _onStart,
                          icon: trackingState?.isInitializingGps == true
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppPalette.limeGreen,
                                  ),
                                )
                              : const Icon(Icons.play_arrow_rounded, size: 28),
                          label: Text(
                            trackingState?.isInitializingGps == true
                                ? 'ACQUIRING GPS...'
                                : 'START WORKOUT',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Pause / Resume Button
                          if (isRecording)
                            _ControlButton(
                              icon: Icons.pause_rounded,
                              label: 'Pause',
                              backgroundColor: AppPalette.deepGreen,
                              iconColor: AppPalette.offWhite,
                              onPressed: _onPause,
                            )
                          else
                            _ControlButton(
                              icon: Icons.play_arrow_rounded,
                              label: 'Resume',
                              backgroundColor: AppPalette.forestGreen,
                              iconColor: AppPalette.limeGreen,
                              onPressed: _onResume,
                            ),

                          // Finish Button
                          _ControlButton(
                            icon: Icons.stop_rounded,
                            label: 'Finish',
                            backgroundColor: AppPalette.limeGreen,
                            iconColor: AppPalette.charcoalGreen,
                            onPressed: _onFinish,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveMetricColumn extends StatelessWidget {
  const _LiveMetricColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: textMuted,
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppPalette.darkSurface.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 34),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}
