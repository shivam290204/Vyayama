import 'dart:math' as math;

import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/date_labels.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// What the bar chart shows.
enum ChartMetric {
  /// Steps per day.
  steps('Steps', 'steps'),

  /// Active calories per day.
  calories('Calories', 'kcal'),

  /// Active minutes per day.
  activeMinutes('Active time', 'min');

  const ChartMetric(this.label, this.unit);

  /// Button label.
  final String label;

  /// Unit shown after numbers.
  final String unit;

  /// The value of this metric for [s].
  int valueOf(DailyStats s) => switch (this) {
        ChartMetric.steps => s.steps,
        ChartMetric.calories => s.calories,
        ChartMetric.activeMinutes => s.activeMinutes,
      };

  /// The daily target for this metric.
  int targetOf(DailyTargets t) => switch (this) {
        ChartMetric.steps => t.steps,
        ChartMetric.calories => t.activeCalories,
        ChartMetric.activeMinutes => t.activeMinutes,
      };
}

/// A 7-day bar chart drawn with [CustomPaint] (no chart package).
///
/// Tap a day to see its value. Each day is a labelled button for screen
/// readers.
class WeekBarChart extends StatefulWidget {
  /// Creates the chart for [days] (oldest first).
  const WeekBarChart({
    super.key,
    required this.days,
    required this.metric,
    required this.target,
  });

  /// Days to show, oldest first.
  final List<DailyStats> days;

  /// Metric to plot.
  final ChartMetric metric;

  /// Daily target, drawn as a dashed line.
  final int target;

  @override
  State<WeekBarChart> createState() => _WeekBarChartState();
}

class _WeekBarChartState extends State<WeekBarChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final metric = widget.metric;
    final selected = (_selected ?? days.length - 1).clamp(0, days.length - 1);
    final values = [for (final d in days) metric.valueOf(d).toDouble()];
    final labelStyle = (text.labelSmall ?? const TextStyle(fontSize: 11))
        .copyWith(color: scheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatShortDate(days[selected].date)} · '
          '${formatInt(metric.valueOf(days[selected]))} ${metric.unit}',
          style: text.titleMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: WeekBarChartPainter(
                      values: values,
                      labels: [for (final d in days) shortWeekday(d.date)],
                      selected: selected,
                      target: widget.target > 0 ? widget.target.toDouble() : null,
                      barColor: scheme.primary.withAlpha(110),
                      selectedColor: scheme.primary,
                      gridColor: scheme.outlineVariant,
                      targetColor: scheme.tertiary,
                      labelStyle: labelStyle,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == selected,
                          label: '${formatShortDate(days[i].date)}: '
                              '${formatInt(metric.valueOf(days[i]))} '
                              '${metric.unit}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _selected = i),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(width: 16, height: 2, color: scheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Daily target: ${formatInt(widget.target)} ${metric.unit}',
                style: text.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Paints the bars, baseline, dashed target line and day labels.
class WeekBarChartPainter extends CustomPainter {
  /// Creates the painter.
  const WeekBarChartPainter({
    required this.values,
    required this.labels,
    required this.selected,
    required this.target,
    required this.barColor,
    required this.selectedColor,
    required this.gridColor,
    required this.targetColor,
    required this.labelStyle,
  });

  /// One value per bar.
  final List<double> values;

  /// One label per bar.
  final List<String> labels;

  /// Index of the highlighted bar.
  final int selected;

  /// Target line value, or null for none.
  final double? target;

  /// Colour of normal bars.
  final Color barColor;

  /// Colour of the highlighted bar.
  final Color selectedColor;

  /// Baseline colour.
  final Color gridColor;

  /// Target line colour.
  final Color targetColor;

  /// Style of the day labels.
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 22.0;
    const topPadding = 8.0;
    final chartHeight = size.height - labelHeight - topPadding;
    if (chartHeight <= 0 || values.isEmpty) return;

    final targetValue = target;
    var maxValue = targetValue ?? 0;
    for (final v in values) {
      maxValue = math.max(maxValue, v);
    }
    if (maxValue <= 0) maxValue = 1;
    maxValue *= 1.1;

    final slot = size.width / values.length;
    final barWidth = math.min(slot * 0.55, 28.0);
    final baseY = topPadding + chartHeight;

    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    if (targetValue != null && targetValue > 0) {
      final y = baseY - targetValue / maxValue * chartHeight;
      final paint = Paint()
        ..color = targetColor
        ..strokeWidth = 1.5;
      for (var x = 0.0; x < size.width; x += 10) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 6, size.width), y),
          paint,
        );
      }
    }

    for (var i = 0; i < values.length; i++) {
      final cx = slot * i + slot / 2;
      final height =
          math.max(values[i] / maxValue * chartHeight, values[i] > 0 ? 3.0 : 0.0);
      if (height > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barWidth / 2, baseY - height, barWidth, height),
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6),
          ),
          Paint()..color = i == selected ? selectedColor : barColor,
        );
      }
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: i == selected
              ? labelStyle.copyWith(fontWeight: FontWeight.w700)
              : labelStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: slot);
      painter.paint(canvas, Offset(cx - painter.width / 2, baseY + 4));
    }
  }

  @override
  bool shouldRepaint(covariant WeekBarChartPainter old) =>
      !listEquals(old.values, values) ||
      !listEquals(old.labels, labels) ||
      old.selected != selected ||
      old.target != target ||
      old.barColor != barColor ||
      old.selectedColor != selectedColor ||
      old.gridColor != gridColor ||
      old.targetColor != targetColor ||
      old.labelStyle != labelStyle;
}
