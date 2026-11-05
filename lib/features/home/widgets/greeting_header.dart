import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// Single constant controlling whether a 16dp logo badge is pinned to the avatar.
const bool kShowAvatarLogoBadge = false;

/// Session flag ensuring the 1.2s launch morph runs only once per app launch.
bool _hasPlayedHomeHeaderIntro = false;

/// Resets intro state (useful for widget tests).
@visibleForTesting
void resetHomeHeaderIntroState() {
  _hasPlayedHomeHeaderIntro = false;
}

/// Upgraded Home header: ONE full-width identity bar.
///
/// Absorbs the old logo/wordmark row, profile pill, and separate greeting block.
/// Features a 1.2s launch morph, scroll-linked compact collapse, concentric
/// status progress ring, streak chip, and notification bell.
class HomeIdentityBar extends ConsumerStatefulWidget {
  const HomeIdentityBar({
    super.key,
    this.scrollProgress,
    this.forceCompact = false,
    this.forceBrand = false,
  });

  /// Scroll progress from 0.0 (fully expanded at top) to 1.0 (compact).
  final ValueListenable<double>? scrollProgress;

  /// If true, renders directly in the compact state (useful for tests/previews).
  final bool forceCompact;

  /// If true, renders directly in the initial brand state.
  final bool forceBrand;

  @override
  ConsumerState<HomeIdentityBar> createState() => HomeIdentityBarState();
}

