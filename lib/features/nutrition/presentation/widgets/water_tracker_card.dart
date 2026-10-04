import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple daily water tracker in glasses.
class WaterTrackerCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const WaterTrackerCard({super.key});

  @override
  ConsumerState<WaterTrackerCard> createState() => _WaterTrackerCardState();
}

class _WaterTrackerCardState extends ConsumerState<WaterTrackerCard> {
  bool _isAnimating = false;
  int _queuedDelta = 0;
  int _lastGlasses = 0;

  Future<void> _handleTap(int delta, int current, int target) async {
    if (_isAnimating) {
      if (_queuedDelta == 0 || _queuedDelta.sign == delta.sign) {
        _queuedDelta = delta;
      }
      return;
    }
    await _applyDelta(delta, current, target);
  }

  Future<void> _applyDelta(int delta, int current, int target) async {
    if (delta == 0) return;
    final next = current + delta;
    if (next < 0 || next > target) return;

    if (mounted) setState(() => _isAnimating = true);
    if (delta > 0) HapticFeedback.lightImpact();

    try {
      await ref.read(waterProvider.notifier).change(delta);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
    
    await Future.delayed(Duration(milliseconds: delta > 0 ? 600 : 400));
    if (mounted) setState(() => _isAnimating = false);

    if (_queuedDelta != 0) {
      final toApply = _queuedDelta;
      _queuedDelta = 0;
      if (mounted) {
        final newCurrent = ref.read(waterProvider).valueOrNull ?? current;
        _applyDelta(toApply, newCurrent, target);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final target = ref.watch(waterTargetGlassesProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.2 : 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Water Tracker', style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AsyncValueView<int>(
              value: ref.watch(waterProvider),
              onRetry: () => ref.invalidate(waterProvider),
              loadingHeight: 80,
              builder: (glasses) {
                final isIncreasing = glasses > _lastGlasses;
                if (!reduceMotion && !_isAnimating && glasses != _lastGlasses) {
                  _lastGlasses = glasses;
                }
                
                final duration = reduceMotion ? Duration.zero : Duration(milliseconds: isIncreasing ? 600 : 400);
                final curve = Curves.easeOutCubic;
                final isComplete = glasses >= target;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: glasses.toDouble()),
                      duration: duration,
                      curve: curve,
                      builder: (context, val, _) {
                        final currentGlasses = val.round();
                        final currentLitres = (val * 250 / 1000).toStringAsFixed(2);
                        final targetLitres = (target * 250 / 1000).toStringAsFixed(2);
                        
                        return Semantics(
                          label: '$currentGlasses of $target glasses, $currentLitres litres',
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$currentGlasses',
                                      style: text.displayLarge?.copyWith(color: Colors.blue, fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      ' / $target',
                                      style: text.headlineMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text('glasses today', style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text('$currentLitres L of $targetLitres L', style: text.titleMedium?.copyWith(color: Colors.blue, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: <Widget>[
                        IconButton.filledTonal(
                          tooltip: 'Remove a glass',
                          onPressed: glasses > 0 ? () => _handleTap(-1, glasses, target) : null,
                          icon: const Icon(Icons.remove, size: 24),
                          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: glasses.toDouble()),
                            duration: duration,
                            curve: curve,
                            builder: (context, val, _) {
                              return ExcludeSemantics(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 12,
                                  children: List.generate(target, (i) {
                                    final cupFill = (val - i).clamp(0.0, 1.0);
                                    return RepaintBoundary(
                                      child: CustomPaint(
                                        size: const Size(20, 28),
                                        painter: _CupPainter(
                                          fill: cupFill,
                                          waterColor: Colors.blue,
                                          outlineColor: scheme.onSurface.withValues(alpha: 0.4),
                                          emptyColor: scheme.surfaceContainerHighest,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            }
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton.filled(
                          tooltip: 'Add a glass',
                          onPressed: glasses < target ? () => _handleTap(1, glasses, target) : null,
                          icon: const Icon(Icons.add, size: 24),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isComplete) ...[
                          const Icon(Icons.check_circle, color: Colors.blue, size: 16),
                          const SizedBox(width: 6),
                          Text('Goal reached! ', style: text.bodySmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                        Text(
                          'About 250 ml per glass. Stay hydrated!',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CupPainter extends CustomPainter {
  _CupPainter({
    required this.fill,
    required this.waterColor,
    required this.outlineColor,
    required this.emptyColor,
  });

  final double fill;
  final Color waterColor;
  final Color outlineColor;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // Cup path
    final path = Path();
    path.moveTo(w * 0.1, 0);
    path.lineTo(w * 0.25, h - 4); // taper in
    path.quadraticBezierTo(w * 0.5, h + 2, w * 0.75, h - 4);
    path.lineTo(w * 0.9, 0);

    // Empty background
    final trackPath = Path.from(path)..lineTo(w * 0.1, 0);
    final emptyPaint = Paint()..color = emptyColor..style = PaintingStyle.fill;
    canvas.drawPath(trackPath, emptyPaint);

    if (fill > 0.0) {
      canvas.save();
      canvas.clipPath(trackPath);
      
      final fillH = h * fill;
      final wavePath = Path();
      wavePath.moveTo(0, h);
      wavePath.lineTo(0, h - fillH);
      
      // Wave effect when animating
      if (fill > 0.01 && fill < 0.99) {
        final waveAmp = 2.0 * (1 - (2 * fill - 1).abs()); // peaks at 0.5
        wavePath.quadraticBezierTo(w * 0.25, h - fillH - waveAmp, w * 0.5, h - fillH);
        wavePath.quadraticBezierTo(w * 0.75, h - fillH + waveAmp, w, h - fillH);
      } else {
        wavePath.lineTo(w, h - fillH);
      }
      wavePath.lineTo(w, h);
      wavePath.close();

      canvas.drawPath(wavePath, Paint()..color = waterColor);
      canvas.restore();
    }

    // Outline
    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outlinePaint);
  }
  
  @override
  bool shouldRepaint(_CupPainter old) => old.fill != fill;
}
