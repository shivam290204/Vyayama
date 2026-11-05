import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/auth/widgets/brand_mark.dart';
import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/home/providers/daily_completion_provider.dart';
import 'package:fitbuddy/features/mascot/mascot_message_picker.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:fitbuddy/features/snaps/providers.dart';

/// Tag used for the shared-element Hero transition between Home and Profile.
const String kHomeProfileAvatarHeroTag = 'vyayama_home_profile_avatar_hero';

/// Session flag ensuring the 1.1s intro sequence runs only once per app launch.
bool _hasPlayedHomeHeaderIntro = false;

/// Resets intro state (useful for widget tests).
@visibleForTesting
void resetHomeHeaderIntroState() {
  _hasPlayedHomeHeaderIntro = false;
}

/// Upgraded Home header top bar:
/// Morphing logo + wordmark into a compact 48dp profile avatar with status ring.
class HomeHeaderBar extends ConsumerStatefulWidget {
  const HomeHeaderBar({
    super.key,
    this.scrollProgress,
    this.forceCompact = false,
  });

  /// Scroll progress from 0.0 (fully expanded at top) to 1.0 (compact).
  final ValueListenable<double>? scrollProgress;

  /// If true, renders directly in the compact state (useful for tests/previews).
  final bool forceCompact;

  @override
  ConsumerState<HomeHeaderBar> createState() => HomeHeaderBarState();
}

