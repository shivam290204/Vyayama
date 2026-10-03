import 'package:fitbuddy/core/utils/unit_conversion.dart';

/// Pure validators and text formatters for profile and onboarding forms.
abstract final class ProfileValidators {
  static const int minAge = 13;
  static const int maxAge = 100;
  static const double minWeightKg = 30;
  static const double maxWeightKg = 300;
  static const double minHeightCm = 100;
  static const double maxHeightCm = 250;

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please tell us your name.';
    if (text.length > 50) return 'That name is a little too long.';
    return null;
  }

  static String? age(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your age.';
    final age = int.tryParse(text);
    if (age == null) return 'Use whole numbers only.';
    if (age < minAge || age > maxAge) {
      return 'Age must be between $minAge and $maxAge.';
    }
    return null;
  }

  static double? parseNumber(String? value) {
    final text = value?.trim().replaceAll(',', '.') ?? '';
    return text.isEmpty ? null : double.tryParse(text);
  }

  /// Weight in kg from text in [unit]; null if not a number (no range check).
  static double? weightKg(String? value, UnitSystem unit) {
    final number = parseNumber(value);
    if (number == null) return null;
    return unit == UnitSystem.metric ? number : UnitConversion.lbToKg(number);
  }

  static String? weight(String? value, UnitSystem unit) {
    if ((value?.trim() ?? '').isEmpty) return 'Enter your weight.';
    final kg = weightKg(value, unit);
    if (kg == null) return 'Enter a number.';
    if (kg < minWeightKg || kg > maxWeightKg) {
      final metric = unit == UnitSystem.metric;
      final low = metric ? minWeightKg : UnitConversion.kgToLb(minWeightKg);
      final high = metric ? maxWeightKg : UnitConversion.kgToLb(maxWeightKg);
      return 'Enter a weight between ${low.round()} and ${high.round()} '
          '${metric ? 'kg' : 'lb'}.';
    }
    return null;
  }

  static String? heightCmField(String? value) {
    if ((value?.trim() ?? '').isEmpty) return 'Enter your height.';
    final cm = parseNumber(value);
    if (cm == null) return 'Enter a number.';
    if (cm < minHeightCm || cm > maxHeightCm) {
      return 'Enter a height between ${minHeightCm.round()} and '
          '${maxHeightCm.round()} cm.';
    }
    return null;
  }

  static String? feetField(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter feet.';
    final feet = int.tryParse(text);
    if (feet == null) return 'Whole numbers only.';
    if (feet < 3 || feet > 8) return 'Use 3 to 8.';
    return null;
  }

  /// Inches are optional (blank means 0).
  static String? inchesField(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final inches = int.tryParse(text);
    if (inches == null) return 'Whole numbers only.';
    if (inches < 0 || inches > 11) return 'Use 0 to 11.';
    return null;
  }

  /// Height in cm from the fields of [unit]; null if incomplete.
  static double? heightCm({
    required UnitSystem unit,
    String? cm,
    String? ft,
    String? inch,
  }) {
    if (unit == UnitSystem.metric) return parseNumber(cm);
    final feet = int.tryParse(ft?.trim() ?? '');
    if (feet == null) return null;
    final inchText = inch?.trim() ?? '';
    final inches = inchText.isEmpty ? 0 : int.tryParse(inchText);
    if (inches == null) return null;
    return UnitConversion.feetInchesToCm(feet, inches);
  }

  /// Combined height validation (first error wins).
  static String? height({
    required UnitSystem unit,
    String? cm,
    String? ft,
    String? inch,
  }) {
    if (unit == UnitSystem.metric) return heightCmField(cm);
    final fieldError = feetField(ft) ?? inchesField(inch);
    if (fieldError != null) return fieldError;
    final total = heightCm(unit: unit, ft: ft, inch: inch)!;
    if (total < minHeightCm || total > maxHeightCm) {
      return 'Please check your height.';
    }
    return null;
  }

  static String weightText(double kg, UnitSystem unit) {
    final value = unit == UnitSystem.metric ? kg : UnitConversion.kgToLb(kg);
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  static ({String cm, String ft, String inch}) heightTexts(
    double cm,
    UnitSystem unit,
  ) {
    if (unit == UnitSystem.metric) {
      return (cm: cm.round().toString(), ft: '', inch: '');
    }
    final parts = UnitConversion.cmToFeetInches(cm);
    return (cm: '', ft: parts.feet.toString(), inch: parts.inches.toString());
  }
}
