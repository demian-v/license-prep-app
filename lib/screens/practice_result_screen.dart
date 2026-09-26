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

class PracticeResultScreen extends StatefulWidget {
  @override
  _PracticeResultScreenState createState() => _PracticeResultScreenState();
}

class _PracticeResultScreenState extends State<PracticeResultScreen> {
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
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(
        title: localizations.translate('result'),
        onBack: () => _onBack(practiceProvider),
      ),
      body: BentoResultBody(
        verdict: BentoVerdictCard(
          pictureAsset: _getResultIconAsset(isPassed)!,
          fallbackIcon: isPassed ? SolarIcons.cupStarBold : SolarIcons.forbiddenCircleLinear,
          title: isPassed
              ? localizations.translate('practice_passed')
              : localizations.translate('practice_not_passed'),
          tone: isPassed ? AppColors.guide : AppColors.stop,
          toneSurface: isPassed ? AppColors.guideSurface : AppColors.stopSurface,
          titleColor: isPassed ? AppColors.guide : AppColors.stop,
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
        actions: SizedBox(
          width: double.infinity,
          child: BentoActionButton(
            text: localizations.translate('back_to_tests'),
            onTap: () => _onBackToTests(practiceProvider),
          ),
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
