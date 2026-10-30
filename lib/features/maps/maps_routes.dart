import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/maps/presentation/screens/maps_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_recording_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/saved_routes_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes for the Maps & Outdoor Activities feature.
final List<RouteBase> mapsRoutes = [
  GoRoute(
    path: AppRoutes.maps,
    builder: (context, state) => const MapsScreen(),
    routes: [
      GoRoute(
        path: 'record',
        builder: (context, state) => const OutdoorRecordingScreen(),
      ),
      GoRoute(
        path: 'saved',
        builder: (context, state) => const SavedRoutesScreen(),
      ),
    ],
  ),
];

