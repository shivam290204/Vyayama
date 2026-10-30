import 'dart:async';
import 'dart:math' as math;
import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/models/user_location_state.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_recording_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/route_detail_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/saved_routes_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/map_controls_overlay.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/map_tile_layer.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_discovery_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

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

  bool _isMapReady = false;
  bool _showSearchThisArea = false;
  LatLng? _currentCameraCenter;
  bool _hasTileError = false;
  DateTime? _lastTileErrorNotification;

  @override
  void dispose() {
    _mapMoveDebounce?.cancel();
    super.dispose();
  }

  /// Safely moves the map camera only when the controller has been fully initialized.
  void _safeMoveCamera(LatLng target, double zoom) {
    if (!_isMapReady) return;
    try {
      _mapController.move(target, zoom);
    } catch (e) {
      debugPrint('[MapsScreen] Safe move camera failed: $e');
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;

    _currentCameraCenter = camera.center;

    // Check distance between current camera center and active search center
    final searchCenter = ref.read(effectiveMapCenterProvider);
    final distanceMoved = searchCenter != null
        ? haversineDistance(searchCenter, camera.center)
        : 0.0;

    // Show "Search This Area" action pill if user has panned beyond threshold
    final movedBeyondThreshold = distanceMoved > 300;
    if (_showSearchThisArea != movedBeyondThreshold) {
      setState(() => _showSearchThisArea = movedBeyondThreshold);
    }

    // Debounce map movement by 600 ms before triggering automatic discovery
    _mapMoveDebounce?.cancel();
    _mapMoveDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (distanceMoved > 300) {
        ref.read(selectedMapCenterProvider.notifier).state = camera.center;
        setState(() => _showSearchThisArea = false);
      }
    });
  }

  void _onSearchThisAreaPressed() {
    _mapMoveDebounce?.cancel();
    if (_currentCameraCenter != null) {
      ref.read(selectedMapCenterProvider.notifier).state = _currentCameraCenter;
      setState(() => _showSearchThisArea = false);
    }
  }

  void _onTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    if (!mounted || _hasTileError) return;
    final now = DateTime.now();
    if (_lastTileErrorNotification == null ||
        now.difference(_lastTileErrorNotification!) > const Duration(seconds: 15)) {
      _lastTileErrorNotification = now;
      setState(() => _hasTileError = true);
    }
  }

  void _recenterLocation() async {
    // 1. Clear any manually selected map center pin so we follow live user GPS
    ref.read(selectedMapCenterProvider.notifier).state = null;
    setState(() => _showSearchThisArea = false);

    final locState = ref.read(userLocationStateProvider);
    if (locState.isAvailable && locState.position != null) {
      _safeMoveCamera(locState.position!, 15.0);
    } else {
      await ref.read(userLocationNotifierProvider.notifier).refreshLocation();
      final updated = ref.read(userLocationStateProvider);
      if (updated.isAvailable && updated.position != null && mounted) {
        _safeMoveCamera(updated.position!, 15.0);
      }
    }
  }

  void _onRouteSelected(SavedRoute route) {
    setState(() {
      _selectedRoute = route;
    });
    if (route.startPoint != null) {
      _safeMoveCamera(route.startPoint!, 14.0);
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
    final textPrimary = isDark ? AppPalette.darkText : AppPalette.lightText;
    final cardBg = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final borderColor = isDark ? AppPalette.darkOutline : AppPalette.lightOutline;

    // Automatically animate camera to user location when first GPS fix is acquired
    ref.listen<UserLocationState>(userLocationNotifierProvider, (prev, next) {
      if (next.isAvailable && (prev == null || !prev.isAvailable)) {
        final currentManual = ref.read(selectedMapCenterProvider);
        if (currentManual == null && next.position != null) {
          _safeMoveCamera(next.position!, 14.5);
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

    // 1. Manually Selected Map Center Pin (distinct visual indicator)
    if (manualCenter != null) {
      markers.add(
        Marker(
          point: manualCenter,
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: Tooltip(
            message: 'Search Center',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppPalette.forestGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_searching_rounded,
                    color: AppPalette.limeGreen,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. User Current Location Marker (Strictly bound to actual GPS position)
    // Only rendered when valid GPS fix is acquired; never renders fake GPS.
    if (locState.hasPosition && locState.position != null) {
      final heading = locState.heading;
      final hasValidHeading = heading != null && heading >= 0;

      markers.add(
        Marker(
          point: locState.position!,
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.limeGreen.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
              ),
              // Heading indicator when valid heading data is available
              if (hasValidHeading)
                Transform.rotate(
                  angle: heading * (math.pi / 180.0),
                  child: const Align(
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.navigation,
                      size: 15,
                      color: AppPalette.forestGreen,
                    ),
                  ),
                ),
              // Inner GPS fix dot
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
              onMapReady: () {
                if (mounted) {
                  setState(() => _isMapReady = true);
                }
              },
            ),
            children: [
              AppMapTileLayer(onError: _onTileError),
              const AppMapAttribution(),
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

          // 3. Tile Loading Error Feedback Banner (positioned alongside floating controls)
          if (_hasTileError)
            Positioned(
              top: 72,
              left: 16,
              right: 72,
              child: Material(
                key: const Key('tile_error_banner'),
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: cardBg.withValues(alpha: 0.95),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 18,
                        color: AppPalette.deepCoral,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Map tiles temporarily unavailable (offline or server busy).',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('tile_error_close_button'),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Dismiss tile warning',
                        onPressed: () => setState(() => _hasTileError = false),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Floating "Search This Area" Action Pill
          if (_showSearchThisArea)
            Positioned(
              top: 72,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(20),
                  color: cardBg,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _onSearchThisAreaPressed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.explore_outlined,
                            size: 16,
                            color: AppPalette.forestGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Search This Area',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 5. Expandable Bottom Sheet (Nearby Routes & Start Recording)
          RouteDiscoverySheet(
            onRouteSelected: _onRouteSelected,
            onRecordPressed: _openRecordingScreen,
          ),
        ],
      ),
    );
  }
}
