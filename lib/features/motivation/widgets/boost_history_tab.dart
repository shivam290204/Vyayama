import 'package:fitbuddy/features/motivation/daily_boost_picker.dart';
import 'package:fitbuddy/features/motivation/providers.dart';
import 'package:fitbuddy/features/motivation/widgets/boost_message.dart';
import 'package:fitbuddy/features/motivation/widgets/favorite_button.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The previous 7 days of quotes and memes.
class BoostHistoryTab extends ConsumerWidget {
  /// Creates the tab.
  const BoostHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(boostHistoryProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => BoostMessage(
            icon: Icons.error_outline,
            text: "We couldn't load your history.",
            onRetry: () {
              ref
                ..invalidate(quotesProvider)
                ..invalidate(memesProvider);
            },
          ),
          data: (days) {
            final shown =
                days.where((d) => d.quote != null || d.meme != null).toList();
            if (shown.isEmpty) {
              return const BoostMessage(
                icon: Icons.history,
                text: 'Your daily boosts will show up here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _DayCard(day: shown[i]),
            );
          },
        );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.day});

  final BoostDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final quote = day.quote;
    final meme = day.meme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(formatLongDate(day.day), style: text.titleSmall),
            ),
            if (quote != null)
              ListTile(
                leading: Icon(
                  Icons.format_quote,
                  color: scheme.primary,
                  semanticLabel: 'Quote',
                ),
                title: Text(quote.text),
                subtitle: quote.author == null ? null : Text(quote.author!),
                trailing: FavoriteButton(
                  isFavorite: ref.watch(isFavoriteProvider(quote.id)),
                  onPressed: () =>
                      ref.read(favoritesProvider.notifier).toggle(quote.id),
                ),
              ),
            if (meme != null)
              ListTile(
                leading: Text(meme.emoji, style: text.headlineSmall),
                title: Text(meme.caption),
                trailing: FavoriteButton(
                  isFavorite: ref.watch(isFavoriteProvider(meme.id)),
                  onPressed: () =>
                      ref.read(favoritesProvider.notifier).toggle(meme.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
