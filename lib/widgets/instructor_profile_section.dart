import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/instructor_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import 'bento_auth_parts.dart';
import 'bento_question_parts.dart';
import 'instructor_stage_badge.dart';

/// The instructor's own part of Профиль (instructors plan v2 §14.2): what
/// has been checked, the licence numbers — which can be added here after a
/// signup that skipped them (owner, 2026-09-30) — and «Показывать в поиске».
///
/// Reads the instructor's own public doc live (owner-readable in
/// firestore.rules), so a change made on the server (the listing trigger,
/// an admin review) shows at once.
class InstructorProfileSection extends StatelessWidget {
  const InstructorProfileSection({super.key, required this.uid, this.service});

  final String uid;
  final InstructorService? service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final svc = service ?? InstructorService();
    return StreamBuilder<Map<String, dynamic>?>(
      stream: svc.ownProfile(uid),
      builder: (context, snapshot) {
        final p = snapshot.data;
        if (p == null) return const SizedBox(height: 120);
        final stage = p['stage'] as int? ?? 0;
        final status = p['status'] as String? ?? 'active';
        final isSchool = p['kind'] == 'school';

        String licenseValue() => switch (p['licenseCheck']) {
              'pending' => l.translate('status_pending'),
              'passed' => l.translate('status_done'),
              'rejected' => l.translate('status_rejected'),
              'expired' => l.translate('status_expired'),
              _ => l.translate('status_add'),
            };
        String idValue() => switch (p['idCheck']) {
              'pending' => l.translate('status_pending'),
              'passed' => l.translate('status_done'),
              'failed' => l.translate('status_rejected'),
              _ => l.translate('status_soon'),
            };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Card(
              children: [
                Text(
                  l.translate('iprof_verification_title'),
                  style: AppTypography.heading.copyWith(
                    fontSize: 18,
                    height: 24 / 18,
                    color: AppColors.ink,
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Align(alignment: Alignment.centerLeft, child: InstructorStageBadge(stage: stage)),
                const SizedBox(height: AppSpacing.x3),
                _Row(
                  icon: SolarIcons.documentTextLinear,
                  title: l.translate('iprof_license'),
                  value: licenseValue(),
                  actionable: p['licenseCheck'] != 'passed' && p['licenseCheck'] != 'pending',
                  onTap: () => _editLicense(context, svc, isSchool, p['schoolLicenseNumber'] as String?),
                ),
                _Row(
                  icon: SolarIcons.userRoundedLinear,
                  title: l.translate('iprof_id_check'),
                  value: idValue(),
                  actionable: false,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            _Card(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.translate('iprof_visible_title'),
                        style: AppTypography.heading.copyWith(
                          fontSize: 18,
                          height: 24 / 18,
                          color: AppColors.ink,
                          fontVariations: const [FontVariation('wght', 600)],
                        ),
                      ),
                    ),
                    Switch(
                      value: status == 'active',
                      activeThumbColor: AppColors.onSignal,
                      activeTrackColor: AppColors.signal,
                      // A suspended profile is an admin decision (plan v2 §7).
                      onChanged: status == 'suspended' ? null : (v) => svc.setVisible(uid, v),
                    ),
                  ],
                ),
                Text(
                  switch (status) {
                    'suspended' => l.translate('iprof_suspended'),
                    'active' => l.translate('iprof_visible_on'),
                    _ => l.translate('iprof_visible_off'),
                  },
                  style: AppTypography.body.copyWith(color: AppColors.inkSecondary),
                ),
                // listInstructors hides a private instructor's price until a
                // licence number is checked (owner, 2026-09-30).
                if (!isSchool && p['licenseCheck'] != 'passed') ...[
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    l.translate('iprof_price_hidden'),
                    style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _editLicense(BuildContext context, InstructorService svc, bool isSchool, String? current) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.field,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BentoTokens.card)),
      ),
      builder: (_) => _LicenseSheet(service: svc, isSchool: isSchool, current: current),
    );
  }
}

class _LicenseSheet extends StatefulWidget {
  const _LicenseSheet({required this.service, required this.isSchool, this.current});

  final InstructorService service;
  final bool isSchool;
  final String? current;

  @override
  State<_LicenseSheet> createState() => _LicenseSheetState();
}

class _LicenseSheetState extends State<_LicenseSheet> {
  late final _school = TextEditingController(text: widget.current ?? '');
  final _own = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _school.dispose();
    _own.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_school.text.trim().length < 2) {
      setState(() => _error = l.translate('iprof_license_required'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.service.submitLicenseNumber(school: _school.text.trim(), instructor: _own.text.trim());
      navigator.pop();
    } catch (e) {
      debugPrint('InstructorProfileSection: licence save failed: $e');
      if (mounted) setState(() => _error = l.translate('iprof_save_error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.x4 + AppSpacing.x1, AppSpacing.x6,
          AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BentoAuthCard(
              title: l.translate('iprof_license'),
              children: [
                if (_error != null) ...[BentoAuthError(_error!), const SizedBox(height: AppSpacing.x3)],
                TextField(
                  controller: _school,
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  decoration: bentoFieldDecoration(
                      label: l.translate('ireg_school_license'), icon: SolarIcons.documentTextLinear),
                ),
                if (!widget.isSchool) ...[
                  const SizedBox(height: AppSpacing.x3),
                  TextField(
                    controller: _own,
                    style: AppTypography.body.copyWith(color: AppColors.ink),
                    decoration: bentoFieldDecoration(
                        label: l.translate('ireg_instructor_license'), icon: SolarIcons.documentTextLinear),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            // The sheet's own lone action: the dark ink pill (owner rule 16).
            _busy
                ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                : BentoActionButton(text: l.translate('save'), ink: true, onTap: _save),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// A list row: icon, title, and the state at the end — blue when it is an
/// action («Добавить»), grey when it is a fact. A chevron only on the
/// actionable rows, which are navigable among ones that are not.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.value, required this.actionable, this.onTap});

  final IconData icon;
  final String title;
  final String value;
  final bool actionable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: actionable ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2 + 2),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.inkSecondary),
            const SizedBox(width: AppSpacing.x3),
            Expanded(child: Text(title, style: AppTypography.body.copyWith(color: AppColors.ink))),
            Text(
              value,
              style: AppTypography.label.copyWith(
                color: actionable ? AppColors.signal : AppColors.inkSecondary,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
            if (actionable) ...[
              const SizedBox(width: AppSpacing.x1),
              const Icon(SolarIcons.altArrowRightLinear, size: 18, color: AppColors.signal),
            ],
          ],
        ),
      ),
    );
  }
}
