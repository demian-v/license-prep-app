import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/state_provider.dart';
import '../providers/language_provider.dart';
import '../models/exam.dart';
import '../models/quiz_question.dart';
import '../services/service_locator.dart';
import '../localization/app_localizations.dart';
import '../services/analytics_service.dart';
import '../widgets/report_sheet.dart';
import '../widgets/animated_exam_timer.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/design_variant.dart';
import '../widgets/adaptive_question_image.dart';
import 'exam_result_screen.dart';
import '../theme/solar_icons.dart';

class ExamQuestionScreen extends StatefulWidget {
  @override
  _ExamQuestionScreenState createState() => _ExamQuestionScreenState();
}

class _ExamQuestionScreenState extends State<ExamQuestionScreen> {
  dynamic selectedAnswer;
  bool isAnswerChecked = false;
  bool? isCorrect;
  ScrollController _pillsScrollController = ScrollController();
  ScrollController _mainScrollController = ScrollController();

  // Presentation state only.
  /// Ledger: pills and app-bar actions dimmed while the learner reads.
  bool _chromeReceded = false;
  /// Direction of the question transition.
  bool _swapForward = true;
  int _lastQuestionIndex = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Scroll to current pill when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentPill();
    });
    designVariant.addListener(_onVariantChanged);
  }

  /// Pill slots differ in width between variants, so re-centre the strip.
  void _onVariantChanged() {
    if (!mounted) return;
    setState(() => _chromeReceded = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentPill());
  }
  
  @override
  void dispose() {
    designVariant.removeListener(_onVariantChanged);
    _pillsScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }
  
  void _scrollToCurrentPill() {
    if (!_pillsScrollController.hasClients) return;
    
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final exam = examProvider.currentExam;
    if (exam == null) return;
    
    // The slot width of the variant on screen, and the list's own inset. The
    // old fixed 48 drifted a little further off-centre with every question,
    // because the slots were 44 wide.
    final variant = designVariant.value;
    final pillWidth = _pillExtent(variant);
    final viewport = _pillsScrollController.position.viewportDimension;
    final targetPosition =
        _pillListPadding + pillWidth * exam.currentQuestionIndex;

    final scrollOffset = (targetPosition - viewport / 2 + (pillWidth / 2))
        .clamp(0.0, _pillsScrollController.position.maxScrollExtent);
    final duration =
        AppMotion.duration(context, VariantTokens.of(variant).swap);

    if (duration == Duration.zero) {
      _pillsScrollController.jumpTo(scrollOffset);
    } else {
      _pillsScrollController.animateTo(
        scrollOffset,
        duration: duration,
        curve: AppMotion.enter,
      );
    }
  }

  void _resetMainScrollPosition() {
    if (_mainScrollController.hasClients) {
      final duration = AppMotion.duration(context, AppMotion.base);
      if (duration == Duration.zero) {
        _mainScrollController.jumpTo(0.0);
      } else {
        _mainScrollController.animateTo(
          0.0,
          duration: duration,
          curve: AppMotion.enter,
        );
      }
    }
  }

  /// Move to the question the user tapped in the strip.
  ///
  /// Clears the in-progress selection for the question being left. A selection
  /// that was never submitted is not an answer, and carrying it across would
  /// pre-fill an unrelated question with someone else's choice.
  void _jumpToQuestion(int index) {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final exam = examProvider.currentExam;
    if (exam == null || index == exam.currentQuestionIndex) return;

    setState(() {
      selectedAnswer = null;
      isAnswerChecked = false;
      isCorrect = null;
    });

    examProvider.goToQuestion(index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetMainScrollPosition();
      _scrollToCurrentPill();
    });
  }

  /// Show report sheet for current question
  void _showReportSheet() {
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final currentQuestion = examProvider.getCurrentQuestion();
    if (currentQuestion == null) return;
    
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        contentType: 'quiz_question',
        contextData: {
          'questionId': currentQuestion.id,
          'language': languageProvider.language,
          'state': authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL',
          'topicId': currentQuestion.topicId,
          'ruleReference': currentQuestion.ruleReference,
        },
      ),
    );
  }


  // ---------------------------------------------------------- handlers ---
  // Moved unchanged from the inline closures that used to sit in `build`, so
  // every design variant runs the same select, check, skip and next logic.

  void _selectOption(dynamic option) {
    setState(() {
      selectedAnswer = option;
      // Presentation only: choosing an answer is an interaction, so Ledger's
      // receded chrome comes back.
      _chromeReceded = false;
    });
  }

  void _checkAnswer(QuizQuestion currentQuestion) {
    // Check answer
    setState(() {
      isAnswerChecked = true;

      if (currentQuestion.correctAnswer is List<String>) {
        isCorrect = (currentQuestion.correctAnswer as List<String>)
            .contains(selectedAnswer);
      } else {
        isCorrect = selectedAnswer == currentQuestion.correctAnswer;
      }
    });
  }

  void _goToNext(ExamProvider examProvider, QuizQuestion currentQuestion) {
    // Save answer and move to next question
    examProvider.answerQuestion(
      currentQuestion.id,
      isCorrect ?? false,
    );

    setState(() {
      selectedAnswer = null;
      isAnswerChecked = false;
      isCorrect = null;
    });

    examProvider.goToNextQuestion();

    // Reset main scroll position and scroll to current pill after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetMainScrollPosition();
      _scrollToCurrentPill();
    });
  }

  void _skipCurrent(ExamProvider examProvider) {
    // Skip question
    examProvider.skipQuestion();

    // Reset main scroll position and scroll to current pill after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetMainScrollPosition();
      _scrollToCurrentPill();
    });
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    final exam = examProvider.currentExam;
    
    if (exam == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final currentQuestion = examProvider.getCurrentQuestion();
    if (currentQuestion == null) {
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context).translate('question_not_found')),
        ),
      );
    }
    
    // Format remaining time
    final remainingTime = exam.remainingTime;
    
    // Check if we need to show result screen
    if (exam.isCompleted) {
      // Navigate to results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ExamResultScreen(),
          ),
        );
      });
      
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Which way the question transition travels: forward for Next, Skip and
    // jumps ahead; back for jumps to an earlier pill.
    if (exam.currentQuestionIndex != _lastQuestionIndex) {
      _swapForward = exam.currentQuestionIndex > _lastQuestionIndex;
      _lastQuestionIndex = exam.currentQuestionIndex;
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: ValueListenableBuilder<DesignVariant>(
        valueListenable: designVariant,
        builder: (context, selected, _) {
          final variant = selected;
          final tokens = VariantTokens.of(variant);
          final bool ledger = variant == DesignVariant.boldB;

          return DesignVariantSwitcher(
            child: Scaffold(
              backgroundColor: ledger ? AppColors.paper : AppColors.field,
              appBar: _buildAppBar(context, examProvider, variant, tokens),
              body: Column(
                children: [
                  // Question number indicator
                  _recede(variant, child: _buildProgress(exam, variant, tokens)),

                  // Question content and answer options in single scrollable area
                  Expanded(
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: (n) => _onContentScroll(n, variant),
                      child: SingleChildScrollView(
                        controller: _mainScrollController,
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x4,
                          ledger ? AppSpacing.x4 : AppSpacing.x2,
                          AppSpacing.x4,
                          AppSpacing.x4,
                        ),
                        child: _buildQuestionSwap(
                          tokens,
                          KeyedSubtree(
                            key: ValueKey('${currentQuestion.id}-${exam.currentQuestionIndex}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Question image (if available)
                                if (currentQuestion.imagePath != null)
                                  AdaptiveQuestionImage(
                                    imagePath: currentQuestion.imagePath!,
                                    assetFallback: currentQuestion.imagePath,
                                  ),
                                _buildQuestionHeader(
                                    context, exam, currentQuestion, variant, tokens),
                                _buildOptions(currentQuestion, variant, tokens),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Action buttons
                  _buildActions(
                      context, examProvider, currentQuestion, variant, tokens),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ chrome ---

  /// Bento's borderless card shadow.
  static const List<BoxShadow> _bentoShadow = [
    BoxShadow(
      color: Color(0x0F0E1F4D),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x080E1F4D),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static final ButtonStyle _roundIconStyle = IconButton.styleFrom(
    backgroundColor: AppColors.paper,
    fixedSize: const Size(44, 44),
    shape: const CircleBorder(),
  );

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ExamProvider examProvider,
    DesignVariant variant,
    VariantTokens tokens,
  ) {
    final bool signal = variant == DesignVariant.boldA;
    final bool ledger = variant == DesignVariant.boldB;
    // Signal and Bento both float their controls as white discs on the page.
    final bool round = signal || variant == DesignVariant.bento;
    final double glyph = ledger ? 20 : 22;

    return AppBar(
      title: AnimatedExamTimer(),
      centerTitle: true,
      toolbarHeight: round ? 64 : ledger ? 52 : kToolbarHeight,
      // Signal lets the bar melt into the page and floats its controls as
      // discs; the others keep a paper bar over a hairline.
      backgroundColor: round ? AppColors.field : AppColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      // A hairline instead of a shadow, and no elevation tint — the tint
      // is what turned scrolled app bars lavender.
      shape: round
          ? null
          : const Border(
              bottom: BorderSide(color: AppColors.border),
            ),
      leading: Padding(
        padding: EdgeInsets.only(left: round ? AppSpacing.x2 : 0),
        child: Center(
          child: IconButton(
            style: round ? _roundIconStyle : null,
            icon: Icon(SolarIcons.arrowLeftLinear, color: AppColors.ink, size: ledger ? 22 : 24),
            onPressed: () {
              _showExitConfirmation(context);
            },
          ),
        ),
      ),
      actions: [
        _recede(
          variant,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Report a problem with this question. Opens ReportSheet.
              IconButton(
                tooltip: AppLocalizations.of(context).translate('report_issue'),
                style: round ? _roundIconStyle : null,
                icon: AppIcons.icon(
                  AppIcons.report,
                  size: glyph,
                  color: AppColors.inkSecondary,
                ),
                onPressed: _showReportSheet,
              ),
              if (round) const SizedBox(width: AppSpacing.x1),
              Consumer<ProgressProvider>(
                builder: (context, progressProvider, child) {
                  final currentQuestion = examProvider.getCurrentQuestion();
                  if (currentQuestion == null) return SizedBox.shrink();

                  final questionId = currentQuestion.id;
                  final isSaved = progressProvider.isQuestionSaved(questionId);

                  return IconButton(
                    style: round ? _roundIconStyle : null,
                    // The heart answers the tap: it swaps outline for fill
                    // with a short scale-in, rather than snapping.
                    icon: AnimatedSwitcher(
                      duration: AppMotion.duration(context, tokens.state),
                      switchInCurve: signal ? AppMotion.spring : AppMotion.enter,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(isSaved),
                        child: AppIcons.icon(
                          isSaved ? AppIcons.savedFilled : AppIcons.saved,
                          size: glyph,
                          color: isSaved ? AppColors.stop : AppColors.inkSecondary,
                        ),
                      ),
                    ),
                    onPressed: () {
                      // Get auth provider to check if user is logged in
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final userId = authProvider.user?.id ?? '';
                      progressProvider.toggleSavedQuestionWithUserId(questionId, userId);
                    },
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(width: round ? AppSpacing.x3 : AppSpacing.x1),
      ],
    );
  }

  /// Ledger's distraction-free reading: while the learner scrolls down
  /// through a question, the pill strip and the app-bar actions dim back.
  /// They stay where they are and stay tappable — one tap on either brings
  /// them back, as does scrolling up or choosing an answer.
  Widget _recede(DesignVariant variant, {required Widget child}) {
    if (variant != DesignVariant.boldB) return child;
    return Listener(
      onPointerDown: (_) {
        if (_chromeReceded) setState(() => _chromeReceded = false);
      },
      child: AnimatedOpacity(
        opacity: _chromeReceded ? 0.35 : 1,
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.crisp,
        child: child,
      ),
    );
  }

  bool _onContentScroll(UserScrollNotification n, DesignVariant variant) {
    if (variant != DesignVariant.boldB) return false;
    if (n.direction == ScrollDirection.reverse && !_chromeReceded) {
      setState(() => _chromeReceded = true);
    } else if (n.direction == ScrollDirection.forward && _chromeReceded) {
      setState(() => _chromeReceded = false);
    }
    return false;
  }

  // ---------------------------------------------------------- progress ---

  /// Horizontal inset of the pill list; the auto-scroll maths needs it.
  static const double _pillListPadding = AppSpacing.x3;

  /// Width of one pill slot. Every slot is at least 44pt — the hit target —
  /// whatever size the visible pill is drawn at.
  double _pillExtent(DesignVariant variant) =>
      variant == DesignVariant.boldA ? 48 : 44;

  Widget _buildProgress(Exam exam, DesignVariant variant, VariantTokens tokens) {
    final double extent = _pillExtent(variant);
    final strip = SizedBox(
      height: extent + AppSpacing.x3,
      child: ListView.builder(
        controller: _pillsScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: _pillListPadding,
          vertical: AppSpacing.x1 + 2,
        ),
        itemCount: exam.questionIds.length,
        itemBuilder: (context, index) =>
            _buildPill(exam, index, variant, tokens, extent),
      ),
    );

    switch (variant) {
      case DesignVariant.refined:
        return strip;
      case DesignVariant.boldA:
        // A segmented track above the pills: the whole exam at a glance.
        // In addition to the pills, never instead — the pills still jump.
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x1,
                AppSpacing.x4,
                0,
              ),
              child: _buildSegmentTrack(exam, tokens),
            ),
            strip,
          ],
        );
      case DesignVariant.boldB:
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.paper,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: strip,
        );
      case DesignVariant.bento:
        // The strip sits in its own soft pill tray, like a dashboard's
        // segmented navigation.
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x1,
            AppSpacing.x4,
            AppSpacing.x1,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(tokens.bar),
              boxShadow: _bentoShadow,
            ),
            // The strip scrolls inside an inset, and its ends fade out, so a
            // pill scrolling past never meets the tray's rounded edge.
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.bar),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  colors: [
                    Color(0x00000000),
                    Color(0xFF000000),
                    Color(0xFF000000),
                    Color(0x00000000),
                  ],
                  stops: [0, 0.04, 0.96, 1],
                ).createShader(rect),
                child: strip,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildSegmentTrack(Exam exam, VariantTokens tokens) {
    final int total = exam.questionIds.length;
    return ExcludeSemantics(
      // A visual duplicate of the pill strip, which carries the semantics.
      child: Row(
        children: List.generate(total, (index) {
          final String questionId = exam.questionIds[index];
          final bool isActive = index == exam.currentQuestionIndex;
          final bool isAnswered = exam.answers.containsKey(questionId);
          final bool isRight = isAnswered ? exam.answers[questionId]! : false;
          final Color color = isActive
              ? AppColors.signal
              : isAnswered
                  ? (isRight ? AppColors.guide : AppColors.stop)
                  : AppColors.borderStrong;
          return Expanded(
            child: AnimatedContainer(
              duration: AppMotion.duration(context, tokens.state),
              curve: AppMotion.enter,
              height: isActive ? 6 : 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPill(
    Exam exam,
    int index,
    DesignVariant variant,
    VariantTokens tokens,
    double extent,
  ) {
    bool isActive = index == exam.currentQuestionIndex;
    String questionId = exam.questionIds[index];
    bool isAnswered = exam.answers.containsKey(questionId);
    bool isAnsweredCorrectly = isAnswered ? exam.answers[questionId]! : false;

    // Pill state, carried by fill rather than a pastel wash:
    // blue = where you are, green = answered right, red =
    // answered wrong, plain = not yet seen. These are the same
    // semantics the answer options use, so the strip doubles as
    // a progress read.
    Color pillFill;
    Color pillInk;
    Color pillEdge;
    double edgeWidth = 1;
    switch (variant) {
      case DesignVariant.refined:
        if (isActive) {
          pillFill = AppColors.signal;
          pillInk = AppColors.onSignal;
          pillEdge = AppColors.signal;
        } else if (isAnswered && isAnsweredCorrectly) {
          pillFill = AppColors.guideSurface;
          pillInk = AppColors.guide;
          pillEdge = AppColors.guideSurface;
        } else if (isAnswered) {
          pillFill = AppColors.stopSurface;
          pillInk = AppColors.stop;
          pillEdge = AppColors.stopSurface;
        } else {
          pillFill = AppColors.paper;
          pillInk = AppColors.inkSecondary;
          pillEdge = AppColors.border;
        }
        break;
      case DesignVariant.boldA:
        // Signal commits: answered pills are solid, not tinted.
        if (isActive) {
          pillFill = AppColors.signal;
          pillInk = AppColors.onSignal;
          pillEdge = AppColors.signal;
        } else if (isAnswered && isAnsweredCorrectly) {
          pillFill = AppColors.guide;
          pillInk = AppColors.onSignal;
          pillEdge = AppColors.guide;
        } else if (isAnswered) {
          pillFill = AppColors.stop;
          pillInk = AppColors.onSignal;
          pillEdge = AppColors.stop;
        } else {
          pillFill = AppColors.paper;
          pillInk = AppColors.inkSecondary;
          pillEdge = AppColors.paper;
        }
        break;
      case DesignVariant.bento:
        // Bento: round pills in the tray; tints for answered, blue for here.
        if (isActive) {
          pillFill = AppColors.signal;
          pillInk = AppColors.onSignal;
          pillEdge = AppColors.signal;
        } else if (isAnswered && isAnsweredCorrectly) {
          pillFill = AppColors.guideSurface;
          pillInk = AppColors.guide;
          pillEdge = AppColors.guideSurface;
        } else if (isAnswered) {
          pillFill = AppColors.stopSurface;
          pillInk = AppColors.stop;
          pillEdge = AppColors.stopSurface;
        } else {
          pillFill = AppColors.field;
          pillInk = AppColors.inkSecondary;
          pillEdge = AppColors.field;
        }
        break;
      case DesignVariant.boldB:
        // Ledger: ink on paper; the current pill is outlined, not filled.
        if (isActive) {
          pillFill = AppColors.signal50;
          pillInk = AppColors.signal;
          pillEdge = AppColors.signal;
          edgeWidth = 1.5;
        } else if (isAnswered && isAnsweredCorrectly) {
          pillFill = AppColors.guideSurface;
          pillInk = AppColors.guide;
          pillEdge = AppColors.guideSurface;
        } else if (isAnswered) {
          pillFill = AppColors.stopSurface;
          pillInk = AppColors.stop;
          pillEdge = AppColors.stopSurface;
        } else {
          pillFill = AppColors.paper;
          pillInk = AppColors.inkSecondary;
          pillEdge = AppColors.border;
        }
        break;
    }

    final double visual = variant == DesignVariant.boldA
        ? 42
        : variant == DesignVariant.boldB
            ? 34
            : variant == DesignVariant.bento
                ? 36
                : 40;
    final Duration duration = AppMotion.duration(context, tokens.state);

    return Semantics(
      label: '${index + 1}',
      selected: isActive,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The strip already showed progress; now it navigates.
        // Any answer typed but not yet submitted on the question
        // being left is discarded, the same way Next discards it
        // after recording — jumping away is not an answer.
        onTap: () => _jumpToQuestion(index),
        child: SizedBox(
          width: extent,
          child: Center(
            child: AnimatedScale(
              scale: variant == DesignVariant.boldA && isActive ? 1.08 : 1,
              duration: duration,
              curve: tokens.curve,
              child: AnimatedContainer(
                duration: duration,
                curve: AppMotion.enter,
                width: visual,
                height: visual,
                decoration: BoxDecoration(
                  color: pillFill,
                  borderRadius: BorderRadius.circular(tokens.chip),
                  border: Border.all(color: pillEdge, width: edgeWidth),
                  boxShadow: variant == DesignVariant.boldA && !isActive && !isAnswered
                      ? AppColors.shadowResting
                      : null,
                ),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    style: AppTypography.pill.copyWith(
                      color: pillInk,
                      fontSize: variant == DesignVariant.boldB ? 13 : 14,
                    ),
                    child: Text('${index + 1}'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- question ---

  /// Question-to-question transition: a shared-axis slide. The incoming
  /// question arrives from the side it lives on; the outgoing one leaves
  /// towards the other. Reduce Motion makes it a cut.
  Widget _buildQuestionSwap(VariantTokens tokens, Widget child) {
    final Duration duration = AppMotion.duration(context, tokens.swap);
    final double shift = tokens.swap == AppMotion.fast ? 0.02 : 0.05;
    final double dir = _swapForward ? 1 : -1;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (transitioning, animation) {
        final bool incoming = transitioning.key == child.key;
        final Offset from = Offset(shift * dir * (incoming ? 1 : -1), 0);
        // Shared-axis choreography: the outgoing question is gone within the
        // first 35% of the transition and only then does the incoming one
        // fade up, so the two never read as overlapping text.
        final Animation<double> opacity = CurvedAnimation(
          parent: animation,
          curve: incoming
              ? const Interval(0.35, 1, curve: AppMotion.enter)
              : const Interval(0.65, 1, curve: AppMotion.exit),
        );
        return FadeTransition(
          opacity: opacity,
          child: SlideTransition(
            position: Tween<Offset>(begin: from, end: Offset.zero)
                .animate(animation),
            child: transitioning,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildQuestionHeader(
    BuildContext context,
    Exam exam,
    QuizQuestion currentQuestion,
    DesignVariant variant,
    VariantTokens tokens,
  ) {
    final localizations = AppLocalizations.of(context);
    final String counter = localizations
        .translate('question_x_of_y')
        .replaceAll('{0}', (exam.currentQuestionIndex + 1).toString())
        .replaceAll('{1}', exam.questionIds.length.toString());
    final bool isMultiple = currentQuestion.type == QuestionType.multipleChoice;

    final TextStyle questionStyle;
    final Color chipFill;
    final Color chipInk;
    final Color chipEdge;
    final double afterHeader;
    switch (variant) {
      case DesignVariant.refined:
        questionStyle = AppTypography.heading.copyWith(
          fontSize: 18,
          height: 26 / 18,
        );
        // Paper, not field: the question sits directly on the field grey,
        // so a field-grey chip would be invisible. It keeps its own surface.
        chipFill = AppColors.paper;
        chipInk = AppColors.inkSecondary;
        chipEdge = AppColors.border;
        afterHeader = AppSpacing.x4;
        break;
      case DesignVariant.boldA:
        // One step smaller under an image, so the options still start
        // above the fold on a timed exam.
        final bool withImage = currentQuestion.imagePath != null;
        questionStyle = AppTypography.title.copyWith(
          fontSize: withImage ? 20 : 22,
          height: (withImage ? 27 : 30) / (withImage ? 20 : 22),
          letterSpacing: -0.3,
        );
        // "You are here" — the one place the counter earns the brand blue.
        chipFill = AppColors.signal50;
        chipInk = AppColors.signal;
        chipEdge = AppColors.signal50;
        afterHeader = withImage ? AppSpacing.x4 : AppSpacing.x6;
        break;
      case DesignVariant.bento:
        questionStyle = AppTypography.heading.copyWith(
          fontSize: 19,
          height: 27 / 19,
          letterSpacing: -0.2,
        );
        chipFill = AppColors.field;
        chipInk = AppColors.inkSecondary;
        chipEdge = AppColors.field;
        afterHeader = AppSpacing.x3;
        break;
      case DesignVariant.boldB:
        questionStyle = AppTypography.heading.copyWith(
          fontSize: 17,
          height: 25 / 17,
          letterSpacing: -0.1,
        );
        chipFill = AppColors.field;
        chipInk = AppColors.inkSecondary;
        chipEdge = AppColors.border;
        afterHeader = AppSpacing.x4;
        break;
    }

    Widget chip(String text, {Color? fill, Color? ink, Color? edge}) => Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: AppSpacing.x1,
          ),
          decoration: BoxDecoration(
            color: fill ?? chipFill,
            borderRadius: BorderRadius.circular(tokens.chip),
            border: Border.all(color: edge ?? chipEdge),
          ),
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: ink ?? chipInk,
              fontVariations: const [FontVariation('wght', 600)],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );

    final Widget header = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number indicator
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              chip(counter),
              // Neutral, not blue: this is a note about the question, not the
              // current state or an action.
              if (isMultiple)
                chip(
                  localizations.translate('multiple_answers'),
                  fill: AppColors.paper,
                  ink: AppColors.ink,
                  edge: AppColors.borderStrong,
                ),
            ],
          ),
          SizedBox(height: variant == DesignVariant.boldA ? AppSpacing.x4 : AppSpacing.x3),
          // Question text
          Text(currentQuestion.questionText, style: questionStyle),
          if (isMultiple)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x3),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: AppSpacing.x2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(tokens.chip),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      SolarIcons.infoCircleLinear,
                      size: 16,
                      color: AppColors.inkSecondary,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Text(
                        localizations.translate('select_all_correct_answers'),
                        style: AppTypography.label.copyWith(
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );

    return Padding(
      padding: EdgeInsets.only(bottom: afterHeader),
      child: variant == DesignVariant.bento
          // Bento: the question is its own card, the panel the options answer.
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(tokens.card),
                boxShadow: _bentoShadow,
              ),
              child: header,
            )
          : header,
    );
  }

  // ----------------------------------------------------------- options ---

  Widget _buildOptions(
    QuizQuestion currentQuestion,
    DesignVariant variant,
    VariantTokens tokens,
  ) {
    final tiles = currentQuestion.options
        .asMap()
        .entries
        .map((entry) =>
            _buildOption(currentQuestion, entry.key, entry.value, variant, tokens))
        .toList();

    if (variant == DesignVariant.boldB) {
      // Ledger: one block of rows split by hairlines, not a stack of cards.
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.card),
          border: Border.all(color: AppColors.borderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1),
              tiles[i],
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tile in tiles)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x3),
            child: tile,
          ),
      ],
    );
  }

  Widget _buildOption(
    QuizQuestion currentQuestion,
    int index,
    dynamic option,
    DesignVariant variant,
    VariantTokens tokens,
  ) {
    bool isSelected = selectedAnswer == option;
    bool showResult = isAnswerChecked;
    bool isCorrectOption = false;

    // Check if this option is a correct answer
    if (currentQuestion.correctAnswer is List<String>) {
      isCorrectOption = (currentQuestion.correctAnswer as List<String>).contains(option);
    } else {
      isCorrectOption = option == currentQuestion.correctAnswer.toString();
    }

    final Color fill =
        _getGradientForAnswerCard(isSelected, showResult, isCorrectOption, index)
            .colors
            .first;
    final Color stateColor = _answerBorder(isSelected, showResult, isCorrectOption);
    final bool emphasised = isSelected || (showResult && isCorrectOption);

    // The verdict glyph: shape reinforces colour, so right and wrong read
    // without relying on hue alone.
    final String? verdictIcon = showResult && isCorrectOption
        ? AppIcons.check
        : showResult && isSelected
            ? AppIcons.close
            : null;
    final Color verdictColor = isCorrectOption ? AppColors.guide : AppColors.stop;

    final Color textColor = showResult && (isSelected || isCorrectOption)
        ? (isSelected && !isCorrectOption)
            ? AppColors.stop
            : AppColors.guide
        : showResult
            // Disabled after the check: the unchosen, wrong options step back.
            ? AppColors.inkSecondary
            : AppColors.ink;

    // Selection feedback is fast; the verdict gets the full reveal.
    final Duration d =
        AppMotion.duration(context, showResult ? tokens.reveal : tokens.state);

    final Widget tile;
    switch (variant) {
      case DesignVariant.refined:
        tile = AnimatedContainer(
          duration: d,
          curve: AppMotion.enter,
          // The border thickens from 1 to 2 when emphasised; the padding
          // gives back the extra pixel so the text never shifts.
          padding: EdgeInsets.all(emphasised ? AppSpacing.x4 - 1 : AppSpacing.x4),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(tokens.button),
            border: Border.all(color: stateColor, width: emphasised ? 2 : 1),
            boxShadow: AppColors.shadowResting,
          ),
          child: Row(
            children: [
              _buildRadio(
                d,
                isSelected: isSelected,
                stateColor: stateColor,
                verdictIcon: verdictIcon,
                verdictColor: verdictColor,
                emphasised: emphasised,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: d,
                  style: AppTypography.body.copyWith(
                    color: textColor,
                    // Weight holds steady on selection: a bolder
                    // face re-wraps the option and jolts the layout.
                    fontVariations: const [FontVariation('wght', 400)],
                  ),
                  child: Text('$option'),
                ),
              ),
            ],
          ),
        );
        break;

      case DesignVariant.boldA:
        final Color keyFill = verdictIcon != null
            ? verdictColor
            : isSelected
                ? AppColors.signal
                : AppColors.field;
        tile = AnimatedContainer(
          duration: d,
          curve: AppMotion.enter,
          padding: EdgeInsets.all(emphasised ? AppSpacing.x4 - 2 : AppSpacing.x4),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(tokens.button),
            border: Border.all(
              color: emphasised ? stateColor : AppColors.paper,
              width: emphasised ? 2 : 0,
            ),
            boxShadow: emphasised
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0F0E1F4D),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: d,
                curve: AppMotion.enter,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: keyFill,
                  borderRadius: BorderRadius.circular(tokens.chip),
                ),
                alignment: Alignment.center,
                child: _buildKeyFace(
                  d,
                  index: index,
                  verdictIcon: verdictIcon,
                  onFill: isSelected || verdictIcon != null,
                ),
              ),
              const SizedBox(width: AppSpacing.x4),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: d,
                  style: AppTypography.body.copyWith(
                    fontSize: 17,
                    height: 25 / 17,
                    color: textColor,
                    fontVariations: const [FontVariation('wght', 500)],
                  ),
                  child: Text('$option'),
                ),
              ),
            ],
          ),
        );
        break;

      case DesignVariant.bento:
        final Color keyFill = verdictIcon != null
            ? verdictColor
            : isSelected
                ? AppColors.signal
                : AppColors.field;
        tile = AnimatedContainer(
          duration: d,
          curve: AppMotion.enter,
          // Borderless until emphasised; the 2pt border's width is given back
          // by the padding so the text never shifts.
          padding: EdgeInsets.all(emphasised ? AppSpacing.x4 - 2 : AppSpacing.x4),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(tokens.card),
            border: Border.all(
              color: emphasised ? stateColor : AppColors.paper,
              width: emphasised ? 2 : 0,
            ),
            boxShadow: emphasised ? null : _bentoShadow,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: d,
                curve: AppMotion.enter,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: keyFill,
                  borderRadius: BorderRadius.circular(tokens.chip),
                ),
                alignment: Alignment.center,
                child: _buildKeyFace(
                  d,
                  index: index,
                  verdictIcon: verdictIcon,
                  onFill: isSelected || verdictIcon != null,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: d,
                  style: AppTypography.body.copyWith(
                    color: textColor,
                    fontVariations: const [FontVariation('wght', 500)],
                  ),
                  child: Text('$option'),
                ),
              ),
            ],
          ),
        );
        break;

      case DesignVariant.boldB:
        final Color keyFill = verdictIcon != null
            ? verdictColor
            : isSelected
                ? AppColors.signal
                : AppColors.field;
        tile = AnimatedContainer(
          duration: d,
          curve: AppMotion.crisp,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          color: fill,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: d,
                curve: AppMotion.crisp,
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: keyFill,
                  borderRadius: BorderRadius.circular(tokens.chip),
                  border: Border.all(
                    color: verdictIcon != null || isSelected
                        ? keyFill
                        : AppColors.borderStrong,
                  ),
                ),
                alignment: Alignment.center,
                child: _buildKeyFace(
                  d,
                  index: index,
                  verdictIcon: verdictIcon,
                  onFill: isSelected || verdictIcon != null,
                  small: true,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: d,
                  style: AppTypography.body.copyWith(
                    fontSize: 15,
                    height: 22 / 15,
                    color: textColor,
                    // Weight holds steady on selection: a bolder
                    // face re-wraps the option and jolts the layout.
                    fontVariations: const [FontVariation('wght', 400)],
                  ),
                  child: Text('$option'),
                ),
              ),
            ],
          ),
        );
        break;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isAnswerChecked ? null : () => _selectOption(option),
        child: PressScale(
          // Ledger rows live inside one block; they answer with fill alone.
          enabled: !isAnswerChecked && variant != DesignVariant.boldB,
          scale: variant == DesignVariant.bento ? 0.98 : tokens.pressScale,
          duration: tokens.state,
          curve: variant == DesignVariant.boldA ? AppMotion.spring : AppMotion.press,
          child: tile,
        ),
      ),
    );
  }

  /// Refined's radio: ring, then dot on selection, then a verdict glyph.
  Widget _buildRadio(
    Duration d, {
    required bool isSelected,
    required Color stateColor,
    required String? verdictIcon,
    required Color verdictColor,
    required bool emphasised,
  }) {
    final bool verdict = verdictIcon != null;
    return AnimatedContainer(
      duration: d,
      curve: AppMotion.enter,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: verdict ? verdictColor : AppColors.paper.withValues(alpha: 0),
        border: Border.all(
          color: verdict
              ? verdictColor
              : emphasised
                  ? stateColor
                  : AppColors.borderStrong,
          width: isSelected || verdict ? 2 : 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: d,
        switchInCurve: AppMotion.enter,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: verdict
            ? KeyedSubtree(
                key: ValueKey(verdictIcon),
                child: AppIcons.icon(verdictIcon, size: 12, color: AppColors.onSignal),
              )
            : isSelected
                ? Container(
                    key: const ValueKey('dot'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stateColor,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
      ),
    );
  }

  /// The numbered key used by Signal and Ledger: the option's number until a
  /// verdict replaces it with ✓ or ✕. Numbers, not letters — they read the
  /// same in every locale the app ships.
  Widget _buildKeyFace(
    Duration d, {
    required int index,
    required String? verdictIcon,
    required bool onFill,
    bool small = false,
  }) {
    return AnimatedSwitcher(
      duration: d,
      switchInCurve: AppMotion.enter,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: verdictIcon != null
          ? KeyedSubtree(
              key: ValueKey(verdictIcon),
              child: AppIcons.icon(
                verdictIcon,
                size: small ? 13 : 18,
                color: AppColors.onSignal,
              ),
            )
          : Text(
              '${index + 1}',
              key: ValueKey('n$onFill'),
              style: AppTypography.pill.copyWith(
                fontSize: small ? 12 : 15,
                color: onFill ? AppColors.onSignal : AppColors.inkSecondary,
              ),
            ),
    );
  }

  // ----------------------------------------------------------- actions ---

  Widget _buildActions(
    BuildContext context,
    ExamProvider examProvider,
    QuizQuestion currentQuestion,
    DesignVariant variant,
    VariantTokens tokens,
  ) {
    final localizations = AppLocalizations.of(context);
    final bool signal = variant == DesignVariant.boldA;
    final bool ledger = variant == DesignVariant.boldB;
    final bool bento = variant == DesignVariant.bento;
    final double height = signal ? 60 : ledger ? 48 : 56;
    final BorderRadius radius = BorderRadius.circular(tokens.button);
    final Duration state = AppMotion.duration(context, tokens.state);

    Widget label(String text, Color color) => Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.label.copyWith(
            fontSize: ledger ? 15 : 16,
            color: color,
            fontVariations: [FontVariation('wght', signal ? 700 : 600)],
          ),
        );

    // 0 = Skip (secondary), 1 = Choose, 2 = Next (both primary).
    Widget button(int type, String text, VoidCallback? onTap) {
      final bool enabled = onTap != null;
      final Color fg = enabled ? _buttonForeground(type) : AppColors.inkTertiary;
      final Color bg = enabled
          ? _getGradientForButton(type).colors.first
          : AppColors.border;
      final bool primary = type != 0;
      return PressScale(
        enabled: enabled,
        scale: bento ? 0.97 : tokens.pressScale,
        duration: tokens.state,
        curve: signal ? AppMotion.spring : AppMotion.press,
        child: AnimatedContainer(
          duration: state,
          curve: AppMotion.enter,
          height: height,
          decoration: BoxDecoration(
            color: ledger && !primary ? AppColors.paper.withValues(alpha: 0) : bg,
            borderRadius: radius,
            // Bento's secondary pill is borderless: shadow alone lifts it.
            border: primary || bento
                ? null
                : Border.all(color: AppColors.borderStrong),
            boxShadow: ledger
                ? null
                : primary
                    ? (enabled ? AppColors.shadowRaised : null)
                    : AppColors.shadowResting,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: label(text, fg)),
                    // Signal's Next nests its arrow in its own disc.
                    if (signal && type == 2) ...[
                      const SizedBox(width: AppSpacing.x3),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.onSignal.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: AppIcons.icon(
                          AppIcons.chevron,
                          size: 16,
                          color: AppColors.onSignal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final Widget content = isAnswerChecked
        ? KeyedSubtree(
            key: const ValueKey('next'),
            child: SizedBox(
              width: double.infinity,
              child: button(
                2,
                localizations.translate('next'),
                () => _goToNext(examProvider, currentQuestion),
              ),
            ),
          )
        : KeyedSubtree(
            key: const ValueKey('choose'),
            child: Row(
              children: [
                Expanded(
                  child: button(
                    0,
                    localizations.translate('skip'),
                    () => _skipCurrent(examProvider),
                  ),
                ),
                SizedBox(width: ledger ? AppSpacing.x2 : AppSpacing.x4),
                Expanded(
                  child: button(
                    1,
                    localizations.translate('choose'),
                    selectedAnswer == null
                        ? null
                        : () => _checkAnswer(currentQuestion),
                  ),
                ),
              ],
            ),
          );

    return Container(
      decoration: ledger
          ? const BoxDecoration(
              color: AppColors.paper,
              border: Border(top: BorderSide(color: AppColors.border)),
            )
          : null,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4,
        ledger ? AppSpacing.x3 : AppSpacing.x1,
        AppSpacing.x4,
        AppSpacing.x6,
      ),
      child: AnimatedSwitcher(
        duration: state,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: content,
      ),
    );
  }

  /// The question surface.
  ///
  /// Was a pastel gradient cycling blue/green/orange/purple by question number,
  /// so the same question changed colour as you advanced and green appeared on
  /// a question card moments before it had to mean "correct". The question is
  /// content, not a category: it gets plain paper.
  ///
  /// Signature kept so the existing call sites are untouched.
  LinearGradient _getQuestionCardGradient(int currentQuestionNumber) {
    return const LinearGradient(
      colors: [AppColors.paper, AppColors.paper],
    );
  }

  // Enhanced question card widget
  Widget _buildEnhancedQuestionCard(QuizQuestion currentQuestion, int currentQuestionNumber, int totalQuestions) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _getQuestionCardGradient(currentQuestionNumber),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number indicator
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.field,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  AppLocalizations.of(context).translate('question_x_of_y')
                      .replaceAll('{0}', currentQuestionNumber.toString())
                      .replaceAll('{1}', totalQuestions.toString()),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
              ),
              if (currentQuestion.type == QuestionType.multipleChoice) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.signal50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('multiple_answers'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12),
          // Question text
          Text(
            currentQuestion.questionText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.4,
            ),
          ),
          if (currentQuestion.type == QuestionType.multipleChoice)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      SolarIcons.infoCircleLinear,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).translate('select_all_correct_answers'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Action buttons.
  ///
  /// Every one of these was a near-white gradient with coloured text, which
  /// reads as disabled. The primary action is now solid brand blue.
  ///
  /// 0 = Skip (secondary), 1 = Choose, 2 = Next (both primary).
  LinearGradient _getGradientForButton(int buttonType) {
    final Color fill =
        buttonType == 0 ? AppColors.paper : AppColors.signal;
    return LinearGradient(colors: [fill, fill]);
  }

  /// Label colour matching [_getGradientForButton].
  Color _buttonForeground(int buttonType) =>
      buttonType == 0 ? AppColors.ink : AppColors.onSignal;

  /// Answer option surfaces.
  ///
  /// This function previously used the SAME green for two different jobs: as
  /// the verdict colour when `showResult` was true, and as decoration for
  /// option index 1 when it was false. A learner cannot build the association
  /// "green = correct" when green was decorating an arbitrary option one tap
  /// earlier, and telling right from wrong is the entire product.
  ///
  /// Decorative tinting is gone. Unanswered options are plain paper, so the
  /// semantic colours are free to carry their one meaning.
  LinearGradient _getGradientForAnswerCard(
    bool isSelected,
    bool showResult,
    bool isCorrectOption, [
    int index = 0,
  ]) {
    Color fill;

    if (showResult) {
      if (isCorrectOption) {
        fill = AppColors.guideSurface;
      } else if (isSelected) {
        fill = AppColors.stopSurface;
      } else {
        fill = AppColors.paper;
      }
    } else if (isSelected) {
      fill = AppColors.signal50;
    } else {
      fill = AppColors.paper;
    }

    return LinearGradient(colors: [fill, fill]);
  }

  /// The border that carries an option's state, now that fill alone no longer
  /// distinguishes an unanswered option from the page behind it.
  Color _answerBorder(bool isSelected, bool showResult, bool isCorrectOption) {
    if (showResult) {
      if (isCorrectOption) return AppColors.guide;
      if (isSelected) return AppColors.stop;
      return AppColors.border;
    }
    return isSelected ? AppColors.signal : AppColors.border;
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await _showExitConfirmation(context);
    return shouldPop ?? false;
  }

  /// Leaves the exam. Moved unchanged from the dialog's Exit button so each
  /// variant's dialog runs the same analytics and cancellation.
  Future<void> _exitExam(BuildContext context) async {
    // Get analytics data before canceling exam
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final exam = examProvider.currentExam;

    if (exam != null) {
      // Get providers for analytics
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Calculate analytics parameters
      final examId = 'exam_${exam.startTime.millisecondsSinceEpoch}';
      final questionsCompleted = exam.answeredQuestionsCount;
      final correctAnswers = exam.correctAnswersCount;
      final timeSpentSeconds = exam.elapsedTime.inSeconds;
      final state = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
      final language = languageProvider.language;
      final licenseType = 'driver'; // Default license type

      // Log exam terminated analytics event
      await analyticsService.logExamTerminated(
        examId: examId,
        questionsCompleted: questionsCompleted,
        correctAnswers: correctAnswers,
        timeSpentSeconds: timeSpentSeconds,
        terminationReason: 'user_exit',
        state: state,
        language: language,
        licenseType: licenseType,
      );

      print('📊 Analytics: exam_terminated logged (exam_id: $examId, completed: $questionsCompleted/40, time: ${timeSpentSeconds}s)');
    }

    Navigator.of(context).pop(true); // Yes, exit
    // Cancel the exam
    examProvider.cancelExam();
    Navigator.of(context).pop(); // Return to previous screen
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    final variant = designVariant.value;
    final tokens = VariantTokens.of(variant);
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        final bool signal = variant == DesignVariant.boldA;
        final bool ledger = variant == DesignVariant.boldB;
        final double height = signal ? 52 : 44;
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.button),
        );

        // Staying is the safe, primary choice; leaving discards the attempt,
        // so it takes the destructive colour — the one job red has besides
        // "wrong".
        final Widget stay = FilledButton(
          onPressed: () {
            Navigator.of(context).pop(false); // No, stay
          },
          style: FilledButton.styleFrom(
            minimumSize: Size(signal ? double.infinity : 0, height),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            shape: shape,
          ),
          child: Text(localizations.translate('stay')),
        );
        final Widget exit = TextButton(
          onPressed: () => _exitExam(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.stop,
            minimumSize: Size(signal ? double.infinity : 0, height),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            shape: ledger
                ? shape.copyWith(
                    side: const BorderSide(color: AppColors.borderStrong),
                  )
                : shape,
            textStyle: AppTypography.label.copyWith(
              fontSize: 16,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
          child: Text(localizations.translate('exit')),
        );

        if (signal) {
          return Dialog(
            backgroundColor: AppColors.paper,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.bar),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x6,
                AppSpacing.x8,
                AppSpacing.x6,
                AppSpacing.x4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    localizations.translate('exit_test_title'),
                    style: AppTypography.title.copyWith(
                      fontVariations: const [FontVariation('wght', 800)],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    localizations.translate('exit_test_message'),
                    style: AppTypography.body.copyWith(
                      color: AppColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  stay,
                  const SizedBox(height: AppSpacing.x2),
                  exit,
                ],
              ),
            ),
          );
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(ledger ? tokens.bar : AppRadius.xl),
          ),
          title: Text(
            localizations.translate('exit_test_title'),
            style: ledger
                ? AppTypography.heading.copyWith(fontSize: 18)
                : AppTypography.heading,
          ),
          content: Text(
            localizations.translate('exit_test_message'),
            style: AppTypography.body.copyWith(
              color: AppColors.inkSecondary,
              fontSize: ledger ? 15 : 16,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            0,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          actions: [exit, stay],
        );
      },
    );
  }
}
