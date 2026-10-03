import 'package:fitbuddy/features/motivation/daily_boost_picker.dart';
import 'package:fitbuddy/features/motivation/data/boost_repository.dart';
import 'package:fitbuddy/features/motivation/data/meme.dart';
import 'package:fitbuddy/features/motivation/data/quote.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Daily Boost storage. Antigravity swaps in a persistent implementation.
final boostRepositoryProvider = Provider<BoostRepository>(
  (ref) => MockBoostRepository(),
);

/// All quotes.
final quotesProvider = FutureProvider<List<Quote>>(
  (ref) => ref.watch(boostRepositoryProvider).fetchQuotes(),
);

/// All memes.
final memesProvider = FutureProvider<List<Meme>>(
  (ref) => ref.watch(boostRepositoryProvider).fetchMemes(),
);

/// Quotes and memes loaded together.
@immutable
class BoostContent {
  /// Creates the content.
  const BoostContent({required this.quotes, required this.memes});

  /// All quotes.
  final List<Quote> quotes;

  /// All memes.
  final List<Meme> memes;
}

/// Quotes and memes, loading or failing as one.
final boostContentProvider = Provider<AsyncValue<BoostContent>>((ref) {
  final quotes = ref.watch(quotesProvider);
  final memes = ref.watch(memesProvider);
  if (quotes.hasError) {
    return AsyncValue.error(
      quotes.error!,
      quotes.stackTrace ?? StackTrace.current,
    );
  }
  if (memes.hasError) {
    return AsyncValue.error(
      memes.error!,
      memes.stackTrace ?? StackTrace.current,
    );
  }
  final q = quotes.asData?.value;
  final m = memes.asData?.value;
  if (q == null || m == null) return const AsyncValue.loading();
  return AsyncValue.data(BoostContent(quotes: q, memes: m));
});

/// Today's quote and meme.
@immutable
class TodayBoost {
  /// Creates the pair. Either may be null if its list is empty.
  const TodayBoost({this.quote, this.meme});

  /// Morning quote.
  final Quote? quote;

  /// Evening meme.
  final Meme? meme;
}

/// Today's morning quote and evening meme.
final todayBoostProvider = Provider<AsyncValue<TodayBoost>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(boostContentProvider).whenData(
        (c) => TodayBoost(
          quote: const DailyBoostPicker().quoteFor(c.quotes, today),
          meme: const DailyBoostPicker().memeFor(c.memes, today),
        ),
      );
});

/// The previous 7 days of quotes and memes, newest first.
final boostHistoryProvider = Provider<AsyncValue<List<BoostDay>>>((ref) {
  final today = ref.watch(todayProvider);
  return ref.watch(boostContentProvider).whenData(
        (c) => const DailyBoostPicker().historyFor(
          quotes: c.quotes,
          memes: c.memes,
          today: today,
        ),
      );
});

/// Ids of favorite quotes and memes, with a toggle action.
class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() =>
      ref.watch(boostRepositoryProvider).fetchFavorites();

  /// Adds [id] to the favorites, or removes it if already there.
  Future<void> toggle(String id) async {
    final current = state.asData?.value ?? <String>{};
    final makeFavorite = !current.contains(id);
    // Update the UI right away, then save.
    state = AsyncData(
      makeFavorite ? {...current, id} : ({...current}..remove(id)),
    );
    await ref.read(boostRepositoryProvider).setFavorite(id, makeFavorite);
  }
}

/// Favorite ids.
final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);

/// Whether the item with [id] is a favorite.
final isFavoriteProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(favoritesProvider).asData?.value.contains(id) ?? false,
);

/// Favorite quotes and memes (each list sorted by id).
@immutable
class FavoriteItems {
  /// Creates the lists.
  const FavoriteItems({required this.quotes, required this.memes});

  /// Favorite quotes.
  final List<Quote> quotes;

  /// Favorite memes.
  final List<Meme> memes;

  /// True when there are no favorites at all.
  bool get isEmpty => quotes.isEmpty && memes.isEmpty;
}

/// The favorites joined with their content.
final favoriteItemsProvider = Provider<AsyncValue<FavoriteItems>>((ref) {
  final ids = ref.watch(favoritesProvider).asData?.value ?? const <String>{};
  return ref.watch(boostContentProvider).whenData(
        (c) => FavoriteItems(
          quotes: [
            for (final q in c.quotes)
              if (ids.contains(q.id)) q,
          ]..sort((a, b) => a.id.compareTo(b.id)),
          memes: [
            for (final m in c.memes)
              if (ids.contains(m.id)) m,
          ]..sort((a, b) => a.id.compareTo(b.id)),
        ),
      );
});
