import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/dashboard/widgets/monthly_activity_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full screen dedicated to the Monthly Daily Activity Calendar.
///
/// Navigated to directly from the calendar icon on the Today dashboard.
class MonthlyActivityScreen extends ConsumerWidget {
  const MonthlyActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Daily Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Refresh Activity',
            onPressed: () {
              final month = ref.read(selectedCalendarMonthProvider);
              ref.invalidate(monthlyActivityProvider(month));
              ref.invalidate(recentStatsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final month = ref.read(selectedCalendarMonthProvider);
          ref.invalidate(monthlyActivityProvider(month));
          ref.invalidate(recentStatsProvider);
          await ref.read(monthlyActivityProvider(month).future);
        },
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: MonthlyActivityCalendar(),
        ),
      ),
    );
  }
}

