import 'package:url_launcher/url_launcher.dart';
import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_recording_screen.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Screen for inspecting a specific route in detail before starting.
class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({super.key, required this.route});

  final SavedRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final polylinePoints = route.points.map((p) => p.toLatLng()).toList();
    final center = polylinePoints.isNotEmpty
        ? polylinePoints[polylinePoints.length ~/ 2]
        : const LatLng(40.785091, -73.968285);

    final savedRoutes = ref.watch(savedRoutesListProvider).asData?.value ?? [];
    final isSaved = savedRoutes.any((r) => r.id == route.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
        actions: [
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isSaved ? AppPalette.limeGreen : null,
            ),
            tooltip: isSaved ? 'Remove from Saved' : 'Save Route',
            onPressed: () async {
              final repo = ref.read(savedRoutesRepositoryProvider);
              if (isSaved) {
                await repo.deleteRoute(route.id);
                ref.invalidate(savedRoutesListProvider);
              } else {
                await repo.saveRoute(route.copyWith(isSavedByUser: true));
                ref.invalidate(savedRoutesListProvider);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Interactive Route Map
          Expanded(
            flex: 5,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14.5,
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
                        strokeWidth: 5.0,
                        color: AppPalette.limeGreen,
                      ),
                    ],
                  ),
                if (polylinePoints.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: polylinePoints.first,
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppPalette.forestGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 2. Route Details Sheet
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor, width: 1.0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              route.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppPalette.limeGreen.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              route.formattedDifficulty.toUpperCase(),
                              style: const TextStyle(
                                color: AppPalette.limeGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        route.surfaceType == RouteSurface.unknown
                            ? '${route.activityType.label} • ${route.isLoop ? 'LOOP' : 'OUT & BACK'}'
                            : '${route.activityType.label} • ${route.surfaceType.name.toUpperCase()} SURFACE • ${route.isLoop ? 'LOOP' : 'OUT & BACK'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metrics Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _DetailMetric(
                            label: 'DISTANCE',
                            value: route.formattedDistance,
                            icon: Icons.straighten_rounded,
                            color: AppPalette.activitySteps,
                          ),
                          _DetailMetric(
                            label: 'EST. TIME',
                            value: route.formattedDuration,
                            icon: Icons.schedule_rounded,
                            color: AppPalette.activityMinutes,
                          ),
                          _DetailMetric(
                            label: 'ELEVATION',
                            value: route.formattedElevation,
                            icon: Icons.terrain_rounded,
                            color: AppPalette.activityCalories,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      if (route.description.isNotEmpty) ...[
                        Text(
                          'Route Description',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route.description,
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Start Workout Button
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
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OutdoorRecordingScreen(
                              initialType: route.activityType,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.directions_run_rounded, size: 22),
                      label: const Text(
                        'Start Workout on this Route',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
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

    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted),
        ),
      ],
    );
  }
}

