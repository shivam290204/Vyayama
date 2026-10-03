import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/motivation/providers.dart';
import 'package:fitbuddy/features/motivation/widgets/meme_card.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Compact Daily Boost card for Home.
///
/// Shows the morning quote until 17:00 and the evening meme after that.
/// Tapping opens `/boost`.
class DailyBoostCard extends ConsumerWidget {
  /// Creates the card.
  const DailyBoostCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boost = ref.watch(todayBoostProvider);
    final now = ref.watch(nowProvider).asData?.value ?? ref.read(clockProvider)();
    final showMeme = now.hour >= 17;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget content = boost.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => ListTile(
        leading: const Icon(Icons.error_outline, semanticLabel: 'Error'),
        title: const Text("Couldn't load your daily boost"),
        trailing: TextButton(
          onPressed: () {
            ref
              ..invalidate(quotesProvider)
              ..invalidate(memesProvider);
          },
          child: const Text('Retry'),
        ),
      ),
      data: (b) {
        final meme = b.meme;
        final quote = b.quote;
        if (showMeme && meme != null) {
          final colors = memeToneColors(scheme, meme.tone);
          return _Tile(
            background: colors.background,
            foreground: colors.foreground,
            heading: 'Evening meme',
            leading: Text(meme.emoji, style: text.headlineMedium),
            body: meme.caption,
          );
        }
        if (quote != null) {
          return _Tile(
            background: scheme.primaryContainer,
            foreground: scheme.onPrimaryContainer,
            heading: 'Morning quote',
            leading: Icon(
              Icons.format_quote,
              size: 32,
              color: scheme.onPrimaryContainer,
              semanticLabel: 'Quote',
            ),
            body: quote.author == null
                ? quote.text
                : '${quote.text} \u2014 ${quote.author}',
          );
        }
        return const ListTile(title: Text('No daily boost yet'));
      },
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.dailyBoost),
        child: content,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.background,
    required this.foreground,
    required this.heading,
    required this.leading,
    required this.body,
  });

  final Color background;
  final Color foreground;
  final String heading;
  final Widget leading;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      color: background,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: text.labelLarge?.copyWith(color: foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: foreground, semanticLabel: 'Open'),
        ],
      ),
    );
  }
}
