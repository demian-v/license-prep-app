import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/config/legal_links.dart';

/// The Terms and Privacy links point at driveusallc.com, from one constant:
/// the sign-up screen and the paywall used to open the old Google Sites pages
/// (moved 2026-10-29). App Review checks the paywall's links.
void main() {
  test('Terms and Privacy are the website pages', () {
    expect(LegalLinks.terms.toString(), 'https://driveusallc.com/terms/');
    expect(LegalLinks.privacy.toString(), 'https://driveusallc.com/privacy/');
  });

  final dartFiles = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  test('nothing in lib/ links the old Google Sites pages', () {
    for (final f in dartFiles) {
      expect(f.readAsStringSync().contains('sites.google.com'), isFalse, reason: f.path);
    }
  });

  test('legal URLs are written only in LegalLinks', () {
    for (final f in dartFiles.where((f) => !f.path.endsWith('legal_links.dart'))) {
      final src = f.readAsStringSync();
      expect(RegExp(r'driveusallc\.com/(terms|privacy)').hasMatch(src), isFalse, reason: f.path);
    }
  });
}
