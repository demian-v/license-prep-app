import 'package:flutter/material.dart';
import '../widgets/subscription_required_view.dart';
import '../providers/content_provider.dart';
import 'package:provider/provider.dart';
import '../models/quiz_topic.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/progress_provider.dart';
import '../services/service_locator.dart';
import '../services/analytics_service.dart';
import '../services/session_validation_service.dart';
import '../localization/app_localizations.dart';
import '../screens/quiz_question_screen.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

class TopicQuizScreen extends StatefulWidget {
  final String? sessionId;
  
  const TopicQuizScreen({
    Key? key,
    this.sessionId,
  }) : super(key: key);
  
  @override
  _TopicQuizScreenState createState() => _TopicQuizScreenState();
}

class _TopicQuizScreenState extends State<TopicQuizScreen> {
  List<QuizTopic> topics = [];
  bool isLoading = true;
  String? errorMessage;
  late String _sessionId;
  
  // Helper method to get subtitle text based on language
  String _getSubtitleText(String language) {
    switch (language) {
      case 'en':
        return 'Questions grouped by topics';
      case 'es':
        return 'Preguntas agrupadas por temas';
      case 'uk':
        return 'Запитання згруповані по темах';
      case 'pl':
        return 'Pytania pogrupowane według tematów';
      case 'ru':
        return 'Вопросы сгруппированы по темам';
      default:
        return 'Questions grouped by topics';
    }
  }
  
  
  // Helper method to get questions count text based on language
  String _getQuestionsCountText(String language, int count) {
    switch (language) {
      case 'en':
        return '$count questions';
      case 'es':
        return '$count preguntas';
      case 'uk':
        return '$count запитань';
      case 'pl':
        return '$count pytań';
      case 'ru':
        return '$count вопросов';
      default:
        return '$count questions';
    }
  }
  
  // Helper method to get empty state title
  String _getEmptyStateTitle(String language) {
    switch (language) {
      case 'en':
        return 'No topics available';
      case 'es':
        return 'No hay temas disponibles';
      case 'uk':
        return 'Немає доступних тем';
      case 'pl':
        return 'Brak dostępnych tematów';
      case 'ru':
        return 'Нет доступных тем';
      default:
        return 'No topics available';
    }
  }
  
  // Helper method to get empty state message
  String _getEmptyStateMessage(String language) {
    switch (language) {
      case 'en':
        return 'There are currently no topics available for the selected language';
      case 'es':
        return 'Actualmente no hay temas disponibles para el idioma seleccionado';
      case 'uk':
        return 'На даний момент немає доступних тем для вибраної мови';
      case 'pl':
        return 'Obecnie nie ma dostępnych tematów dla wybranego języka';
      case 'ru':
        return 'В настоящее время нет доступных тем для выбранного языка';
      default:
        return 'There are currently no topics available for the selected language';
    }
  }
  
  // Helper method to get try again button text
  String _getTryAgainText(String language) {
    switch (language) {
      case 'en':
        return 'Try Again';
      case 'es':
        return 'Intentar de nuevo';
      case 'uk':
        return 'Повторити спробу';
      case 'pl':
        return 'Spróbuj ponownie';
      case 'ru':
        return 'Попробовать снова';
      default:
        return 'Try Again';
    }
  }
  
  @override
  void initState() {
    super.initState();
    
    // Generate or use provided session ID
    _sessionId = widget.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    loadTopics();
  }

  // Helper method to get thematic icon for topics
  IconData _getTopicIcon(String topicTitle) {
    if (topicTitle.toLowerCase().contains('загальн') || topicTitle.toLowerCase().contains('general')) {
      return SolarIcons.infoCircleLinear;
    } else if (topicTitle.toLowerCase().contains('правила') || topicTitle.toLowerCase().contains('rule')) {
      return SolarIcons.checklistMinimalisticLinear;
    } else if (topicTitle.toLowerCase().contains('безпек') || topicTitle.toLowerCase().contains('safety')) {
      return SolarIcons.shieldCheckBold;
    } else if (topicTitle.toLowerCase().contains('велосипед') || topicTitle.toLowerCase().contains('bike')) {
      return SolarIcons.bicyclingLinear;
    } else if (topicTitle.toLowerCase().contains('пішоход') || topicTitle.toLowerCase().contains('pedestrian')) {
      return SolarIcons.walkingLinear;
    } else if (topicTitle.toLowerCase().contains('транспорт') || topicTitle.toLowerCase().contains('transport')) {
      return SolarIcons.busLinear;
    } else if (topicTitle.toLowerCase().contains('водінн') || topicTitle.toLowerCase().contains('driving')) {
      return SolarIcons.carLinear;
    } else {
      return SolarIcons.documentTextLinear;
    }
  }


