import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/data/services/nominatim_service.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_filter_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Floating search bar and map control buttons overlaid on top of the interactive map.
class MapControlsOverlay extends ConsumerStatefulWidget {
  const MapControlsOverlay({
    super.key,
    required this.mapController,
    required this.onRecenter,
    required this.onSavedRoutesTap,
  });

  final MapController mapController;
  final VoidCallback onRecenter;
  final VoidCallback onSavedRoutesTap;

  @override
  ConsumerState<MapControlsOverlay> createState() => _MapControlsOverlayState();
}

class _MapControlsOverlayState extends ConsumerState<MapControlsOverlay> {
  final TextEditingController _searchCtrl = TextEditingController();
  final NominatimService _nominatimService = NominatimService();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearchSubmitted(String query) async {
    final trimmed = query.trim();
    // Update route name filter for any non-empty query
    ref.read(activeRouteFilterProvider.notifier).update(
          (current) => current.copyWith(searchQuery: trimmed),
        );

    if (trimmed.isEmpty) return;

    if (_isSearching) return;
    setState(() => _isSearching = true);

    try {
      final results = await _nominatimService.search(trimmed);
      if (!mounted) return;

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No places found for that search.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final first = results.first;
      ref.read(selectedMapCenterProvider.notifier).state = first.latLng;
      widget.mapController.move(first.latLng, 14.5);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved to: ${first.shortName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark
        ? AppPalette.darkSurfaceContainer
        : AppPalette.lightSurface;
    final borderColor =
        isDark ? AppPalette.darkOutline : AppPalette.lightOutline;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    final savedRoutesCount =
        ref.watch(savedRoutesListProvider).asData?.value.length ?? 0;

    return SafeArea(
      child: Stack(
        children: [
          // 1. Top Search Bar
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: borderColor, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search_rounded, color: textMuted, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearchSubmitted,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search places, parks, trails...',
                        hintStyle: TextStyle(color: textMuted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: textMuted,
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchSubmitted('');
                      },
                    ),
                  // Filter trigger button — replaced with progress when searching
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: _isSearching
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark
                                    ? AppPalette.limeGreen
                                    : AppPalette.forestGreen,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.tune_rounded, size: 20),
                            color: isDark
                                ? AppPalette.limeGreen
                                : AppPalette.forestGreen,
                            tooltip: 'Filter Routes',
                            onPressed: () {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const RouteFilterSheet(),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Right Floating Controls: Re-center, Zoom In, Zoom Out, Saved Routes
          Positioned(
            right: 16,
            top: 76,
            child: Column(
              children: [
                // Re-center Location Button
                _MapFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Re-center My Location',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  iconColor: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
                  onPressed: widget.onRecenter,
                ),
                const SizedBox(height: 10),

                // Zoom In
                _MapFloatingButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  iconColor: textPrimary,
                  onPressed: () {
                    final currentZoom = widget.mapController.camera.zoom;
                    widget.mapController.move(
                      widget.mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Zoom Out
                _MapFloatingButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  iconColor: textPrimary,
                  onPressed: () {
                    final currentZoom = widget.mapController.camera.zoom;
                    widget.mapController.move(
                      widget.mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Saved Routes Shortcut
                _MapFloatingButton(
                  icon: Icons.bookmarks_rounded,
                  tooltip: 'Saved Routes',
                  cardBg: cardBg,
                  borderColor: borderColor,
                  badgeCount: savedRoutesCount,
                  iconColor: AppPalette.activitySteps,
                  onPressed: widget.onSavedRoutesTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  const _MapFloatingButton({
    required this.icon,
    required this.tooltip,
    required this.cardBg,
    required this.borderColor,
    required this.iconColor,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final Color cardBg;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cardBg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: Badge(
              isLabelVisible: badgeCount > 0,
              label: Text('$badgeCount'),
              backgroundColor: AppPalette.limeGreen,
              textColor: AppPalette.charcoalGreen,
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

