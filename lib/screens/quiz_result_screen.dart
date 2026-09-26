import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz_topic.dart';
import '../localization/app_localizations.dart';
import '../services/analytics_service.dart';
import '../services/service_locator.dart';
import '../providers/state_provider.dart';
import '../theme/app_theme.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart';

class QuizResultScreen extends StatefulWidget {
  final QuizTopic topic;
  final Map<String, bool> answers;
  final bool isTopicMode;
  final String? sessionId;
  final DateTime? startTime;
  
  const QuizResultScreen({
    Key? key,
    required this.topic,
    required this.answers,
    this.isTopicMode = false,
    this.sessionId,
    this.startTime,
  }) : super(key: key);

  @override
  _QuizResultScreenState createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  int get _correctAnswers => widget.answers.values.where((result) => result).length;
  int get _totalQuestions => widget.answers.length;
  // Nothing answered (every question skipped) is 0%, not 0/0 = NaN — which
  // used to reach the q_topic_finished analytics event.
  double get _accuracyPercentage =>
      _totalQuestions == 0 ? 0 : (_correctAnswers / _totalQuestions) * 100;

  /// A topic run earns the trophy on the same bar as Экзамен and Практика:
  /// 90% of the topic's questions answered correctly. Skipped questions count
  /// against it, so one right answer and fourteen skips is not a trophy.
  /// (It showed the trophy for any score, 0 included, until 2026-09-26.)
  bool get _isPassed {
    final total = widget.topic.questionCount > 0
        ? widget.topic.questionCount
        : _totalQuestions;
    return total > 0 && _correctAnswers >= (total * 0.9).ceil();
  }
  int get _timeSpentSeconds {
    if (widget.startTime != null) {
      return DateTime.now().difference(widget.startTime!).inSeconds;
    }
    return 0;
  }

  Future<void> _trackTopicFinished(String completionMethod) async {
    if (widget.isTopicMode && widget.sessionId != null) {
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      await serviceLocator.analytics.trackQTopicFinished(
        sessionId: widget.sessionId!,
        stateId: stateProvider.selectedState?.id ?? 'unknown',
        licenseType: 'cdl',
        topicId: widget.topic.id,
        topicName: widget.topic.title,
        correctAnswers: _correctAnswers,
        totalQuestions: _totalQuestions,
        timeSpentSeconds: _timeSpentSeconds,
        completionMethod: completionMethod,
        accuracyPercentage: _accuracyPercentage,
      );
    }
  }

  // Helper method to get custom result icon asset path for Learn by Topics:
  // the trophy when passed, the same "not passed" picture as the other
  // result pages otherwise.
  String? _getLearnByTopicsIconAsset() {
    return _isPassed
        ? 'assets/images/success_fail/learn_by_topics.png'
        : 'assets/images/success_fail/fail.png';
  }

  @override
  Widget build(BuildContext context) {
    int totalAnswered = widget.answers.length;
    int correctAnswers = widget.answers.values.where((v) => v).length;
    int incorrectAnswers = totalAnswered - correctAnswers;
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(
        title: localizations.translate('learn_by_topics'),
        onBack: _onBackToTopics,
      ),
      body: BentoResultBody(
        // The card names the topic; the picture and its disc carry the
        // verdict — green passed, red not passed.
        verdict: BentoVerdictCard(
          pictureAsset: _getLearnByTopicsIconAsset()!,
          fallbackIcon: _isPassed ? SolarIcons.cupStarBold : SolarIcons.forbiddenCircleLinear,
          title: widget.topic.title,
          tone: _isPassed ? AppColors.guide : AppColors.stop,
          toneSurface: _isPassed ? AppColors.guideSurface : AppColors.stopSurface,
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
            // The topic's full size, not just the answered ones: one right
            // answer and fourteen skips reads «1 / 15», not «1 / 1».
            BentoStatTile(
              icon: SolarIcons.questionSquareBold,
              value: (widget.topic.questionCount > 0
                      ? widget.topic.questionCount
                      : totalAnswered)
                  .toString(),
              label: localizations.translate('questions'),
            ),
          ],
        ),
        // Another topic is the likely next step, so it is the primary pill.
        actions: Row(
          children: [
            Expanded(
              child: BentoActionButton(
                text: localizations.translate('back_to_tests'),
                onTap: _onBackToTests,
                primary: false,
              ),
            ),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: BentoActionButton(
                text: localizations.translate('back_to_topics'),
                onTap: _onBackToTopics,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation handlers, moved unchanged from the inline closures.

  Future<void> _onBackToTests() async {
    await _trackTopicFinished('back_to_tests');
    // Navigate back to test screen (home)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _onBackToTopics() async {
    await _trackTopicFinished('back_to_topics');
    // Navigate back to topic selection screen (skip the question screen)
    Navigator.pop(context); // Pop quiz result screen
    Navigator.pop(context); // Pop quiz question screen to reach topic selection
  }
}
