import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/workouts/widgets/browse_plans_tab.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_library_tab.dart';
import 'package:fitbuddy/features/workouts/widgets/my_plan_tab.dart';
import 'package:fitbuddy/features/workouts/widgets/yoga_section_tab.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `/workouts`: My Plan, Browse Plans, Yoga, and Exercises tabs.
class WorkoutsHomeScreen extends StatelessWidget {
  const WorkoutsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workouts'),
          actions: [
            IconButton(
              tooltip: 'Create custom plan',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => context.push(AppRoutes.planBuilder),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'My Plan'),
              Tab(text: 'Workouts'),
              Tab(text: 'Yoga'),
              Tab(text: 'Exercises'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: const TabBarView(
              children: [
                MyPlanTab(),
                BrowsePlansTab(),
                YogaSectionTab(),
                ExerciseLibraryTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
