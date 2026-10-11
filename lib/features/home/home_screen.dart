import 'package:fitbuddy/core/widgets/animated_section_header.dart';
import 'package:fitbuddy/core/widgets/glow_background.dart';
import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/challenges/widgets/challenge_summary_card.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/home/widgets/greeting_header.dart';
import 'package:fitbuddy/features/home/widgets/mascot_section.dart';
import 'package:fitbuddy/features/home/widgets/quick_links_grid.dart';
import 'package:fitbuddy/features/home/widgets/summary_row.dart';
import 'package:fitbuddy/features/home/widgets/time_blocks_section.dart';
import 'package:fitbuddy/features/home/widgets/today_workout_card.dart';
import 'package:fitbuddy/features/home/widgets/wellness_summary_cards.dart';
import 'package:fitbuddy/features/mascot/mascot_debug_panel.dart';
import 'package:fitbuddy/features/motivation/providers.dart';
import 'package:fitbuddy/features/motivation/widgets/daily_boost_card.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:fitbuddy/features/schedule/providers.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:fitbuddy/core/widgets/staggered_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The home screen: greeting, reacting mascot, today's time blocks,
/// activity summary, daily challenge, Daily Boost and quick links.
class HomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(recentStatsProvider)
      ..invalidate(scheduleBlocksProvider)
      ..invalidate(todayCompletionsProvider)
      ..invalidate(challengesProvider)
      ..invalidate(quotesProvider)
      ..invalidate(memesProvider)
      ..invalidate(waterProvider)
      ..invalidate(sleepSettingsProvider);
    await ref.read(recentStatsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Let GlowBackground show through
      body: GlowBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _refresh(ref),
            color: Theme.of(context).colorScheme.primary,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: const _HomeContent(),
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

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return const StaggeredEntrance(
      children: [
        GreetingHeader(),
        SizedBox(height: 12),
        MascotSection(),
        SizedBox(height: 20),
        AnimatedSectionHeader(
          title: "Today's activity",
          icon: Icons.insights_rounded,
          delay: Duration(milliseconds: 150),
        ),
        SummaryRow(),
        SizedBox(height: 20),
        AnimatedSectionHeader(
          title: "Today's workout",
          icon: Icons.fitness_center_rounded,
          delay: Duration(milliseconds: 250),
        ),
        TodayWorkoutCard(),
        SizedBox(height: 20),
        AnimatedSectionHeader(
          title: "Daily schedule",
          icon: Icons.calendar_today_rounded,
          delay: Duration(milliseconds: 350),
        ),
        TimeBlocksSection(),
        SizedBox(height: 20),
        AnimatedSectionHeader(
          title: "Wellness & sleep",
          icon: Icons.spa_rounded,
          delay: Duration(milliseconds: 400),
        ),
        WellnessSummaryCards(),
        SizedBox(height: 20),
        AnimatedSectionHeader(
          title: "Today's challenge",
          icon: Icons.emoji_events_rounded,
          delay: Duration(milliseconds: 450),
        ),
        ChallengeSummaryCard(),
        SizedBox(height: 16),
        AnimatedSectionHeader(
          title: 'Daily Boost',
          icon: Icons.bolt_rounded,
          delay: Duration(milliseconds: 500),
        ),
        DailyBoostCard(),
        SizedBox(height: 20),
        AnimatedSectionHeader(
          title: 'Explore',
          icon: Icons.explore_rounded,
          delay: Duration(milliseconds: 550),
        ),
        QuickLinksGrid(),
        SizedBox(height: 16),
        MascotDebugPanel(),
      ],
    );
  }
}
