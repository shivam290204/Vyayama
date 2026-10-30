import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_recording_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/route_detail_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_card.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen listing user's saved routes and recorded outdoor activity history.
class SavedRoutesScreen extends ConsumerStatefulWidget {
  const SavedRoutesScreen({super.key});

  @override
  ConsumerState<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends ConsumerState<SavedRoutesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onRenameRoute(SavedRoute route) async {
    final ctrl = TextEditingController(text: route.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Route'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Route Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      await ref.read(savedRoutesRepositoryProvider).renameRoute(route.id, newName);
      ref.invalidate(savedRoutesListProvider);
    }
  }

  void _onDeleteRoute(SavedRoute route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Saved Route?'),
        content: Text('Are you sure you want to delete "${route.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppPalette.deepCoral),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(savedRoutesRepositoryProvider).deleteRoute(route.id);
      ref.invalidate(savedRoutesListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    final savedRoutesAsync = ref.watch(savedRoutesListProvider);
    final activitiesAsync = ref.watch(outdoorActivitiesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routes & Activities'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppPalette.limeGreen,
          labelColor: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
          unselectedLabelColor: textMuted,
          tabs: const [
            Tab(text: 'Saved Routes', icon: Icon(Icons.bookmarks_rounded)),
            Tab(text: 'Activity History', icon: Icon(Icons.history_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Saved Routes
          savedRoutesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (routes) {
              if (routes.isEmpty) {
                return _EmptyState(
                  icon: Icons.bookmark_border_rounded,
                  title: 'No saved routes yet',
                  subtitle:
                      'Explore nearby routes or record your own outdoor activities to save them here.',
                  actionLabel: 'Record Activity',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OutdoorRecordingScreen(),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: routes.length,
                itemBuilder: (context, index) {
                  final route = routes[index];
                  return Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      RouteCard(
                        route: route,
                        isSaved: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RouteDetailScreen(route: route),
                          ),
                        ),
                        onSaveToggle: () => _onDeleteRoute(route),
                      ),
                      Positioned(
                        right: 48,
                        top: 10,
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Rename Route',
                          onPressed: () => _onRenameRoute(route),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          // Tab 2: Activity History
          activitiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (activities) {
              if (activities.isEmpty) {
                return _EmptyState(
                  icon: Icons.directions_walk_rounded,
                  title: 'No outdoor activities recorded yet',
                  subtitle:
                      'Your recorded GPS walking, running, and hiking activities will appear here.',
                  actionLabel: 'Start First Workout',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OutdoorRecordingScreen(),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _ActivityHistoryCard(
                    activity: activity,
                    onTap: () {
                      // Convert activity to route to inspect
                      final route = SavedRoute(
                        id: activity.id,
                        name: activity.title,
                        activityType: activity.activityType,
                        distanceMeters: activity.distanceMeters,
                        estimatedDurationSeconds: activity.durationSeconds,
                        difficulty: activity.distanceKm > 5
                            ? RouteDifficulty.hard
                            : RouteDifficulty.easy,
                        points: activity.points,
                        elevationGainMeters: activity.elevationGainMeters,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RouteDetailScreen(route: route),
                        ),
                      );
                    },
                    onDelete: () async {
                      await ref
                          .read(outdoorActivityRepositoryProvider)
                          .deleteActivity(activity.id);
                      ref.invalidate(outdoorActivitiesListProvider);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActivityHistoryCard extends StatelessWidget {
  const _ActivityHistoryCard({
    required this.activity,
    required this.onTap,
    required this.onDelete,
  });

  final OutdoorActivity activity;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg =
        isDark ? AppPalette.darkSurfaceContainer : AppPalette.lightSurface;
    final borderColor =
        isDark ? AppPalette.darkOutline : AppPalette.lightOutline;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(activity.activityType.icon,
                          color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        activity.title.isNotEmpty
                            ? activity.title
                            : '${activity.activityType.label} Workout',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: AppPalette.deepCoral,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${activity.distanceKm.toStringAsFixed(2)} km',
                    style: TextStyle(
                      color: AppPalette.activitySteps,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    activity.formattedDuration,
                    style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    activity.formattedPace,
                    style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${activity.caloriesBurned} kcal',
                    style: TextStyle(
                      color: AppPalette.activityCalories,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    activity.isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    size: 14,
                    color: activity.isSynced
                        ? (isDark ? AppPalette.limeGreen : AppPalette.forestGreen)
                        : textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    activity.isSynced ? 'Cloud Synced' : 'Local Only',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: activity.isSynced
                          ? (isDark ? AppPalette.limeGreen : AppPalette.forestGreen)
                          : textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
