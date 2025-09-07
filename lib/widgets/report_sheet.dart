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
            content: Text(AppLocalizations.of(context).translate('report_thanks')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('report_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              AppLocalizations.of(context).translate('report_issue'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Radio buttons
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  RadioListTile<ReportReason>(
                    title: Text(
                      AppLocalizations.of(context).translate('issue_with_image'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    value: ReportReason.image,
                    groupValue: _reason,
                    onChanged: (v) => setState(() => _reason = v),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Divider(height: 1, color: Colors.grey[300]),
                  RadioListTile<ReportReason>(
                    title: Text(
                      AppLocalizations.of(context).translate('issue_with_text_translation'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    value: ReportReason.translation,
                    groupValue: _reason,
                    onChanged: (v) => setState(() => _reason = v),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Divider(height: 1, color: Colors.grey[300]),
                  RadioListTile<ReportReason>(
                    title: Text(
                      AppLocalizations.of(context).translate('other_issue'),
                      style: const TextStyle(fontSize: 16),
                    ),
                    value: ReportReason.other,
                    groupValue: _reason,
                    onChanged: (v) => setState(() => _reason = v),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ],
              ),
            ),

            // Text field for "Other" option
            if (_reason == ReportReason.other) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _ctrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).translate('describe_issue'),
                  border: const OutlineInputBorder(),
                  helperText: '${_ctrl.text.trim().length}/10 minimum',
                ),
                onChanged: (value) => setState(() {}),
              ),
            ],

            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting || !_canSubmit ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        AppLocalizations.of(context).translate('submit'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
