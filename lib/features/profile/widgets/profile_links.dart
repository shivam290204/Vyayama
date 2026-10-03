import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';

/// Links from Profile to the features that are not bottom-bar tabs.
class ProfileLinks extends StatelessWidget {
  const ProfileLinks({super.key});

  static const List<(IconData, String, String)> _links = [
    (Icons.restaurant_menu_rounded, 'Nutrition', AppRoutes.nutrition),
    (Icons.favorite_border_rounded, 'Health', AppRoutes.health),
    (Icons.bedtime_outlined, 'Sleep', AppRoutes.sleep),
    (Icons.emoji_events_outlined, 'Challenges', AppRoutes.challenges),
    (Icons.groups_outlined, 'Teams', AppRoutes.teams),
    (Icons.auto_awesome_outlined, 'Daily Boost', AppRoutes.dailyBoost),
    (Icons.settings_outlined, 'Settings', AppRoutes.settings),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < _links.length; i++) ...[
            ListTile(
              minTileHeight: 56,
              leading: Icon(_links[i].$1),
              title: Text(_links[i].$2),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(_links[i].$3),
            ),
            if (i < _links.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}
