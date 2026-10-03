/// Where the user stands in the XP level system.
class LevelInfo {
  /// Creates the info.
  const LevelInfo({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForLevel,
  });

  /// Current level, starting at 1.
  final int level;

  /// XP earned inside the current level.
  final int xpIntoLevel;

  /// XP needed to finish the current level.
  final int xpForLevel;

  /// Progress through the current level from 0.0 to 1.0.
  double get progress => xpForLevel == 0 ? 1 : xpIntoLevel / xpForLevel;

  /// XP still needed for the next level.
  int get xpToNext => xpForLevel - xpIntoLevel;
}

/// Pure Dart level curve: level 1 needs 100 XP, each next level 25 more.
abstract final class LevelLogic {
  /// XP needed for level 1.
  static const int baseXp = 100;

  /// Extra XP each later level needs.
  static const int increment = 25;

  /// XP needed to complete [level].
  static int xpForLevel(int level) => baseXp + (level - 1) * increment;

  /// Level and progress for a total of [xp] points.
  static LevelInfo levelFor(int xp) {
    var remaining = xp < 0 ? 0 : xp;
    var level = 1;
    while (remaining >= xpForLevel(level)) {
      remaining -= xpForLevel(level);
      level++;
    }
    return LevelInfo(
      level: level,
      xpIntoLevel: remaining,
      xpForLevel: xpForLevel(level),
    );
  }
}
