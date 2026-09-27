import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';

class PasswordResetSuccessScreen extends StatefulWidget {
  @override
  _PasswordResetSuccessScreenState createState() => _PasswordResetSuccessScreenState();
}

class _PasswordResetSuccessScreenState extends State<PasswordResetSuccessScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final blocks = <Widget>[
      // Green: done.
      bentoAuthBadge(
        SolarIcons.checkLinear,
        tone: AppColors.guide,
        surface: AppColors.guideSurface,
      ),
      const SizedBox(height: AppSpacing.x6),
      BentoAuthCard(
        title: l.translate('auth_password_changed_title'),
        children: [
          Text(
            l.translate('auth_password_changed_message'),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              fontSize: 15,
              height: 22 / 15,
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          BentoAuthPrimaryButton(
            label: l.translate('auth_return_to_login'),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.field,
      // From the top, as the reset form before it (owner, 2026-09-26:
      // centred, the card sat too low).
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x8,
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
