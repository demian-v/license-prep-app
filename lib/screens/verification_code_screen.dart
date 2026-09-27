import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../services/email_verification_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';

/// Risk #12 — the code-entry step of signup.
///
/// Sits between "email + password → Sign Up" and language selection
/// (owner-confirmed ordering, 2026-09-17). The 3-day trial has already been
/// granted by this point and is NOT gated on getting through this screen —
/// that is the owner's decision of 2026-09-16 and there are server tests
/// asserting it. This screen confirms the address is real; it does not decide
/// entitlement.
///
/// [onVerified] is injected rather than the screen navigating itself, so the
/// same screen serves both signup and resume-on-relaunch without knowing which
/// it is in.
class VerificationCodeScreen extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;
  final VoidCallback? onBack;
  final EmailVerificationService? service;

  /// Whether to request a code as soon as the screen opens. False when
  /// resuming, where a code is already outstanding and sending another would
  /// waste the user's quota and invalidate the one in their inbox.
  final bool sendOnOpen;

  const VerificationCodeScreen({
    Key? key,
    required this.email,
    required this.onVerified,
    this.onBack,
    this.service,
    this.sendOnOpen = true,
  }) : super(key: key);

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  static const int _codeLength = 6;

  /// Mirrors the server's RESEND_COOLDOWN_MS. If the two ever disagree the
  /// server wins — the countdown is a courtesy, not the control.
  static const int _resendCooldownSeconds = 60;

  late final EmailVerificationService _service;
  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  bool _submitting = false;
  bool _sending = false;
  String? _error;
  String? _notice;

  /// Risk #67 — whether a code is actually in the user's inbox.
  ///
  /// The heading and subtitle used to assert "Check your email" / "We sent a
  /// 6-digit code to X" unconditionally, so a FAILED send rendered that claim
  /// directly above "Something went wrong. Please try again." Observed on a
  /// device 2026-09-19: both at once. The user then hunts an inbox that has
  /// nothing in it, and "Send a new code" invites them to repeat it.
  ///
  /// True when the screen was opened because a code is already outstanding
  /// (`sendOnOpen == false`), when a send succeeds, and when a send is
  /// throttled — throttling means one was sent recently enough to still be
  /// there, which is exactly why a second was refused.
  late bool _codeSent;
  int _resendIn = 0;
  Timer? _resendTimer;

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EmailVerificationService();
    // Not sending on open means one is already outstanding — see sendOnOpen.
    _codeSent = !widget.sendOnOpen;
    if (widget.sendOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(initial: true));
    } else {
      _startCooldown();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _t(String key) => AppLocalizations.of(context).translate(key);

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _send({bool initial = false}) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });

    final language =
        Provider.of<LanguageProvider>(context, listen: false).language;
    final result = await _service.sendCode(language: language);
    if (!mounted) return;

    setState(() => _sending = false);

    switch (result.outcome) {
      case SendCodeOutcome.sent:
        setState(() {
          _codeSent = true;
          _notice = _t('verify_sent');
        });
        _startCooldown();
        break;
      case SendCodeOutcome.alreadyVerified:
        // Nothing to do here — most likely a resume where verification
        // completed on another device.
        widget.onVerified();
        break;
      case SendCodeOutcome.throttled:
        setState(() {
          // Refused BECAUSE one was sent recently — so there is one to find.
          _codeSent = true;
          _resendIn = result.retryAfter?.inSeconds ?? _resendCooldownSeconds;
          if (!initial) _error = _t('verify_err_throttled');
        });
        _startCountdownFrom(_resendIn);
        break;
      case SendCodeOutcome.transportFailed:
        setState(() => _error = _t('verify_err_send'));
        break;
      case SendCodeOutcome.failed:
        setState(() => _error = _t('verify_err_generic'));
        break;
    }
  }

  void _startCountdownFrom(int seconds) {
    _resendTimer?.cancel();
    if (seconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    if (_submitting || _code.length != _codeLength) return;
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });

    final result = await _service.verify(_code);
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result.outcome) {
      case VerifyOutcome.verified:
        widget.onVerified();
        break;
      case VerifyOutcome.wrongCode:
        final left = result.attemptsLeft;
        setState(() {
          _error = left == 1
              ? _t('verify_err_wrong_last')
              : _t('verify_err_wrong').replaceAll('{attempts}', '${left ?? ''}');
        });
        _clearCode();
        break;
      case VerifyOutcome.expired:
        setState(() => _error = _t('verify_err_expired'));
        _clearCode();
        break;
      case VerifyOutcome.tooManyAttempts:
        setState(() => _error = _t('verify_err_attempts'));
        _clearCode();
        break;
      case VerifyOutcome.noCode:
        setState(() => _error = _t('verify_err_none'));
        _clearCode();
        break;
      case VerifyOutcome.emailChanged:
        setState(() => _error = _t('verify_err_changed'));
        _clearCode();
        break;
      case VerifyOutcome.failed:
        setState(() => _error = _t('verify_err_generic'));
        break;
    }
  }

  void _clearCode() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  /// Accepts a pasted code in any box, so "paste" works wherever the caret is —
  /// people paste into the first empty box, not necessarily the first box.
  void _onChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 1) {
      for (var i = 0; i < _codeLength; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      FocusScope.of(context).unfocus();
      setState(() {});
      if (_code.length == _codeLength) _submit();
      return;
    }

    // Only rewrite the field when the value actually needs correcting (a
    // non-digit was typed). Reassigning `.text` on every keystroke resets the
    // field's editing state, and characters arriving while that happens are
    // dropped — typing a code quickly landed only the first digit.
    if (digits != value) {
      _controllers[index].value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    setState(() {});

    if (digits.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_code.length == _codeLength) {
      FocusScope.of(context).unfocus();
      _submit();
    }
  }

  /// Backspace on an empty box steps back, which is what every OTP field does
  /// and what people expect when correcting a typo.
  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  /// One digit as a grey field panel, as the login fields: no outline at
  /// rest, a blue ring on the box being typed in.
  Widget _buildBox(int index) {
    OutlineInputBorder ring(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: color, width: width),
        );
    return Expanded(
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) => _onKey(index, event),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          autofocus: index == 0,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          cursorColor: AppColors.signal,
          style: AppTypography.title.copyWith(
            fontSize: 24,
            height: 1,
            color: AppColors.ink,
            fontVariations: const [FontVariation('wght', 600)],
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.field,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
            border: ring(Colors.transparent, 0),
            enabledBorder: ring(Colors.transparent, 0),
            focusedBorder: ring(AppColors.signal, 1.5),
          ),
          onChanged: (value) => _onChanged(index, value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _resendIn <= 0 && !_sending;

    final blocks = <Widget>[
      bentoAuthBadge(SolarIcons.letterLinear),
      const SizedBox(height: AppSpacing.x6),
      BentoAuthCard(
        title: _t(_codeSent ? 'verify_title' : 'verify_title_unsent'),
        children: [
          Text(
            // #67 — only claim a code was sent when one was.
            _t(_codeSent ? 'verify_subtitle' : 'verify_subtitle_unsent')
                .replaceAll('{email}', widget.email),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              fontSize: 15,
              height: 22 / 15,
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          Row(
            children: [
              for (var i = 0; i < _codeLength; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.x2),
                _buildBox(i),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.x4),
            BentoAuthError(_error!),
          ],
          if (_notice != null && _error == null) ...[
            const SizedBox(height: AppSpacing.x4),
            BentoAuthNotice(_notice!),
          ],
          const SizedBox(height: AppSpacing.x6),
          BentoAuthPrimaryButton(
            label: _t('verify_cta'),
            loading: _submitting,
            onPressed:
                _submitting || _code.length != _codeLength ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.x2),
          BentoAuthLink(
            label: canResend
                ? _t('verify_resend')
                : _t('verify_resend_in').replaceAll('{seconds}', '$_resendIn'),
            onPressed: canResend ? () => _send() : null,
          ),
        ],
      ),
      if (widget.onBack != null) ...[
        const SizedBox(height: AppSpacing.x3),
        Center(
          child: BentoAuthLink(
            label: _t('verify_change_email'),
            onPressed: widget.onBack!,
          ),
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: widget.onBack == null ? null : bentoAuthAppBar(onBack: widget.onBack!),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x2,
            AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < blocks.length; i++)
                StaggerIn(
                  index: i,
                  count: blocks.length,
                  curve: BentoTokens.curve,
                  child: blocks[i],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
