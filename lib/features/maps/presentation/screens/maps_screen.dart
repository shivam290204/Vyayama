import 'package:url_launcher/url_launcher.dart';
import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_recording_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/route_detail_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/saved_routes_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/map_controls_overlay.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_discovery_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Main interactive Maps and Outdoor Route Discovery screen.
class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  final MapController _mapController = MapController();
  SavedRoute? _selectedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialLocation();
    });
  }

  Future<void> _fetchInitialLocation() async {
    final location =
        await ref.read(locationTrackingServiceProvider).getCurrentPosition();
    if (location != null && mounted) {
      ref.read(selectedMapCenterProvider.notifier).state = location;
      _mapController.move(location, 14.5);
    }
  }

  void _recenterLocation() async {
    final location =
        await ref.read(locationTrackingServiceProvider).getCurrentPosition();
    if (location != null && mounted) {
      ref.read(selectedMapCenterProvider.notifier).state = location;
      _mapController.move(location, 15.0);
    }
  }

  void _onRouteSelected(SavedRoute route) {
    setState(() {
      _selectedRoute = route;
    });
    if (route.points.isNotEmpty) {
      _mapController.move(route.startPoint, 14.0);
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
    final center = ref.watch(selectedMapCenterProvider);
    final userLocAsync = ref.watch(userCurrentLocationProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final userCoord = userLocAsync.asData?.value;
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
      if (r.points.isNotEmpty) {
        markers.add(
          Marker(
            point: r.startPoint,
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

    // User Current Location Marker
    if (userCoord != null) {
      markers.add(
        Marker(
          point: userCoord,
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
              initialCenter: center,
              initialZoom: 14.5,
              minZoom: 3.0,
              maxZoom: 18.0,
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
