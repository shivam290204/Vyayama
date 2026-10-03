import 'package:fitbuddy/features/motivation/providers.dart';
import 'package:fitbuddy/features/motivation/widgets/boost_favorites_tab.dart';
import 'package:fitbuddy/features/motivation/widgets/boost_history_tab.dart';
import 'package:fitbuddy/features/motivation/widgets/boost_message.dart';
import 'package:fitbuddy/features/motivation/widgets/meme_card.dart';
import 'package:fitbuddy/features/motivation/widgets/quote_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Daily Boost: today's quote and meme, the last 7 days, and favorites.
class BoostScreen extends StatelessWidget {
  /// Creates the screen.
  const BoostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daily Boost'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'History'),
              Tab(text: 'Favorites'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TodayTab(),
            BoostHistoryTab(),
            BoostFavoritesTab(),
          ],
        ),
      ),
    );
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(favoritesProvider.notifier);
    return ref.watch(todayBoostProvider).when(
          loading: () => Center(
            child: Semantics(
              label: 'Loading daily boost',
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => BoostMessage(
            icon: Icons.error_outline,
            text: "We couldn't load today's boost.",
            onRetry: () {
              ref
                ..invalidate(quotesProvider)
                ..invalidate(memesProvider);
            },
          ),
          data: (boost) {
            final quote = boost.quote;
            final meme = boost.meme;
            if (quote == null && meme == null) {
              return const BoostMessage(
                icon: Icons.wb_sunny_outlined,
                text: 'No daily boost available yet.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref
                  ..invalidate(quotesProvider)
                  ..invalidate(memesProvider);
                await ref.read(quotesProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (quote != null)
                    QuoteCard(
                      title: 'Morning quote',
                      quote: quote,
                      isFavorite: ref.watch(isFavoriteProvider(quote.id)),
                      onToggleFavorite: () => notifier.toggle(quote.id),
                    ),
                  const SizedBox(height: 12),
                  if (meme != null)
                    MemeCard(
                      title: 'Evening meme',
                      meme: meme,
                      isFavorite: ref.watch(isFavoriteProvider(meme.id)),
                      onToggleFavorite: () => notifier.toggle(meme.id),
                    ),
                ],
              ),
            );
          },
        );
  }
}
