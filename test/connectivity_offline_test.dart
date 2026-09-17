import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:license_prep_app/providers/content_provider.dart';

void main() {
  group('Risk #38 — offline detection', () {
    test('the old comparison was always false, which is the whole bug', () {
      // connectivity_plus 7 returns a LIST of active transports. The provider
      // compared that list directly against a single enum value, so the
      // expression could never be true no matter what the device reported.
      // Pinned here so nobody reintroduces `== ConnectivityResult.none`.
      // ignore: unrelated_type_equality_checks
      expect(<ConnectivityResult>[ConnectivityResult.none] == ConnectivityResult.none,
          isFalse);
    });

    test('no transports at all reads as offline', () {
      expect(isOfflineFromConnectivity(const []), isTrue);
    });

    test('an explicit "none" reads as offline', () {
      expect(isOfflineFromConnectivity(const [ConnectivityResult.none]), isTrue);
    });

    test('wifi reads as online (positive control)', () {
      expect(isOfflineFromConnectivity(const [ConnectivityResult.wifi]), isFalse);
    });

    test('mobile data reads as online (positive control)', () {
      expect(isOfflineFromConnectivity(const [ConnectivityResult.mobile]), isFalse);
    });

    test('a real transport alongside "none" is still online', () {
      // The plugin reports every interface. A device can list `none` for one
      // stack while another is genuinely connected; treating that as offline
      // would be a new bug in the opposite direction.
      expect(
        isOfflineFromConnectivity(
          const [ConnectivityResult.none, ConnectivityResult.wifi],
        ),
        isFalse,
      );
    });
  });
}
