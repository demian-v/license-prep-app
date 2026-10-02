import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../services/instructor_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import 'bento_auth_parts.dart';
import 'bento_question_parts.dart';
import 'instructor_form_fields.dart';
import 'instructor_stage_badge.dart';

/// The instructor's own part of Профиль (instructors plan v2 §14.2): what
/// has been checked, the licence numbers — which can be added here after a
/// signup that skipped them (owner, 2026-09-30) — the profile students see
/// (description, school, price, car, contacts; P3b) and «Показывать в поиске».
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
            _PublicProfileCard(profile: p, service: svc),
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
    // A school gives its school licence; a private instructor either number
    // (submitLicenseNumber, owner 2026-09-30).
    final school = _school.text.trim();
    final own = _own.text.trim();
    if (widget.isSchool ? school.length < 2 : school.length < 2 && own.length < 2) {
      setState(() => _error = widget.isSchool
          ? l.translate('iprof_license_required')
          : l.translate('iprof_license_required_any'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.service.submitLicenseNumber(school: school, instructor: own);
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
                const SizedBox(height: AppSpacing.x3),
                Text(
                  widget.isSchool ? l.translate('ireg_license_note_school') : l.translate('ireg_license_note_private'),
                  style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
                ),
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

enum _Section { bio, school, price, car, contacts }

/// «Профиль для учеников»: what the wizard skipped (the description, a
/// private instructor's school) or the instructor wants to change. Each row
/// opens a sheet that saves one section through updateInstructorProfile.
/// Kind, role and location are fixed after registration.
class _PublicProfileCard extends StatelessWidget {
  const _PublicProfileCard({required this.profile, required this.service});

  final Map<String, dynamic> profile;
  final InstructorService service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = profile;
    final isSchool = p['kind'] == 'school';
    // A suspended profile is frozen (updateInstructorProfile refuses it).
    final editable = p['status'] != 'suspended';
    final bio = (p['bio'] as String? ?? '').trim();
    final schoolName = (p['schoolName'] as String? ?? '').trim();
    final rate = p['hourlyRateCents'] as int?;
    final durations = List<int>.from(p['lessonDurations'] as List? ?? const []);
    final carModel = p['carModel'] as String? ?? '';
    final carYear = p['carYear'] as int?;

    void open(_Section section) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.field,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(BentoTokens.card)),
          ),
          builder: (_) => _EditSheet(section: section, profile: p, service: service),
        );

    return _Card(
      children: [
        Text(
          l.translate('iprof_public_title'),
          style: AppTypography.heading.copyWith(
            fontSize: 18,
            height: 24 / 18,
            color: AppColors.ink,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(l.translate('iprof_public_desc'), style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
        const SizedBox(height: AppSpacing.x2),
        _EditRow(
          icon: SolarIcons.documentTextLinear,
          title: l.translate('iprof_bio'),
          summary: bio.isEmpty ? null : bio,
          addLabel: l.translate('status_add'),
          onTap: editable ? () => open(_Section.bio) : null,
        ),
        if (!isSchool)
          _EditRow(
            icon: SolarIcons.squareAcademicCapBold,
            title: l.translate('ireg_school_title'),
            summary: schoolName.isEmpty ? null : schoolName,
            addLabel: l.translate('status_add'),
            onTap: editable ? () => open(_Section.school) : null,
          ),
        _EditRow(
          icon: SolarIcons.clockCircleLinear,
          title: l.translate('ireg_price_title'),
          summary: rate == null
              ? null
              : l
                  .translate('iprof_price_summary')
                  .replaceAll('{rate}', '\$${rate ~/ 100}')
                  .replaceAll('{durations}',
                      l.translate('ireg_minutes').replaceAll('{n}', (durations..sort()).join(', '))),
          addLabel: l.translate('status_add'),
          onTap: editable ? () => open(_Section.price) : null,
        ),
        _EditRow(
          icon: SolarIcons.carLinear,
          title: l.translate('ireg_car_title'),
          summary: carModel.isEmpty ? null : [carModel, if (carYear != null) '$carYear'].join(', '),
          addLabel: l.translate('status_add'),
          onTap: editable ? () => open(_Section.car) : null,
        ),
        _EditRow(
          icon: SolarIcons.chatRoundLineLinear,
          title: l.translate('ireg_contacts_title'),
          // The contacts are private (instructorPrivate): the sheet loads them.
          summary: l.translate('ireg_contacts_desc'),
          addLabel: l.translate('status_add'),
          onTap: editable ? () => open(_Section.contacts) : null,
        ),
      ],
    );
  }
}

/// A settings row: icon, title with the current value under it, chevron.
/// Nothing saved yet → the blue «Добавить» instead of a value.
class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.icon,
    required this.title,
    required this.summary,
    required this.addLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? summary;
  final String addLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2 + 2),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.inkSecondary),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body.copyWith(color: AppColors.ink)),
                  if (summary != null)
                    Text(
                      summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
                    ),
                ],
              ),
            ),
            if (summary == null)
              Text(
                addLabel,
                style: AppTypography.label.copyWith(
                  color: onTap == null ? AppColors.inkSecondary : AppColors.signal,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.x1),
              Icon(SolarIcons.altArrowRightLinear,
                  size: 18, color: summary == null ? AppColors.signal : AppColors.inkSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// One section's fields, checked the way updateInstructorProfile checks them.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.section, required this.profile, required this.service});

  final _Section section;
  final Map<String, dynamic> profile;
  final InstructorService service;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final Map<String, dynamic> _p = widget.profile;
  late final _bio = TextEditingController(text: _p['bio'] as String? ?? '');
  late final _school = TextEditingController(text: _p['schoolName'] as String? ?? '');
  late final _rate = TextEditingController(
      text: _p['hourlyRateCents'] is int ? '${(_p['hourlyRateCents'] as int) ~/ 100}' : '');
  late final Set<int> _durations = {...List<int>.from(_p['lessonDurations'] as List? ?? const [60])};
  late final _carModel = TextEditingController(text: _p['carModel'] as String? ?? '');
  late final _carYear = TextEditingController(text: _p['carYear'] is int ? '${_p['carYear']}' : '');
  late bool _dualControls = _p['hasDualControls'] as bool? ?? true;
  final _phone = TextEditingController();
  final _email = TextEditingController();
  // Contacts are fetched first; the other sections start from the live doc.
  late bool _loading = widget.section == _Section.contacts;
  bool _busy = false;
  String? _error;

  // Named `translate` so localization_coverage_test sees every key literal.
  String translate(String key) => AppLocalizations.of(context).translate(key);

  @override
  void initState() {
    super.initState();
    if (widget.section == _Section.contacts) _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final c = await widget.service.contacts();
      _phone.text = c.phone;
      _email.text = c.email;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('InstructorProfileSection: contacts load failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = translate('iprof_load_error');
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_bio, _school, _rate, _carModel, _carYear, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The error for the section (translated), or null when it can be saved.
  String? _validate() {
    switch (widget.section) {
      case _Section.bio:
        return null; // optional; the field stops at 600
      case _Section.school:
        final v = _school.text.trim();
        return v.isEmpty || (v.length >= 2 && v.length <= 80) ? null : translate('ireg_error_school_name');
      case _Section.price:
        final rate = int.tryParse(_rate.text.trim());
        if (rate == null || rate < 20 || rate > 200) return translate('ireg_error_rate');
        return _durations.isEmpty ? translate('ireg_error_durations') : null;
      case _Section.car:
        final model = _carModel.text.trim();
        if (model.length < 2 || model.length > 60) return translate('ireg_error_car_model');
        final year = int.tryParse(_carYear.text.trim());
        return year != null && year >= 1995 && year <= DateTime.now().year + 1
            ? null
            : translate('ireg_error_car_year');
      case _Section.contacts:
        final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 10 || digits.length > 15) return translate('ireg_error_phone');
        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())
            ? null
            : translate('ireg_error_email');
    }
  }

  Map<String, dynamic> _fields() => switch (widget.section) {
        _Section.bio => {'bio': _bio.text.trim()},
        _Section.school => {'schoolName': _school.text.trim()},
        _Section.price => {
            'hourlyRateCents': int.parse(_rate.text.trim()) * 100,
            'lessonDurations': _durations.toList()..sort(),
          },
        _Section.car => {
            'carModel': _carModel.text.trim(),
            'carYear': int.parse(_carYear.text.trim()),
            'hasDualControls': _dualControls,
          },
        _Section.contacts => {'phone': _phone.text.trim(), 'contactEmail': _email.text.trim()},
      };

  Future<void> _save() async {
    final error = _validate();
    setState(() => _error = error);
    if (error != null) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await widget.service.updateProfile(widget.section.name, _fields());
      navigator.pop();
    } catch (e) {
      debugPrint('InstructorProfileSection: ${widget.section.name} save failed: $e');
      if (mounted) setState(() => _error = translate('iprof_save_error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon,
          {TextInputType? type,
          List<TextInputFormatter>? formatters,
          int maxLines = 1,
          int? maxLength,
          Widget? prefix}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: maxLines == 1
            ? TextField(
                controller: c,
                keyboardType: type,
                inputFormatters: formatters,
                maxLength: maxLength,
                style: AppTypography.body.copyWith(color: AppColors.ink),
                decoration: prefix == null
                    ? bentoFieldDecoration(label: label, icon: icon)
                    : bentoFieldDecoration(label: label, icon: icon).copyWith(prefixIcon: prefix),
              )
            // InputDecorator centres prefixIcon vertically; in a tall field
            // the icon belongs on the first line, so the slot stays empty
            // (same text indent) and the icon is drawn over it.
            : Stack(
                children: [
                  TextField(
                    controller: c,
                    keyboardType: type,
                    inputFormatters: formatters,
                    maxLines: maxLines,
                    maxLength: maxLength,
                    style: AppTypography.body.copyWith(color: AppColors.ink),
                    decoration: bentoFieldDecoration(label: label, icon: icon)
                        .copyWith(prefixIcon: const SizedBox(width: 48)),
                  ),
                  Positioned(
                    left: 13,
                    top: AppSpacing.x4 + 1,
                    child: IgnorePointer(child: Icon(icon, color: AppColors.inkSecondary, size: 22)),
                  ),
                ],
              ),
      );

  Widget _note(String text) =>
      Text(text, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary));

  (String, List<Widget>) _content() {
    final isSchool = _p['kind'] == 'school';
    switch (widget.section) {
      case _Section.bio:
        return (translate('iprof_bio'), [
          _field(_bio, translate('ireg_bio'), SolarIcons.documentTextLinear,
              type: TextInputType.multiline, maxLines: 6, maxLength: 600),
          _note(isSchool ? translate('ireg_about_desc_school') : translate('ireg_about_desc_instructor')),
        ]);
      case _Section.school:
        return (translate('ireg_school_title'), [
          _field(_school, translate('ireg_school_name'), SolarIcons.squareAcademicCapBold),
          _note(translate('iprof_school_optional')),
        ]);
      case _Section.price:
        return (translate('ireg_price_title'), [
          _field(_rate, translate('ireg_hourly_rate'), SolarIcons.medalRibbonsStarBold,
              type: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              prefix: const InstructorDollarPrefix()),
          Text(translate('ireg_durations'), style: AppTypography.label.copyWith(color: AppColors.inkSecondary)),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            children: [
              for (final m in instructorLessonDurations)
                InstructorChoicePill(
                  label: translate('ireg_minutes').replaceAll('{n}', '$m'),
                  selected: _durations.contains(m),
                  onTap: () => setState(() => _durations.contains(m) ? _durations.remove(m) : _durations.add(m)),
                ),
            ],
          ),
          // listInstructors hides it until a licence number is checked.
          if (!isSchool && _p['licenseCheck'] != 'passed') ...[
            const SizedBox(height: AppSpacing.x3),
            _note(translate('iprof_price_hidden')),
          ],
        ]);
      case _Section.car:
        return (translate('ireg_car_title'), [
          _field(_carModel, translate('ireg_car_model'), SolarIcons.carLinear),
          _field(_carYear, translate('ireg_car_year'), SolarIcons.clockCircleLinear,
              type: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)]),
          Row(
            children: [
              Expanded(
                child: Text(translate('ireg_dual_controls'), style: AppTypography.body.copyWith(color: AppColors.ink)),
              ),
              Switch(
                value: _dualControls,
                activeThumbColor: AppColors.onSignal,
                activeTrackColor: AppColors.signal,
                onChanged: (v) => setState(() => _dualControls = v),
              ),
            ],
          ),
        ]);
      case _Section.contacts:
        return (translate('ireg_contacts_title'), [
          if (_loading)
            const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
          else ...[
            _field(_phone, translate('ireg_phone'), SolarIcons.chatRoundLineLinear, type: TextInputType.phone),
            _field(_email, translate('ireg_contact_email'), SolarIcons.letterLinear,
                type: TextInputType.emailAddress),
          ],
          _note(translate('ireg_contacts_desc')),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, fields) = _content();
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.x4 + AppSpacing.x1, AppSpacing.x6,
          AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BentoAuthCard(
                title: title,
                children: [
                  if (_error != null) ...[BentoAuthError(_error!), const SizedBox(height: AppSpacing.x3)],
                  ...fields,
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              // The sheet's own lone action: the dark ink pill (owner rule 16).
              _busy
                  ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                  : BentoActionButton(text: translate('save'), ink: true, onTap: _loading ? () {} : _save),
            ],
          ),
        ),
      ),
    );
  }
}
