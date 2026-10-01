import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';
import '../widgets/bento_choice_card.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import 'instructor_kind_screen.dart';
import 'language_selection_screen.dart';

/// Who is signing up (instructors plan v2 §4.1). Owner, 2026-09-30:
/// Sign Up -> Check email -> this -> language. Reached after the email code
/// (SignupScreen, SignupResumeGate), so the account already exists; the
/// answer is saved on the server once, and only a student's trial starts
/// here — an instructor must not spend the device's only trial.
///
/// Student is the page's blue hero (the common case), instructor the smaller
/// `ink` card, under the logo like login and signup. No arrows (rule 7), and
/// no way back: the account is made.
class RoleChoiceScreen extends StatefulWidget {
  const RoleChoiceScreen({super.key});

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _choose(String role, String? kind) async {
    final l = AppLocalizations.of(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.chooseSignupRole(role, kind, context: context);
      if (role == 'student') {
        analyticsService.logSignupTrialStarted(
          userId: auth.user?.id,
          signupMethod: 'email',
          trialType: '3_day_free_trial',
          trialDays: 3,
        );
      }
      navigator.pushReplacement(MaterialPageRoute(builder: (_) => LanguageSelectionScreen()));
    } catch (e) {
      debugPrint('RoleChoiceScreen: saving the role failed: $e');
      if (mounted) setState(() => _error = l.translate('auth_error_network'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _instructor() async {
    final kind = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const InstructorKindScreen()),
    );
    if (kind != null && mounted) await _choose('instructor', kind);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final blocks = <Widget>[
      // As on login and signup (owner, 2026-09-30): the logo above, then the
      // question as the page's heading.
      bentoAuthLogo(l.translate('auth_app_title')),
      const SizedBox(height: AppSpacing.x6),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          l.translate('role_choice_title'),
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
      if (_error != null) ...[BentoAuthError(_error!), const SizedBox(height: AppSpacing.x3)],
      BentoChoiceCard(
        tone: BentoChoiceTone.hero,
        icon: SolarIcons.squareAcademicCapBold,
        title: l.translate('role_student_title'),
        description: l.translate('role_student_desc'),
        pills: [
          l.translate('role_pill_tests'),
          l.translate('role_pill_theory'),
          l.translate('role_pill_schools'),
        ],
        onTap: _busy ? null : () => _choose('student', null),
      ),
      const SizedBox(height: AppSpacing.x3),
      BentoChoiceCard(
        tone: BentoChoiceTone.ink,
        icon: SolarIcons.carLinear,
        title: l.translate('role_instructor_title'),
        description: l.translate('role_instructor_desc'),
        onTap: _busy ? null : _instructor,
      ),
      if (_busy) ...[
        const SizedBox(height: AppSpacing.x4),
        const Center(child: CircularProgressIndicator()),
      ],
    ];

    // The auth pages' layout: the group centred, scrolling if it has to.
    return Scaffold(
      backgroundColor: AppColors.field,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4 + AppSpacing.x1,
              vertical: AppSpacing.x6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < blocks.length; i++)
                  StaggerIn(index: i, count: blocks.length, curve: BentoTokens.curve, child: blocks[i]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
