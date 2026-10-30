import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
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
    final cardBg =
        isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
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
                        'Discovered via OpenStreetMap',
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

              // Routes List, Error State, or Empty State
              routesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Discovering real mapped routes...',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                error: (err, _) => _RouteErrorView(
                  error: err,
                  onRetry: () => ref.invalidate(discoveredRoutesProvider),
                ),
                data: (routes) {
                  if (routes.isEmpty) {
                    final hasActiveFilter = filter.activityType != null ||
                        filter.minDistanceKm != null ||
                        filter.maxDistanceKm != null ||
                        filter.difficulty != null ||
                        filter.surface != null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          Icon(Icons.explore_off_rounded, size: 40, color: textMuted),
                          const SizedBox(height: 8),
                          Text(
                            'No mapped routes found nearby.',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              hasActiveFilter
                                  ? 'No routes matched your active filters. Try clearing filters or expanding distance.'
                                  : 'Route availability depends on local OpenStreetMap data. '
                                      'Try panning to an area with mapped pedestrian paths or parks.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textMuted, fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (hasActiveFilter)
                            OutlinedButton.icon(
                              onPressed: () {
                                ref.read(activeRouteFilterProvider.notifier).state =
                                    const RouteFilter();
                              },
                              icon: const Icon(Icons.clear_all_rounded, size: 16),
                              label: const Text('Clear Filters'),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => ref.invalidate(discoveredRoutesProvider),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Check Again'),
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

class _RouteErrorView extends StatelessWidget {
  const _RouteErrorView({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    IconData icon;
    String title;
    String message;

    if (error is RouteRateLimitException) {
      icon = Icons.timer_outlined;
      title = 'Rate Limit Reached';
      message = 'OpenStreetMap request limit reached. Please wait a moment and try again.';
    } else if (error is RouteNetworkException) {
      icon = Icons.wifi_off_rounded;
      title = 'No Internet Connection';
      message = 'Unable to reach routing services. Please verify your connection.';
    } else if (error is OverpassServiceException) {
      icon = Icons.cloud_off_rounded;
      title = 'Map Data Temporarily Unavailable';
      message = 'OpenStreetMap data server is currently busy. Tap below to retry.';
    } else if (error is ValhallaRoutingException) {
      icon = Icons.alt_route_rounded;
      title = 'Routing Engine Unavailable';
      message = 'Pedestrian routing service is temporarily unavailable. Tap below to retry.';
    } else {
      icon = Icons.error_outline_rounded;
      title = 'Route Discovery Error';
      message = 'Could not load routes right now. Tap below to retry.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 38, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
