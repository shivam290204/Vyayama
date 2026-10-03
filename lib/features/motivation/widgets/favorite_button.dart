import 'package:flutter/material.dart';

/// Heart toggle with a 48dp tap target and a clear tooltip.
class FavoriteButton extends StatelessWidget {
  /// Creates the button.
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.color,
  });

  /// Whether the item is currently a favorite.
  final bool isFavorite;

  /// Called when pressed.
  final VoidCallback onPressed;

  /// Icon colour, for use on coloured cards. Defaults to the theme.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      isSelected: isFavorite,
      color: color,
      selectedIcon: const Icon(Icons.favorite),
      icon: const Icon(Icons.favorite_border),
      onPressed: onPressed,
    ).withSelectedColor(color);
  }
}

extension on IconButton {
  /// Returns this button with `selectedIcon` coloured like the base icon.
  Widget withSelectedColor(Color? color) {
    if (color == null) return this;
    return IconTheme.merge(data: IconThemeData(color: color), child: this);
  }
}
