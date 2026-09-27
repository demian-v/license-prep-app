import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../services/report_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

enum ReportReason { image, translation, other }

class ReportSheet extends StatefulWidget {
  final String contentType; // 'quiz_question' | 'theory_section'
  final Map<String, dynamic> contextData; 
  // For quiz: {questionId, language, state, topicId?, ruleReference?}
  // For theory: {topicDocId, sectionIndex, sectionTitle, language, state}

  const ReportSheet({
    super.key,
    required this.contentType,
    required this.contextData,
  });

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  ReportReason? _reason;
  final _ctrl = TextEditingController();
  bool _submitting = false;

  bool get _canSubmit {
    if (_reason == null) return false;
    if (_reason == ReportReason.other) {
      return _ctrl.text.trim().length >= 10;
    }
    return true;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    
    setState(() => _submitting = true);

    final reportService = serviceLocator.report;
    final reason = _reason!.name; // 'image' | 'translation' | 'other'

    try {
      if (widget.contentType == 'quiz_question') {
        await reportService.submitQuizReport(
          questionId: widget.contextData['questionId'],
          reason: reason,
          message: _reason == ReportReason.other ? _ctrl.text.trim() : null,
          language: widget.contextData['language'],
          state: widget.contextData['state'],
          topicId: widget.contextData['topicId'],
          ruleReference: widget.contextData['ruleReference'],
        );
      } else {
        await reportService.submitTheoryReport(
          topicDocId: widget.contextData['topicDocId'],
          sectionIndex: widget.contextData['sectionIndex'],
          sectionTitle: widget.contextData['sectionTitle'],
          reason: reason,
          message: _reason == ReportReason.other ? _ctrl.text.trim() : null,
          language: widget.contextData['language'],
          state: widget.contextData['state'],
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('report_thanks'),
            ),
            backgroundColor: AppColors.guide,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('report_error'),
            ),
            backgroundColor: AppColors.stop,
          ),
        );
      }
    }
  }

  /// A reason as a picker row, as in the language and state dialogs: a white
  /// rounded row on the field sheet; the chosen one the dark `ink` row, no
  /// radio (2026-09-26). Tapping sets the reason exactly as the radio did.
  Widget _buildRadioOption({
    required ReportReason value,
    required String title,
    required bool isLast,
  }) {
    final isSelected = _reason == value;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.x2),
      child: Semantics(
        selected: isSelected,
        inMutuallyExclusiveGroup: true,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, BentoTokens.state),
          curve: AppMotion.enter,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.ink : AppColors.paper,
            borderRadius: radius,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: () {
                setState(() => _reason = value);
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x3,
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontSize: 17,
                    color: isSelected ? AppColors.onSignal : AppColors.ink,
                    fontVariations: [FontVariation('wght', isSelected ? 600 : 400)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final count = _ctrl.text.trim().length;
    final enough = count >= 10;
    final enabled = !_submitting && _canSubmit;
    final buttonRadius = BorderRadius.circular(BentoTokens.button);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.vertical(top: Radius.circular(BentoTokens.card)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x4,
            left: AppSpacing.x4 + AppSpacing.x1,
            right: AppSpacing.x4 + AppSpacing.x1,
            top: AppSpacing.x3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x4 + AppSpacing.x1),

              Text(
                l.translate('report_issue'),
                style: AppTypography.title.copyWith(
                  fontSize: 22,
                  height: 28 / 22,
                  color: AppColors.ink,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),

              _buildRadioOption(
                value: ReportReason.image,
                title: l.translate('issue_with_image'),
                isLast: false,
              ),
              _buildRadioOption(
                value: ReportReason.translation,
                title: l.translate('issue_with_text_translation'),
                isLast: false,
              ),
              _buildRadioOption(
                value: ReportReason.other,
                title: l.translate('other_issue'),
                isLast: true,
              ),

              // Text field for "Other": a white card with the character count
              // as a pill in its corner, as on Поддержка.
              if (_reason == ReportReason.other) ...[
                const SizedBox(height: AppSpacing.x3),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x4,
                    AppSpacing.x1,
                    AppSpacing.x4,
                    AppSpacing.x3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _ctrl,
                        maxLines: 4,
                        minLines: 3,
                        style: AppTypography.body.copyWith(color: AppColors.ink),
                        decoration: InputDecoration(
                          hintText: l.translate('describe_issue'),
                          hintStyle: AppTypography.body.copyWith(
                            color: AppColors.inkSecondary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedContainer(
                          duration: AppMotion.duration(context, BentoTokens.state),
                          curve: AppMotion.enter,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x2 + 2,
                            vertical: AppSpacing.x1,
                          ),
                          decoration: BoxDecoration(
                            color: enough ? AppColors.guideSurface : AppColors.field,
                            borderRadius: BorderRadius.circular(BentoTokens.chip),
                          ),
                          child: Text(
                            // Was a hard-coded English «N/10 minimum»; the
                            // same counter key as Поддержка.
                            l.translate('character_counter').replaceAll('{0}', '$count'),
                            style: AppTypography.caption.copyWith(
                              fontSize: 13,
                              color: enough ? AppColors.guide : AppColors.inkSecondary,
                              fontVariations: const [FontVariation('wght', 500)],
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.x4 + AppSpacing.x1),

              // Submit: the dark `ink` pill, grey until a reason (and, for
              // «Другое», enough text) is given; a spinner while sending.
              PressScale(
                scale: 0.97,
                duration: BentoTokens.state,
                enabled: enabled,
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, BentoTokens.state),
                  curve: AppMotion.enter,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _canSubmit ? AppColors.ink : AppColors.border,
                    borderRadius: buttonRadius,
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
                      onTap: enabled ? _submit : null,
                      borderRadius: buttonRadius,
                      child: Center(
                        child: _submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.onSignal),
                                ),
                              )
                            : Text(
                                l.translate('submit'),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
