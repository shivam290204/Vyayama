import 'package:flutter/foundation.dart';

/// Which theme colours a meme card uses. Maps to `ColorScheme` roles, so
/// memes follow light and dark mode.
enum BoostTone {
  /// Primary container colours.
  primary,

  /// Secondary container colours.
  secondary,

  /// Tertiary container colours.
  tertiary,

  /// Inverse surface colours (a strong contrast card).
  inverse;

  /// Parses a stored value, defaulting to [primary].
  static BoostTone parse(String? value) => values.firstWhere(
        (t) => t.name == value,
        orElse: () => BoostTone.primary,
      );
}

/// An original text-and-emoji health meme from `assets/data/memes.json`.
@immutable
class Meme {
  /// Creates a meme.
  const Meme({
    required this.id,
    required this.caption,
    required this.emoji,
    this.tone = BoostTone.primary,
  });

  /// Parses an entry of `memes.json`.
  factory Meme.fromJson(Map<String, dynamic> json) {
    return Meme(
      id: json['id'] as String,
      caption: (json['caption'] as String?) ?? '',
      emoji: (json['emoji'] as String?) ?? '',
      tone: BoostTone.parse(json['tone'] as String?),
    );
  }

  /// Stable id, for example `m-001`.
  final String id;

  /// The caption shown on the card.
  final String caption;

  /// One emoji shown large on the card.
  final String emoji;

  /// Card colours.
  final BoostTone tone;

  /// Converts back to the JSON shape.
  Map<String, dynamic> toJson() => {
        'id': id,
        'caption': caption,
        'emoji': emoji,
        'tone': tone.name,
      };
}
