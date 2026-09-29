import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/exam_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../providers/auth_provider.dart';
import '../localization/app_localizations.dart';
import '../services/analytics_service.dart';
import 'exam_question_screen.dart';
import '../theme/app_theme.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart';
import '../services/result_meme_service.dart';
import '../widgets/result_meme_picture.dart';
import '../widgets/result_share_sheet.dart';

class ExamResultScreen extends StatefulWidget {
  @override
  _ExamResultScreenState createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  // Chosen once per result page, not on every rebuild.
  Future<String?>? _memeUrl;

  // Helper method to get custom result icon asset path based on result state
  String? _getResultIconAsset(bool isPassed) {
    return isPassed 
      ? 'assets/images/success_fail/success.png'
      : 'assets/images/success_fail/fail.png';
  }

  Future<void> _logExamFinished(String completionMethod) async {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final exam = examProvider.currentExam;
    
    if (exam != null) {
      // Get providers for analytics
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Calculate analytics parameters
      final examId = 'exam_${exam.startTime.millisecondsSinceEpoch}';
      final finalScore = exam.correctAnswersCount;
      final totalQuestions = exam.questionIds.length;
      final correctAnswers = exam.correctAnswersCount;
      final incorrectAnswers = exam.incorrectAnswersCount;
      final examPassed = exam.isPassed;
      final timeSpentSeconds = exam.elapsedTime.inSeconds;
      final state = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
      final language = languageProvider.language;
      final licenseType = 'driver'; // Default license type
      
      // Log exam finished analytics event
      await analyticsService.logExamFinished(
        examId: examId,
        finalScore: finalScore,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        incorrectAnswers: incorrectAnswers,
        examPassed: examPassed,
        timeSpentSeconds: timeSpentSeconds,
        completionMethod: completionMethod,
        state: state,
        language: language,
        licenseType: licenseType,
      );
      
      print('📊 Analytics: exam_finished logged (exam_id: $examId, score: $correctAnswers/$totalQuestions, passed: $examPassed, method: $completionMethod)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    final exam = examProvider.currentExam;
    
    if (exam == null) {
      // If no exam data, navigate back to test screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
      
      return Scaffold(
        backgroundColor: AppColors.field,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final correctAnswers = exam.correctAnswersCount;
    final incorrectAnswers = exam.incorrectAnswersCount;
    final isPassed = exam.isPassed;
    final percent =
        ResultMemeService.percentOf(correctAnswers, exam.questionIds.length);
    // The timer completed the exam (completeExam() at the time limit) and the
    // pass mark was not reached — a pass always keeps the win picture.
    final outOfTime = !isPassed && ResultMemeService.ranOutOfTime(exam);
    final bucket = ResultMemeService.bucketFor(
      percent: percent,
      passed: isPassed,
      outOfTime: outOfTime,
    );
    final memeUrl = _memeUrl ??= ResultMemeService.instance.pickUrl(bucket);
    
    // Format elapsed time
    final elapsedTime = exam.elapsedTime;
    final minutes = elapsedTime.inMinutes;
    final seconds = elapsedTime.inSeconds % 60;
    final timeText = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    final localizations = AppLocalizations.of(context);
    final verdict = isPassed
        ? localizations.translate('exam_passed')
        : localizations.translate('exam_not_passed');
    final tone = isPassed ? AppColors.guide : AppColors.stop;
    final toneSurface = isPassed ? AppColors.guideSurface : AppColors.stopSurface;
    final timeUpLabel = outOfTime ? localizations.translate('time_is_up') : null;
    
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(
        title: localizations.translate('result'),
        onBack: () => _onBack(examProvider),
      ),
      body: BentoResultBody(
        verdict: BentoVerdictCard(
          picture: ResultMemePicture(
            url: memeUrl,
            fallbackAsset: _getResultIconAsset(isPassed)!,
            toneSurface: toneSurface,
          ),
          title: verdict,
          titleColor: tone,
          score: '$percent%',
          tone: tone,
          toneSurface: toneSurface,
          timeUpLabel: timeUpLabel,
        ),
        stats: BentoStatRow(
          tiles: [
            BentoStatTile(
              icon: SolarIcons.checkCircleBold,
              value: correctAnswers.toString(),
              label: localizations.translate('correct'),
              color: AppColors.guide,
            ),
            BentoStatTile(
              icon: SolarIcons.closeCircleBold,
              value: incorrectAnswers.toString(),
              label: localizations.translate('incorrect'),
              color: AppColors.stop,
            ),
            // Time is neutral: it is neither right nor wrong.
            BentoStatTile(
              icon: SolarIcons.stopwatchLinear,
              value: timeText,
              label: localizations.translate('time'),
            ),
          ],
        ),
        // Two actions: back as the white pill, share as the dark one (owner).
        actions: Row(
          children: [
            Expanded(
              child: BentoActionButton(
                text: localizations.translate('back_to_tests'),
                onTap: () => _onBackToTests(examProvider),
                primary: false,
              ),
            ),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: BentoInkButton(
                text: localizations.translate('share'),
                onTap: () => showResultShareSheet(
                  context,
                  ResultShareData(
                    module: 'exam',
                    memeUrl: memeUrl,
                    fallbackAsset: _getResultIconAsset(isPassed)!,
                    verdict: verdict,
                    titleColor: tone,
                    tone: tone,
                    toneSurface: toneSurface,
                    percent: percent,
                    bucket: bucket.id,
                    passed: isPassed,
                    timeUpLabel: timeUpLabel,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation handlers, moved unchanged from the inline closures.

  Future<void> _onBack(ExamProvider examProvider) async {
    // Log analytics before navigation
    await _logExamFinished('back_arrow');
    
    // Return to test screen
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    // Reset exam
    examProvider.cancelExam();
  }

  Future<void> _onBackToTests(ExamProvider examProvider) async {
    // Log analytics before navigation
    await _logExamFinished('back_to_tests_button');
    
    // Cancel current exam
    examProvider.cancelExam();
    
    // Navigate back to test screen (home)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
