package com.driveusa.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, not FlutterActivity: Stripe's PaymentSheet needs
// the support fragment manager (flutter_stripe, instructors P9).
class MainActivity: FlutterFragmentActivity()
