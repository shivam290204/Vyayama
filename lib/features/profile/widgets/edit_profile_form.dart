import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/auth/widgets/button_spinner.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/measurement_converter.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/profile/profile_validators.dart';
import 'package:fitbuddy/features/profile/widgets/choice_field.dart';
import 'package:fitbuddy/features/profile/widgets/measurement_fields.dart';
import 'package:fitbuddy/features/settings/providers.dart';

/// Form for editing the basic profile fields.
class EditProfileForm extends ConsumerStatefulWidget {
  const EditProfileForm({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  String? _gender;
  String? _goal;
  late String _level;
  String _weight = '';
  String _cm = '';
  String _ft = '';
  String _inch = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    final unit = ref.read(unitSystemProvider);
    _name = TextEditingController(text: p.name ?? '');
    _age = TextEditingController(text: p.age?.toString() ?? '');
    _gender = p.gender;
    _goal = p.goal;
    _level = p.fitnessLevel;
    if (p.weightKg != null) {
      _weight = ProfileValidators.weightText(p.weightKg!, unit);
    }
    if (p.heightCm != null) {
      final h = ProfileValidators.heightTexts(p.heightCm!, unit);
      _cm = h.cm;
      _ft = h.ft;
      _inch = h.inch;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  bool get _isMinor {
    final age = int.tryParse(_age.text.trim());
    return age != null && age < 18;
  }

  void _onAgeChanged(String _) {
    setState(() {
      // Weight-loss goals are not offered to under-18s.
      if (_isMinor && _goal == 'lose') _goal = null;
    });
  }

  void _changeUnit(UnitSystem to) {
    final from = ref.read(unitSystemProvider);
    if (from == to) return;
    final c = convertMeasurementTexts(
      from: from,
      to: to,
      weight: _weight,
      cm: _cm,
      ft: _ft,
      inch: _inch,
    );
    setState(() {
      _weight = c.weight;
      _cm = c.cm;
      _ft = c.ft;
      _inch = c.inch;
    });
    ref.read(unitSystemProvider.notifier).setSystem(to);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final unit = ref.read(unitSystemProvider);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_gender == null || _goal == null) {
      _toast('Please choose your gender and goal.');
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = widget.profile.copyWith(
        name: _name.text.trim(),
        age: int.parse(_age.text.trim()),
        gender: _gender,
        weightKg: ProfileValidators.weightKg(_weight, unit),
        heightCm: ProfileValidators.heightCm(
          unit: unit,
          cm: _cm,
          ft: _ft,
          inch: _inch,
        ),
        goal: _goal,
        fitnessLevel: _level,
      );
      await ref.read(currentProfileProvider.notifier).save(updated);
      if (!mounted) return;
      _toast('Profile saved');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.profile);
      }
    } catch (_) {
      _toast("We couldn't save your profile. Please try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(unitSystemProvider);
    const gap = SizedBox(height: AppSpacing.xl);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: ProfileValidators.name,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _age,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: ProfileValidators.age,
            onChanged: _onAgeChanged,
            decoration: const InputDecoration(
              labelText: 'Age',
              suffixText: 'years',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
          ),
          gap,
          ChoiceField(
            label: 'Gender',
            value: _gender,
            options: const {'male': 'Male', 'female': 'Female', 'other': 'Other'},
            onChanged: (v) => setState(() => _gender = v),
          ),
          gap,
          MeasurementFields(
            unit: unit,
            weightText: _weight,
            cmText: _cm,
            ftText: _ft,
            inText: _inch,
            onUnitChanged: _changeUnit,
            onWeightChanged: (v) => _weight = v,
            onCmChanged: (v) => _cm = v,
            onFtChanged: (v) => _ft = v,
            onInChanged: (v) => _inch = v,
          ),
          gap,
          ChoiceField(
            label: 'Goal',
            value: _goal,
            options: {
              if (!_isMinor) 'lose': 'Lose',
              'gain': 'Gain',
              'maintain': 'Stay fit',
            },
            onChanged: (v) => setState(() => _goal = v),
          ),
          gap,
          ChoiceField(
            label: 'Fitness level',
            value: _level,
            options: const {
              'beginner': 'Beginner',
              'intermediate': 'Intermediate',
            },
            onChanged: (v) => setState(() => _level = v),
          ),
          gap,
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const ButtonSpinner() : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
