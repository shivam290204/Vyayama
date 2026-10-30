import 'package:fitbuddy/features/maps/data/services/map_tile_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralized, production-grade map tile layer widget.
///
/// Ensures compliance with OpenStreetMap tile usage policies, supports
/// `--dart-define` overrides, emits release-mode warnings for public servers,
/// and delegates tile loading error feedback without introducing no-cache headers.
class AppMapTileLayer extends StatelessWidget {
  const AppMapTileLayer({
    super.key,
    this.onError,
    this.tileProvider,
  });

  /// Optional error callback invoked when an individual tile fails to load.
  final ErrorTileCallBack? onError;

  /// Optional tile provider override (defaults to [NetworkTileProvider] with built-in caching).
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    MapTileConfig.warnIfPublicTileServerInRelease();

    final provider = tileProvider ??
        NetworkTileProvider(
          headers: {
            'User-Agent': MapTileConfig.userAgent,
          },
          silenceExceptions: true,
        );
    provider.headers.putIfAbsent('User-Agent', () => MapTileConfig.userAgent);

    return TileLayer(
      urlTemplate: MapTileConfig.tileUrl,
      userAgentPackageName: MapTileConfig.userAgent,
      errorTileCallback: onError,
      tileProvider: provider,
    );
  }
}

/// Standardized, clickable OpenStreetMap attribution widget.
class AppMapAttribution extends StatelessWidget {
  const AppMapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => launchUrl(
            Uri.parse(MapTileConfig.osmCopyrightUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }
}
