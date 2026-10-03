/// Human-friendly labels for stored profile values.
abstract final class ProfileLabels {
  static String goal(String? value) => switch (value) {
        'lose' => 'Lose weight',
        'gain' => 'Gain weight',
        'maintain' => 'Stay fit',
        _ => 'Not set',
      };

  static String gender(String? value) => switch (value) {
        'male' => 'Male',
        'female' => 'Female',
        'other' => 'Other',
        _ => 'Not set',
      };

  static String level(String value) => switch (value) {
        'intermediate' => 'Intermediate',
        _ => 'Beginner',
      };
}
