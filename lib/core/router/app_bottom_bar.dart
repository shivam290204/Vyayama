import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';

/// Bottom bar with four tabs and a large center Camera button.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selectedBranch,
    required this.onBranchSelected,
    required this.onCameraPressed,
  });

  final int selectedBranch;
  final ValueChanged<int> onBranchSelected;
  final VoidCallback onCameraPressed;

  static const _home = _TabSpec(0, 'Home', Icons.home_outlined, Icons.home_rounded);
  static const _workouts = _TabSpec(
    1,
    'Workouts',
    Icons.fitness_center_outlined,
    Icons.fitness_center_rounded,
  );
  static const _friends = _TabSpec(
    2,
    'Friends',
    Icons.people_outline_rounded,
    Icons.people_rounded,
  );
  static const _profile = _TabSpec(
    3,
    'Profile',
    Icons.person_outline_rounded,
    Icons.person_rounded,
  );

  Widget _tab(_TabSpec spec) => _TabButton(
        spec: spec,
        selected: selectedBranch == spec.branch,
        onTap: () => onBranchSelected(spec.branch),
      );

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
          height: 72,
          child: Row(
            children: [
              _tab(_home),
              _tab(_workouts),
              Expanded(
                child: Center(child: _CameraButton(onPressed: onCameraPressed)),
              ),
              _tab(_friends),
              _tab(_profile),
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
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

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
                  width: 56,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    selected ? spec.selectedIcon : spec.icon,
                    color: color,
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

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Open camera to share an exercise snap',
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: scheme.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Icon(
              Icons.photo_camera_rounded,
              size: 30,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
