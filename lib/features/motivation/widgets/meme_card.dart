import 'package:fitbuddy/features/motivation/data/meme.dart';
import 'package:fitbuddy/features/motivation/widgets/favorite_button.dart';
import 'package:flutter/material.dart';

/// Background and text colours for a meme [tone], taken from [scheme].
({Color background, Color foreground}) memeToneColors(
  ColorScheme scheme,
  BoostTone tone,
) {
  switch (tone) {
    case BoostTone.primary:
      return (
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
      );
    case BoostTone.secondary:
      return (
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      );
    case BoostTone.tertiary:
      return (
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      );
    case BoostTone.inverse:
      return (
        background: scheme.inverseSurface,
        foreground: scheme.onInverseSurface,
      );
  }
}

/// A coloured card with a big emoji and a caption.
class MemeCard extends StatelessWidget {
  /// Creates the card.
  const MemeCard({
    super.key,
    required this.meme,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.title,
  });

  /// The meme.
  final Meme meme;

  /// Whether it is a favorite.
  final bool isFavorite;

  /// Called when the heart is pressed.
  final VoidCallback onToggleFavorite;

  /// Small heading, for example "Evening meme".
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colors = memeToneColors(Theme.of(context).colorScheme, meme.tone);
    final text = Theme.of(context).textTheme;
    return Card(
      color: colors.background,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 8),
                child: Text(
                  title!,
                  style: text.labelLarge?.copyWith(color: colors.foreground),
                ),
              ),
            Center(child: Text(meme.emoji, style: text.displayMedium)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                meme.caption,
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(color: colors.foreground),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FavoriteButton(
                isFavorite: isFavorite,
                onPressed: onToggleFavorite,
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
