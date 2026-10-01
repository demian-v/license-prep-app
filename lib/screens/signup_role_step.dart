import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bento_auth_parts.dart';
import 'instructor_kind_screen.dart';
import 'language_selection_screen.dart';
import 'role_choice_screen.dart';

/// Which Sign Up the person used — «Create Student Account» or «Create
/// Instructor Account» (owner, 2026-09-30) — kept on the phone until the
/// role is saved, so closing the app before the email code does not lose it.
class SignupIntent {
  static const _key = 'signup_intent_v1';

  static Future<void> save(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({'uid': uid, 'role': role}));
  }

  /// The role chosen for [uid], or null if this phone does not know it.
  static Future<String?> read(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final d = jsonDecode(raw) as Map<String, dynamic>;
    return d['uid'] == uid ? d['role'] as String? : null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Saves the role on the server (set once), starts a student's trial, and
/// goes on to the language question. Throws if the server refuses.
Future<void> completeSignupRole(BuildContext context, String role, String? kind) async {
  final auth = Provider.of<AuthProvider>(context, listen: false);
  final navigator = Navigator.of(context);
  await auth.chooseSignupRole(role, kind, context: context);
  if (role == 'student') {
    analyticsService.logSignupTrialStarted(
      userId: auth.user?.id,
      signupMethod: 'email',
      trialType: '3_day_free_trial',
      trialDays: 3,
    );
  }
  await SignupIntent.clear();
  // Nothing behind language is worth going back to: the account is made.
  navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LanguageSelectionScreen()), (_) => false);
}

/// The step after the email code (Sign Up → Check email → this → Language).
/// A student's role is saved straight away; an instructor picks a kind
/// first. [role] comes from the Sign Up page; when it is unknown (a resumed
/// signup) the phone's [SignupIntent] is used, and only if this phone never
/// saw the Sign Up page does the person get the role cards.
class SignupRoleStep extends StatefulWidget {
  const SignupRoleStep({super.key, this.role});

  final String? role;

  @override
  State<SignupRoleStep> createState() => _SignupRoleStepState();
}

class _SignupRoleStepState extends State<SignupRoleStep> {
  String? _role;
  bool _resolved = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _role = widget.role;
    _resolved = _role != null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_role == null) {
      final uid = Provider.of<AuthProvider>(context, listen: false).user?.id;
      final saved = uid == null ? null : await SignupIntent.read(uid);
      if (!mounted) return;
      setState(() {
        _role = saved;
        _resolved = true;
      });
    }
    if (_role == 'student') await _saveStudent();
  }

  Future<void> _saveStudent() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await completeSignupRole(context, 'student', null);
    } catch (e) {
      debugPrint('SignupRoleStep: saving the role failed: $e');
      if (mounted) setState(() => _error = l.translate('auth_error_network'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_role == 'instructor') return const InstructorKindScreen();
    if (_role == null) return const RoleChoiceScreen();
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.field,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
            child: _error == null || _busy
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BentoAuthError(_error!),
                      const SizedBox(height: AppSpacing.x4),
                      BentoAuthPrimaryButton(label: l.translate('try_again'), onPressed: _saveStudent),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
