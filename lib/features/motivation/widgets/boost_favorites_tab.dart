import 'package:fitbuddy/features/motivation/providers.dart';
import 'package:fitbuddy/features/motivation/widgets/boost_message.dart';
import 'package:fitbuddy/features/motivation/widgets/meme_card.dart';
import 'package:fitbuddy/features/motivation/widgets/quote_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The quotes and memes the user marked as favorites.
class BoostFavoritesTab extends ConsumerWidget {
  /// Creates the tab.
  const BoostFavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(favoritesProvider.notifier);
    return ref.watch(favoriteItemsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => BoostMessage(
            icon: Icons.error_outline,
            text: "We couldn't load your favorites.",
            onRetry: () {
              ref
                ..invalidate(quotesProvider)
                ..invalidate(memesProvider)
                ..invalidate(favoritesProvider);
            },
          ),
          data: (items) {
            if (items.isEmpty) {
              return const BoostMessage(
                icon: Icons.favorite_border,
                text: 'Tap the heart on a quote or meme to save it here.',
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final q in items.quotes) ...[
                  QuoteCard(
                    quote: q,
                    isFavorite: true,
                    onToggleFavorite: () => notifier.toggle(q.id),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final m in items.memes) ...[
                  MemeCard(
                    meme: m,
                    isFavorite: true,
                    onToggleFavorite: () => notifier.toggle(m.id),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        );
  }
}
