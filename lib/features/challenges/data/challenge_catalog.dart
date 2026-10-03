import 'dart:convert';

import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:flutter/services.dart';

/// Path of the bundled challenge list.
const String challengesAssetPath = 'assets/data/challenges.json';

/// Loads the bundled challenges (`{ "challenges": [ ... ] }`).
Future<List<Challenge>> loadChallengesFromAsset({AssetBundle? bundle}) async {
  final raw = await (bundle ?? rootBundle).loadString(challengesAssetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final list = (decoded['challenges'] as List<dynamic>?) ?? const <dynamic>[];
  return List<Challenge>.unmodifiable([
    for (final entry in list) Challenge.fromJson(entry as Map<String, dynamic>),
  ]);
}
