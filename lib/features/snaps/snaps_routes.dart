import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/snaps/screens/camera_screen.dart';
import 'package:fitbuddy/features/snaps/screens/friends_feed_screen.dart';
import 'package:fitbuddy/features/snaps/screens/snap_inbox_screen.dart';
import 'package:fitbuddy/features/snaps/screens/snap_preview_screen.dart';
import 'package:fitbuddy/features/snaps/screens/snap_view_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes of the snaps feature. Static paths come before `/snaps/view/:id`.
final List<RouteBase> snapsRoutes = [
  GoRoute(
    path: AppRoutes.snapsCamera,
    builder: (context, state) =>
        CameraScreen(toFriendId: state.uri.queryParameters['to']),
  ),
  GoRoute(
    path: AppRoutes.snapsPreview,
    builder: (context, state) =>
        SnapPreviewScreen(toFriendId: state.uri.queryParameters['to']),
  ),
  GoRoute(
    path: AppRoutes.snapsInbox,
    builder: (context, state) => const SnapInboxScreen(),
  ),
  GoRoute(
    path: AppRoutes.snapView,
    builder: (context, state) =>
        SnapViewScreen(snapId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: AppRoutes.feed,
    builder: (context, state) => const FriendsFeedScreen(),
  ),
];
