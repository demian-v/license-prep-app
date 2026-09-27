import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

/// The Bento pieces the sign-in screens share (login, signup, and the
/// password-reset pages that follow). Presentation only: each screen keeps
/// its own validation, analytics and navigation.

/// The app logo above the form, with the app title as a text fallback.
Widget bentoAuthLogo(String fallbackTitle) {
  return SizedBox(
    height: 72,
    child: Image.asset(
      'assets/images/logo/logo.png',
      height: 72,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Text(
          fallbackTitle,
          textAlign: TextAlign.center,
          style: AppTypography.title.copyWith(
            color: AppColors.signal,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      ),
    ),
  );
}

/// The form's white card, as the Bento cards elsewhere.
class BentoAuthCard extends StatelessWidget {
  const BentoAuthCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // One line; a long translation shrinks rather than wraps.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(
                fontSize: 26,
                height: 32 / 26,
                color: AppColors.ink,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x4 + AppSpacing.x1),
          ...children,
        ],
      ),
    );
  }
}

/// A form field as a grey panel inside the white card (no card in a card):
/// no outline at rest, a blue ring while focused, a red one on error.
InputDecoration bentoFieldDecoration({
  required String label,
  required IconData icon,
}) {
  OutlineInputBorder ring(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    labelStyle: AppTypography.body.copyWith(color: AppColors.inkSecondary),
    floatingLabelStyle: AppTypography.label.copyWith(color: AppColors.inkSecondary),
    prefixIcon: Icon(icon, color: AppColors.inkSecondary, size: 22),
    filled: true,
    fillColor: AppColors.field,
    contentPadding: const EdgeInsets.symmetric(
      vertical: AppSpacing.x4,
      horizontal: AppSpacing.x4,
    ),
    border: ring(Colors.transparent, 0),
    enabledBorder: ring(Colors.transparent, 0),
    focusedBorder: ring(AppColors.signal, 1.5),
    errorBorder: ring(AppColors.stop, 1.5),
    focusedErrorBorder: ring(AppColors.stop, 1.5),
    errorStyle: AppTypography.caption.copyWith(
      fontSize: 13,
      color: AppColors.stop,
      fontVariations: const [FontVariation('wght', 500)],
    ),
  );
}

/// The form's error, as a soft red panel with its icon.
class BentoAuthError extends StatelessWidget {
  const BentoAuthError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.stopSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(SolarIcons.dangerCircleLinear, color: AppColors.stop, size: 20),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              message,
              style: AppTypography.label.copyWith(
                color: AppColors.stop,
                fontVariations: const [FontVariation('wght', 500)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The form's action: the dark `ink` pill, as the paywall's buy button; a
/// spinner in place of the label while it works. [onPressed] null = disabled.
class BentoAuthPrimaryButton extends StatelessWidget {
  const BentoAuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      enabled: onPressed != null,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.onSignal,
          disabledBackgroundColor: AppColors.ink,
          disabledForegroundColor: AppColors.onSignal,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: AppTypography.label.copyWith(
            fontSize: 16,
            fontVariations: const [FontVariation('wght', 500)],
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.onSignal,
                  strokeWidth: 3,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// A text link (forgot password, switch between login and signup): blue,
/// at least 44 tall.
class BentoAuthLink extends StatelessWidget {
  const BentoAuthLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.signal,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
        textStyle: AppTypography.label.copyWith(
          fontSize: 15,
          fontVariations: const [FontVariation('wght', 500)],
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
