import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/auth/screens/forgot_password_screen.dart';
import 'package:fitbuddy/features/auth/screens/login_screen.dart';
import 'package:fitbuddy/features/auth/screens/signup_screen.dart';
import 'package:fitbuddy/features/auth/screens/splash_screen.dart';

/// Splash, login, sign-up and forgot-password routes.
final List<RouteBase> authRoutes = [
  GoRoute(
    path: AppRoutes.splash,
    builder: (context, state) => const SplashScreen(),
  ),
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => const LoginScreen(),
  ),
  GoRoute(
    path: AppRoutes.signup,
    builder: (context, state) => const SignupScreen(),
  ),
  GoRoute(
    path: AppRoutes.forgot,
    builder: (context, state) => const ForgotPasswordScreen(),
  ),
];
