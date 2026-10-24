import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:fitbuddy/features/friends/data/invite_link.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Central service handling incoming Android and web app links / deep links.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  Future<void> init(GoRouter router) async {
    // 1. Initial cold start link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri, router);
      }
    } catch (e) {
      debugPrint('DeepLinkService initial link error: $e');
    }

    // 2. Continuous incoming links while active
    _sub = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri, router),
      onError: (err) => debugPrint('DeepLinkService stream error: $err'),
    );
  }

  void _handleUri(Uri uri, GoRouter router) {
    debugPrint('Handling deep link: $uri');

    // Ignore OAuth login redirects (handled directly by Supabase auth listener)
    if (uri.scheme == 'io.vyayama.fitbuddy' && uri.host == 'login-callback') {
      return;
    }

    final raw = uri.toString();
    final identifier = parseProfileIdentifier(raw);
    if (identifier != null && identifier.isNotEmpty) {
      router.go('/u/$identifier');
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