class HomeIdentityBarState extends ConsumerState<HomeIdentityBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;
  double _profileTapScale = 1.0;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.forceBrand) {
      _introController.value = 0.0;
    } else if (_hasPlayedHomeHeaderIntro || widget.forceCompact) {
      _introController.value = 1.0;
    } else {
      _hasPlayedHomeHeaderIntro = true;
      _introController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guard against replaying intro on theme changes
    if (_hasPlayedHomeHeaderIntro &&
        !widget.forceBrand &&
        !_introController.isAnimating &&
        _introController.value < 1.0) {
      _introController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  /// Skips the intro animation immediately (e.g. upon user tap or scroll).
  void skipIntro() {
    if (_introController.isAnimating) {
      _introController.stop();
      _introController.value = 1.0;
    }
  }

  void _onProfileTap() {
    skipIntro();
    setState(() => _profileTapScale = 0.96);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() => _profileTapScale = 1.0);
        // Switch to Profile tab using context.go to update bottom-bar and prevent stack duplicates
        context.go(AppRoutes.profile);
      }
    });
  }

  void _onBellTap(int friendRequests) {
    skipIntro();
    // Use context.push so user can inspect requests/inbox and press back to return to Home
    if (friendRequests > 0) {
      context.push(AppRoutes.friendsRequests);
    } else {
      context.push(AppRoutes.snapsInbox);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _introController.value < 1.0 && !widget.forceBrand) {
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

    final now =
        ref.watch(nowProvider).asData?.value ?? ref.read(clockProvider)();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => skipIntro(),
      child: RepaintBoundary(
        child: SizedBox(
          height: 64,
          child: widget.scrollProgress == null
              ? _buildBarContent(
                  context,
                  scrollProgress: widget.forceCompact ? 1.0 : 0.0,
                  profile: profile,
                  completionFraction: completionFraction,
                  streak: streak,
                  notifications: totalNotifications,
                  friendRequests: incomingRequests,
                  now: now,
                )
              : ValueListenableBuilder<double>(
                  valueListenable: widget.scrollProgress!,
                  builder: (context, scrollVal, _) {
                    final effectiveVal = widget.forceCompact
                        ? 1.0
                        : scrollVal.clamp(0.0, 1.0);
                    return _buildBarContent(
                      context,
                      scrollProgress: effectiveVal,
                      profile: profile,
                      completionFraction: completionFraction,
                      streak: streak,
                      notifications: totalNotifications,
                      friendRequests: incomingRequests,
                      now: now,
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildBarContent(
    BuildContext context, {
    required double scrollProgress,
    required Profile? profile,
    required double completionFraction,
    required int streak,
    required int notifications,
    required int friendRequests,
    required DateTime now,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    final compactMorph = Curves.easeInOutCubic.transform(scrollProgress);
    // Center greeting & streak chip fade out between 0.0 and 0.45 scroll progress
    final contentOpacity = (1.0 - (compactMorph / 0.45)).clamp(0.0, 1.0);

    final notificationLabel = notifications > 0
        ? '$notifications notification${notifications > 1 ? 's' : ''}, '
        : '';
    final streakLabel = streak > 0 ? '$streak day streak' : '';
    final profileSemanticsLabel =
        'Open profile, $notificationLabel$streakLabel'.trim();

    final who = const MascotMessagePicker().displayName(profile?.name);
    final part = DayPart.of(now);
    final greeting = switch (part) {
      DayPart.morning => 'Good morning',
      DayPart.afternoon => 'Good afternoon',
      DayPart.evening => 'Good evening',
      DayPart.night => 'Hello',
    };

    // Solid surface token without BackdropFilter blur (Rule 4)
    final surfaceColor =
        isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.35);

    return AnimatedBuilder(
      animation: _introController,
      builder: (context, _) {
        final introVal = widget.forceBrand ? 0.0 : _introController.value;

        // Phase 1 (0.0 to 0.5): Brand state fades/slides out
        final brandOpacity = (1.0 - (introVal / 0.45)).clamp(0.0, 1.0);
        final brandSlide = (introVal * -24.0).clamp(-24.0, 0.0);

        // Phase 2 (0.35 to 0.85): Identity content slides in
        final identityOpacity =
            ((introVal - 0.35) / 0.50).clamp(0.0, 1.0);
        final identitySlide = ((1.0 - introVal) * 20.0).clamp(0.0, 20.0);

        // Phase 3 (0.7 to 1.0): Streak chip and bell scale in
        final trailingOpacity =
            ((introVal - 0.65) / 0.35).clamp(0.0, 1.0);
        final trailingScale = 0.8 + (0.2 * trailingOpacity);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. BRAND LAUNCH STATE (Logo + VYAYAMA + Tagline)
              if (brandOpacity > 0.01)
                Positioned.fill(
                  child: Opacity(
                    opacity: brandOpacity,
                    child: Transform.translate(
                      offset: Offset(brandSlide, 0),
                      child: Row(
                        children: [
                          const BrandMark(size: 36, showBackground: false),
                          const SizedBox(width: 12),
                          Expanded(
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
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. FULL-WIDTH REST & COMPACT IDENTITY BAR
              if (identityOpacity > 0.01)
                Positioned.fill(
                  child: Opacity(
                    opacity: identityOpacity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Avatar with Concentric Progress Ring (Tappable -> Profile)
                        Semantics(
                          button: true,
                          label: profileSemanticsLabel,
                          child: Tooltip(
                            message: profileSemanticsLabel,
                            child: GestureDetector(
                              key: const Key('home_profile_button'),
                              onTap: _onProfileTap,
                              child: AnimatedScale(
                                scale: _profileTapScale,
                                duration: const Duration(milliseconds: 100),
                                child: _AvatarWithConcentricRing(
                                  profile: profile,
                                  progress: completionFraction,
                                  isDark: isDark,
                                  scheme: scheme,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Center: Greeting & Date (Fades out when scrolled compact)
                        if (contentOpacity > 0.01) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Opacity(
                              opacity: contentOpacity,
                              child: Transform.translate(
                                offset: Offset(identitySlide, 0),
                                child: GestureDetector(
                                  onTap: _onProfileTap,
                                  behavior: HitTestBehavior.opaque,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$greeting, $who!',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: text.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          formatLongDate(now),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: text.labelSmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),

                        // Right: Streak Chip (priority over date, hides on compact)
                        if (streak > 0 && contentOpacity > 0.05) ...[
                          const SizedBox(width: 6),
                          Opacity(
                            opacity: contentOpacity * trailingOpacity,
                            child: Transform.scale(
                              scale: trailingScale,
                              child: _StreakChip(
                                streak: streak,
                                isDark: isDark,
                                scheme: scheme,
                              ),
                            ),
                          ),
                        ],

                        // Right: Notification Bell (Always visible in rest and compact)
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: trailingScale,
                          child: _NotificationBell(
                            notifications: notifications,
                            isDark: isDark,
                            scheme: scheme,
                            onTap: () => _onBellTap(friendRequests),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Avatar with a concentric progress ring matching the daily completion fraction.
class _AvatarWithConcentricRing extends StatelessWidget {
  const _AvatarWithConcentricRing({
    required this.profile,
    required this.progress,
    required this.isDark,
    required this.scheme,
  });

  final Profile? profile;
  final double progress;
  final bool isDark;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    // Ring contrast rule: primary on light mode, lime on dark mode; visible track (>3:1 contrast)
    final ringActiveColor = isDark ? AppPalette.limeGreen : scheme.primary;
    final ringTrackColor = isDark
        ? AppPalette.darkSurfaceContainerHighest
        : scheme.outlineVariant.withValues(alpha: 0.45);

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Concentric Animated Progress Ring
          CustomPaint(
            size: const Size(46, 46),
            painter: _ConcentricProgressRingPainter(
              progress: progress,
              activeColor: ringActiveColor,
              trackColor: ringTrackColor,
              strokeWidth: 2.5,
            ),
          ),

          // 38dp Circular Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildAvatarImage(context),
          ),

          // Optional 16dp Brand Mark Badge
          if (kShowAvatarLogoBadge)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkSurface : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 1),
                ),
                child: const BrandMark(size: 12, showBackground: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(BuildContext context) {
    final url = profile?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _buildInitial(),
      );
    }
    return _buildInitial();
  }

  Widget _buildInitial() {
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

/// Custom painter for the concentric progress ring around the avatar.
class _ConcentricProgressRingPainter extends CustomPainter {
  const _ConcentricProgressRingPainter({
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

    // Background track with visible contrast (>3:1)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc matching mascot daily completion
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
  bool shouldRepaint(covariant _ConcentricProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// High-contrast streak chip (Rule 5: dark text on soft lime for light mode).
class _StreakChip extends StatelessWidget {
  const _StreakChip({
    required this.streak,
    required this.isDark,
    required this.scheme,
  });

  final int streak;
  final bool isDark;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    // Light mode: AppPalette.softLime with deep forest green text (>7:1 contrast)
    // Dark mode: scheme.primaryContainer with vibrant lime text (>5:1 contrast)
    final chipBg =
        isDark ? scheme.primaryContainer : AppPalette.softLime;
    final chipText =
        isDark ? AppPalette.limeGreen : AppPalette.forestGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppPalette.limeGreen.withValues(alpha: 0.3) : chipBg,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: chipText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Notification bell with badge dot capped at "9+".
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.notifications,
    required this.isDark,
    required this.scheme,
    required this.onTap,
  });

  final int notifications;
  final bool isDark;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = notifications > 0
        ? 'Notifications, $notifications unread'
        : 'Notifications';

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('home_bell_button'),
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: scheme.onSurfaceVariant,
                    size: 24,
                  ),

                  // Notification Badge Dot (Hidden if 0)
                  if (notifications > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Backwards-compatible wrapper rendering [HomeIdentityBar].
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: const HomeIdentityBar(),
    );
  }
}
