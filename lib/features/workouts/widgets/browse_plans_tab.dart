import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/widgets/plan_card.dart';
import 'package:fitbuddy/features/workouts/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Browse Plans" tab: system plans grouped by level.
class BrowsePlansTab extends ConsumerWidget {
  const BrowsePlansTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref.watch(systemPlansProvider).when(
          loading: () => const WorkoutLoading(),
          error: (e, _) => WorkoutErrorView(
            onRetry: () => ref.invalidate(systemPlansProvider),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return const WorkoutMessageView(
                icon: Icons.list_alt_rounded,
                title: 'No plans available',
                message: 'Please check back soon.',
              );
            }
            final levels = <String>[];
            for (final p in plans) {
              final l = p.level ?? 'beginner';
              if (!levels.contains(l)) levels.add(l);
            }
            levels.sort();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final level in levels) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(prettyLabel(level),
                        style: theme.textTheme.titleMedium),
                  ),
                  for (final p in plans.where((p) => (p.level ?? 'beginner') == level))
                    PlanCard(
                      plan: p,
                      onTap: () =>
                          context.push(AppRoutes.workoutPlanPath(p.id)),
                    ),
                ],
              ],
            );
          },
        );
  }
}
