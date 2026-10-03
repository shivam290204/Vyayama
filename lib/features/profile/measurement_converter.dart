import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/profile/profile_validators.dart';

/// Converts typed weight/height texts when the user switches unit system.
/// Anything that cannot be parsed becomes an empty string.
({String weight, String cm, String ft, String inch}) convertMeasurementTexts({
  required UnitSystem from,
  required UnitSystem to,
  required String weight,
  required String cm,
  required String ft,
  required String inch,
}) {
  final kg = ProfileValidators.weightKg(weight, from);
  final heightCm = ProfileValidators.heightCm(
    unit: from,
    cm: cm,
    ft: ft,
    inch: inch,
  );
  final height = heightCm == null
      ? null
      : ProfileValidators.heightTexts(heightCm, to);

  return (
    weight: kg == null ? '' : ProfileValidators.weightText(kg, to),
    cm: height?.cm ?? '',
    ft: height?.ft ?? '',
    inch: height?.inch ?? '',
  );
}
