import 'package:fitbuddy/features/mascot/mascot_message_picker.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Good morning, Asha!" plus today's date.
class GreetingHeader extends ConsumerWidget {
  /// Creates the header.
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider).asData?.value ?? ref.read(clockProvider)();
    final name = ref.watch(currentProfileProvider).asData?.value?.name;
    final who = const MascotMessagePicker().displayName(name);
    final greeting = switch (DayPart.of(now)) {
      DayPart.morning => 'Good morning',
      DayPart.afternoon => 'Good afternoon',
      DayPart.evening => 'Good evening',
      DayPart.night => 'Hello',
    };
    final text = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$greeting, $who!', style: text.headlineSmall),
          const SizedBox(height: 2),
          Text(formatLongDate(now), style: text.bodyMedium),
        ],
      ),
    );
  }
}
