import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/profile/screens/edit_profile_screen.dart';
import 'package:fitbuddy/features/profile/screens/profile_screen.dart';

/// Profile tab branch routes.
final List<RouteBase> profileRoutes = [
  GoRoute(
    path: AppRoutes.profile,
    builder: (context, state) => const ProfileScreen(),
  ),
  GoRoute(
    path: AppRoutes.profileEdit,
    builder: (context, state) => const EditProfileScreen(),
  ),
];
