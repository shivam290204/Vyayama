import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/home/providers/daily_completion_provider.dart';
import 'package:fitbuddy/features/home/widgets/speech_bubble.dart';
import 'package:fitbuddy/features/mascot/providers.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top section on Home displaying the speech bubble and the dynamic mascot.
///
/// Changes character image based on today's accomplishments:
/// - [DailyCompletionTier.nothingDone]: `Sad_Drooped_Head.png` (when nothing done)
/// - [DailyCompletionTier.fourToFiveDone]: `flex_proud.png` (when done 4 to 5 things, not all)
/// - [DailyCompletionTier.everythingDone]: `Fire_Determined.png` (when everything done)
///
/// Wrapped with a rounded card and border radius on all corners.
class MascotSection extends ConsumerWidget {
  /// Creates the section.
  const MascotSection({super.key});

  String _getMessage({
    required DailyCompletionTier tier,
    required String name,
    required int variant,
    required int count,
  }) {
    switch (tier) {
      case DailyCompletionTier.nothingDone:
        final variants = [
          "Every journey starts with a single step, $name. Let's make today count!",
          "Ready to get moving, $name? Drink some water or take a quick walk!",
          "No activities logged yet, $name. Let's conquer your first goal together!",
        ];
        return variants[variant % variants.length];

      case DailyCompletionTier.fourToFiveDone:
        final variants = [
          "Crushing it, $name! $count goals down—keep pushing, you're almost at 100%!",
          "Looking strong, $name! That momentum is unstoppable today!",
          "Great dedication, $name! Just a little more to conquer everything!",
        ];
        return variants[variant % variants.length];

      case DailyCompletionTier.everythingDone:
        final variants = [
          "That's how it's done, $name! All daily goals conquered—pure fire today! 🔥",
          "Unstoppable, $name! Every single target hit. Rest up, you earned it! 🏆",
          "Absolute champion mode, $name! 100% daily completion! ⚡",
        ];
        return variants[variant % variants.length];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(dailyCompletionProgressProvider);
    final variant = ref.watch(mascotVariantProvider);
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final rawName = profile?.name;
    final name = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : 'Shivam';

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = _getMessage(
      tier: progress.tier,
      name: name,
      variant: variant,
      count: progress.completedCount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth.clamp(280.0, 420.0).toDouble();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speech bubble with tail pointing at the mascot
            SpeechBubble(message: message),
            const SizedBox(height: 6),

            // Interactive rounded Mascot Card
            Semantics(
              button: true,
              label: 'Mascot status: ${progress.label}. Tap for another message.',
              child: InkWell(
                onTap: () {
                  ref.read(dailyCompletionTierOverrideProvider.notifier).cycleNext();
                  ref.read(mascotVariantProvider.notifier).next();
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: cardWidth,
                  height: 230,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF141A14)
                        : const Color(0xFF192319),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E3D2E)
                          : AppPalette.forestGreen.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.45)
                            : Colors.black.withValues(alpha: 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      if (progress.tier == DailyCompletionTier.everythingDone)
                        BoxShadow(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.28),
                          blurRadius: 24,
                          spreadRadius: 2,
                        )
                      else if (progress.tier == DailyCompletionTier.fourToFiveDone)
                        BoxShadow(
                          color: AppPalette.limeGreen.withValues(alpha: 0.18),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Subtle radial gradient backdrop for depth
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.85,
                                colors: [
                                  if (progress.tier ==
                                      DailyCompletionTier.everythingDone) ...[
                                    const Color(0xFF5A2A10).withValues(alpha: 0.4),
                                    const Color(0xFF141A14),
                                  ] else if (progress.tier ==
                                      DailyCompletionTier.fourToFiveDone) ...[
                                    const Color(0xFF253D25).withValues(alpha: 0.5),
                                    const Color(0xFF141A14),
                                  ] else ...[
                                    const Color(0xFF1F261F).withValues(alpha: 0.4),
                                    const Color(0xFF141A14),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Animated mascot image
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Image.asset(
                              progress.assetPath,
                              key: ValueKey(progress.assetPath),
                              height: 214,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  size: 64,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Progress Pill in bottom-right corner
                        Positioned(
                          bottom: 12,
                          right: 14,
                          child: _ProgressBadge(
                            progress: progress,
                            onCycleOverride: () {
                              ref
                                  .read(dailyCompletionTierOverrideProvider
                                      .notifier)
                                  .cycleNext();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.progress,
    required this.onCycleOverride,
  });

  final DailyCompletionProgress progress;
  final VoidCallback onCycleOverride;

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;
    IconData badgeIcon;
    String badgeText;

    switch (progress.tier) {
      case DailyCompletionTier.nothingDone:
        badgeColor = const Color(0xFF2C352C);
        textColor = const Color(0xFFB0BEB0);
        badgeIcon = Icons.flag_outlined;
        badgeText = '${progress.completedCount} / ${progress.totalCount} Done';
        break;
      case DailyCompletionTier.fourToFiveDone:
        badgeColor = AppPalette.limeGreen;
        textColor = const Color(0xFF142314);
        badgeIcon = Icons.bolt_rounded;
        badgeText = '${progress.completedCount} / ${progress.totalCount} Done';
        break;
      case DailyCompletionTier.everythingDone:
        badgeColor = const Color(0xFFFF7A00);
        textColor = Colors.white;
        badgeIcon = Icons.local_fire_department_rounded;
        badgeText = 'All Done! 🔥';
        break;
    }

    return GestureDetector(
      onTap: onCycleOverride,
      child: Tooltip(
        message: 'Tap to preview other states',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 14, color: textColor),
              const SizedBox(width: 4),
              Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
