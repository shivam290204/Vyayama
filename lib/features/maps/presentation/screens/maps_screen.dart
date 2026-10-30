import 'dart:async';
import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/models/user_location_state.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_recording_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/route_detail_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/saved_routes_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/map_controls_overlay.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_discovery_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Main interactive Maps and Outdoor Route Discovery screen.
class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  final MapController _mapController = MapController();
  SavedRoute? _selectedRoute;
  Timer? _mapMoveDebounce;

  @override
  void dispose() {
    _mapMoveDebounce?.cancel();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _mapMoveDebounce?.cancel();
    _mapMoveDebounce = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final currentCenter = ref.read(selectedMapCenterProvider) ??
          ref.read(userLocationStateProvider).position;
      final newCenter = camera.center;
      if (currentCenter == null ||
          haversineDistance(currentCenter, newCenter) > 350) {
        ref.read(selectedMapCenterProvider.notifier).state = newCenter;
      }
    });
  }

  void _recenterLocation() async {
    // 1. Clear any manually selected map center pin so we follow live user GPS
    ref.read(selectedMapCenterProvider.notifier).state = null;

    final locState = ref.read(userLocationStateProvider);
    if (locState.isAvailable) {
      _mapController.move(locState.position!, 15.0);
    } else {
      await ref.read(userLocationNotifierProvider.notifier).refreshLocation();
      final updated = ref.read(userLocationStateProvider);
      if (updated.isAvailable && mounted) {
        _mapController.move(updated.position!, 15.0);
      }
    }
  }

  void _onRouteSelected(SavedRoute route) {
    setState(() {
      _selectedRoute = route;
    });
    if (route.startPoint != null) {
      _mapController.move(route.startPoint!, 14.0);
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RouteDetailScreen(route: route),
      ),
    );
  }

  void _openRecordingScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const OutdoorRecordingScreen(),
      ),
    );
  }

  void _openSavedRoutesScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SavedRoutesScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(userLocationStateProvider);
    final manualCenter = ref.watch(selectedMapCenterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Automatically animate camera to user location when first GPS fix is acquired
    ref.listen<UserLocationState>(userLocationNotifierProvider, (prev, next) {
      if (next.isAvailable && (prev == null || !prev.isAvailable)) {
        final currentManual = ref.read(selectedMapCenterProvider);
        if (currentManual == null) {
          _mapController.move(next.position!, 14.5);
        }
      }
    });

    final effectiveCenter = manualCenter ??
        locState.bestAvailablePosition ??
        const LatLng(20.0, 0.0);
    final initialZoom =
        (manualCenter != null || locState.hasPosition) ? 14.5 : 2.5;

    final discoveredRoutes =
        ref.watch(discoveredRoutesProvider).asData?.value ?? [];

    // Polylines to render: selected route or all discovered route hints
    final polylines = <Polyline>[];
    final markers = <Marker>[];

    // Draw discovered route paths with subtle glow
    for (final r in discoveredRoutes) {
      final isSelected = _selectedRoute?.id == r.id;
      final polyColor = isSelected
          ? AppPalette.limeGreen
          : (isDark
              ? AppPalette.limeGreen.withValues(alpha: 0.50)
              : AppPalette.forestGreen.withValues(alpha: 0.65));

      polylines.add(
        Polyline(
          points: r.points.map((p) => p.toLatLng()).toList(),
          strokeWidth: isSelected ? 5.0 : 3.5,
          color: polyColor,
        ),
      );

      // Start marker for route
      if (r.startPoint != null) {
        markers.add(
          Marker(
            point: r.startPoint!,
            width: 32,
            height: 32,
            child: GestureDetector(
              onTap: () => _onRouteSelected(r),
              child: Container(
                decoration: BoxDecoration(
                  color: AppPalette.forestGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.0),
                ),
                child: Icon(r.activityType.icon, color: Colors.white, size: 16),
              ),
            ),
          ),
        );
      }
    }

    // User Current Location Marker (Strictly bound to actual GPS position)
    if (locState.position != null) {
      markers.add(
        Marker(
          point: locState.position!,
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppPalette.limeGreen.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: AppPalette.limeGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3.0),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-screen Interactive OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: effectiveCenter,
              initialZoom: initialZoom,
              minZoom: 3.0,
              maxZoom: 18.0,
              onPositionChanged: _onPositionChanged,
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
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),

          // 2. Floating Controls Overlay (Search Bar & Map Buttons)
          MapControlsOverlay(
            mapController: _mapController,
            onRecenter: _recenterLocation,
            onSavedRoutesTap: _openSavedRoutesScreen,
          ),

          // 3. Expandable Bottom Sheet (Nearby Routes & Start Recording)
          RouteDiscoverySheet(
            onRouteSelected: _onRouteSelected,
            onRecordPressed: _openRecordingScreen,
          ),
        ],
      ),
    );
  }
}
