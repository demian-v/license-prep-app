import 'package:flutter/material.dart';
import '../models/traffic_rule_topic.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/state_provider.dart';
import '../providers/progress_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/report_sheet.dart';
import '../widgets/adaptive_question_image.dart';
import 'package:provider/provider.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart';

class TrafficRuleContentScreen extends StatefulWidget {
  final TrafficRuleTopic topic;

  /// The Теория module this topic belongs to, when opened from one. Reaching
  /// the end of the page marks that module done (its tick on Теория).
  final String? moduleId;

  const TrafficRuleContentScreen({
    Key? key,
    required this.topic,
    this.moduleId,
  }) : super(key: key);

  @override
  _TrafficRuleContentScreenState createState() => _TrafficRuleContentScreenState();
}

class _TrafficRuleContentScreenState extends State<TrafficRuleContentScreen> {
  // Analytics tracking variables
  DateTime? _contentViewStartTime;
  bool _hasTrackedContentViewed = false;
  bool _hasTrackedViewFailed = false;

  // Reading progress (owner, 2026-09-26): how far down the page the reader
  // has been, saved locally when they leave. Reaching the end counts as done.
  late final ProgressProvider _progressProvider;
  double _readFraction = 0;
  bool _reachedEnd = false;

  // «Назад к теории» steps out of the way while reading down and returns on
  // the way back up or at the end of the page (owner, 2026-09-26).
  bool _showBackButton = true;
  
