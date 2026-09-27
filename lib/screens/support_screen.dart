import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import '../services/report_service.dart';
import '../services/service_locator.dart';
import '../theme/solar_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../widgets/bento_result_parts.dart';

class SupportScreen extends StatefulWidget {
  @override
  _SupportScreenState createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  // The four delayed entrance/press controllers were replaced by a one-shot
  // StaggerIn and PressScale (2026-09-26, Bento).

  bool get _canSubmit => _messageController.text.trim().length >= 10;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final reportService = serviceLocator.report;

      await reportService.submitSupportReport(
        message: _messageController.text.trim(),
        language: languageProvider.language,
        state: authProvider.user?.state ?? 'unknown',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.paper,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(SolarIcons.checkLinear, color: AppColors.guide, size: 16),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).translate('support_thanks'),
                      style: AppTypography.label.copyWith(
                        fontSize: 15,
                        color: AppColors.onSignal,
                        fontVariations: const [FontVariation('wght', 600)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: AppColors.guide,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = AppLocalizations.of(context).translate('support_error');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // In the Тесты look (2026-09-26): a blue hero saying what this page is,
    // the message as a white card, then the actions — the dark pill sends.
    final blocks = <Widget>[
      _buildEnhancedInfoSection(),
      const SizedBox(height: AppSpacing.x8),
      _buildSectionHeader(
        l.translate('message_details').replaceFirst(RegExp(r'\s*:\s*$'), ''),
      ),
      _buildEnhancedMessageSection(),
      const SizedBox(height: AppSpacing.x4),
      // Error message
      if (_errorMessage != null) ...[
        _buildEnhancedErrorMessage(),
        const SizedBox(height: AppSpacing.x3),
      ],
      _buildEnhancedActionButtons(),
      const SizedBox(height: AppSpacing.x4),
      // Fine print
      Text(
        l.translate('support_response_info'),
        style: AppTypography.caption.copyWith(
          fontSize: 13,
          height: 18 / 13,
          color: AppColors.inkSecondary,
          fontVariations: const [FontVariation('wght', 400)],
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.x6),
      // Attribution the Solar icon licence (CC BY 4.0) requires.
      // Proper names and a licence id, so it is not translated.
      Text(
        'Icons: Solar by 480 Design · CC BY 4.0',
        style: AppTypography.caption.copyWith(
          color: AppColors.inkSecondary,
          fontVariations: const [FontVariation('wght', 400)],
        ),
        textAlign: TextAlign.center,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(
        title: l.translate('support_title'),
        onBack: () => Navigator.maybePop(context),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.x4 + AppSpacing.x1,
          AppSpacing.x2,
          AppSpacing.x4 + AppSpacing.x1,
          AppSpacing.x6 + MediaQuery.of(context).padding.bottom,
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
    );
  }

  /// A section label, as on Тесты: 15/600 ink, 12 below.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Text(
        title,
        style: AppTypography.label.copyWith(
          fontSize: 15,
          color: AppColors.ink,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
    );
  }

  /// The page's hero, in the Тесты exam card's blue: the headphones on a
  /// white disc, «Связаться с поддержкой», one line under it, and the faint
  /// bar strip behind.
  Widget _buildEnhancedInfoSection() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BentoTokens.card),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.signal600, AppColors.signal, AppColors.signal400],
          stops: [0, 0.55, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x290048C3),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: AppSpacing.x4 + AppSpacing.x1,
            bottom: 0,
            child: ExcludeSemantics(child: _heroBars()),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.paper,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    SolarIcons.headphonesRoundSoundLinear,
                    color: AppColors.signal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // One line; a long translation shrinks rather than wraps.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context).translate('contact_support'),
                          maxLines: 1,
                          style: AppTypography.title.copyWith(
                            fontSize: 22,
                            height: 28 / 22,
                            color: AppColors.onSignal,
                            fontVariations: const [FontVariation('wght', 700)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context).translate('support_desc'),
                        style: AppTypography.label.copyWith(
                          color: AppColors.signal100,
                          fontVariations: const [FontVariation('wght', 400)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The exam card's bar strip (`EnhancedTestCard._questionBars`, frozen —
  /// copied), larger and fainter, as on the Профиль hero.
  Widget _heroBars() {
    const heights = [
      10, 16, 12, 22, 14, 26, 18, 30, 20, 34, 24, 28, 38, 26, 42, 30, 36, 46,
      32, 40, 50, 36, 44, 54, 40, 48, 58, 44, 52, 60, 48, 56, 62, 52, 58, 64,
      56, 60, 66, 62,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in heights)
          Container(
            width: 3,
            height: h * 1.5,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: AppColors.onSignal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }

  /// The message as a white card: the text field, and the character count
  /// as a pill in its bottom-right corner — green once there is enough to
  /// send (enough = done), grey before.
  Widget _buildEnhancedMessageSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: TextField(
              controller: _messageController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: AppTypography.body.copyWith(
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).translate('support_message_placeholder'),
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.inkSecondary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _buildEnhancedCharacterCounter(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedCharacterCounter() {
    return AnimatedContainer(
      duration: AppMotion.duration(context, BentoTokens.state),
      curve: AppMotion.enter,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2 + 2,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: _canSubmit ? AppColors.guideSurface : AppColors.field,
        borderRadius: BorderRadius.circular(BentoTokens.chip),
      ),
      child: Text(
        AppLocalizations.of(context).translate('character_counter').replaceAll('{0}', _messageController.text.trim().length.toString()),
        style: AppTypography.caption.copyWith(
          fontSize: 13,
          color: _canSubmit ? AppColors.guide : AppColors.inkSecondary,
          fontVariations: const [FontVariation('wght', 500)],
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildEnhancedErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.stopSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(SolarIcons.dangerCircleLinear, color: AppColors.stop, size: 20),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              _errorMessage!,
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

  Widget _buildEnhancedActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildEnhancedBackButton(),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: _buildEnhancedSendButton(),
        ),
      ],
    );
  }

  /// «Назад»: the white secondary pill.
  Widget _buildEnhancedBackButton() {
    final radius = BorderRadius.circular(BentoTokens.button);
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: radius,
          boxShadow: AppColors.shadowCard,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: radius,
            child: Center(
              child: Text(
                AppLocalizations.of(context).translate('back'),
                style: AppTypography.label.copyWith(
                  fontSize: 16,
                  color: AppColors.ink,
                  fontVariations: const [FontVariation('wght', 500)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// «Отправить»: the dark `ink` pill, as the paywall's buy button — grey
  /// until the message is long enough, a spinner while it sends.
  Widget _buildEnhancedSendButton() {
    final radius = BorderRadius.circular(BentoTokens.button);
    final enabled = !_isSubmitting && _canSubmit;
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      enabled: enabled,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, BentoTokens.state),
        curve: AppMotion.enter,
        height: 56,
        decoration: BoxDecoration(
          color: _canSubmit ? AppColors.ink : AppColors.border,
          borderRadius: radius,
          boxShadow: _canSubmit
              ? const [
                  BoxShadow(
                    color: Color(0x290E1422),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSubmitting || !_canSubmit ? null : _sendMessage,
            borderRadius: radius,
            child: Center(
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.onSignal,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      AppLocalizations.of(context).translate('support_send'),
                      style: AppTypography.label.copyWith(
                        fontSize: 16,
                        color: _canSubmit ? AppColors.onSignal : AppColors.inkTertiary,
                        fontVariations: const [FontVariation('wght', 500)],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
