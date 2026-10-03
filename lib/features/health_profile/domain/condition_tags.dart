import 'package:fitbuddy/features/health_profile/data/condition_rule.dart';

/// Combines the avoid-tags of every selected condition into one sorted,
/// duplicate-free list.
List<String> combineConditionTags(
  List<ConditionRule> rules,
  List<String> selectedKeys,
) {
  final tags = <String>{};
  for (final rule in rules) {
    if (selectedKeys.contains(rule.key)) {
      tags.addAll(rule.avoidExerciseTags);
    }
  }
  final sorted = tags.toList()..sort();
  return List<String>.unmodifiable(sorted);
}

/// Toggles [key] in [current]. Choosing "none" clears everything else, and
/// choosing any real condition removes "none".
List<String> toggleCondition(List<String> current, String key) {
  if (key == 'none') {
    return current.contains('none') ? <String>[] : <String>['none'];
  }
  final next = current.where((k) => k != 'none').toList();
  if (next.contains(key)) {
    next.remove(key);
  } else {
    next.add(key);
  }
  return next;
}
