import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/motivation/daily_boost_picker.dart';
import 'package:fitbuddy/features/motivation/data/quote.dart';
import 'package:fitbuddy/features/motivation/providers.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Interactive daily motivation quote popup dialog that displays once per day
/// upon opening the app, featuring a prominent cross (close) button for quick dismissal.
class DailyQuoteDialog extends ConsumerWidget {
  const DailyQuoteDialog({
    super.key,
    required this.quote,
  });

  final Quote quote;

  /// SharedPreferences key for recording the last date this popup was shown.
  static const String prefKey = 'vyayama_last_quote_popup_date';

  /// Checks if the daily quote popup has already been shown today.
  /// If not, loads today's quote, saves today's date, and displays the dialog.
  static Future<void> checkAndShow(BuildContext context, WidgetRef ref) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final today = ref.read(todayProvider);
      final todayStr = dayKey(today);

      final lastDate = prefs.getString(prefKey);
      if (lastDate == todayStr) {
        // Already shown today
        return;
      }

      // Mark as shown for today
      await prefs.setString(prefKey, todayStr);

      // Resolve today's quote
      Quote? quote = ref.read(todayBoostProvider).asData?.value.quote;
      if (quote == null) {
        try {
          final quotes = await ref.read(quotesProvider.future);
          quote = const DailyBoostPicker().quoteFor(quotes, today);
        } catch (_) {}
      }

      quote ??= const Quote(
        id: 'default',
        text: 'Small daily steps lead to massive lifetime transformations.',
        author: 'Vyayama',
      );

      if (!context.mounted) return;
      await show(context, quote);
    } catch (e) {
      debugPrint('DailyQuoteDialog checkAndShow error: $e');
    }
  }

  /// Shows the dialog directly with a given quote.
  static Future<void> show(BuildContext context, Quote quote) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => DailyQuoteDialog(quote: quote),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isFav = ref.watch(isFavoriteProvider(quote.id));

    final dialogBg = scheme.surfaceContainer;
    final borderColor = scheme.outlineVariant;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                blurRadius: 36,
                offset: const Offset(0, 10),
              ),
              if (isDark)
                BoxShadow(
                  color: AppPalette.forestGreen.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header Row with Badge & Cross (Close) Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.limeGreen.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppPalette.limeGreen.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: AppPalette.limeGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'DAILY SPARK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? AppPalette.limeGreen
                                : AppPalette.forestGreen,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cross Button (X) for quick removal if not interested
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: 'Close quote',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                    ),
                    onPressed: () {
                      try {
                        HapticFeedback.lightImpact();
                      } catch (_) {}
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Cheering Mascot Avatar
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.25),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/mascot/thumbs_up.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.format_quote_rounded,
                      size: 40,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quote Decorative Icon
              Icon(
                Icons.format_quote_rounded,
                size: 32,
                color: scheme.primary.withValues(alpha: 0.4),
              ),

              const SizedBox(height: 4),

              // Quote text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '"${quote.text}"',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Author Attribution
              Text(
                quote.author != null ? '— ${quote.author}' : '— Daily Wisdom',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 24),

              // Bottom Action Bar
              Row(
                children: [
                  // Favorite Heart Button
                  IconButton(
                    icon: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav
                          ? context.colors.danger
                          : scheme.onSurfaceVariant,
                      size: 24,
                    ),
                    tooltip: isFav ? 'Remove favorite' : 'Save to favorites',
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    onPressed: () {
                      ref.read(favoritesProvider.notifier).toggle(quote.id);
                      try {
                        HapticFeedback.lightImpact();
                      } catch (_) {}
                    },
                  ),

                  const SizedBox(width: 12),

                  // Primary Dismiss / Let's Go Button
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark
                            ? AppPalette.limeGreen
                            : AppPalette.forestGreen,
                        foregroundColor:
                            isDark ? AppPalette.charcoalGreen : Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        try {
                          HapticFeedback.mediumImpact();
                        } catch (_) {}
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "Let's Crush Today! 💪",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
