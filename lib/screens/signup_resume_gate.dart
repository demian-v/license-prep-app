import 'package:flutter/material.dart';

import '../services/email_verification_service.dart';
import 'state_selection_screen.dart';
import 'verification_code_screen.dart';

/// Risk #12 — resume-on-relaunch for an interrupted signup.
///
/// Reached only when `user.state == null`, i.e. signup was never finished.
/// That scoping is the important part: **existing accounts all have a state
/// set, so none of them are sent here.** Gating on `emailVerified` alone would
/// route the entire pre-existing user base to a verification screen on their
/// next launch, which is not what was asked for and would look like an outage.
///
/// It also fails OPEN. If the status call cannot be made — offline, functions
/// unreachable — the user continues to state selection rather than being held
/// at a screen they cannot get past. Verification is a step in signup, not a
/// door in front of entitlement (owner decision, 2026-09-16), so an
/// unanswerable question must not become a wall.
class SignupResumeGate extends StatefulWidget {
  final String email;
  final EmailVerificationService? service;

  const SignupResumeGate({Key? key, required this.email, this.service}) : super(key: key);

  @override
  State<SignupResumeGate> createState() => _SignupResumeGateState();
}

class _SignupResumeGateState extends State<SignupResumeGate> {
  late final EmailVerificationService _service;
  late final Future<VerificationStatus?> _status;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EmailVerificationService();
    _status = _service.status();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VerificationStatus?>(
      future: _status,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final status = snapshot.data;

        // Could not ask, or already verified: carry on with signup.
        if (status == null || status.emailVerified) {
          return StateSelectionScreen();
        }

        return VerificationCodeScreen(
          email: widget.email,
          service: _service,
          // A code may still be outstanding in their inbox. Sending another
          // would invalidate it and spend a send from their hourly budget.
          sendOnOpen: !status.hasPendingCode,
          onVerified: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => StateSelectionScreen()),
          ),
        );
      },
    );
  }
}
