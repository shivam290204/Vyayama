import 'package:fitbuddy/features/auth/widgets/brand_mark.dart';
import 'package:fitbuddy/features/mascot/mascot_message_picker.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Good morning, Asha!" header with brand logo.
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
    final scheme = Theme.of(context).colorScheme;
    
    IconData timeIcon;
    Color iconColor;
    switch (DayPart.of(now)) {
      case DayPart.morning:
        timeIcon = Icons.wb_twilight;
        iconColor = Colors.orangeAccent;
        break;
      case DayPart.afternoon:
        timeIcon = Icons.wb_sunny;
        iconColor = Colors.amber;
        break;
      case DayPart.evening:
      case DayPart.night:
        timeIcon = Icons.nights_stay;
        iconColor = scheme.primary;
        break;
    }

    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 32, showBackground: false),
              const SizedBox(width: 10),
              Text(
                'VYAYAMA',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(timeIcon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $who!',
                      style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatLongDate(now),
                      style: text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
