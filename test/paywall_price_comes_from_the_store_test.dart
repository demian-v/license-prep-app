import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// The paywall must show the price the store will actually charge.
///
/// **Demonstrated on a real iPhone, 2026-09-19**, by accident. The same build
/// and the same product, through two Apple accounts on different storefronts:
///
/// ```
///   Apple's sheet, account A ... 11,99 US$ per month
///   Apple's sheet, account B ... $9.99 per month
///   the app's paywall, both ... $9.99/month
/// ```
///
/// The paywall passed the string literal `"9.99"` and the card rendered
/// `'\$${widget.price}'` — so both the amount and the currency symbol were
/// hardcoded in Dart source. `queryProductDetails` already fetches
/// `ProductDetails.price`, a **fully formatted, localized** string from
/// StoreKit or Play, and it was being ignored.
///
/// This is not a US overcharge — on a US storefront the two agree. It is a
/// misquote for every customer outside it, and a hardcoded `$` cannot express
/// another currency at all.
///
/// Same principle the rest of this branch already applies: the server is
/// authoritative for entitlement (#48), Apple is authoritative for the receipt
/// (#56), and **the store is authoritative for the price**. Firestore's
/// catalogue keeps plan metadata — name, features, ordering — not money.
void main() {
  String codeOf(String path) => File(path)
      .readAsStringSync()
      .split('\n')
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');

  final screen = codeOf('lib/screens/subscription_screen.dart');
  final card = codeOf('lib/widgets/enhanced_subscription_card.dart');

  group('the amount', () {
    test('is not a literal in the paywall', () {
      expect(
        screen,
        isNot(matches(RegExp(r'''price:\s*["']\d'''))),
        reason: 'A literal price cannot be right on more than one storefront.',
      );
    });

    test('comes from the store product', () {
      expect(
        screen,
        contains('getProduct('),
        reason: 'ProductDetails.price is already fetched by '
            'queryProductDetails; it is the only price that is true.',
      );
    });
  });

  group('the currency', () {
    test('is not a hardcoded dollar sign in the card', () {
      // ProductDetails.price arrives already formatted for the storefront —
      // "$9.99", "11,99 US$", "£7.99". Prefixing our own symbol corrupts it.
      expect(
        card,
        isNot(contains(r"'\$${widget.price}'")),
        reason: 'The store string already carries its own currency.',
      );
    });

    test('the card still renders the price it is given', () {
      expect(card, contains(r'${widget.price}'));
    });
  });
}
