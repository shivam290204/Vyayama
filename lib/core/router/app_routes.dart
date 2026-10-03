/// Every route path in the app. Shared contract for all parts.
abstract final class AppRoutes {
  // Auth and onboarding
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgot = '/forgot';
  static const String onboarding = '/onboarding';

  // Home area
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String schedule = '/schedule';
  static const String dailyBoost = '/boost';
  static const String challenges = '/challenges';

  // Workouts
  static const String workouts = '/workouts';
  static const String workoutPlan = '/workouts/plan/:id';
  static const String workoutSession = '/workouts/session/:dayId';
  static const String exercise = '/workouts/exercise/:id';
  static const String planBuilder = '/workouts/builder';

  /// Prefix of the guided session (shown full screen, no bottom bar).
  static const String workoutSessionPrefix = '/workouts/session';

  // Health, nutrition, sleep, teams
  static const String nutrition = '/nutrition';
  static const String health = '/health';
  static const String sleep = '/sleep';
  static const String teams = '/teams';
  static const String teamDetail = '/teams/:id';

  // Friends and snaps
  static const String friends = '/friends';
  static const String friendsAdd = '/friends/add';
  static const String friendsRequests = '/friends/requests';
  static const String friendDetail = '/friends/:id';
  static const String snapsCamera = '/snaps/camera';
  static const String snapsPreview = '/snaps/preview';
  static const String snapsInbox = '/snaps/inbox';
  static const String snapView = '/snaps/view/:id';
  static const String feed = '/feed';

  // Settings and profile
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';

  // Helpers for parameterized paths
  static String workoutPlanPath(String id) =>
      '/workouts/plan/${Uri.encodeComponent(id)}';
  static String workoutSessionPath(String dayId) =>
      '/workouts/session/${Uri.encodeComponent(dayId)}';
  static String exercisePath(String id) =>
      '/workouts/exercise/${Uri.encodeComponent(id)}';
  static String teamDetailPath(String id) =>
      '/teams/${Uri.encodeComponent(id)}';
  static String friendDetailPath(String id) =>
      '/friends/${Uri.encodeComponent(id)}';
  static String snapViewPath(String id) =>
      '/snaps/view/${Uri.encodeComponent(id)}';
}
