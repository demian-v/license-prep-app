import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// A purchase timer must never tell a paying customer their purchase failed.
///
/// **Observed on a real iPhone, 2026-09-19**, against a real sandbox purchase:
///
/// ```
/// 🛒 Initiating purchase for: monthly
/// ⏱️ Purchase timed out — clearing pending state     <- Apple's sheet still open
/// ❌ Purchase error: Purchase timed out. Please try again.
/// ...
/// 📱 Purchase update: monthly - PurchaseStatus.purchased
/// ✅ Receipt validated successfully
/// ```
///
/// A 60-second `Timer` started at `purchaseProduct()` fired while the user was
/// still entering their App Store password. The purchase then succeeded, the
/// server wrote `monthly / active`, and the customer had been told it failed
/// and to try again — which invites a second purchase.
///
/// **Why no fixed deadline is correct.** The App Store sheet is open-ended by
/// design: password entry, a 2FA prompt, Apple's "Terms and Conditions have
/// changed" interstitial, a Face ID retry, a slow sandbox. With Family Sharing
/// **Ask to Buy** a purchase stays pending for *days* awaiting a parent's
/// approval. The purchase STREAM is the source of truth; a timer cannot be.
///
/// The safety net itself is legitimate and is kept — it exists because an old
/// renewal event can steal `_purchasePending` and strand the UI in a loading
/// state. What it must not do is assert failure.
///
/// Asserted on the source, because `InAppPurchaseService` builds
/// `InAppPurchase.instance` in a field initialiser and cannot be driven from a
/// unit test without a refactor of the money path.
void main() {
  final raw = File('lib/services/in_app_purchase_service.dart').readAsStringSync();

  /// Comments are stripped before matching. Twice in this project a guard test
  /// has passed or failed on its own explanatory prose; the rule now is that
  /// assertions only ever see code.
  final code = raw
      .split('\n')
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');

  group('the safety-net timer', () {
    test('does not tell the user the purchase failed', () {
      expect(
        code,
        isNot(contains('Purchase timed out. Please try again.')),
        reason: 'This exact string was shown over a purchase that succeeded.',
      );
    });

    test('does not invite a retry of a purchase that may have succeeded', () {
      // "Try again" on the money path is the specific harm: the customer has
      // possibly already been charged.
      final timerBlock = _safetyNetBlock(code);
      expect(timerBlock, isNotNull,
          reason: 'could not find the purchase-pending Timer');
      expect(
        timerBlock!.toLowerCase(),
        isNot(contains('try again')),
      );
    });

    test('does not call onPurchaseError at all', () {
      final timerBlock = _safetyNetBlock(code)!;
      expect(
        timerBlock,
        isNot(contains('onPurchaseError')),
        reason: 'Clearing a stuck loading state is fine. Reporting a failure '
            'for a purchase whose outcome is unknown is not.',
      );
    });

    test('still clears the pending state, so the UI cannot strand', () {
      final timerBlock = _safetyNetBlock(code)!;
      expect(timerBlock, contains('_clearPurchasePending()'));
    });
  });

  group('StoreKit telling us it is in flight', () {
    test('PurchaseStatus.pending cancels the safety net', () {
      // Ask to Buy lives here: StoreKit says "pending" and the answer may be
      // days away. A timer must not outlive that.
      final pendingCase = _caseBody(code, 'PurchaseStatus.pending');
      expect(pendingCase, isNotNull,
          reason: 'PurchaseStatus.pending case not found');
      expect(
        pendingCase!,
        contains('_purchasePendingTimeoutTimer?.cancel()'),
        reason: 'A purchase Apple has confirmed is in flight must not be '
            'timed out by us.',
      );
    });
  });
}

/// The body of the `Timer(...)` started when a purchase begins.
String? _safetyNetBlock(String code) {
  final start = code.indexOf('_purchasePendingTimeoutTimer = Timer(');
  if (start < 0) return null;
  // Read to the end of the callback: the first '});' after the opening.
  final end = code.indexOf('});', start);
  if (end < 0) return null;
  return code.substring(start, end + 3);
}

/// The body of one `case X:` in the purchase-update switch.
String? _caseBody(String code, String label) {
  final start = code.indexOf('case $label:');
  if (start < 0) return null;
  final next = code.indexOf('case PurchaseStatus.', start + 1);
  return code.substring(start, next < 0 ? code.length : next);
}
