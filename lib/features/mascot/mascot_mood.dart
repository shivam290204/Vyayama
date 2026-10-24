/// Moods the mascot can show.
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
  /// Plain-language label used for screen readers and debug UI.
  String get label => name;
}
