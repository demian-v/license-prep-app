import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:license_prep_app/providers/state_provider.dart';
import 'package:license_prep_app/services/service_locator.dart';
import 'package:license_prep_app/services/service_locator_extensions.dart';

/// Risk #41 — `ServiceLocatorExtensions.initialize()` used to do
/// `_stateProvider ??= StateProvider()`, building a SECOND provider beside the
/// one `main()` puts in the widget tree. That copy was never initialised from
/// preferences and no screen ever wrote to it, so it reported a null state
/// forever — and the ContentLoadingManager listened to it, so its state-change
/// reload could never fire.
///
/// The fix makes the state provider registered like the other two. That
/// registry is the part worth pinning here: `initialize()` itself cannot be
/// exercised in a unit test because building a ContentProvider drags in the
/// whole ServiceLocator (and therefore Firebase). The wiring is verified on the
/// simulator instead — see the commit message.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Risk #41 — the app\'s StateProvider is reachable, not duplicated', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ServiceLocatorExtensions.reset();
    });

    test('the registered instance comes back, not a copy', () {
      final appStateProvider = StateProvider();
      serviceLocator.registerStateProvider(appStateProvider);

      expect(identical(serviceLocator.$stateProvider, appStateProvider), isTrue);
    });

    test('a state chosen by the user is visible through the registry', () async {
      final appStateProvider = StateProvider();
      serviceLocator.registerStateProvider(appStateProvider);
      expect(serviceLocator.$stateProvider.selectedStateId, isNull);

      await appStateProvider.setSelectedState('IL');

      // The whole point: one object, so a write on one side is a read on the
      // other. A duplicate provider would still report null here.
      expect(serviceLocator.$stateProvider.selectedStateId, 'IL');
    });

    test('an unregistered provider throws instead of being faked', () {
      // Positive control in the other direction. Quietly substituting a fresh
      // StateProvider is exactly the bug, so absence has to be loud.
      expect(() => serviceLocator.$stateProvider, throwsA(isA<Exception>()));
    });

    test('registering does not disturb the other providers', () {
      // Guards against the new registry key colliding with the existing two.
      serviceLocator.registerStateProvider(StateProvider());

      expect(() => serviceLocator.$languageProvider, throwsA(isA<Exception>()));
      expect(() => serviceLocator.$contentProvider, throwsA(isA<Exception>()));
    });
  });
}
