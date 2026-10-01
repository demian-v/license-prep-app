import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/state_data.dart';
import '../data/teaching_languages.dart';
import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/instructor_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../utils/state_display.dart';
import '../widgets/bento_auth_parts.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart';
import 'home_screen.dart';
import 'instructor_kind_screen.dart';

/// The instructor registration wizard (instructors plan v2 §4.3): one
/// question per page, a progress bar, the fields in one white card, «Далее»
/// at the bottom. It ends with registerAsInstructor, which grants the role.
///
/// Owner decision 2026-09-30: verification is not a wall. The last step (the
/// licence numbers) can be skipped; the profile is then listed as
/// «Не проверен» and the numbers — and later the photo and the ID check —
/// are added in Профиль.
///
/// The draft is saved on the device after every step, so an interrupted
/// signup resumes with what was typed.
class InstructorRegistrationScreen extends StatefulWidget {
  const InstructorRegistrationScreen({super.key, this.service});

  final InstructorService? service;

  static const draftKey = 'instructor_registration_draft_v1';

  @override
  State<InstructorRegistrationScreen> createState() => _InstructorRegistrationScreenState();
}

// No «About» step (owner, 2026-09-30): the description is optional and is
// added later in Профиль settings.
enum _Step { languages, location, school, car, price, contacts, license }

class _InstructorRegistrationScreenState extends State<InstructorRegistrationScreen> {
  late final InstructorService _service = widget.service ?? InstructorService();

  _Step _step = _Step.languages;
  // Which way the last step change went, for the step slide.
  bool _forward = true;
  bool _busy = false;
  String? _error;

  final Set<String> _languages = {};
  String? _state;
  bool _dualControls = true;
  final Set<int> _durations = {60};
  final _c = <String, TextEditingController>{
    for (final k in [
      'schoolName', 'city', 'zip', 'schoolAddress', 'fleetSize', 'instructorCount',
      'carModel', 'carYear', 'rate', 'phone', 'email', 'schoolLicense', 'instructorLicense',
    ])
      k: TextEditingController(),
  };
  final _stateText = TextEditingController();
  final _stateFocus = FocusNode();

  String get _kind =>
      Provider.of<AuthProvider>(context, listen: false).user?.signupKind ?? 'school';
  bool get _isSchool => _kind == 'school';

