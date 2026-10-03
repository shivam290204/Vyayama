import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/screens/add_friend_screen.dart';
import 'package:fitbuddy/features/friends/screens/friend_detail_screen.dart';
import 'package:fitbuddy/features/friends/screens/friend_requests_screen.dart';
import 'package:fitbuddy/features/friends/screens/friends_list_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes of the friends feature. Static paths come before `/friends/:id`.
final List<RouteBase> friendsRoutes = [
  GoRoute(
    path: AppRoutes.friends,
    builder: (context, state) => const FriendsListScreen(),
  ),
  GoRoute(
    path: AppRoutes.friendsAdd,
    builder: (context, state) => const AddFriendScreen(),
  ),
  GoRoute(
    path: AppRoutes.friendsRequests,
    builder: (context, state) => const FriendRequestsScreen(),
  ),
  GoRoute(
    path: AppRoutes.friendDetail,
    builder: (context, state) =>
        FriendDetailScreen(friendId: state.pathParameters['id']!),
  ),
];
