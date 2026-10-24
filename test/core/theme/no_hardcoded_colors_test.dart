import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no hardcoded Color(0x...) appears outside lib/core/theme', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final hardcodedColorPattern = RegExp(r'Color\s*\(\s*0x[0-9a-fA-F]+\s*\)');
    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final normalizedPath = entity.path.replaceAll('\\', '/');
      if (normalizedPath.contains('lib/core/theme/')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (hardcodedColorPattern.hasMatch(line)) {
          violations.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Hardcoded Color(0x...) values found outside lib/core/theme/:\n'
          '${violations.join('\n')}\n'
          'Use Theme.of(context).colorScheme, context.colors (AppColorsExtension), '
          'or define brand tokens centrally in lib/core/theme/.',
    );
  });
}
