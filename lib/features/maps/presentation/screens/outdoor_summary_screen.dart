import 'package:url_launcher/url_launcher.dart';
import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Screen displaying the completed outdoor workout summary with route map and metrics.
class OutdoorSummaryScreen extends ConsumerStatefulWidget {
  const OutdoorSummaryScreen({super.key, required this.activity});

  final OutdoorActivity activity;

  @override
  ConsumerState<OutdoorSummaryScreen> createState() =>
      _OutdoorSummaryScreenState();
}

class _OutdoorSummaryScreenState extends ConsumerState<OutdoorSummaryScreen> {
  late TextEditingController _titleCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.activity.title.isNotEmpty
          ? widget.activity.title
          : '${widget.activity.activityType.label} Workout',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _onSaveActivity() async {
    setState(() => _isSaving = true);
    final repo = ref.read(outdoorActivityRepositoryProvider);

    final finalActivity = widget.activity.copyWith(
      title: _titleCtrl.text.trim().isNotEmpty
          ? _titleCtrl.text.trim()
          : '${widget.activity.activityType.label} Workout',
    );

    await repo.saveActivity(finalActivity);
    ref.invalidate(outdoorActivitiesListProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outdoor workout saved successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _onSaveAsRoute() async {
    final routeRepo = ref.read(savedRoutesRepositoryProvider);
    final newRoute = SavedRoute(
      id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
      name: _titleCtrl.text.trim().isNotEmpty
          ? _titleCtrl.text.trim()
          : '${widget.activity.activityType.label} Route',
      activityType: widget.activity.activityType,
      distanceMeters: widget.activity.distanceMeters,
      estimatedDurationSeconds: widget.activity.durationSeconds,
      difficulty: widget.activity.distanceKm > 5
          ? RouteDifficulty.hard
          : (widget.activity.distanceKm > 2.5
              ? RouteDifficulty.moderate
              : RouteDifficulty.easy),
      points: widget.activity.points,
      elevationGainMeters: widget.activity.elevationGainMeters,
      isSavedByUser: true,
      createdAt: DateTime.now(),
    );

    await routeRepo.saveRoute(newRoute);
    ref.invalidate(savedRoutesListProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Route "${newRoute.name}" saved to your routes!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;
    final cardBg =
        isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final borderColor =
        isDark ? AppPalette.darkOutline : AppPalette.lightOutline;

    final polylinePoints =
        widget.activity.points.map((p) => p.toLatLng()).toList();
    final center = polylinePoints.isNotEmpty
        ? polylinePoints[polylinePoints.length ~/ 2]
        : const LatLng(40.785091, -73.968285);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save as Route Template',
            onPressed: _onSaveAsRoute,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Map Overview with Route Polyline
            SizedBox(
              height: 240,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.vyayama.fitbuddy',
                  ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                            onTap: () => launchUrl(
                              Uri.parse('https://openstreetmap.org/copyright'),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                        ],
                      ),
                  if (polylinePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: polylinePoints,
                          strokeWidth: 4.5,
                          color: AppPalette.limeGreen,
                        ),
                      ],
                    ),
                  if (polylinePoints.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: polylinePoints.first,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppPalette.forestGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                          ),
                        ),
                        Marker(
                          point: polylinePoints.last,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppPalette.limeGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flag_rounded, color: AppPalette.charcoalGreen, size: 14),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // 2. Summary Details Card
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title text field
                  TextField(
                    controller: _titleCtrl,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Workout Title',
                      labelStyle: TextStyle(color: textMuted),
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Hero 2x2 Grid of Metrics
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.0),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryMetric(
                                label: 'Distance',
                                value: '${widget.activity.distanceKm.toStringAsFixed(2)} km',
                                icon: Icons.straighten_rounded,
                                color: AppPalette.activitySteps,
                              ),
                            ),
                            Expanded(
                              child: _SummaryMetric(
                                label: 'Duration',
                                value: widget.activity.formattedDuration,
                                icon: Icons.timer_rounded,
                                color: AppPalette.activityMinutes,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryMetric(
                                label: 'Avg Pace',
                                value: widget.activity.formattedPace,
                                icon: Icons.speed_rounded,
                                color: AppPalette.activitySteps,
                              ),
                            ),
                            Expanded(
                              child: _SummaryMetric(
                                label: 'Est. Calories',
                                value: '${widget.activity.caloriesBurned} kcal',
                                icon: Icons.local_fire_department_rounded,
                                color: AppPalette.activityCalories,
                              ),
                            ),
                          ],
                        ),
                        if (widget.activity.elevationGainMeters > 0) ...[
                          const Divider(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryMetric(
                                  label: 'Elevation Gain',
                                  value: '+${widget.activity.elevationGainMeters.round()} m',
                                  icon: Icons.terrain_rounded,
                                  color: AppPalette.activityMinutes,
                                ),
                              ),
                              Expanded(
                                child: _SummaryMetric(
                                  label: 'Avg Speed',
                                  value: '${widget.activity.averageSpeedKmh.toStringAsFixed(1)} km/h',
                                  icon: Icons.trending_up_rounded,
                                  color: AppPalette.activityCalories,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Save Activity Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.forestGreen,
                        foregroundColor: AppPalette.limeGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isSaving ? null : _onSaveActivity,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: const Text(
                        'Save Workout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Discard Button
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppPalette.deepCoral),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Discard Activity'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

