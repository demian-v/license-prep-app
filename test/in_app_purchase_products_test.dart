import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/services/in_app_purchase_service.dart';

/// Risk #6 — `yearly` receipts were dropped client-side.
///
/// `_activeProductIds` contained only `monthly`, so a restored or auto-renewed
/// `yearly` transaction was completePurchase()-ed to clear StoreKit's queue and
/// never sent to the backend. If the SKU was purchasable anywhere, that user
/// paid and received nothing.
void main() {
  group('Risk #6 — product configuration', () {
    test('yearly is no longer offered for purchase', () {
      expect(InAppPurchaseService.productIds, isNot(contains('yearly')));
      expect(InAppPurchaseService.productIds, contains('monthly'));
    });

    test('every offered product can be validated by the backend', () {
      // The invariant that actually matters: we must never offer a product
      // whose receipt we would then silently discard.
      for (final id in InAppPurchaseService.productIds) {
        expect(
          InAppPurchaseService.validatableProductIds,
          contains(id),
          reason: 'Offering "$id" while dropping its receipts would charge a '
              'user and give them nothing.',
        );
      }
    });

    test('a legacy yearly receipt is still forwarded, not dropped', () {
      expect(InAppPurchaseService.validatableProductIds, contains('yearly'));
    });
  });
}
