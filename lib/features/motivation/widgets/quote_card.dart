import 'package:fitbuddy/features/motivation/data/quote.dart';
import 'package:fitbuddy/features/motivation/widgets/favorite_button.dart';
import 'package:flutter/material.dart';

/// Card showing one quote, with an optional [title] and a favorite toggle.
class QuoteCard extends StatelessWidget {
  /// Creates the card.
  const QuoteCard({
    super.key,
    required this.quote,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.title,
  });

  /// The quote.
  final Quote quote;

  /// Whether it is a favorite.
  final bool isFavorite;

  /// Called when the heart is pressed.
  final VoidCallback onToggleFavorite;

  /// Small heading, for example "Morning quote".
  final String? title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = scheme.onPrimaryContainer;
    return Card(
      color: scheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 8),
                child: Text(title!, style: text.labelLarge?.copyWith(color: fg)),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                quote.text,
                style: text.titleLarge?.copyWith(color: fg),
              ),
            ),
            if (quote.author != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: Text(
                  '\u2014 ${quote.author}',
                  style: text.bodyMedium?.copyWith(color: fg),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: FavoriteButton(
                isFavorite: isFavorite,
                onPressed: onToggleFavorite,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
