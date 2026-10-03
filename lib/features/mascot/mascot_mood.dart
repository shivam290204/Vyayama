/// Moods the mascot can show.
///
/// The declaration order matches the Rive `mood` number input
/// (neutral 0, happy 1, proud 2, sad 3, angry 4, sleepy 5,
/// celebrating 6, worried 7).
enum MascotMood {
  neutral,
  happy,
  proud,
  sad,
  angry,
  sleepy,
  celebrating,
  worried,
}

/// Helpers for [MascotMood].
extension MascotMoodX on MascotMood {
  /// Value written to the Rive state machine input called `mood`.
  double get riveValue => switch (this) {
        MascotMood.neutral => 0,
        MascotMood.happy => 1,
        MascotMood.proud => 2,
        MascotMood.sad => 3,
        MascotMood.angry => 4,
        MascotMood.sleepy => 5,
        MascotMood.celebrating => 6,
        MascotMood.worried => 7,
      };

  /// Plain-language label used for screen readers and debug UI.
  String get label => name;
}
