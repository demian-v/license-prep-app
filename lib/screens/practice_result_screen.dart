import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/practice_provider.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/progress_provider.dart';
import '../services/analytics_service.dart';
import '../localization/app_localizations.dart';
import 'practice_question_screen.dart';
import '../theme/app_theme.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart';
import '../services/result_meme_service.dart';
import '../widgets/result_meme_picture.dart';
import '../widgets/result_share_sheet.dart';

class PracticeResultScreen extends StatefulWidget {
  @override
  _PracticeResultScreenState createState() => _PracticeResultScreenState();
}

class _PracticeResultScreenState extends State<PracticeResultScreen> {
  // Chosen once per result page, not on every rebuild.
  Future<String?>? _memeUrl;

  // Helper method to get custom result icon asset path based on result state
  String? _getResultIconAsset(bool isPassed) {
    return isPassed 
      ? 'assets/images/success_fail/success.png'
      : 'assets/images/success_fail/fail.png';
  }

  /// Analytics method for practice finished event
  Future<void> _logPracticeFinished(String completionMethod) async {
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    final practice = practiceProvider.currentPractice;
    
    if (practice != null) {
      // Get providers for analytics
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      
      // Calculate analytics parameters
      final practiceId = 'practice_${practice.startTime.millisecondsSinceEpoch}';
      final finalScore = practice.correctAnswersCount;
      final totalQuestions = practice.answeredQuestionsCount;
      final correctAnswers = practice.correctAnswersCount;
      final incorrectAnswers = practice.incorrectAnswersCount;
      final practicePassed = practice.isPassed;
      final timeSpentSeconds = practice.elapsedTime.inSeconds;
      final state = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
      final language = languageProvider.language;
      final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
      
      // Log practice finished analytics event
      await analyticsService.logPracticeFinished(
        practiceId: practiceId,
        finalScore: finalScore,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        incorrectAnswers: incorrectAnswers,
        practicePassed: practicePassed,
        timeSpentSeconds: timeSpentSeconds,
        completionMethod: completionMethod,
        state: state,
        language: language,
        licenseType: licenseType,
      );
      
      print('📊 Analytics: practice_finished logged (practice_id: $practiceId, score: $correctAnswers/$totalQuestions, passed: $practicePassed, method: $completionMethod)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final practiceProvider = Provider.of<PracticeProvider>(context);
    final practice = practiceProvider.currentPractice;
    
    if (practice == null) {
      // If no practice data, navigate back to test screen
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
    
    final correctAnswers = practice.correctAnswersCount;
    final incorrectAnswers = practice.incorrectAnswersCount;
    final isPassed = practice.isPassed;
    // Практика has no timer (timeLimit 0), so it never gets "out of time".
    final percent = ResultMemeService.percentOf(
        correctAnswers, practice.questionIds.length);
    final bucket =
        ResultMemeService.bucketFor(percent: percent, passed: isPassed);
    final memeUrl = _memeUrl ??= ResultMemeService.instance.pickUrl(bucket);
    final localizations = AppLocalizations.of(context);
    final verdict = isPassed
        ? localizations.translate('practice_passed')
        : localizations.translate('practice_not_passed');
    final tone = isPassed ? AppColors.guide : AppColors.stop;
    final toneSurface = isPassed ? AppColors.guideSurface : AppColors.stopSurface;
    
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(
        title: localizations.translate('result'),
        onBack: () => _onBack(practiceProvider),
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
          ],
        ),
        // Two actions: back as the white pill, share as the dark one (owner).
        actions: Row(
          children: [
            Expanded(
              child: BentoActionButton(
                text: localizations.translate('back_to_tests'),
                onTap: () => _onBackToTests(practiceProvider),
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
                    module: 'practice',
                    memeUrl: memeUrl,
                    fallbackAsset: _getResultIconAsset(isPassed)!,
                    verdict: verdict,
                    titleColor: tone,
                    tone: tone,
                    toneSurface: toneSurface,
                    percent: percent,
                    bucket: bucket.id,
                    passed: isPassed,
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

  Future<void> _onBack(PracticeProvider practiceProvider) async {
    // Log analytics before navigation
    await _logPracticeFinished('back_arrow');
    
    // Return to test screen
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    // Reset practice
    practiceProvider.cancelPractice();
  }

  Future<void> _onBackToTests(PracticeProvider practiceProvider) async {
    // Log analytics before navigation
    await _logPracticeFinished('back_to_tests_button');
    
    // Cancel current practice
    practiceProvider.cancelPractice();
    
    // Navigate back to test screen (home)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
