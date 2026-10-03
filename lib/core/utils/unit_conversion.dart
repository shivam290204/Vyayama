/// Measurement system chosen by the user.
enum UnitSystem { metric, imperial }

/// Pure helpers for kg/lb and cm/ft+in conversions and display.
abstract final class UnitConversion {
  static const double _lbPerKg = 2.2046226218;

  static double kgToLb(double kg) => kg * _lbPerKg;
  static double lbToKg(double lb) => lb / _lbPerKg;

  static double feetInchesToCm(int feet, int inches) =>
      (feet * 12 + inches) * 2.54;

  static ({int feet, int inches}) cmToFeetInches(double cm) {
    final totalInches = (cm / 2.54).round();
    return (feet: totalInches ~/ 12, inches: totalInches % 12);
  }

  static String formatWeight(double kg, UnitSystem system) {
    return system == UnitSystem.metric
        ? '${_trim(kg)} kg'
        : '${_trim(kgToLb(kg))} lb';
  }

  static String formatHeight(double cm, UnitSystem system) {
    if (system == UnitSystem.metric) return '${cm.round()} cm';
    final ft = cmToFeetInches(cm);
    return "${ft.feet}' ${ft.inches}\"";
  }

  static String _trim(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
}
