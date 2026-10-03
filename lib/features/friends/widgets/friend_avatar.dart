import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:flutter/material.dart';

/// Round avatar with an initials fallback.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.user, this.radius = 24});

  final FriendUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = user.avatarUrl;
    return Semantics(
      image: true,
      label: '${user.name} profile picture',
      excludeSemantics: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        foregroundImage: url == null ? null : NetworkImage(url),
        child: Text(
          user.initials,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
