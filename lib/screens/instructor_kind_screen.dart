import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_choice_card.dart';
import '../widgets/bento_auth_parts.dart';

/// «Автошкола» or «Частный инструктор» (instructors plan v2 §4.1; renamed
/// from «Инструктор автошколы» by the owner, 2026-09-30).
///
/// In all 20 released states a paid lesson must be sold by a licensed
/// driving school (vault raw/drive_usa/2026-09-30-State instructor
/// requirements), so only a school takes bookings and payments; a private
/// instructor gets a profile and chat, and adds their school later in
/// Профиль. Two equal white cards — neither is the default — and the
/// licence rule stated under them.
class InstructorKindScreen extends StatelessWidget {
  const InstructorKindScreen({super.key});

  // Back to RoleChoiceScreen, which saves the answer.
  void _signup(BuildContext context, String kind) => Navigator.of(context).pop(kind);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final blocks = <Widget>[
      // The same layout as the role cards before it and signup after it.
      bentoAuthLogo(l.translate('auth_app_title')),
      const SizedBox(height: AppSpacing.x6),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          l.translate('instructor_kind_title'),
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
      BentoChoiceCard(
        icon: SolarIcons.carLinear,
        title: l.translate('kind_school_title'),
        description: l.translate('kind_school_desc'),
        pills: [l.translate('kind_pill_bookings'), l.translate('kind_pill_payments')],
        onTap: () => _signup(context, 'school'),
      ),
      const SizedBox(height: AppSpacing.x3),
      BentoChoiceCard(
        icon: SolarIcons.userRoundedLinear,
        title: l.translate('kind_school_instructor_title'),
        description: l.translate('kind_school_instructor_desc'),
        pills: [l.translate('kind_pill_profile'), l.translate('kind_pill_chat')],
        onTap: () => _signup(context, 'schoolInstructor'),
      ),
      const SizedBox(height: AppSpacing.x4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
        child: Text(
          l.translate('instructor_kind_licence_note'),
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
        ),
      ),
    ];

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
