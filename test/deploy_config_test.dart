import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A functions deploy uploads everything in `functions/` except what's listed:
/// without these, the Play receipt key and the local secrets go up with it.
void main() {
  test('a functions deploy leaves secrets and local files out', () {
    final config = jsonDecode(File('firebase.json').readAsStringSync()) as Map<String, dynamic>;
    final ignore = (config['functions'] as Map<String, dynamic>)['ignore'] as List<dynamic>;
    expect(ignore, containsAll(['node_modules', '*.local', 'service-account.json', '*.log', 'build']));
  });
}
