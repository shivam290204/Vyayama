import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _Link {
  const _Link(this.label, this.icon, this.path, this.gradientColors);

  final String label;
  final IconData icon;
  final String path;
  final List<Color> gradientColors;
}

/// Quick-link tiles to Nutrition, Health, Sleep, Challenges and Teams.
class QuickLinksGrid extends StatelessWidget {
  /// Creates the grid.
  const QuickLinksGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final links = <_Link>[
      const _Link('Nutrition', Icons.restaurant_menu, AppRoutes.nutrition,
          [AppPalette.deepGreen, AppPalette.forestGreen]),
      const _Link('Health', Icons.monitor_heart_outlined, AppRoutes.health,
          [AppPalette.softCoral, AppPalette.deepCoral]),
      const _Link('Sleep', Icons.bedtime_outlined, AppRoutes.sleep,
          [AppPalette.charcoalGreen, AppPalette.forestGreen]),
      const _Link('Challenges', Icons.emoji_events_outlined, AppRoutes.challenges,
          [AppPalette.limeGreen, AppPalette.deepGreen]),
      const _Link('Teams', Icons.groups_outlined, AppRoutes.teams,
          [AppPalette.forestGreen, AppPalette.deepGreen]),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 100,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: links.length,
      itemBuilder: (context, i) {
        final link = links[i];
        return _QuickLinkTile(link: link, text: text, scheme: scheme);
      },
    );
  }
}

class _QuickLinkTile extends StatefulWidget {
  const _QuickLinkTile({
    required this.link,
    required this.text,
    required this.scheme,
  });

  final _Link link;
  final TextTheme text;
  final ColorScheme scheme;

  @override
  State<_QuickLinkTile> createState() => _QuickLinkTileState();
}

class _QuickLinkTileState extends State<_QuickLinkTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget card = GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push(link.path),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gradient icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: link.gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: link.gradientColors.first.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(link.icon, size: 20, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            link.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.text.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (reduceMotion) return card;

    return GestureDetector(
      onTapDown: (_) => _hoverController.forward(),
      onTapUp: (_) => _hoverController.reverse(),
      onTapCancel: () => _hoverController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: card,
      ),
    );
  }
}
