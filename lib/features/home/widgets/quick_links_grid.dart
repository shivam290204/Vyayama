import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _Link {
  const _Link(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

const List<_Link> _links = [
  _Link('Nutrition', Icons.restaurant_menu, AppRoutes.nutrition),
  _Link('Health', Icons.monitor_heart_outlined, AppRoutes.health),
  _Link('Sleep', Icons.bedtime_outlined, AppRoutes.sleep),
  _Link('Challenges', Icons.emoji_events_outlined, AppRoutes.challenges),
  _Link('Teams', Icons.groups_outlined, AppRoutes.teams),
];

/// Quick-link tiles to Nutrition, Health, Sleep, Challenges and Teams.
class QuickLinksGrid extends StatelessWidget {
  /// Creates the grid.
  const QuickLinksGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 88,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _links.length,
      itemBuilder: (context, i) {
        final link = _links[i];
        return Semantics(
          button: true,
          label: link.label,
          excludeSemantics: true,
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(link.path),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(link.icon, size: 28, color: scheme.primary),
                    const SizedBox(height: 6),
                    Text(
                      link.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
