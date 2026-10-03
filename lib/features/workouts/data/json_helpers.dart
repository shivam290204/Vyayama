/// Reads a JSON value as a list of strings (empty when missing).
List<String> jsonStringList(Object? value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList(growable: false);
  }
  return const <String>[];
}

/// Reads instruction steps from either a list or a newline-separated string
/// (the `exercises.instructions` column is plain text in Postgres).
List<String> jsonSteps(Object? value) {
  if (value is String) {
    return value
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
  return jsonStringList(value);
}
