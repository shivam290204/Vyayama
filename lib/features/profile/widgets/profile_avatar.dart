import 'package:flutter/material.dart';

import 'package:fitbuddy/features/profile/data/profile.dart';

/// Round avatar: the profile photo if available, otherwise initials.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.size = 96});

  final Profile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = profile.avatarUrl;

    return Semantics(
      image: true,
      label: 'Profile photo of ${profile.displayName}',
      excludeSemantics: true,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: (url == null || url.isEmpty)
              ? _Initials(text: profile.initials, size: size)
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      _Initials(text: profile.initials, size: size),
                ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
              ),
        ),
      ),
    );
  }
}
