import 'dart:convert';

import 'package:fitbuddy/features/motivation/data/meme.dart';
import 'package:fitbuddy/features/motivation/data/quote.dart';
import 'package:flutter/services.dart';

/// Path of the bundled quotes.
const String quotesAssetPath = 'assets/data/quotes.json';

/// Path of the bundled memes.
const String memesAssetPath = 'assets/data/memes.json';

/// Loads the bundled quotes (`{ "quotes": [ ... ] }`).
Future<List<Quote>> loadQuotesFromAsset({AssetBundle? bundle}) async {
  final raw = await (bundle ?? rootBundle).loadString(quotesAssetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final list = (decoded['quotes'] as List<dynamic>?) ?? const <dynamic>[];
  return List<Quote>.unmodifiable([
    for (final e in list) Quote.fromJson(e as Map<String, dynamic>),
  ]);
}

/// Loads the bundled memes (`{ "memes": [ ... ] }`).
Future<List<Meme>> loadMemesFromAsset({AssetBundle? bundle}) async {
  final raw = await (bundle ?? rootBundle).loadString(memesAssetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final list = (decoded['memes'] as List<dynamic>?) ?? const <dynamic>[];
  return List<Meme>.unmodifiable([
    for (final e in list) Meme.fromJson(e as Map<String, dynamic>),
  ]);
}

/// Source of Daily Boost content and the user's favorites.
///
/// Content could later come from Supabase so it can change without an app
/// release. Favorites need persistence (for example `shared_preferences`).
abstract class BoostRepository {
  /// All quotes.
  Future<List<Quote>> fetchQuotes();

  /// All memes.
  Future<List<Meme>> fetchMemes();

  /// Ids (quote and meme ids) the user marked as favorite.
  Future<Set<String>> fetchFavorites();

  /// Adds or removes [itemId] from the favorites.
  Future<void> setFavorite(String itemId, bool favorite);
}

/// Loads content from the bundled JSON and keeps favorites in memory.
class MockBoostRepository implements BoostRepository {
  /// Creates the repository. Pass loaders or [favorites] in tests.
  MockBoostRepository({
    Future<List<Quote>> Function()? quotes,
    Future<List<Meme>> Function()? memes,
    Set<String>? favorites,
  })  : _quotes = quotes ?? loadQuotesFromAsset,
        _memes = memes ?? loadMemesFromAsset,
        _favorites = {...?favorites};

  final Future<List<Quote>> Function() _quotes;
  final Future<List<Meme>> Function() _memes;
  final Set<String> _favorites;

  @override
  Future<List<Quote>> fetchQuotes() => _quotes();

  @override
  Future<List<Meme>> fetchMemes() => _memes();

  @override
  Future<Set<String>> fetchFavorites() async => Set<String>.of(_favorites);

  @override
  Future<void> setFavorite(String itemId, bool favorite) async {
    if (favorite) {
      _favorites.add(itemId);
    } else {
      _favorites.remove(itemId);
    }
  }
}
