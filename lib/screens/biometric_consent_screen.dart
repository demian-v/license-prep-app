import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/instructor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bento_auth_parts.dart';

/// The biometric consent before Didit's identity check (instructors plan v2
/// §6.3): what is collected, why, who processes it and for how long, then an
/// UNCHECKED box — an Illinois BIPA-grade written release, stored on the
/// server with its wording version before any face is captured. Didit's own
/// consent step isn't relied on (and SDKs below 4.10.0 don't show one).
///
/// The wording is a DRAFT for the lawyer (P11); it is versioned
/// ([InstructorService.biometricConsentVersion]).
///
/// Continue: consent → createIdentitySession → Didit's flow. The result
/// arrives on the server later; Профиль shows «Проверяем…» until then.
class BiometricConsentScreen extends StatefulWidget {
  const BiometricConsentScreen({super.key, this.service});

  final InstructorService? service;

  @override
  State<BiometricConsentScreen> createState() => _BiometricConsentScreenState();
}

class _BiometricConsentScreenState extends State<BiometricConsentScreen> {
  late final _svc = widget.service ?? InstructorService();
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  Future<void> _continue() async {
    final l = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.recordBiometricConsent();
      final token = await _svc.createIdentitySession();
      final finished = await _svc.runIdentityCheck(token, language);
      if (!mounted) return;
      if (finished) messenger.showSnackBar(SnackBar(content: Text(l.translate('iid_started'))));
      navigator.pop();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      if (e.message == 'already-passed') {
        navigator.pop();
        return;
      }
      setState(() {
        _busy = false;
        _error = l.translate(e.message == 'too-many-sessions' ? 'iid_too_many' : 'iid_error');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.translate('iid_error');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget paragraph(String key) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x3),
          child: Text(l.translate(key), style: AppTypography.body.copyWith(color: AppColors.ink)),
        );
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoAuthAppBar(onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x2, AppSpacing.x4, AppSpacing.x6),
          children: [
            BentoAuthCard(
              title: l.translate('iid_title'),
              children: [
                const SizedBox(height: AppSpacing.x3),
                for (final key in ['iid_intro', 'iid_what', 'iid_why', 'iid_who', 'iid_keep']) paragraph(key),
                _AgreeBox(
                  agreed: _agreed,
                  label: l.translate('iid_agree'),
                  onChanged: _busy ? null : (v) => setState(() => _agreed = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.x3),
                  BentoAuthError(_error!),
                ],
                const SizedBox(height: AppSpacing.x4),
                BentoAuthPrimaryButton(
                  label: l.translate('iid_continue'),
                  loading: _busy,
                  onPressed: _agreed && !_busy ? _continue : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The release itself: starts unticked, the whole row toggles it (as Sign
/// Up's terms box).
class _AgreeBox extends StatelessWidget {
  const _AgreeBox({required this.agreed, required this.label, required this.onChanged});

  final bool agreed;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onChanged == null ? null : () => onChanged!(!agreed),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.x1, AppSpacing.x2, AppSpacing.x3, AppSpacing.x3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: agreed,
                onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
                activeColor: AppColors.signal,
                side: const BorderSide(color: AppColors.inkSecondary, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x2 + 2),
                  child: Text(label, style: AppTypography.body.copyWith(color: AppColors.ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
