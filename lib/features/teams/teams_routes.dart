import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/teams/presentation/create_team_screen.dart';
import 'package:fitbuddy/features/teams/presentation/team_detail_screen.dart';
import 'package:fitbuddy/features/teams/presentation/teams_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes owned by the teams feature. The static `create` path comes before
/// the parameterised `:id` path.
final List<RouteBase> teamsRoutes = <RouteBase>[
  GoRoute(
    path: AppRoutes.teams,
    builder: (context, state) => const TeamsScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: 'create',
        builder: (context, state) => const CreateTeamScreen(),
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            TeamDetailScreen(teamId: state.pathParameters['id']!),
      ),
    ],
  ),
];
