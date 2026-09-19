import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Concurrent renewal receipts must be serialised, not discarded.
///
/// **Observed on a real iPhone, 2026-09-19.** After ~45 minutes of sandbox
/// auto-renewal (a sandbox month is ~5 minutes), StoreKit delivered 11
/// `purchased` events on launch. One was validated; the rest were dropped:
///
/// ```
/// ⚠️ Validation already in progress — skipping concurrent receipt for monthly/2000001238843179
/// ⚠️ ...                                                              /2000001238842454
/// ⚠️ ...                                                              /2000001238841511
/// ⚠️ ...                                                              /2000001238840596
/// ⚠️ ...                                                              /2000001238839466
/// ```
///
/// Five **distinct** transaction ids — separate billing cycles, not
/// redeliveries. The stored `nextBillingDate` sat at 19:29:47Z while Apple had
/// already billed past it, and the paywall read "Next Billing: 9/19/2026".
///
/// **The guard is not wrong, and this does not remove it.** Its call site in
/// `SubscriptionProvider.checkAndAutoRestoreIfNeeded` explains why it exists:
/// repeated restores make StoreKit deliver every pending receipt at once, and
/// "Firebase gets 10+ concurrent validation calls → rate limit exceeded".
/// Serialising keeps that protection. Dropping was the part that cost money.
///
/// It was also self-healing — the skipped receipts are never completed, so
/// StoreKit redelivers them and the backlog drains (measured: the billing date
/// recovered from 2 minutes behind to 5.5 minutes ahead within one session).
/// What remains is the lag, and the risk that renewals arriving faster than
/// they drain leave a paid-up customer looking expired.
void main() {
  final code = File('lib/services/in_app_purchase_service.dart')
      .readAsStringSync()
      .split('\n')
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');

  group('a receipt that arrives during a validation', () {
    test('is queued rather than discarded', () {
      final guard = code.indexOf('if (!isUserInitiated && _isValidating)');
      expect(guard, greaterThan(-1), reason: 'concurrency guard not found');
      final block = code.substring(guard, guard + 700);
      expect(
        block,
        contains('_validationQueue'),
        reason: 'A distinct renewal dropped here is money Apple has already '
            'taken and the server never records.',
      );
    });

    test('there is a queue to hold it', () {
      expect(code, contains('_validationQueue'));
    });
  });

  group('the queue drains', () {
    test('a settled validation processes the next receipt', () {
      expect(
        code,
        contains('_onValidationSettled'),
        reason: 'Queueing without draining is just a slower way to lose them.',
      );
    });

    test('draining is still one at a time', () {
      // The whole reason the guard exists: a burst of concurrent calls
      // exhausts the backend rate limit. Serialise, do not parallelise.
      final settled = code.indexOf('void _onValidationSettled');
      expect(settled, greaterThan(-1));
      final body = code.substring(settled, settled + 600);
      expect(body, contains('_isValidating = false'));
      expect(
        body,
        isNot(contains('Future.wait')),
        reason: 'Draining must not fan out.',
      );
    });
  });

  group('safety', () {
    test('an already-processed receipt is not re-queued', () {
      // StoreKit redelivers unfinished transactions repeatedly. Without this
      // the queue would grow on every redelivery.
      final guard = code.indexOf('if (!isUserInitiated && _isValidating)');
      final block = code.substring(guard, guard + 700);
      expect(block, contains('_processedPurchaseIds'));
    });
  });
}
