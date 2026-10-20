import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every user-facing string lives in the Rust core. Hand-written Dart under
/// `lib/` may only use quotes in directives such as `import`.
void main() {
  test('app code has no string literals', () {
    final offenders = <String>[];
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.replaceAll('\\', '/').contains('lib/src/bindings/'));
    for (final file in sources) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first.trim();
        if (code.startsWith('import ') || code.startsWith('export ') || code.startsWith('part ')) {
          continue;
        }
        if (code.contains("'") || code.contains('"')) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
