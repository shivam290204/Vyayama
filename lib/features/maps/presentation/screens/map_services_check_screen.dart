import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/data/services/map_diagnostics_service.dart';
import 'package:fitbuddy/features/maps/data/services/real_route_discovery_service.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/route_discovery_result.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

/// Flag allowing diagnostics screen in release builds when explicitly requested via --dart-define.
const bool kEnableMapDiagnosticsInRelease =
    bool.fromEnvironment('ENABLE_MAP_DIAGNOSTICS', defaultValue: false);

/// Whether the diagnostics screen should be accessible in the current runtime environment.
bool get isMapDiagnosticsAccessible =>
    kDebugMode || kEnableMapDiagnosticsInRelease;

/// Screen presenting real-time reachability, latency, and status of all mapping dependencies.
class MapServicesCheckScreen extends StatefulWidget {
  const MapServicesCheckScreen({
    super.key,
    this.diagnosticsService,
    this.discoveryDiagnostics,
  });

  final MapDiagnosticsService? diagnosticsService;
  final RouteDiscoveryDiagnostics? discoveryDiagnostics;

  @override
  State<MapServicesCheckScreen> createState() => _MapServicesCheckScreenState();
}

class _MapServicesCheckScreenState extends State<MapServicesCheckScreen> {
  late final MapDiagnosticsService _service;
  MapDiagnosticsReport? _report;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isRunningKnownParkTest = false;
  KnownParkPipelineReport? _knownParkReport;

  @override
  void initState() {
    super.initState();
    _service = widget.diagnosticsService ?? MapDiagnosticsService();
    _runCheck();
  }

