import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom modal sheet for filtering discoverable routes.
class RouteFilterSheet extends ConsumerStatefulWidget {
  const RouteFilterSheet({super.key});

  @override
  ConsumerState<RouteFilterSheet> createState() => _RouteFilterSheetState();
}

class _RouteFilterSheetState extends ConsumerState<RouteFilterSheet> {
  late RouteFilter _current;

  @override
  void initState() {
    super.initState();
    _current = ref.read(activeRouteFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkOutline : AppPalette.lightOutline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Route Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _current = const RouteFilter();
                    });
                  },
                  child: const Text('Reset All'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 1. Activity Type
            _FilterSectionTitle(title: 'Activity', color: textMuted),
            Wrap(
              spacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'All Activities',
                  selected: _current.activityType == null,
                  onSelected: (val) => setState(() => _current = _current.copyWith(clearActivityType: true)),
                ),
                for (final type in OutdoorActivityType.values)
                  _buildChoiceChip(
                    label: type.label,
                    icon: type.icon,
                    selected: _current.activityType == type,
                    onSelected: (val) => setState(() => _current = _current.copyWith(activityType: type)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Distance
            _FilterSectionTitle(title: 'Distance', color: textMuted),
            Wrap(
              spacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'Any',
                  selected: _current.minDistanceKm == null && _current.maxDistanceKm == null,
                  onSelected: (val) => setState(() => _current = _current.copyWith(clearDistance: true)),
                ),
                _buildChoiceChip(
                  label: 'Under 3 km',
                  selected: _current.maxDistanceKm == 3.0,
                  onSelected: (val) => setState(() => _current = _current.copyWith(minDistanceKm: 0, maxDistanceKm: 3.0)),
                ),
                _buildChoiceChip(
                  label: '3 - 5 km',
                  selected: _current.minDistanceKm == 3.0 && _current.maxDistanceKm == 5.0,
                  onSelected: (val) => setState(() => _current = _current.copyWith(minDistanceKm: 3.0, maxDistanceKm: 5.0)),
                ),
                _buildChoiceChip(
                  label: '5 - 10 km',
                  selected: _current.minDistanceKm == 5.0 && _current.maxDistanceKm == 10.0,
                  onSelected: (val) => setState(() => _current = _current.copyWith(minDistanceKm: 5.0, maxDistanceKm: 10.0)),
                ),
                _buildChoiceChip(
                  label: '10+ km',
                  selected: _current.minDistanceKm == 10.0,
                  onSelected: (val) => setState(() => _current = _current.copyWith(minDistanceKm: 10.0, clearDistance: false)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Difficulty
            _FilterSectionTitle(title: 'Difficulty', color: textMuted),
            Wrap(
              spacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'Any',
                  selected: _current.difficulty == null,
                  onSelected: (val) => setState(() => _current = _current.copyWith(clearDifficulty: true)),
                ),
                for (final diff in RouteDifficulty.values)
                  _buildChoiceChip(
                    label: diff.name[0].toUpperCase() + diff.name.substring(1),
                    selected: _current.difficulty == diff,
                    onSelected: (val) => setState(() => _current = _current.copyWith(difficulty: diff)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Surface
            _FilterSectionTitle(title: 'Surface', color: textMuted),
            Wrap(
              spacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'Any',
                  selected: _current.surface == null,
                  onSelected: (val) => setState(() => _current = _current.copyWith(clearSurface: true)),
                ),
                for (final surf in RouteSurface.values)
                  _buildChoiceChip(
                    label: surf.name[0].toUpperCase() + surf.name.substring(1),
                    selected: _current.surface == surf,
                    onSelected: (val) => setState(() => _current = _current.copyWith(surface: surf)),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Apply Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  ref.read(activeRouteFilterProvider.notifier).state = _current;
                  Navigator.of(context).pop();
                },
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    IconData? icon,
  }) {
    return ChoiceChip(
      avatar: icon != null ? Icon(icon, size: 16) : null,
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

