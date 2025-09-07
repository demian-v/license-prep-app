import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../services/report_service.dart';
import '../services/service_locator.dart';

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

class _ReportSheetState extends State<ReportSheet> with TickerProviderStateMixin {
  // Design constants matching app theme
  static const Color primaryBlue = Colors.blue;
  static const Color primaryGreen = Colors.green;
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 12.0;
  
  // Gradients for different states
  static const LinearGradient submitButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, Color(0x66E3F2FD)], // Colors.blue.shade50.withOpacity(0.4) equivalent
  );
  
  static const LinearGradient disabledButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFBDBDBD), Color(0xFF9E9E9E)],
  );
  
  static const LinearGradient dragHandleGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)],
  );

  ReportReason? _reason;
  final _ctrl = TextEditingController();
  bool _submitting = false;
  
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

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
    _scaleController.dispose();
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
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 6,
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
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 6,
          ),
        );
      }
    }
  }

  Widget _buildRadioOption({
    required ReportReason value,
    required String title,
    required bool isLast,
  }) {
    final isSelected = _reason == value;
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: isSelected 
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.purple.shade50.withOpacity(0.4)], // Like "Збережені" card
            )
          : null,
        borderRadius: isLast 
          ? BorderRadius.only(
              bottomLeft: Radius.circular(cardBorderRadius),
              bottomRight: Radius.circular(cardBorderRadius),
            )
          : null,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          radioTheme: RadioThemeData(
            fillColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.purple.shade600;
              }
              return Colors.grey.shade400;
            }),
          ),
        ),
        child: RadioListTile<ReportReason>(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? Colors.purple.shade700 : Colors.grey.shade800,
            ),
          ),
          value: value,
          groupValue: _reason,
          onChanged: (v) {
            setState(() => _reason = v);
            // Add subtle haptic feedback
            // HapticFeedback.selectionClick(); // Uncomment if you want haptic feedback
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          dense: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced drag handle
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: dragHandleGradient,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Enhanced title
              Text(
                AppLocalizations.of(context).translate('report_issue'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 24),

              // Enhanced radio buttons section
              Card(
                elevation: 3,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(cardBorderRadius),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cardBorderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cardBackground,
                        cardBackground.withOpacity(0.95),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildRadioOption(
                        value: ReportReason.image,
                        title: AppLocalizations.of(context).translate('issue_with_image'),
                        isLast: false,
                      ),
                      Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _buildRadioOption(
                        value: ReportReason.translation,
                        title: AppLocalizations.of(context).translate('issue_with_text_translation'),
                        isLast: false,
                      ),
                      Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                        indent: 20,
                        endIndent: 20,
                      ),
                      _buildRadioOption(
                        value: ReportReason.other,
                        title: AppLocalizations.of(context).translate('other_issue'),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),

              // Enhanced text field for "Other" option
              if (_reason == ReportReason.other) ...[
                const SizedBox(height: 20),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cardBorderRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: 4,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Roboto',
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).translate('describe_issue'),
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.all(16),
                        helperText: '${_ctrl.text.trim().length}/10 minimum',
                        helperStyle: TextStyle(
                          color: _ctrl.text.trim().length >= 10 
                            ? primaryGreen 
                            : Colors.grey.shade600,
                          fontWeight: _ctrl.text.trim().length >= 10 
                            ? FontWeight.w500 
                            : FontWeight.normal,
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Enhanced submit button
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: _submitting || !_canSubmit 
                      ? disabledButtonGradient 
                      : submitButtonGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: _submitting || !_canSubmit 
                      ? []
                      : [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.3),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _submitting || !_canSubmit ? null : () {
                        _scaleController.forward().then((_) {
                          _scaleController.reverse();
                          _submit();
                        });
                      },
                      borderRadius: BorderRadius.circular(30),
                      splashColor: Colors.white.withOpacity(0.2),
                      highlightColor: Colors.white.withOpacity(0.1),
                      child: Container(
                        alignment: Alignment.center,
                        child: _submitting
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                AppLocalizations.of(context).translate('submit'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  fontFamily: 'Roboto',
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