  /// The page heading, beside the back button: the screen's name, then one
  /// line on what it holds — title first, then description. Each line stays
  /// on one line; a long translation shrinks to fit rather than wrapping.
  ///
  /// Replaces two competing lines: a centred title in the app bar and, under
  /// it, «Вопросы сгруппированы по темам» centred between hairline rules.
  Widget _buildSectionHeader(String title, String subtitle) {
    Widget oneLine(Widget child) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: child,
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        oneLine(
          Text(
            title,
            maxLines: 1,
            style: AppTypography.title.copyWith(
              fontSize: 22,
              height: 28 / 22,
              letterSpacing: -0.4,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
        ),
        oneLine(
          Text(
            subtitle,
            maxLines: 1,
            style: AppTypography.body.copyWith(
              fontSize: 14,
              height: 20 / 14,
              color: AppColors.inkSecondary,
            ),
          ),
        ),
      ],
    );
  }


  /// Opens a topic. Moved unchanged from the card's inline `onTap`, so the
  /// card can change without touching the session check, analytics or
  /// navigation.
  Future<void> _onTopicTap(QuizTopic topic) async {
    // Session validation - validate before starting topic quiz
    if (!SessionValidationService.validateBeforeActionSafely(context)) {
      print('🚨 TopicQuizScreen: Session invalid, blocking topic selection: ${topic.title}');
      return; // User will be logged out by the validation service
    }
    
    try {
      // Track topic started analytics event
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      
      final stateId = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
      final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
      
      await analyticsService.trackQTopicStarted(
        sessionId: _sessionId,
        stateId: stateId,
        licenseType: licenseType,
        topicId: topic.id,
        topicName: topic.title,
        questionCount: topic.questionCount,
      );
      
      print('📊 Analytics: q_topic_started logged (session_id: $_sessionId, topic_id: ${topic.id}, topic_name: ${topic.title})');
    } catch (e) {
      print('❌ Analytics error: $e');
      // Don't block user flow if analytics fails
    }
    
    // Navigate to quiz questions with session ID and parameters for analytics
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizQuestionScreen(
          topic: topic,
          sessionId: _sessionId,
          isTopicMode: true,
          startTime: DateTime.now(),
        ),
      ),
    );
  }

  /// A topic: its 3D picture, then the title, with the question count as a
  /// pill in the bottom-right corner. The whole card is the button — no
  /// chevron. Colour is neutral: the old per-topic pastel washes (green,
  /// orange, purple…) spent the semantic colours on decoration.
  Widget _buildEnhancedTopicCard(QuizTopic topic, int index, String currentLanguage) {
    return _TopicCard(
      title: topic.title,
      count: _getQuestionsCountText(currentLanguage, topic.questionCount),
      picture: _buildTopicPicture(topic),
      onTap: () => _onTopicTap(topic),
    );
  }

  /// The topic's 3D picture (owner decision, 2026-09-26: keep the pictures).
  /// Falls back to a Solar glyph if the topic has no picture or it fails to
  /// load, as before.
  Widget _buildTopicPicture(QuizTopic topic) {
    Widget fallback() => Container(
          width: _topicPictureSize,
          height: _topicPictureSize,
          decoration: const BoxDecoration(
            color: AppColors.signal50,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            _getTopicIcon(topic.title),
            size: 28,
            color: AppColors.signal,
          ),
        );

    if (topic.iconAsset == null) return fallback();
    return Image.asset(
      topic.iconAsset!,
      width: _topicPictureSize,
      height: _topicPictureSize,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => fallback(),
    );
  }

  static const double _topicPictureSize = 64;
  
  Future<void> loadTopics() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      
      final language = languageProvider.language;
      final state = stateProvider.selectedStateId ?? 'ALL'; // Use actual state ID from provider
      
      print('TopicQuizScreen: Loading topics with language=$language, state=$state');
      
      // Fetch topics from Firebase
      final fetchedTopics = await serviceLocator.content.getQuizTopics(
        language,
        state,
      );
      
      if (mounted) {
        setState(() {
          topics = fetchedTopics;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading quiz topics: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load topics. Please try again.';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current language
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.language;
    
    // The same name as the Тесты tile and the topic result page — one
    // translation key, rather than a separate inline wording
    // («Учиться по темам» vs «Обучение по темам», unified 2026-09-26).
    final screenTitle = AppLocalizations.of(context).translate('learn_by_topics');
    
    // A pushed screen: back as a round white button on the field page, and
    // the page heading beside it, left-aligned.
    final appBar = AppBar(
      title: _buildSectionHeader(screenTitle, _getSubtitleText(currentLanguage)),
      centerTitle: false,
      titleSpacing: AppSpacing.x2,
      toolbarHeight: 72,
      backgroundColor: AppColors.field,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.x2),
        child: Center(
          child: IconButton(
            style: _roundIconStyle,
            icon: const Icon(SolarIcons.arrowLeftLinear, color: AppColors.ink, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
    
    // Show loading state
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.field,
        appBar: appBar,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Show error state
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.field,
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  errorMessage!,
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x4),
                FilledButton(
                  onPressed: loadTopics,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(_getTryAgainText(currentLanguage)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: appBar,
      // Risk #3 follow-up — distinguish a refusal from an empty shelf.
      body: Provider.of<ContentProvider>(context).contentRequiresSubscription
          ? const SubscriptionRequiredView()
          : topics.isEmpty
              ? _buildEmptyState(currentLanguage)
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.x4,
                    AppSpacing.x3,
                    AppSpacing.x4,
                    AppSpacing.x6 + MediaQuery.of(context).padding.bottom,
                  ),
                  itemCount: topics.length,
                  itemBuilder: (context, index) {
                    final topic = topics[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                      // One-shot entrance, capped so the whole list lands
                      // inside AppMotion.base.
                      child: StaggerIn(
                        index: index,
                        count: topics.length,
                        curve: BentoTokens.curve,
                        child: _buildEnhancedTopicCard(topic, index, currentLanguage),
                      ),
                    );
                  },
                ),
      );
  }

  Widget _buildEmptyState(String currentLanguage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.signal50,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                SolarIcons.listLinear,
                size: 28,
                color: AppColors.signal,
              ),
            ),
            const SizedBox(height: AppSpacing.x6),
            Text(
              _getEmptyStateTitle(currentLanguage),
              style: AppTypography.heading.copyWith(
                fontSize: 18,
                height: 24 / 18,
                fontVariations: const [FontVariation('wght', 600)],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              _getEmptyStateMessage(currentLanguage),
              style: AppTypography.label.copyWith(
                color: AppColors.inkSecondary,
                fontVariations: const [FontVariation('wght', 400)],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static final ButtonStyle _roundIconStyle = IconButton.styleFrom(
    backgroundColor: AppColors.paper,
    fixedSize: const Size(44, 44),
    shape: const CircleBorder(),
  );
}

/// One topic as a Bento card. Presses lift the card a few points rather than
/// shrinking it, as on Тесты.
class _TopicCard extends StatefulWidget {
  const _TopicCard({
    required this.title,
    required this.count,
    required this.picture,
    required this.onTap,
  });

  final String title;
  final String count;
  final Widget picture;
  final VoidCallback onTap;

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.count}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: Offset(0, _pressed ? -0.025 : 0),
          duration: AppMotion.duration(context, BentoTokens.state),
          curve: AppMotion.enter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(BentoTokens.card),
              boxShadow: AppColors.shadowCard,
            ),
            // Picture first, then the title; the count sits in the bottom
            // right corner, so the card is filled edge to edge.
            child: Row(
              children: [
                widget.picture,
                const SizedBox(width: AppSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.body.copyWith(
                          fontSize: 17,
                          height: 22 / 17,
                          letterSpacing: -0.2,
                          color: AppColors.ink,
                          fontVariations: const [FontVariation('wght', 600)],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      // One line always: a long translation shrinks slightly
                      // to fit rather than wrapping the pill.
                      Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.x2 + 2,
                              vertical: AppSpacing.x1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.signal50,
                              borderRadius: BorderRadius.circular(BentoTokens.chip),
                            ),
                            child: Text(
                              widget.count,
                              maxLines: 1,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.signal,
                                fontVariations: const [FontVariation('wght', 500)],
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
