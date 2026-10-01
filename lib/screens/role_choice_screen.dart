import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';
import '../widgets/bento_choice_card.dart';
import '../providers/auth_provider.dart';
import 'language_selection_screen.dart';
import 'signup_role_step.dart';

/// The role cards — now only a fallback (owner, 2026-09-30). The Sign Up
/// page has «Create Student Account» / «Create Instructor Account», and
/// [SignupRoleStep] carries that answer past the email code. These cards are
/// shown only when this phone never saw the Sign Up page (a signup resumed on
/// another device), so the answer is still asked before any trial starts.
///
/// Student is the blue hero, instructor the smaller `ink` card. No arrows
/// (rule 7), no way back: the account is made.
class RoleChoiceScreen extends StatefulWidget {
  const RoleChoiceScreen({super.key});

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _student() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await completeSignupRole(context, 'student', null);
    } catch (e) {
      debugPrint('RoleChoiceScreen: saving the role failed: $e');
      if (mounted) setState(() => _error = l.translate('auth_error_network'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Like the Sign Up page's instructor version: remember it, then language,
  // which leads on to «How do you teach?» (that screen saves the role).
  Future<void> _instructor() async {
    final navigator = Navigator.of(context);
    final uid = Provider.of<AuthProvider>(context, listen: false).user?.id;
    if (uid != null) await SignupIntent.save(uid, 'instructor');
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LanguageSelectionScreen()), (_) => false);
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
        onTap: _busy ? null : _student,
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
