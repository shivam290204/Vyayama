import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/profile/profile_validators.dart';

/// Weight and height inputs with a metric/imperial toggle.
/// When [unit] changes, the fields reset to the texts passed in, so the
/// parent is responsible for converting values before switching.
class MeasurementFields extends StatefulWidget {
  const MeasurementFields({
    super.key,
    required this.unit,
    required this.weightText,
    required this.cmText,
    required this.ftText,
    required this.inText,
    required this.onUnitChanged,
    required this.onWeightChanged,
    required this.onCmChanged,
    required this.onFtChanged,
    required this.onInChanged,
  });

  final UnitSystem unit;
  final String weightText;
  final String cmText;
  final String ftText;
  final String inText;
  final ValueChanged<UnitSystem> onUnitChanged;
  final ValueChanged<String> onWeightChanged;
  final ValueChanged<String> onCmChanged;
  final ValueChanged<String> onFtChanged;
  final ValueChanged<String> onInChanged;

  @override
  State<MeasurementFields> createState() => _MeasurementFieldsState();
}

class _MeasurementFieldsState extends State<MeasurementFields> {
  late final TextEditingController _weight;
  late final TextEditingController _cm;
  late final TextEditingController _ft;
  late final TextEditingController _inch;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: widget.weightText);
    _cm = TextEditingController(text: widget.cmText);
    _ft = TextEditingController(text: widget.ftText);
    _inch = TextEditingController(text: widget.inText);
  }

  @override
  void didUpdateWidget(MeasurementFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unit != widget.unit) {
      _weight.text = widget.weightText;
      _cm.text = widget.cmText;
      _ft.text = widget.ftText;
      _inch.text = widget.inText;
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _cm.dispose();
    _ft.dispose();
    _inch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metric = widget.unit == UnitSystem.metric;
    final decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<UnitSystem>(
          segments: const [
            ButtonSegment(value: UnitSystem.metric, label: Text('kg / cm')),
            ButtonSegment(value: UnitSystem.imperial, label: Text('lb / ft')),
          ],
          selected: {widget.unit},
          onSelectionChanged: (selection) =>
              widget.onUnitChanged(selection.first),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextFormField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          inputFormatters: [decimal],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) => ProfileValidators.weight(value, widget.unit),
          onChanged: widget.onWeightChanged,
          decoration: InputDecoration(
            labelText: 'Weight',
            suffixText: metric ? 'kg' : 'lb',
            prefixIcon: const Icon(Icons.monitor_weight_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (metric)
          TextFormField(
            controller: _cm,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [decimal],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: ProfileValidators.heightCmField,
            onChanged: widget.onCmChanged,
            decoration: const InputDecoration(
              labelText: 'Height',
              suffixText: 'cm',
              prefixIcon: Icon(Icons.height_rounded),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ft,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: ProfileValidators.feetField,
                  onChanged: widget.onFtChanged,
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    suffixText: 'ft',
                    prefixIcon: Icon(Icons.height_rounded),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _inch,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: ProfileValidators.inchesField,
                  onChanged: widget.onInChanged,
                  decoration: const InputDecoration(
                    labelText: 'Inches',
                    suffixText: 'in',
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Only used to estimate calories. You can change this any time.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
