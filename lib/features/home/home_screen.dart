import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/challenges/widgets/challenge_summary_card.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/home/widgets/greeting_header.dart';
import 'package:fitbuddy/features/home/widgets/mascot_section.dart';
import 'package:fitbuddy/features/home/widgets/quick_links_grid.dart';
import 'package:fitbuddy/features/home/widgets/summary_row.dart';
import 'package:fitbuddy/features/home/widgets/time_blocks_section.dart';
import 'package:fitbuddy/features/mascot/mascot_debug_panel.dart';
import 'package:fitbuddy/features/motivation/providers.dart';
import 'package:fitbuddy/features/motivation/widgets/daily_boost_card.dart';
import 'package:fitbuddy/features/schedule/providers.dart';
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
      ..invalidate(memesProvider);
    await ref.read(recentStatsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
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
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GreetingHeader(),
        SizedBox(height: 16),
        MascotSection(),
        SizedBox(height: 24),
        _SectionTitle("Today's plan"),
        TimeBlocksSection(),
        SizedBox(height: 16),
        SummaryRow(),
        SizedBox(height: 24),
        _SectionTitle("Today's challenge"),
        ChallengeSummaryCard(),
        SizedBox(height: 16),
        _SectionTitle('Daily Boost'),
        DailyBoostCard(),
        SizedBox(height: 24),
        _SectionTitle('Explore'),
        QuickLinksGrid(),
        SizedBox(height: 16),
        MascotDebugPanel(),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
