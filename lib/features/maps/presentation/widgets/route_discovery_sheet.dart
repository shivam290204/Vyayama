import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_card.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_filter_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Draggable bottom sheet displaying nearby discoverable routes and quick record action.
class RouteDiscoverySheet extends ConsumerWidget {
  const RouteDiscoverySheet({
    super.key,
    required this.onRouteSelected,
    required this.onRecordPressed,
  });

  final ValueChanged<SavedRoute> onRouteSelected;
  final VoidCallback onRecordPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark
        ? AppPalette.darkSurface
        : AppPalette.lightSurface;
    final borderColor =
        isDark ? AppPalette.darkOutline : AppPalette.lightOutline;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    final routesAsync = ref.watch(discoveredRoutesProvider);
    final savedRoutes = ref.watch(savedRoutesListProvider).asData?.value ?? [];
    final savedIds = savedRoutes.map((r) => r.id).toSet();
    final filter = ref.watch(activeRouteFilterProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.16,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.16, 0.38, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: borderColor, width: 1.0),
              left: BorderSide(color: borderColor, width: 1.0),
              right: BorderSide(color: borderColor, width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppPalette.darkOutline : AppPalette.lightOutline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Action row: "Record Outdoor Activity" button
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.forestGreen,
                        foregroundColor: AppPalette.limeGreen,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: onRecordPressed,
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                      label: const Text(
                        'Record Outdoor Activity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Header: Nearby Routes & Filter Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby Routes',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Suggested local circuits',
                        style: TextStyle(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(
                        color: isDark ? AppPalette.darkOutline : AppPalette.lightOutline,
                      ),
                    ),
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const RouteFilterSheet(),
                      );
                    },
                    icon: const Icon(Icons.filter_list_rounded, size: 16),
                    label: Text(
                      filter.activityType != null ? filter.activityType!.label : 'Filter',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Routes List
              routesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Could not discover routes: $err',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
                data: (routes) {
                  if (routes.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        children: [
                          Icon(Icons.explore_off_rounded, size: 40, color: textMuted),
                          const SizedBox(height: 8),
                          Text(
                            'No routes matched your filters.',
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try expanding distance or clearing activity filters.',
                            style: TextStyle(color: textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: routes.map((route) {
                      final isSaved = savedIds.contains(route.id);
                      return RouteCard(
                        route: route,
                        isSaved: isSaved,
                        onTap: () => onRouteSelected(route),
                        onSaveToggle: () async {
                          final repo = ref.read(savedRoutesRepositoryProvider);
                          if (isSaved) {
                            await repo.deleteRoute(route.id);
                            ref.invalidate(savedRoutesListProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed "${route.name}" from saved routes'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            await repo.saveRoute(route.copyWith(isSavedByUser: true));
                            ref.invalidate(savedRoutesListProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Saved "${route.name}" to your routes!'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

