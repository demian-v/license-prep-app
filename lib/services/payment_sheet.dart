import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../models/booking.dart';

enum PaymentOutcome { paid, cancelled, failed }

/// How Stripe's PaymentSheet ended. [message] is Stripe's own text for a
/// failure, already in the phone's language.
class PaymentResult {
  const PaymentResult(this.outcome, [this.message]);

  final PaymentOutcome outcome;
  final String? message;
}

/// Opens the payment for a lesson (instructors P9). An interface so the
/// booking page can be tested without the native Stripe SDK.
abstract class PaymentSheetLauncher {
  Future<PaymentResult> pay(PaymentStart start);
}

/// Stripe's PaymentSheet, cards only (owner decision, P9: Apple Pay and
/// Google Pay later). No Customer, so no saved cards. The booking is
/// confirmed by the server's webhook, not by this result: a paid sheet only
/// means the app should wait for it.
class StripePaymentSheet implements PaymentSheetLauncher {
  const StripePaymentSheet();

  @override
  Future<PaymentResult> pay(PaymentStart start) async {
    try {
      Stripe.publishableKey = start.publishableKey;
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: start.clientSecret,
          merchantDisplayName: 'DriveUSA',
          style: ThemeMode.light,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return const PaymentResult(PaymentOutcome.paid);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return const PaymentResult(PaymentOutcome.cancelled);
      return PaymentResult(PaymentOutcome.failed, e.error.localizedMessage ?? e.error.message);
    } catch (e) {
      debugPrint('PaymentSheet failed: $e');
      return const PaymentResult(PaymentOutcome.failed);
    }
  }
}
