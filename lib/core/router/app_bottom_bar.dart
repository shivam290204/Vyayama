import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';

/// Bottom bar with five clean navigation tabs: Home, Workouts, Snap, Friends, and Maps.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selectedBranch,
    required this.onBranchSelected,
    this.onCameraPressed,
    this.snapBadgeCount = 0,
    this.friendsBadgeCount = 0,
  });

  final int selectedBranch;
  final ValueChanged<int> onBranchSelected;
  final VoidCallback? onCameraPressed;
  final int snapBadgeCount;
  final int friendsBadgeCount;

  static const _home = _TabSpec(0, 'Home', Icons.home_outlined, Icons.home_rounded);
  static const _workouts = _TabSpec(
    1,
    'Workouts',
    Icons.fitness_center_outlined,
    Icons.fitness_center_rounded,
  );
  static const _snap = _TabSpec(
    2,
    'Snap',
    Icons.photo_camera_outlined,
    Icons.photo_camera_rounded,
  );
  static const _friends = _TabSpec(
    3,
    'Friends',
    Icons.people_outline_rounded,
    Icons.people_rounded,
  );
  static const _maps = _TabSpec(
    4,
    'Maps',
    Icons.explore_outlined,
    Icons.explore_rounded,
  );

  Widget _tab(_TabSpec spec) {
    int badge = 0;
    if (spec.branch == 2) badge = snapBadgeCount;
    if (spec.branch == 3) badge = friendsBadgeCount;
    return _TabButton(
      spec: spec,
      selected: selectedBranch == spec.branch,
      badgeCount: badge,
      onTap: () => onBranchSelected(spec.branch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      elevation: 3,
      surfaceTintColor: scheme.surfaceTint,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _tab(_home),
              _tab(_workouts),
              _tab(_snap),
              _tab(_friends),
              _tab(_maps),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.branch, this.label, this.icon, this.selectedIcon);

  final int branch;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: spec.label,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Badge(
                    isLabelVisible: badgeCount > 0,
                    label: badgeCount > 9 ? const Text('9+') : Text('$badgeCount'),
                    backgroundColor: Colors.redAccent,
                    child: Icon(
                      selected ? spec.selectedIcon : spec.icon,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

