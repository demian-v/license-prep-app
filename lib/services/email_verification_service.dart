import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Risk #12 — the client side of email verification by 6-digit code.
///
/// Thin on purpose: every rule that matters (expiry, the attempt cap, send
/// throttling, and the hashing) lives on the server, because a client can be
/// modified and a server cannot. This class only carries requests across and
/// turns `FirebaseFunctionsException` codes into something the UI can switch on
/// without matching on message strings.

/// Why a send was refused, when it was.
enum SendCodeOutcome { sent, alreadyVerified, throttled, transportFailed, failed }

/// Why a code was rejected, mirroring the server's own reasons.
enum VerifyOutcome { verified, wrongCode, expired, tooManyAttempts, noCode, emailChanged, failed }

class SendCodeResult {
  final SendCodeOutcome outcome;

  /// Only meaningful for [SendCodeOutcome.throttled] — how long until a resend
  /// is allowed, so the UI can count down rather than guess.
  final Duration? retryAfter;

  const SendCodeResult(this.outcome, {this.retryAfter});
}

class VerifyResult {
  final VerifyOutcome outcome;

  /// Only meaningful for [VerifyOutcome.wrongCode]. The server decides this;
  /// the client must not compute it, or the two would drift.
  final int? attemptsLeft;

  const VerifyResult(this.outcome, {this.attemptsLeft});
}

class VerificationStatus {
  final bool emailVerified;
  final bool hasPendingCode;
  final Duration expiresIn;

  const VerificationStatus({
    required this.emailVerified,
    required this.hasPendingCode,
    required this.expiresIn,
  });
}

class EmailVerificationService {
  final FirebaseFunctions _functions;

  EmailVerificationService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Ask for a code. [language] picks the template, so the email matches the
  /// language the user is about to see the app in.
  Future<SendCodeResult> sendCode({String language = 'en'}) async {
    try {
      final result = await _functions
          .httpsCallable('sendEmailVerificationCode')
          .call<Map<String, dynamic>>({'language': language});

      final data = Map<String, dynamic>.from(result.data);
      if (data['alreadyVerified'] == true) {
        return const SendCodeResult(SendCodeOutcome.alreadyVerified);
      }
      return const SendCodeResult(SendCodeOutcome.sent);
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'resource-exhausted':
          final ms = (e.details is Map) ? e.details['retryAfterMs'] : null;
          return SendCodeResult(
            SendCodeOutcome.throttled,
            retryAfter: ms is int ? Duration(milliseconds: ms) : null,
          );
        case 'unavailable':
          // The mail transport refused. Distinct from a throttle: retrying
          // immediately is reasonable, and nothing was recorded server-side.
          return const SendCodeResult(SendCodeOutcome.transportFailed);
        default:
          debugPrint('EmailVerificationService.sendCode failed: ${e.code} ${e.message}');
          return const SendCodeResult(SendCodeOutcome.failed);
      }
    } catch (e) {
      debugPrint('EmailVerificationService.sendCode error: $e');
      return const SendCodeResult(SendCodeOutcome.failed);
    }
  }

  /// Submit a code. Returns why it was refused, so the screen can say something
  /// specific rather than "invalid code" for six different situations.
  Future<VerifyResult> verify(String code) async {
    try {
      final result = await _functions
          .httpsCallable('verifyEmailCode')
          .call<Map<String, dynamic>>({'code': code});

      final data = Map<String, dynamic>.from(result.data);
      if (data['verified'] == true) {
        return const VerifyResult(VerifyOutcome.verified);
      }

      final attemptsLeft = data['attemptsLeft'];
      switch (data['reason']) {
        case 'mismatch':
          return VerifyResult(
            VerifyOutcome.wrongCode,
            attemptsLeft: attemptsLeft is int ? attemptsLeft : null,
          );
        case 'expired':
          return const VerifyResult(VerifyOutcome.expired);
        case 'too_many_attempts':
          return const VerifyResult(VerifyOutcome.tooManyAttempts);
        case 'no_code':
          return const VerifyResult(VerifyOutcome.noCode);
        case 'email_changed':
          return const VerifyResult(VerifyOutcome.emailChanged);
        default:
          return const VerifyResult(VerifyOutcome.failed);
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('EmailVerificationService.verify failed: ${e.code} ${e.message}');
      return const VerifyResult(VerifyOutcome.failed);
    } catch (e) {
      debugPrint('EmailVerificationService.verify error: $e');
      return const VerifyResult(VerifyOutcome.failed);
    }
  }

  /// Does this account still owe us a verification, and is a code outstanding?
  ///
  /// Drives resume-on-relaunch: someone who closes the app at the code screen
  /// comes back to it rather than being stranded halfway through signup.
  Future<VerificationStatus?> status() async {
    try {
      final result = await _functions
          .httpsCallable('getEmailVerificationStatus')
          .call<Map<String, dynamic>>();
      final data = Map<String, dynamic>.from(result.data);
      final ms = data['expiresInMs'];
      return VerificationStatus(
        emailVerified: data['emailVerified'] == true,
        hasPendingCode: data['hasPendingCode'] == true,
        expiresIn: Duration(milliseconds: ms is int ? ms : 0),
      );
    } catch (e) {
      // Null means "we could not ask". The caller must not read that as
      // "verified" or as "not verified" — both would be a guess.
      debugPrint('EmailVerificationService.status error: $e');
      return null;
    }
  }
}
