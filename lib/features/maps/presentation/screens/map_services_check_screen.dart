import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/data/services/map_diagnostics_service.dart';
import 'package:fitbuddy/features/maps/domain/models/route_discovery_result.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void _copyReportToClipboard() {
    final report = _report;
    final diag = _getEffectiveDiscoveryDiagnostics(context);
    final buf = StringBuffer();
    if (report != null) {
      buf.writeln(report.toPlainText());
    }
    if (diag != null) {
      if (buf.isNotEmpty) buf.writeln('\n');
      buf.writeln(diag.toPlainText());
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
}

