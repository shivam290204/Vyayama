import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App bar with a back button that falls back to Home when there is nothing
/// to pop (for example after `context.go`).
class WellnessAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates the app bar.
  const WellnessAppBar({super.key, required this.title, this.actions});

  /// Screen title.
  final String title;

  /// Optional trailing actions.
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        },
      ),
      actions: actions,
    );
  }
}