  // A private instructor has no School step (owner, 2026-09-30): the school,
  // if any, is added later in Профиль settings.
  List<_Step> get _steps => _isSchool ? _Step.values : [for (final s in _Step.values) if (s != _Step.school) s];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _stateText.dispose();
    _stateFocus.dispose();
    super.dispose();
  }

  // ── Draft ─────────────────────────────────────────────────────────────────

  Future<void> _restoreDraft() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(InstructorRegistrationScreen.draftKey);
    if (!mounted) return;
    setState(() {
      if (raw != null) {
        final d = jsonDecode(raw) as Map<String, dynamic>;
        final saved = _Step.values[(d['step'] as int? ?? 0).clamp(0, _Step.values.length - 1)];
        _step = _steps.contains(saved) ? saved : _Step.languages;
        _languages.addAll(List<String>.from(d['languages'] ?? const []));
        _state = d['state'] as String?;
        if (_state != null) _stateText.text = stateDisplayName(_state!);
        _dualControls = d['dualControls'] as bool? ?? true;
        _durations
          ..clear()
          ..addAll(List<int>.from(d['durations'] ?? const [60]));
        (d['fields'] as Map? ?? const {}).forEach((k, v) => _c[k]?.text = v as String);
      }
      // A school is registered under the school's name, which the signup form
      // did not ask for; an instructor's own name is the account name.
      if (_c['email']!.text.isEmpty) _c['email']!.text = user?.email ?? '';
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      InstructorRegistrationScreen.draftKey,
      jsonEncode({
        'step': _step.index,
        'languages': _languages.toList(),
        'state': _state,
        'dualControls': _dualControls,
        'durations': _durations.toList(),
        'fields': {for (final e in _c.entries) e.key: e.value.text},
      }),
    );
  }

  // ── Validation (mirrors registerAsInstructor) ─────────────────────────────

  // Named `translate` so localization_coverage_test sees every key literal.
  String translate(String key) => AppLocalizations.of(context).translate(key);

  bool _len(String key, int min, int max) {
    final v = _c[key]!.text.trim();
    return v.length >= min && v.length <= max;
  }

  bool _intIn(String key, int min, int max) {
    final v = int.tryParse(_c[key]!.text.trim());
    return v != null && v >= min && v <= max;
  }

  /// The error for the current step (translated), or null when it can move on.
  String? _validate() {
    switch (_step) {
      case _Step.languages:
        return _languages.isEmpty ? translate('ireg_error_languages') : null;
      case _Step.location:
        if (_state == null) return translate('ireg_error_state');
        if (!_len('city', 2, 60)) return translate('ireg_error_city');
        return RegExp(r'^\d{5}$').hasMatch(_c['zip']!.text.trim()) ? null : translate('ireg_error_zip');
      case _Step.school:
        if (!_len('schoolName', 2, 80)) return translate('ireg_error_school_name');
        if (!_len('schoolAddress', 5, 120)) return translate('ireg_error_address');
        if (!_intIn('fleetSize', 1, 200) || !_intIn('instructorCount', 1, 500)) return translate('ireg_error_count');
        return null;
      case _Step.car:
        if (!_len('carModel', 2, 60)) return translate('ireg_error_car_model');
        return _intIn('carYear', 1995, DateTime.now().year + 1) ? null : translate('ireg_error_car_year');
      case _Step.price:
        if (!_intIn('rate', 20, 200)) return translate('ireg_error_rate');
        return _durations.isEmpty ? translate('ireg_error_durations') : null;
      case _Step.contacts:
        final digits = _c['phone']!.text.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 10 || digits.length > 15) return translate('ireg_error_phone');
        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_c['email']!.text.trim())
            ? null
            : translate('ireg_error_email');
      case _Step.license:
        return null; // optional
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _next({bool skipLicense = false}) async {
    final error = skipLicense ? null : _validate();
    setState(() => _error = error);
    if (error != null) return;
    if (_step == _Step.license) {
      await _submit(skipLicense: skipLicense);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = true;
      _step = _steps[_steps.indexOf(_step) + 1];
    });
    await _saveDraft();
  }

  void _back() {
    if (_step == _Step.languages) {
      // Nothing is under the wizard (the kind screen replaced itself), so
      // back reopens «How do you teach?» — maybePop did nothing here
      // (owner, 2026-09-30). The draft is kept.
      Navigator.of(context).pushReplacement(BackPageRoute(child: const InstructorKindScreen()));
    } else {
      FocusScope.of(context).unfocus();
      setState(() {
        _forward = false;
        _error = null;
        _step = _steps[_steps.indexOf(_step) - 1];
      });
    }
  }

  Future<void> _submit({required bool skipLicense}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    String v(String k) => _c[k]!.text.trim();
    final profile = <String, dynamic>{
      'kind': _kind,
      'name': _isSchool ? v('schoolName') : (auth.user?.name ?? ''),
      'languages': _languages.toList(),
      'state': _state,
      'city': v('city'),
      'zipCode': v('zip'),
      if (_isSchool) ...{
        'schoolAddress': v('schoolAddress'),
        'fleetSize': int.parse(v('fleetSize')),
        'instructorCount': int.parse(v('instructorCount')),
      },
      'carModel': v('carModel'),
      'carYear': int.parse(v('carYear')),
      'hasDualControls': _dualControls,
      'hourlyRateCents': int.parse(v('rate')) * 100,
      'lessonDurations': (_durations.toList()..sort()),
      'phone': v('phone'),
      'contactEmail': v('email'),
      if (!skipLicense && v('schoolLicense').isNotEmpty) 'schoolLicenseNumber': v('schoolLicense'),
      if (!skipLicense && !_isSchool && v('instructorLicense').isNotEmpty)
        'instructorLicenseNumber': v('instructorLicense'),
    };

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String state;
      try {
        state = await _service.register(profile);
      } on FirebaseFunctionsException catch (e) {
        // A retry after a lost response: the account is already registered.
        if (e.code != 'already-exists') rethrow;
        state = _state!;
      }
      await auth.applyInstructorRole(state);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(InstructorRegistrationScreen.draftKey);
      navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeScreen()), (_) => false);
    } catch (e) {
      debugPrint('InstructorRegistration: register failed: $e');
      if (mounted) setState(() => _error = translate('ireg_error_generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  InputDecoration _field(String label, IconData icon) => bentoFieldDecoration(label: label, icon: icon);

  Widget _text(String key, String label, IconData icon,
      {TextInputType? type,
      int? maxLength,
      int maxLines = 1,
      List<TextInputFormatter>? formatters,
      Widget? prefix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: TextField(
        controller: _c[key],
        keyboardType: type,
        maxLength: maxLength,
        maxLines: maxLines,
        inputFormatters: formatters,
        style: AppTypography.body.copyWith(color: AppColors.ink),
        decoration: prefix == null ? _field(label, icon) : _field(label, icon).copyWith(prefixIcon: prefix),
      ),
    );
  }

  /// A pill that is the dark `ink` row when chosen (owner rule 10).
  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, BentoTokens.state),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4, vertical: AppSpacing.x2 + 2),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.field,
            borderRadius: BorderRadius.circular(BentoTokens.chip),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: selected ? AppColors.onSignal : AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
        ),
      ),
    );
  }

  /// State: type to filter, then pick from the list that opens under the
  /// field (owner, 2026-09-30). Only a picked state counts; editing the text
  /// afterwards clears it until one is picked again.
  Widget _stateField() {
    final ids = StateData.releasedStateIds.toList()
      ..sort((a, b) => stateDisplayName(a).compareTo(stateDisplayName(b)));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: LayoutBuilder(
        builder: (context, box) => RawAutocomplete<String>(
          textEditingController: _stateText,
          focusNode: _stateFocus,
          displayStringForOption: stateDisplayName,
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            // The field still shows the picked state: offer them all.
            if (_state != null && value.text == stateDisplayName(_state!)) return ids;
            return ids.where((id) => stateDisplayName(id).toLowerCase().contains(q) || id.toLowerCase() == q);
          },
          onSelected: (id) {
            setState(() => _state = id);
            _stateFocus.unfocus();
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.words,
            // A state name is picked from the list; iOS suggestions only cover it.
            autocorrect: false,
            enableSuggestions: false,
            style: AppTypography.body.copyWith(color: AppColors.ink),
            decoration: _field(translate('ireg_state'), SolarIcons.mapPointBold).copyWith(
              suffixIcon: const Icon(SolarIcons.altArrowDownLinear, color: AppColors.inkSecondary, size: 20),
            ),
            // Tapping a filled field selects the name, so typing replaces it.
            onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
            onChanged: (v) {
              if (_state != null && v != stateDisplayName(_state!)) setState(() => _state = null);
            },
            onSubmitted: (_) => onSubmitted(),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: box.maxWidth,
              constraints: const BoxConstraints(maxHeight: 264),
              margin: const EdgeInsets.only(top: AppSpacing.x1),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppColors.shadowCard,
              ),
              clipBehavior: Clip.antiAlias,
              child: _OptionsScrollbar(
                builder: (controller) => Material(
                  type: MaterialType.transparency,
                  child: ListView(
                    controller: controller,
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(AppSpacing.x2),
                    children: [
                      for (final id in options)
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          onTap: () => onSelected(id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x3),
                            decoration: BoxDecoration(
                              color: id == _state ? AppColors.ink : null,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Text(
                              stateDisplayName(id),
                              style: AppTypography.body.copyWith(
                                color: id == _state ? AppColors.onSignal : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, String, List<Widget>) _page() {
    switch (_step) {
      case _Step.languages:
        return (translate('ireg_languages_title'), translate('ireg_languages_desc'), [
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              for (final (code, name) in teachingLanguages)
                _choice(name, _languages.contains(code), () => setState(() {
                      _languages.contains(code) ? _languages.remove(code) : _languages.add(code);
                    })),
            ],
          ),
        ]);
      case _Step.location:
        return (translate('ireg_location_title'), translate('ireg_location_desc'), [
          _stateField(),
          _text('city', translate('ireg_city'), SolarIcons.mapPointBold),
          _text('zip', translate('ireg_zip'), SolarIcons.letterLinear,
              type: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)]),
        ]);
      case _Step.school:
        return (
          translate('ireg_school_title'),
          translate('ireg_school_desc_school'),
          [
            _text('schoolName', translate('ireg_school_name'), SolarIcons.squareAcademicCapBold),
            _text('schoolAddress', translate('ireg_school_address'), SolarIcons.mapPointBold),
            _text('fleetSize', translate('ireg_fleet_size'), SolarIcons.carLinear,
                type: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly]),
            _text('instructorCount', translate('ireg_instructor_count'), SolarIcons.userRoundedLinear,
                type: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly]),
          ]
        );
      case _Step.car:
        return (translate('ireg_car_title'), translate('ireg_car_desc'), [
          _text('carModel', translate('ireg_car_model'), SolarIcons.carLinear),
          _text('carYear', translate('ireg_car_year'), SolarIcons.clockCircleLinear,
              type: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)]),
          Row(
            children: [
              Expanded(
                child: Text(translate('ireg_dual_controls'),
                    style: AppTypography.body.copyWith(color: AppColors.ink)),
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
      case _Step.price:
        return (translate('ireg_price_title'), translate('ireg_price_desc'), [
          _text('rate', translate('ireg_hourly_rate'), SolarIcons.medalRibbonsStarBold,
              // The font subset has no money glyph; a "$" in the icon slot
              // says "price" better than the old medal.
              prefix: SizedBox(
                width: 48,
                child: Center(
                  child: Text('\$',
                      style: AppTypography.body.copyWith(
                        fontSize: 20,
                        color: AppColors.inkSecondary,
                        fontVariations: const [FontVariation('wght', 600)],
                      )),
                ),
              ),
              type: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)]),
          Text(translate('ireg_durations'), style: AppTypography.label.copyWith(color: AppColors.inkSecondary)),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: AppSpacing.x2,
            children: [
              for (final m in const [60, 90, 120])
                _choice(translate('ireg_minutes').replaceAll('{n}', '$m'), _durations.contains(m), () => setState(() {
                      _durations.contains(m) ? _durations.remove(m) : _durations.add(m);
                    })),
            ],
          ),
        ]);
      case _Step.contacts:
        return (translate('ireg_contacts_title'), translate('ireg_contacts_desc'), [
          _text('phone', translate('ireg_phone'), SolarIcons.chatRoundLineLinear, type: TextInputType.phone),
          _text('email', translate('ireg_contact_email'), SolarIcons.letterLinear, type: TextInputType.emailAddress),
        ]);
      case _Step.license:
        return (translate('ireg_license_title'), translate('ireg_license_desc'), [
          _text('schoolLicense', translate('ireg_school_license'), SolarIcons.documentTextLinear),
          if (!_isSchool) _text('instructorLicense', translate('ireg_instructor_license'), SolarIcons.documentTextLinear),
          // Not a driver's licence: that one is read by the identity check.
          Text(
            _isSchool ? translate('ireg_license_note_school') : translate('ireg_license_note_private'),
            style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
          ),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, description, fields) = _page();
    final last = _step == _Step.license;
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(title: title, onBack: _busy ? () {} : _back),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Progress: one segment per step, filled up to the current one.
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.x4 + AppSpacing.x1, AppSpacing.x1,
                  AppSpacing.x4 + AppSpacing.x1, AppSpacing.x3),
              child: Row(
                children: [
                  for (var i = 0; i < _steps.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.x1),
                    Expanded(
                      child: AnimatedContainer(
                        duration: AppMotion.duration(context, BentoTokens.state),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _steps.indexOf(_step) ? AppColors.signal : AppColors.border,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              // Steps slide in from the side you are heading to, and the
              // one leaving recedes the other way (owner, 2026-09-30: steps
              // swapped with no motion).
              child: AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.base),
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey(_step);
                  final dx = (incoming ? 0.06 : 0.03) * (_forward == incoming ? 1 : -1);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: ListView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4 + AppSpacing.x1),
                  children: [
                    Text(description, style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
                    const SizedBox(height: AppSpacing.x3),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(BentoTokens.card),
                        boxShadow: AppColors.shadowCard,
                      ),
                      // Keyed by step: without it Flutter reuses the text
                      // field at the same position on the next step, and its
                      // focus (the keyboard) carries over untapped.
                      child: Column(
                        key: ValueKey(_step),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            BentoAuthError(_error!),
                            const SizedBox(height: AppSpacing.x4),
                          ],
                          ...fields,
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                  ],
                  ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.x4 + AppSpacing.x1, AppSpacing.x2,
                  AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4),
              child: _busy
                  ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                  : last
                      ? Row(
                          children: [
                            Expanded(
                              child: BentoActionButton(
                                text: translate('skip'),
                                primary: false,
                                onTap: () => _next(skipLicense: true),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x3),
                            // The account exists by now (owner, 2026-09-30): this finishes the profile.
                            Expanded(child: BentoActionButton(text: translate('ireg_done'), onTap: _next)),
                          ],
                        )
                      : BentoActionButton(text: translate('next'), onTap: _next),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dropdown's scrollbar, styled like the Профиль state picker's.
class _OptionsScrollbar extends StatefulWidget {
  const _OptionsScrollbar({required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<_OptionsScrollbar> createState() => _OptionsScrollbarState();
}

class _OptionsScrollbarState extends State<_OptionsScrollbar> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      controller: _controller,
      thumbVisibility: true,
      thickness: 4,
      radius: const Radius.circular(2),
      thumbColor: AppColors.inkTertiary.withValues(alpha: 0.5),
      child: widget.builder(_controller),
    );
  }
}
