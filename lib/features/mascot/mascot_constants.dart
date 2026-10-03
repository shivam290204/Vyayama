/// Asset paths and Rive names shared inside the mascot feature.
abstract final class MascotAssets {
  /// Final mascot animation file (made by an artist, may not exist yet).
  static const String rivePath = 'assets/rive/mascot.riv';

  /// Name of the Rive state machine.
  static const String stateMachine = 'MascotMachine';

  /// Name of the Rive number input that selects the mood.
  static const String moodInput = 'mood';

  /// Message templates per mood.
  static const String messagesPath = 'assets/data/mascot_messages.json';
}