  RouteDiscoveryDiagnostics? _getEffectiveDiscoveryDiagnostics(BuildContext context) {
    if (widget.discoveryDiagnostics != null) {
      return widget.discoveryDiagnostics;
    }
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      return container.read(latestDiscoveryDiagnosticsProvider);
    } catch (_) {
      return null;
    }
  }

  Future<void> _runCheck() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final report = await _service.runDiagnostics();
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Diagnostics check failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _runKnownParkTest() async {
    setState(() {
      _isRunningKnownParkTest = true;
    });

    try {
      final diag = _getEffectiveDiscoveryDiagnostics(context);
      final container = ProviderScope.containerOf(context, listen: false);
      final lastGps = container.read(userLocationStateProvider).position ??
          container.read(userLocationStateProvider).lastKnownPosition;

      LatLng? searchCenter;
      if (diag?.roundedLat != null && diag?.roundedLon != null) {
        searchCenter = LatLng(diag!.roundedLat!, diag.roundedLon!);
      } else {
        searchCenter = container.read(effectiveMapCenterProvider);
      }

      String? distanceSearchToGps;
      if (searchCenter != null && lastGps != null) {
        final dM = haversineDistance(searchCenter, lastGps);
        distanceSearchToGps = dM >= 1000
            ? '${(dM / 1000).toStringAsFixed(1)} km'
            : '${dM.round()} m';
      }

      final testPoints = <({String name, LatLng coords})>[
        (name: 'Central Park (New York)', coords: const LatLng(40.7829, -73.9654)),
        (name: 'Lodhi Garden (Delhi)', coords: const LatLng(28.5933, 77.2197)),
      ];

      if (searchCenter != null) {
        testPoints.add((name: 'Your Search Center', coords: searchCenter));
      }

      final results = <KnownParkTestPointResult>[];
      final discoveryService = RealRouteDiscoveryService();

      for (final tp in testPoints) {
        String? distFromGps;
        if (lastGps != null) {
          final dM = haversineDistance(tp.coords, lastGps);
          distFromGps = dM >= 1000
              ? '${(dM / 1000).toStringAsFixed(1)} km'
              : '${dM.round()} m';
        }

        try {
          final res = await discoveryService.discoverRoutes(
            center: tp.coords,
            radiusKm: 5.0,
            forceRefresh: true,
          );
          final d = res.diagnostics;
          results.add(KnownParkTestPointResult(
            name: tp.name,
            coords: tp.coords,
            placesFound: d.overpassElementCount + d.nominatimCount,
            candidates: d.candidatesCount,
            valhallaSuccesses: d.valhallaSuccesses,
            routes: d.finalRouteCount,
            distanceFromGpsFormatted: distFromGps,
          ));
        } catch (e) {
          results.add(KnownParkTestPointResult(
            name: tp.name,
            coords: tp.coords,
            placesFound: 0,
            candidates: 0,
            valhallaSuccesses: 0,
            routes: 0,
            distanceFromGpsFormatted: distFromGps,
            error: e.toString(),
          ));
        }
      }

      final benchmarkPoints =
          results.where((r) => r.name != 'Your Search Center').toList();
      final userCenterResult =
          results.where((r) => r.name == 'Your Search Center').firstOrNull;

      final benchmarkSuccess = benchmarkPoints.any((r) => r.isSuccess);
      final userSuccess = userCenterResult?.isSuccess ?? false;

      String summary;
      if (benchmarkSuccess && !userSuccess) {
        summary =
            'Pipeline works at known parks, but found no routes at your search center. '
            'This confirms services are functioning normally; your local area may have sparse OpenStreetMap coverage.';
      } else if (benchmarkSuccess && userSuccess) {
        summary =
            'Pipeline is working normally at both known parks and your search center.';
      } else if (!benchmarkSuccess && userSuccess) {
        summary =
            'Routes were found at your search center, though some benchmark fixtures failed.';
      } else {
        summary =
            'Pipeline failed at both known parks and your search center. '
            'External mapping services (Overpass/Valhalla) may be experiencing an outage or network restrictions.';
      }

      if (!mounted) return;
      setState(() {
        _knownParkReport = KnownParkPipelineReport(
          points: results,
          summary: summary,
          distanceSearchCenterToGpsFormatted: distanceSearchToGps,
        );
        _isRunningKnownParkTest = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRunningKnownParkTest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Known-park test error: $e')),
      );
    }
  }

  void _copyReportToClipboard() {
    final report = _report;
    final diag = _getEffectiveDiscoveryDiagnostics(context);
    final kpReport = _knownParkReport;
    final buf = StringBuffer();
    if (report != null) {
      buf.writeln(report.toPlainText());
    }
    if (diag != null) {
      if (buf.isNotEmpty) buf.writeln('\n');
      buf.writeln(diag.toPlainText());
    }
    if (kpReport != null) {
      if (buf.isNotEmpty) buf.writeln('\n');
      buf.writeln(kpReport.toPlainText());
    }
    if (buf.isEmpty) return;

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics report copied to clipboard'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _copyDiscoveryReportToClipboard(RouteDiscoveryDiagnostics diag) {
    Clipboard.setData(ClipboardData(text: diag.toPlainText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Route discovery report copied to clipboard'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final textPrimary = isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted = isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;
    final borderColor = isDark ? AppPalette.darkOutline : AppPalette.lightOutline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Services Check'),
        actions: [
          if (_report != null)
            IconButton(
              icon: const Icon(Icons.copy_all_rounded),
              tooltip: 'Copy Report',
              onPressed: _copyReportToClipboard,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-run Check',
            onPressed: _isLoading ? null : _runCheck,
          ),
        ],
      ),
      body: _buildBody(theme, cardBg, textPrimary, textMuted, borderColor),
      bottomNavigationBar: _report != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.forestGreen,
                    foregroundColor: AppPalette.limeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _copyReportToClipboard,
                  icon: const Icon(Icons.content_copy_rounded, size: 20),
                  label: const Text(
                    'Copy Diagnostics Report',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(
    ThemeData theme,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
    Color borderColor,
  ) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Probing map endpoints & internet...',
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                'Check Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              const SizedBox(height: 6),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: textMuted)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _runCheck,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final report = _report;
    if (report == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Internet Connectivity Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: report.deviceOnline
                ? AppPalette.limeGreen.withValues(alpha: 0.15)
                : theme.colorScheme.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: report.deviceOnline ? AppPalette.limeGreen : theme.colorScheme.error,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                report.deviceOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: report.deviceOnline ? AppPalette.forestGreen : theme.colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.deviceOnline ? 'General Internet: Online' : 'General Internet: Offline',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      report.deviceOnline
                          ? 'Neutral internet endpoints are responding normally.'
                          : 'Device appears to have no network connection.',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pipeline stage counts & diagnostics ("Why no routes?")
        _buildDiscoverySection(
          context,
          theme,
          cardBg,
          textPrimary,
          textMuted,
          borderColor,
        ),
        const SizedBox(height: 16),

        Text(
          'Service Endpoints',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
        ),
        const SizedBox(height: 8),

        ...report.results.map((result) {
          final isOk = result.isReachable;
          final statusColor = isOk ? AppPalette.forestGreen : theme.colorScheme.error;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        result.serviceName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOk ? 'REACHABLE' : result.errorTypeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Host: ${result.host}',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Latency: ${result.latency.inMilliseconds} ms',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOk ? AppPalette.forestGreen : textMuted,
                      ),
                    ),
                    if (result.statusCode != null)
                      Text(
                        'HTTP ${result.statusCode}',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                  ],
                ),
                if (!isOk && result.details.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    result.details,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        _buildKnownParkSection(
          context,
          theme,
          cardBg,
          textPrimary,
          textMuted,
          borderColor,
        ),
      ],
    );
  }

  Widget _buildDiscoverySection(
    BuildContext context,
    ThemeData theme,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
    Color borderColor,
  ) {
    final diag = _getEffectiveDiscoveryDiagnostics(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Route Discovery Pipeline ("Why no routes?")',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (diag == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: textMuted, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No route discovery run recorded in this session. Open Maps to trigger discovery.',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pipeline Stage Breakdown',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (diag.emptyReason == EmptyReason.none
                                ? AppPalette.forestGreen
                                : (diag.isServiceFailure
                                    ? theme.colorScheme.error
                                    : textMuted))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        diag.emptyReason == EmptyReason.none
                            ? 'ROUTES FOUND (${diag.finalRouteCount})'
                            : (diag.isServiceFailure
                                ? 'FAILED (${diag.emptyReason.name})'
                                : 'EMPTY (${diag.emptyReason.name})'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: diag.emptyReason == EmptyReason.none
                              ? AppPalette.forestGreen
                              : (diag.isServiceFailure
                                  ? theme.colorScheme.error
                                  : textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildStageRow('1. Search Center', [
                  'Source: ${diag.searchCenterSource.name}',
                  'Non-fallback valid: ${diag.hasValidNonFallbackLocation}',
                  if (diag.roundedLat != null && diag.roundedLon != null)
                    'Approx coords: ${diag.roundedLat}, ${diag.roundedLon}',
                  'Search radius: ${diag.searchRadiusMeters.round()} m',
                ], textMuted, textPrimary),
                const Divider(height: 16),
                _buildStageRow('2. Overpass Query', [
                  'Status: ${diag.overpassStatus}',
                  'Elements found: ${diag.overpassElementCount}',
                  if (diag.overpassRemark != null && diag.overpassRemark!.isNotEmpty)
                    'Server Remark: "${diag.overpassRemark}"',
                ], textMuted, textPrimary),
                const Divider(height: 16),
                _buildStageRow('3. Nominatim Fallback', [
                  'Places found: ${diag.nominatimCount}',
                  if (diag.nominatimError != null)
                    'Error: "${diag.nominatimError}"',
                ], textMuted, textPrimary),
                const Divider(height: 16),
                _buildStageRow('4. Waypoint Routing (Valhalla)', [
                  'Candidates picked: ${diag.candidatesCount}',
                  'Routing attempts: ${diag.valhallaAttempts}',
                  'Successes: ${diag.valhallaSuccesses} | Nulls: ${diag.valhallaNulls} | Errors: ${diag.valhallaErrors}',
                ], textMuted, textPrimary),
                const Divider(height: 16),
                _buildStageRow('5. Filtering & Final Output', [
                  'Dropped (too short <300m): ${diag.droppedTooShort}',
                  'Dropped (too few points <5): ${diag.droppedTooFewPoints}',
                  'Dropped (duplicate): ${diag.droppedDuplicate}',
                  'Final routes returned: ${diag.finalRouteCount}',
                ], textMuted, textPrimary),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _copyDiscoveryReportToClipboard(diag),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Route Discovery Report'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStageRow(
    String title,
    List<String> details,
    Color textMuted,
    Color textPrimary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        ...details.map((d) => Padding(
              padding: const EdgeInsets.only(left: 6, top: 1),
              child: Text(
                '• $d',
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
            )),
      ],
    );
  }

  Widget _buildKnownParkSection(
    BuildContext context,
    ThemeData theme,
    Color cardBg,
    Color textPrimary,
    Color textMuted,
    Color borderColor,
  ) {
    final report = _knownParkReport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Known-Park Pipeline Test (Benchmark Fixtures)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Runs the full discovery pipeline at fixed test fixtures (Central Park, NY & Lodhi Garden, Delhi) to verify external service health without using your location.',
          style: TextStyle(fontSize: 12, color: textMuted),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Benchmark Fixture Verification',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  if (_isRunningKnownParkTest)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isRunningKnownParkTest) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Testing Overpass and Valhalla at benchmark locations...',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (report == null) ...[
                Text(
                  'Tap below to run the pipeline test against fixed benchmark parks.',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.forestGreen,
                    foregroundColor: AppPalette.limeGreen,
                  ),
                  onPressed: _runKnownParkTest,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Run Known-Park Test'),
                ),
              ] else ...[
                // Report summary banner
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (report.points.any((p) => p.isSuccess)
                            ? AppPalette.limeGreen
                            : theme.colorScheme.error)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: report.points.any((p) => p.isSuccess)
                          ? AppPalette.limeGreen
                          : theme.colorScheme.error,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        report.points.any((p) => p.isSuccess)
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        color: report.points.any((p) => p.isSuccess)
                            ? AppPalette.forestGreen
                            : theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.summary,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (report.distanceSearchCenterToGpsFormatted != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Search Center to Last GPS Fix: ${report.distanceSearchCenterToGpsFormatted}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
                  ),
                ],
                const Divider(height: 20),
                ...report.points.map((pt) {
                  final ok = pt.isSuccess;
                  final statusCol = ok ? AppPalette.forestGreen : theme.colorScheme.error;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? AppPalette.darkSurface
                          : AppPalette.lightSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                pt.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusCol.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ok ? '${pt.routes} ROUTES' : '0 ROUTES',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: statusCol,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coords: ${pt.coords.latitude.toStringAsFixed(4)}, ${pt.coords.longitude.toStringAsFixed(4)}'
                          '${pt.distanceFromGpsFormatted != null ? " (${pt.distanceFromGpsFormatted} from GPS)" : ""}',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                        if (pt.error != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Error: ${pt.error}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            'Places found: ${pt.placesFound} | Candidates: ${pt.candidates} | Valhalla successes: ${pt.valhallaSuccesses}',
                            style: TextStyle(fontSize: 11, color: textMuted),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _runKnownParkTest,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Re-run Known-Park Test'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class KnownParkTestPointResult {
  const KnownParkTestPointResult({
    required this.name,
    required this.coords,
    required this.placesFound,
    required this.candidates,
    required this.valhallaSuccesses,
    required this.routes,
    this.distanceFromGpsFormatted,
    this.error,
  });

  final String name;
  final LatLng coords;
  final int placesFound;
  final int candidates;
  final int valhallaSuccesses;
  final int routes;
  final String? distanceFromGpsFormatted;
  final String? error;

  bool get isSuccess => routes > 0;
}

class KnownParkPipelineReport {
  const KnownParkPipelineReport({
    required this.points,
    required this.summary,
    required this.distanceSearchCenterToGpsFormatted,
  });

  final List<KnownParkTestPointResult> points;
  final String summary;
  final String? distanceSearchCenterToGpsFormatted;

  String toPlainText() {
    final buf = StringBuffer();
    buf.writeln('=== Known-Park Pipeline Test ===');
    if (distanceSearchCenterToGpsFormatted != null) {
      buf.writeln('Distance (Search Center to GPS): $distanceSearchCenterToGpsFormatted');
    }
    buf.writeln('Summary: $summary');
    for (final p in points) {
      buf.writeln('');
      buf.writeln('• ${p.name} (${p.coords.latitude.toStringAsFixed(4)}, ${p.coords.longitude.toStringAsFixed(4)})');
      if (p.distanceFromGpsFormatted != null) {
        buf.writeln('  Distance from your GPS: ${p.distanceFromGpsFormatted}');
      }
      if (p.error != null) {
        buf.writeln('  Error: ${p.error}');
      } else {
        buf.writeln('  Places Found: ${p.placesFound} | Candidates: ${p.candidates}');
        buf.writeln('  Valhalla Successes: ${p.valhallaSuccesses} | Routes: ${p.routes}');
      }
    }
    buf.writeln('================================');
    return buf.toString();
  }
}

