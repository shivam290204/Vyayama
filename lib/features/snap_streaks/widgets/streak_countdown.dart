import 'dart:async';

import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:flutter/material.dart';

/// Time left in the pair's streak day. Shows ⏳ and the error colour in the
/// last 4 hours.
class StreakCountdown extends StatefulWidget {
  const StreakCountdown({
    super.key,
    required this.timezone,
    this.clock = DateTime.now,
  });

  final String timezone;
  final DateTime Function() clock;

  @override
  State<StreakCountdown> createState() => _StreakCountdownState();
}

class _StreakCountdownState extends State<StreakCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = SnapStreakCalculator.timeLeftToday(
      widget.clock().toUtc(),
      widget.timezone,
    );
    final warn = left <= SnapStreakCalculator.atRiskWindow;
    final label = '${warn ? '⏳ ' : ''}${_format(left)} left today';
    return Semantics(
      label: '${_format(left)} left in today\'s streak day',
      excludeSemantics: true,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: warn ? scheme.error : scheme.onSurfaceVariant,
              fontWeight: warn ? FontWeight.w600 : FontWeight.w400,
            ),
      ),
    );
  }
}
