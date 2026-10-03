import 'package:flutter/foundation.dart';

/// A short motivational quote from `assets/data/quotes.json`.
@immutable
class Quote {
  /// Creates a quote.
  const Quote({required this.id, required this.text, this.author});

  /// Parses an entry of `quotes.json`.
  factory Quote.fromJson(Map<String, dynamic> json) {
    final author = (json['author'] as String?)?.trim();
    return Quote(
      id: json['id'] as String,
      text: (json['text'] as String?) ?? '',
      author: (author == null || author.isEmpty) ? null : author,
    );
  }

  /// Stable id, for example `q-001`.
  final String id;

  /// The quote text.
  final String text;

  /// Author, when known.
  final String? author;

  /// Converts back to the JSON shape.
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        if (author != null) 'author': author,
      };
}