class HomeHeaderBarState extends ConsumerState<HomeHeaderBar>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _logoBounceController;
  late final Animation<double> _logoBounceAnim;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _logoBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _logoBounceAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(
        parent: _logoBounceController,
        curve: Curves.easeOutBack,
      ),
    );

    if (_hasPlayedHomeHeaderIntro || widget.forceCompact) {
      _introController.value = 1.0;
    } else {
      _hasPlayedHomeHeaderIntro = true;
      _introController.forward();
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _logoBounceController.dispose();
    super.dispose();
  }

  /// Skips the intro animation immediately (e.g. upon user tap or scroll).
  void skipIntro() {
    if (_introController.isAnimating) {
      _introController.stop();
      _introController.value = 1.0;
    }
  }

  void _onLogoTap() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion) {
      HapticFeedback.lightImpact();
      _logoBounceController.forward().then((_) {
        if (mounted) _logoBounceController.reverse();
      });
    }
    skipIntro();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _introController.value < 1.0) {
      _introController.value = 1.0;
    }

    final profile = ref.watch(currentProfileProvider).asData?.value;
    final progressState = ref.watch(dailyCompletionProgressProvider);
    final streak =
        ref.watch(challengesProvider).asData?.value.streak.current ?? 0;
    final incomingRequests = ref.watch(incomingRequestCountProvider);
    final unviewedSnaps = ref.watch(unviewedSnapsCountProvider);
    final totalNotifications = incomingRequests + unviewedSnaps;

    final completionFraction = progressState.totalCount > 0
        ? (progressState.completedCount / progressState.totalCount)
            .clamp(0.0, 1.0)
        : 0.0;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => skipIntro(),
      child: RepaintBoundary(
        child: SizedBox(
          height: 56,
          child: widget.scrollProgress == null
              ? _buildHeaderContent(
                  context,
                  scrollProgress: widget.forceCompact ? 1.0 : 0.0,
                  profile: profile,
                  completionFraction: completionFraction,
                  streak: streak,
                  notifications: totalNotifications,
                )
              : ValueListenableBuilder<double>(
                  valueListenable: widget.scrollProgress!,
                  builder: (context, scrollVal, _) {
                    final effectiveVal =
                        widget.forceCompact ? 1.0 : scrollVal.clamp(0.0, 1.0);
                    return _buildHeaderContent(
                      context,
                      scrollProgress: effectiveVal,
                      profile: profile,
                      completionFraction: completionFraction,
                      streak: streak,
                      notifications: totalNotifications,
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderContent(
    BuildContext context, {
    required double scrollProgress,
    required Profile? profile,
    required double completionFraction,
    required int streak,
    required int notifications,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    // Wordmark & tagline fade out between 0.0 and 0.45 scroll progress
    final wordmarkOpacity = (1.0 - (scrollProgress / 0.45)).clamp(0.0, 1.0);

    // Pill expands/collapses width & padding
    // At scrollProgress 0.0: pill mode; At 1.0: 48dp circular avatar
    final morphFactor = Curves.easeInOutCubic.transform(scrollProgress);

    final notificationLabel = notifications > 0
        ? '$notifications notification${notifications > 1 ? 's' : ''}, '
        : '';
    final streakLabel = streak > 0 ? '$streak day streak' : '';
    final semanticsLabel =
        'Open profile, $notificationLabel$streakLabel'.trim();

    return AnimatedBuilder(
      animation: _introController,
      builder: (context, _) {
        // Intro slide & flip
        final introVal = _introController.value;
        final slideIn = ((1.0 - introVal) * -24.0).clamp(-24.0, 0.0);
        final flipAngle = (introVal < 0.5)
            ? 0.0
            : ((introVal - 0.5) / 0.5) * (math.pi * 2);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Left: Logo + Wordmark & Tagline
            Positioned(
              left: 0,
              top: 4,
              bottom: 4,
              right: 60, // Keep space for the right avatar/pill
              child: Transform.translate(
                offset: Offset(slideIn, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Interactive Logo with tap bounce
                    GestureDetector(
                      onTap: _onLogoTap,
                      child: ScaleTransition(
                        scale: _logoBounceAnim,
                        child: Opacity(
                          opacity: (1.0 - (morphFactor * 0.9)).clamp(0.1, 1.0),
                          child: const BrandMark(
                            size: 32,
                            showBackground: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Wordmark + Tagline
                    if (wordmarkOpacity > 0.01)
                      Expanded(
                        child: Opacity(
                          opacity: wordmarkOpacity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VYAYAMA',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: scheme.primary,
                                  ),
                                ),
                                Text(
                                  'Every effort counts.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Right: Profile Pill / Collapsed Avatar with Status Ring
            Positioned(
              right: 0,
              top: 4,
              bottom: 4,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(flipAngle),
                child: Semantics(
                  button: true,
                  label: semanticsLabel,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: semanticsLabel,
                    child: _ProfileMorphButton(
                      morphFactor: morphFactor,
                      profile: profile,
                      completionFraction: completionFraction,
                      streak: streak,
                      notifications: notifications,
                      isDark: isDark,
                      onTap: () {
                        skipIntro();
                        context.push(AppRoutes.profile);
                      },
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

/// The morphing profile pill that smoothly collapses to a 48dp status circle.
class _ProfileMorphButton extends StatelessWidget {
  const _ProfileMorphButton({
    required this.morphFactor,
    required this.profile,
    required this.completionFraction,
    required this.streak,
    required this.notifications,
    required this.isDark,
    required this.onTap,
  });

  final double morphFactor; // 0.0 = expanded pill, 1.0 = 48dp circle
  final Profile? profile;
  final double completionFraction;
  final int streak;
  final int notifications;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final displayName = const MascotMessagePicker().displayName(profile?.name);
    final pillOpacity = (1.0 - (morphFactor / 0.5)).clamp(0.0, 1.0);

    // Active ring colors meeting 3:1 contrast rule:
    // Light mode: theme primary (Forest Green, dark on light bg); Dark mode: vibrant Lime Green.
    final ringActiveColor = isDark ? AppPalette.limeGreen : scheme.primary;
    final ringTrackColor = isDark
        ? AppPalette.darkSurfaceContainerHighest
        : scheme.outlineVariant.withValues(alpha: 0.4);

    return Material(
      key: const Key('home_profile_button'),
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.symmetric(
            horizontal: (1.0 - morphFactor) * 10.0,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: morphFactor < 0.5
                ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: morphFactor < 0.5
                ? Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with Animated Progress Ring & Badges
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Progress Ring
                  CustomPaint(
                    size: const Size(44, 44),
                    painter: _AvatarProgressRingPainter(
                      progress: completionFraction,
                      activeColor: ringActiveColor,
                      trackColor: ringTrackColor,
                      strokeWidth: 2.5,
                    ),
                  ),

                  // Avatar Circle with Hero Transition
                  Hero(
                    tag: kHomeProfileAvatarHeroTag,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildAvatarContent(context),
                    ),
                  ),

                  // Notification Dot (pending requests + unread snaps)
                  if (notifications > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppPalette.darkSurface : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            notifications > 9 ? '9+' : '$notifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Expanded pill details (fades out as morphFactor increases)
              if (pillOpacity > 0.05) ...[
                const SizedBox(width: 8),
                Opacity(
                  opacity: pillOpacity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // User First Name
                      Text(
                        displayName,
                        style: text.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),

                      // Streak Flame Badge (if streak > 0)
                      if (streak > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.streakContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 2),
                              Text(
                                '$streak',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.streak,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(BuildContext context) {
    final url = profile?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildFallbackInitial(),
      );
    }
    return _buildFallbackInitial();
  }

  Widget _buildFallbackInitial() {
    final initial = profile?.initials.isNotEmpty == true
        ? profile!.initials.substring(0, 1)
        : '';
    if (initial.isNotEmpty) {
      return Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      );
    }
    return const Icon(
      Icons.person_rounded,
      color: Colors.white,
      size: 20,
    );
  }
}

/// Paints the animated status progress ring around the profile avatar.
class _AvatarProgressRingPainter extends CustomPainter {
  const _AvatarProgressRingPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc
    if (progress > 0.0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// The time-of-day subheader with cross-fading icon, greeting, and date.
class GreetingSubheader extends ConsumerWidget {
  const GreetingSubheader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now =
        ref.watch(nowProvider).asData?.value ?? ref.read(clockProvider)();
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final who = const MascotMessagePicker().displayName(profile?.name);

    final part = DayPart.of(now);
    final greeting = switch (part) {
      DayPart.morning => 'Good morning',
      DayPart.afternoon => 'Good afternoon',
      DayPart.evening => 'Good evening',
      DayPart.night => 'Hello',
    };
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Token-based icon & color mapping (no hardcoded peach)
    final (IconData timeIcon, Color iconColor) = switch (part) {
      DayPart.morning => (
          Icons.wb_twilight_rounded,
          context.colors.warning, // Warm sunrise token
        ),
      DayPart.afternoon => (
          Icons.wb_sunny_rounded,
          scheme.tertiary, // Lime Green midday energy
        ),
      DayPart.evening => (
          Icons.nights_stay_rounded,
          scheme.primary, // Forest Green calm
        ),
      DayPart.night => (
          Icons.dark_mode_rounded,
          scheme.primary, // Calm night
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Cross-fading time-of-day icon
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey<IconData>(timeIcon),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(timeIcon, color: iconColor, size: 26),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $who!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                formatLongDate(now),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Standalone composable GreetingHeader containing both HomeHeaderBar and
/// GreetingSubheader for backward compatibility with existing tests.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          HomeHeaderBar(),
          SizedBox(height: 14),
          GreetingSubheader(),
        ],
      ),
    );
  }
}