  @override
  void initState() {
    super.initState();
    _contentViewStartTime = DateTime.now();
    _progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    
    // Track content viewed once the first frame is up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackContentViewed();
    });
  }
  
  @override
  void dispose() {
    _saveReadingProgress();
    super.dispose();
  }

  /// Follows the page's scroll position. The furthest point reached is the
  /// topic's reading progress (the ring on the module page); the end of the
  /// page — or a page short enough to need no scrolling — is done.
  void _onReadingPosition(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical || _reachedEnd) return;
    final fraction = metrics.maxScrollExtent <= 0
        ? 1.0
        : (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0);
    if (fraction > _readFraction) _readFraction = fraction;
    if (metrics.extentAfter <= _endSlack) {
      _reachedEnd = true;
      _readFraction = 1.0;
      _saveReadingProgress();
    }
  }

  /// How close to the bottom counts as the end, so the last few pixels of
  /// padding need not be scrolled.
  static const double _endSlack = 24;

  /// Saves the reading progress locally — never lowering what was saved
  /// before — and, at the end of the page, marks the module done.
  void _saveReadingProgress() {
    final topicId = widget.topic.id;
    final saved = _progressProvider.progress.topicProgress[topicId] ?? 0.0;
    if (_readFraction > saved) {
      _progressProvider.updateTopicProgress(topicId, _readFraction);
    }
    final moduleId = widget.moduleId;
    if (_reachedEnd && moduleId != null) {
      _progressProvider.completeModule(moduleId);
    }
  }

  void _onScrollDirection(ScrollUpdateNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return;
    final delta = n.scrollDelta ?? 0;
    bool show = _showBackButton;
    if (n.metrics.extentAfter <= _endSlack || n.metrics.pixels <= 0) {
      show = true;
    } else if (delta > 2) {
      show = false;
    } else if (delta < -2) {
      show = true;
    }
    if (show != _showBackButton) setState(() => _showBackButton = show);
  }

  Widget _trackReading(Widget content) {
    bool onMetrics(ScrollMetrics metrics, int depth) {
      if (depth == 0) _onReadingPosition(metrics);
      return false;
    }

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => onMetrics(n.metrics, n.depth),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => onMetrics(n.metrics, n.depth),
        child: content,
      ),
    );
  }

  // Analytics tracking methods
  void _trackContentViewed() {
    if (_hasTrackedContentViewed) return;
    
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    final userState = authProvider.user?.state ?? stateProvider.selectedStateId;
    
    analyticsService.logTheoryContentViewed(
      moduleId: null, // Module info not available in topic model
      moduleTitle: null, // Module info not available in topic model
      topicId: widget.topic.id,
      topicTitle: widget.topic.title,
      state: userState,
      language: languageProvider.language,
      licenseType: 'driver', // Default license type
    );
    
    _hasTrackedContentViewed = true;
    debugPrint('📊 Analytics: theory_content_viewed logged (topic: ${widget.topic.title})');
  }

  void _trackContentViewFailed(Object error) {
    if (_hasTrackedViewFailed) return;
    
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    final userState = authProvider.user?.state ?? stateProvider.selectedStateId;
    final errorMessage = error.toString();
    
    analyticsService.logTheoryContentViewFailed(
      moduleId: null, // Module info not available in topic model
      moduleTitle: null, // Module info not available in topic model
      topicId: widget.topic.id,
      topicTitle: widget.topic.title,
      errorType: _getErrorType(errorMessage),
      errorMessage: errorMessage.length > 100 
          ? errorMessage.substring(0, 97) + '...'
          : errorMessage,
      state: userState,
      language: languageProvider.language,
    );
    
    _hasTrackedViewFailed = true;
    debugPrint('📊 Analytics: theory_content_view_failed logged (topic: ${widget.topic.title}, error: ${_getErrorType(errorMessage)})');
  }

  void _trackContentCompleted() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    final userState = authProvider.user?.state ?? stateProvider.selectedStateId;
    final timeSpent = _contentViewStartTime != null 
        ? DateTime.now().difference(_contentViewStartTime!).inSeconds 
        : null;
    
    analyticsService.logTheoryContentCompleted(
      moduleId: null, // Module info not available in topic model
      moduleTitle: null, // Module info not available in topic model
      topicId: widget.topic.id,
      topicTitle: widget.topic.title,
      timeSpentReadingSeconds: timeSpent,
      state: userState,
      language: languageProvider.language,
      licenseType: 'driver', // Default license type
    );
    
    debugPrint('📊 Analytics: theory_content_completed logged (topic: ${widget.topic.title}, reading_time: ${timeSpent}s)');
  }

  // Helper method for error type classification
  String _getErrorType(String errorMessage) {
    if (errorMessage.contains('network') || errorMessage.contains('connection')) {
      return 'network_error';
    } else if (errorMessage.contains('content') || errorMessage.contains('load')) {
      return 'content_load_error';
    } else if (errorMessage.contains('render') || errorMessage.contains('display')) {
      return 'render_error';
    } else if (errorMessage.contains('firestore') || errorMessage.contains('firebase')) {
      return 'database_error';
    } else {
      return 'unknown_error';
    }
  }

  // Report methods
  void _showTopicReportSheet() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    final userState = authProvider.user?.state ?? stateProvider.selectedStateId;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        contentType: 'theory_section',
        contextData: {
          'topicDocId': widget.topic.id, // e.g., topic_3_en_IL
          'sectionIndex': -1, // -1 indicates entire topic
          'sectionTitle': 'Entire Topic: ${widget.topic.title}',
          'language': languageProvider.language,
          'state': userState,
          'topicTitle': widget.topic.title, // Additional context for triage
          'totalSections': widget.topic.sections?.length ?? 0, // Context for section count
        },
      ),
    );
  }

  void _showSectionReportSheet(int sectionIndex, String sectionTitle) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    final userState = authProvider.user?.state ?? stateProvider.selectedStateId;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        contentType: 'theory_section',
        contextData: {
          'topicDocId': widget.topic.id,
          'sectionIndex': sectionIndex,
          'sectionTitle': sectionTitle.isNotEmpty ? sectionTitle : 'Section ${sectionIndex + 1}',
          'language': languageProvider.language,
          'state': userState,
          'topicTitle': widget.topic.title, // Additional context for triage
          'totalSections': widget.topic.sections?.length ?? 0, // Context for section count
        },
      ),
    );
  }

  /// Leaves the page. Moved unchanged from the back arrow's and «Назад к
  /// теории»'s inline handlers (they were identical).
  void _onBack() {
    // Track content completion
    _trackContentCompleted();
    Navigator.pop(context);
  }

  /// A section title and its ⚠ report button (44pt target), title first.
  Widget _buildSectionHeader(String title, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            // Centres a one-line title on the 44pt button.
            padding: const EdgeInsets.only(top: 9),
            child: Text(
              title,
              style: AppTypography.heading.copyWith(
                fontSize: 19,
                height: 26 / 19,
                letterSpacing: -0.2,
                color: AppColors.ink,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x1),
        // The card's right padding is narrow on this row only, so the full
        // 44pt target fits while the glyph lines up with the text edge.
        IconButton(
          tooltip: 'Report Section Issue',
          style: IconButton.styleFrom(
            fixedSize: const Size(44, 44),
            shape: const CircleBorder(),
          ),
          icon: AppIcons.icon(
            AppIcons.report,
            size: 20,
            color: AppColors.inkSecondary,
          ),
          onPressed: () => _showSectionReportSheet(index, title),
        ),
      ],
    );
  }

  /// Reading text: 16/24 at 400 in ink, straight on the card — no inner
  /// bordered box.
  Widget _buildSectionContent(String content) {
    // Process content for better formatting
    final processedContent = content
        .replaceAll('\\n•', '\n• ') // Format bullet points with space
        .replaceAll('\\n\\n', '\n\n') // Handle double newlines
        .replaceAll('\\n', '\n'); // Handle regular newlines
    
    return Text(processedContent, style: _bodyStyle);
  }

  static final TextStyle _bodyStyle = AppTypography.body.copyWith(
    fontSize: 16,
    height: 24 / 16,
    color: AppColors.ink,
    fontVariations: const [FontVariation('wght', 400)],
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      );

  /// One section as one white card: title and ⚠, the picture, then the text.
  /// The right padding is 8 so the ⚠ row can hold a full 44pt target; the
  /// picture and text add 12 back, for the same 20 on both sides.
  Widget _buildSectionCard(section, int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4 + AppSpacing.x1,
        AppSpacing.x3,
        AppSpacing.x2,
        AppSpacing.x4 + AppSpacing.x1,
      ),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced section header with report button
          if (section.title != null && section.title.isNotEmpty)
            _buildSectionHeader(section.title, index),
          
          if (section.title != null && section.title.isNotEmpty)
            const SizedBox(height: AppSpacing.x3),
          
          // NEW: Add image display if imagePath exists
          if (section.imagePath != null && section.imagePath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x3),
              child: AdaptiveQuestionImage(
                imagePath: section.imagePath,
                storageFolder: 'theory_images',
                assetFallback: section.imagePath,
                // Theory is long-form reading: no timer, no action bar competing
                // for the viewport. The widget's default is deliberately short
                // for question screens; diagrams here keep their original height.
                maxHeight: 265,
              ),
            ),
          
          if (section.imagePath != null && section.imagePath.isNotEmpty)
            const SizedBox(height: AppSpacing.x4),
          
          // Enhanced content text
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.x3),
            child: _buildSectionContent(section.content ?? "No content available"),
          ),
        ],
      ),
    );
  }

  /// The heading over a topic's full text. It was «Зміст теми» in Ukrainian
  /// for every language (fixed 2026-09-26, owner).
  String _topicContentLabel() {
    switch (Provider.of<LanguageProvider>(context, listen: false).language) {
      case 'ru':
        return 'Содержание темы';
      case 'uk':
        return 'Зміст теми';
      case 'es':
        return 'Contenido del tema';
      case 'pl':
        return 'Treść tematu';
      default:
        return 'Topic content';
    }
  }

  /// A topic without sections: its full text in one card.
  Widget _buildFallbackContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _topicContentLabel(),
            style: AppTypography.heading.copyWith(
              fontSize: 19,
              height: 26 / 19,
              color: AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            widget.topic.fullContent
                ?.replaceAll('\\n•', '\n• ')
                ?.replaceAll('\\n\\n', '\n\n')
                ?.replaceAll('\\n', '\n') ?? 
                "No content available for this topic.",
            style: _bodyStyle,
          ),
        ],
      ),
    );
  }

  /// Rendering failed: a soft red disc, a title, one quiet line.
  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.stopSurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                SolarIcons.dangerCircleLinear,
                size: 40,
                color: AppColors.stop,
              ),
            ),
            const SizedBox(height: AppSpacing.x6),
            Text(
              'Error displaying content',
              textAlign: TextAlign.center,
              style: AppTypography.heading.copyWith(
                fontSize: 20,
                height: 26 / 20,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Please try again later or contact support if the issue persists.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                fontSize: 15,
                height: 22 / 15,
                color: AppColors.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The sections as a stack of cards on the field page, entering once.
  Widget _buildEnhancedContent() {
    final sections = widget.topic.sections;
    final hasSections = sections != null && sections.isNotEmpty;
    final count = hasSections ? sections.length : 1;
    return SingleChildScrollView(
      // The end of the text stays clear of the floating «Назад к теории».
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x2 + 56 + AppSpacing.x4 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasSections)
            ...sections.asMap().entries.map((entry) {
              final int index = entry.key;
              final section = entry.value;
              return Padding(
                padding: EdgeInsets.only(top: index > 0 ? AppSpacing.x3 : 0),
                child: StaggerIn(
                  index: index,
                  count: count,
                  curve: BentoTokens.curve,
                  child: _buildSectionCard(section, index),
                ),
              );
            })
          else
            StaggerIn(
              index: 0,
              count: 1,
              curve: BentoTokens.curve,
              child: _buildFallbackContent(),
            ),
        ],
      ),
    );
  }

  /// A neutral dark pill: it floats over both the white cards and the field
  /// page, so it needs contrast with both — a white pill vanished into the
  /// cards. `ink` is neutral, not semantic (as on the «Сохраненные» card).
  Widget _buildInkPill(String text, VoidCallback onTap) {
    final radius = BorderRadius.circular(BentoTokens.button);
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: radius,
          boxShadow: AppColors.shadowRaised,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Center(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  fontSize: 16,
                  color: AppColors.onSignal,
                  fontVariations: const [FontVariation('wght', 500)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// «Назад к теории» as a dark pill floating over the text (owner: the
  /// blue one was loud). It slides away while reading down and comes back on
  /// the way up; hidden, it takes no taps.
  Widget _buildBackToTheoryButton() {
    return IgnorePointer(
      ignoring: !_showBackButton,
      child: AnimatedSlide(
        offset: _showBackButton ? Offset.zero : const Offset(0, 1),
        duration: AppMotion.duration(context, AppMotion.base),
        curve: _showBackButton ? AppMotion.enter : AppMotion.exit,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: AppSpacing.x4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              0,
            ),
            child: _buildInkPill(
              AppLocalizations.of(context).translate('back_to_theory'),
              _onBack,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.field,
      // The round back button with the topic's name beside it (one line,
      // shrinking rather than wrapping), and the ⚠ for the whole topic.
      appBar: bentoHeadingAppBar(
        title: widget.topic.title,
        onBack: _onBack,
        actions: [
          IconButton(
            tooltip: 'Report Issue',
            style: bentoRoundIconStyle,
            icon: AppIcons.icon(
              AppIcons.report,
              size: 22,
              color: AppColors.inkSecondary,
            ),
            onPressed: _showTopicReportSheet,
          ),
          const SizedBox(width: AppSpacing.x3),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (n) {
                _onScrollDirection(n);
                return false;
              },
              child: Builder(
              builder: (context) {
                try {
                  return _trackReading(_buildEnhancedContent());
                } catch (e) {
                  print('Error rendering topic content: $e');
                  // Track content view failure
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _trackContentViewFailed(e);
                  });
                  return _buildErrorState(e);
                }
              },
              ),
            ),
          ),
          
          // Bottom button area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBackToTheoryButton(),
          ),
        ],
      ),
    );
  }
}
