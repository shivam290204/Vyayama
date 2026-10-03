import 'package:fitbuddy/features/motivation/data/meme.dart';
import 'package:fitbuddy/features/motivation/data/quote.dart';
import 'package:flutter/foundation.dart';

/// The quote and meme of one past day.
@immutable
class BoostDay {
  /// Creates a day. [quote] or [meme] is null if that list is empty.
  const BoostDay({required this.day, this.quote, this.meme});

  /// The calendar day.
  final DateTime day;

  /// That day's quote.
  final Quote? quote;

  /// That day's meme.
  final Meme? meme;
}

/// Picks the daily quote and meme from the date. Pure Dart.
///
/// Lists are sorted by id first, so every device shows the same items on
/// the same date whatever order they were loaded in.
class DailyBoostPicker {
  /// Creates the picker.
  const DailyBoostPicker();

  /// Offset that keeps the meme cycle out of step with the quote cycle.
  static const int memeOffset = 5;

  /// Whole days between 1970-01-01 and the calendar day of [day].
  int epochDay(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// The quote for [day], or null when [all] is empty.
  Quote? quoteFor(List<Quote> all, DateTime day) {
    if (all.isEmpty) return null;
    final sorted = [...all]..sort((a, b) => a.id.compareTo(b.id));
    return sorted[epochDay(day) % sorted.length];
  }

  /// The meme for [day], or null when [all] is empty.
  Meme? memeFor(List<Meme> all, DateTime day) {
    if (all.isEmpty) return null;
    final sorted = [...all]..sort((a, b) => a.id.compareTo(b.id));
    return sorted[(epochDay(day) + memeOffset) % sorted.length];
  }

  /// The previous [days] days (not including [today]), newest first.
  List<BoostDay> historyFor({
    required List<Quote> quotes,
    required List<Meme> memes,
    required DateTime today,
    int days = 7,
  }) {
    return [
      for (var i = 1; i <= days; i++)
        () {
          final day = DateTime(today.year, today.month, today.day - i);
          return BoostDay(
            day: day,
            quote: quoteFor(quotes, day),
            meme: memeFor(memes, day),
          );
        }(),
    ];
  }
}
