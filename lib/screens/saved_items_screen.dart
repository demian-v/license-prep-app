import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/quiz_question.dart';
import '../providers/progress_provider.dart';
import '../providers/auth_provider.dart';
import '../services/service_locator.dart';
import '../services/direct_firestore_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/adaptive_question_image.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({Key? key}) : super(key: key);

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  int? _expandedIndex;
  Map<String, Set<String>> _selectedAnswers = {}; // Changed to Set<String> for multiple selections
  Map<String, bool> _checkedAnswers = {};
  List<QuizQuestion> _savedQuestions = [];
  bool _isLoading = true;
  String _error = '';
  
  // Presentation only: questions being un-saved, animating out until the
  // reload drops them from the list.
  final Set<String> _leaving = {};

  @override
  void initState() {
    super.initState();
    
    // Check if we need to migrate saved questions from old to new structure
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? '';
      
      progressProvider.migrateSavedQuestionsIfNeeded(userId);
      _loadSavedQuestions();
    });
  }

  Future<void> _loadSavedQuestions() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? '';
      
      List<QuizQuestion> questions = [];
      
      try {
        // 🚀 Primary: Try optimized Firebase Functions first
        print('🔄 Trying optimized getSavedQuestionsWithContent...');
        final response = await serviceLocator.progress.getSavedQuestionsWithContent(userId);
        
        if (response is Map<String, dynamic> && response.containsKey('questions')) {
          final questionsData = response['questions'] as List;
          
          questions = questionsData.map((questionData) {
            return QuizQuestion.fromMap(questionData);
          }).toList();
          
          print('✅ Optimized Firebase Functions returned ${questions.length} saved questions with content');
        }
      } catch (functionsError) {
        print('❌ Optimized Firebase Functions failed: $functionsError');
        
        // 🔥 Backup: Use legacy approach with DirectFirestore
        print('🔄 Using legacy DirectFirestore backup...');
        
        List<String> savedQuestionIds = [];
        
        try {
          // Try legacy Firebase Functions for question IDs
          final savedItemsResponse = await serviceLocator.progress.getSavedItems(userId);
          
          if (savedItemsResponse is Map<String, dynamic> && 
              savedItemsResponse.containsKey('savedQuestions')) {
            final savedQuestions = savedItemsResponse['savedQuestions'];
            if (savedQuestions is List) {
              savedQuestionIds = savedQuestions.cast<String>();
              print('✅ Legacy Firebase Functions returned ${savedQuestionIds.length} saved question IDs');
            }
          }
        } catch (legacyError) {
          print('❌ Legacy Firebase Functions failed: $legacyError');
          
          // Final backup: Direct Firestore with timestamp sorting
          final directFirestore = serviceLocator.directFirestore;
          final savedQuestionsData = await directFirestore.getSavedQuestionsWithTimestamps(userId);
          savedQuestionIds = savedQuestionsData.map((data) => data['questionId'] as String).toList();
          
          print('✅ DirectFirestore returned ${savedQuestionIds.length} saved question IDs (sorted by timestamp)');
        }

        // Load question content using direct question loading (NEW APPROACH)
        if (savedQuestionIds.isNotEmpty) {
          print('🔄 Loading ${savedQuestionIds.length} questions directly by ID...');
          
          for (final questionId in savedQuestionIds) {
            try {
              print('📚 Loading question: $questionId');
              final question = await serviceLocator.content.getQuestionById(questionId);
              
              if (question != null) {
                questions.add(question);
                print('✅ Added saved question: ${question.id}');
              } else {
                print('❌ Question not found: $questionId');
              }
            } catch (e) {
              print('❌ Error loading question $questionId: $e');
            }
          }
          
          // Sort questions to match the chronological order from savedQuestionIds
          questions.sort((a, b) {
            final indexA = savedQuestionIds.indexOf(a.id);
            final indexB = savedQuestionIds.indexOf(b.id);
            return indexA.compareTo(indexB);
          });
        }
      }

      print('🎉 Successfully loaded ${questions.length} saved questions');

      setState(() {
        _savedQuestions = questions;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading saved questions: $e');
      setState(() {
        _error = 'Failed to load saved questions: $e';
        _isLoading = false;
      });
    }
  }


  // Handlers moved unchanged from the inline closures in `build`, so the
  // presentation can change without touching expanding, un-saving,
  // selecting or checking.

  void _toggleExpanded(int index, QuizQuestion question, bool isExpanded) {
    setState(() {
      if (isExpanded) {
        _expandedIndex = null;
      } else {
        _expandedIndex = index;
        // Reset answer state when expanding
        _selectedAnswers.remove(question.id);
        _checkedAnswers.remove(question.id);
      }
    });
  }

  void _unsave(ProgressProvider provider, QuizQuestion question) {
    // Animation trigger: the heart empties and the card leaves the list.
    setState(() {
      _leaving.add(question.id);
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? '';
    provider.toggleSavedQuestionWithUserId(question.id, userId);
    // Reload the questions after a short delay
    Future.delayed(Duration(milliseconds: 500), () {
      _loadSavedQuestions().then((_) {
        if (mounted) setState(() => _leaving.remove(question.id));
      });
    });
  }

  void _selectOption(QuizQuestion question, String option, bool isSelected) {
    setState(() {
      if (question.type == QuestionType.multipleChoice) {
        // Toggle selection for multiple choice
        if (isSelected) {
          _selectedAnswers[question.id]?.remove(option);
        } else {
          _selectedAnswers[question.id]?.add(option);
        }
      } else {
        // Single selection for other types
        _selectedAnswers[question.id] = {option};
      }
    });
  }

  void _checkAnswer(QuizQuestion question) {
    setState(() {
      // Check answers based on question type
      if (question.type == QuestionType.multipleChoice) {
        final selectedSet = _selectedAnswers[question.id] ?? <String>{};
        
        if (question.correctAnswer is List<String>) {
          final correctList = question.correctAnswer as List<String>;
          _checkedAnswers[question.id] = 
            selectedSet.length == correctList.length &&
            correctList.every((answer) => selectedSet.contains(answer));
        } else {
          _checkedAnswers[question.id] = 
            selectedSet.contains(question.correctAnswer.toString());
        }
      } else {
        // Single choice question
        final selectedOption = _selectedAnswers[question.id]?.first;
        
        if (question.correctAnswer is List<String> && 
            (question.correctAnswer as List<String>).isNotEmpty) {
          _checkedAnswers[question.id] = 
            selectedOption == (question.correctAnswer as List<String>)[0];
        } else {
          _checkedAnswers[question.id] = 
            selectedOption == question.correctAnswer.toString();
        }
      }
    });
  }

  void _tryAgain(QuizQuestion question) {
    setState(() {
      _selectedAnswers.remove(question.id);
      _checkedAnswers.remove(question.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(
        title: localizations.translate('saved'),
        onBack: () => Navigator.pop(context),
      ),
      // The spinner is for the first load only. A reload after un-saving
      // keeps the list on screen, so the leaving card's motion is not cut
      // by a flash to a spinner and a replayed entrance.
      body: _isLoading && _savedQuestions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildMessage(
                  icon: SolarIcons.dangerCircleLinear,
                  title: _error,
                )
              : _savedQuestions.isEmpty
                  ? _buildMessage(
                      icon: SolarIcons.heartLinear,
                      title: localizations.translate('no_saved_questions'),
                      message: localizations.translate('tap_heart_to_save'),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.x4,
                        AppSpacing.x2,
                        AppSpacing.x4,
                        AppSpacing.x6 + MediaQuery.of(context).padding.bottom,
                      ),
                      itemCount: _savedQuestions.length,
                      // Cards are matched by question, not position, so after
                      // an un-save the cards below keep their state and slide
                      // up instead of being rebuilt (and re-entering).
                      findChildIndexCallback: (key) {
                        final id = (key as ValueKey<String>).value;
                        final i = _savedQuestions.indexWhere((q) => q.id == id);
                        return i < 0 ? null : i;
                      },
                      itemBuilder: (context, index) => _LeaveTransition(
                        key: ValueKey(_savedQuestions[index].id),
                        leaving: _leaving.contains(_savedQuestions[index].id),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                          child: StaggerIn(
                            index: index,
                            count: _savedQuestions.length,
                            curve: BentoTokens.curve,
                            child: _buildSavedCard(index),
                          ),
                        ),
                      ),
                    ),
    );
  }

  /// The empty and error states: a soft red disc (the saved heart's colour,
  /// or the error's), a title, then one quiet line.
  Widget _buildMessage({
    required IconData icon,
    required String title,
    String? message,
  }) {
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
              child: Icon(icon, size: 40, color: AppColors.stop),
            ),
            const SizedBox(height: AppSpacing.x6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.heading.copyWith(
                fontSize: 20,
                height: 26 / 20,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  fontSize: 15,
                  height: 22 / 15,
                  color: AppColors.inkSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A saved question as a Bento card: its number and text, the red saved
  /// heart (tap to un-save), and a chevron — the card opens in place to
  /// answer the question again. The number is neutral: the old
  /// blue/green/orange/purple cycle by position spent the verdict colours on
  /// decoration.
  Widget _buildSavedCard(int index) {
    final question = _savedQuestions[index];
    final bool isExpanded = _expandedIndex == index;
    final bool isAnswerChecked = _checkedAnswers.containsKey(question.id);
    final localizations = AppLocalizations.of(context);
    final Duration d = AppMotion.duration(context, AppMotion.base);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleExpanded(index, question, isExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(BentoTokens.chip),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: AppTypography.pill.copyWith(
                          fontSize: 15,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(
                        question.questionText,
                        style: AppTypography.body.copyWith(
                          fontSize: 16,
                          height: 22 / 16,
                          color: AppColors.ink,
                          fontVariations: const [FontVariation('wght', 500)],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x1),
                    Consumer<ProgressProvider>(
                      builder: (context, provider, _) {
                        final bool leaving = _leaving.contains(question.id);
                        return IconButton(
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          // The heart answers first: it empties with a short
                          // pop, then the card leaves.
                          icon: AnimatedSwitcher(
                            duration: AppMotion.duration(context, AppMotion.fast),
                            switchInCurve: AppMotion.enter,
                            transitionBuilder: (child, animation) => ScaleTransition(
                              scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                              child: FadeTransition(opacity: animation, child: child),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey(leaving),
                              child: AppIcons.icon(
                                leaving ? AppIcons.saved : AppIcons.savedFilled,
                                size: 22,
                                color: AppColors.stop,
                              ),
                            ),
                          ),
                          onPressed: leaving ? null : () => _unsave(provider, question),
                        );
                      },
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: d,
                      curve: AppMotion.enter,
                      child: const Icon(
                        SolarIcons.altArrowDownLinear,
                        color: AppColors.inkSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x2),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: d,
              curve: AppMotion.enter,
              alignment: Alignment.topCenter,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4,
                        0,
                        AppSpacing.x4,
                        AppSpacing.x4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Question image (if available)
                          if (question.imagePath != null)
                            AdaptiveQuestionImage(
                              imagePath: question.imagePath!,
                              assetFallback: question.imagePath,
                            ),
                          if (question.type == QuestionType.multipleChoice)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.x3),
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
                          ..._buildOptions(question, isAnswerChecked),
                          if (isAnswerChecked && question.explanation != null)
                            BentoExplanation(
                              title: localizations.translate('explanation'),
                              ruleReference: question.ruleReference,
                              text: question.explanation!,
                              onCard: true,
                            ),
                          const SizedBox(height: AppSpacing.x3),
                          isAnswerChecked
                              ? BentoActionButton(
                                  text: localizations.translate('try_again'),
                                  onTap: () => _tryAgain(question),
                                  primary: false,
                                  onCard: true,
                                )
                              : BentoActionButton(
                                  text: localizations.translate('check'),
                                  onTap: (_selectedAnswers[question.id]?.isEmpty ?? true)
                                      ? null
                                      : () => _checkAnswer(question),
                                ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  /// The options, with the same ✓/✕ verdict as the question pages, drawn as
  /// field panels inside the card.
  List<Widget> _buildOptions(QuizQuestion question, bool isAnswerChecked) {
    // Initialize the set if it doesn't exist yet
    if (!_selectedAnswers.containsKey(question.id)) {
      _selectedAnswers[question.id] = <String>{};
    }
    return [
      for (final entry in question.options.asMap().entries)
        Builder(builder: (context) {
          final option = entry.value;
          final bool isSelected =
              _selectedAnswers[question.id]?.contains(option) ?? false;
          bool isCorrectOption = false;
          
          // Check if this option is a correct answer
          if (question.correctAnswer is List<String>) {
            isCorrectOption = (question.correctAnswer as List<String>).contains(option);
          } else {
            isCorrectOption = option == question.correctAnswer.toString();
          }
          
          return BentoOptionTile(
            index: entry.key,
            text: option,
            isSelected: isSelected,
            showResult: isAnswerChecked,
            isCorrectOption: isCorrectOption,
            onCard: true,
            onTap: isAnswerChecked
                ? null
                : () => _selectOption(question, option, isSelected),
          );
        }),
    ];
  }
}

/// Takes an un-saved card out of the list: after the heart's pop, the card
/// fades and drifts right while its height closes, so the cards below glide
/// up into its place. One-shot; under Reduce Motion it is gone at once.
class _LeaveTransition extends StatefulWidget {
  const _LeaveTransition({
    super.key,
    required this.leaving,
    required this.child,
  });

  final bool leaving;
  final Widget child;

  @override
  State<_LeaveTransition> createState() => _LeaveTransitionState();
}

class _LeaveTransitionState extends State<_LeaveTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(covariant _LeaveTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving == oldWidget.leaving) return;
    // Heart pop (fast), then the card leaves (base).
    final duration = AppMotion.duration(context, AppMotion.fast + AppMotion.base);
    _controller.duration = duration;
    if (widget.leaving) {
      duration == Duration.zero ? _controller.value = 0 : _controller.reverse();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Played in reverse (1 → 0). The first ~40% of the time is the heart's
    // pop; the card then fades and slides, and its height closes last.
    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.8, curve: AppMotion.exit),
      reverseCurve: const Interval(0.35, 0.8, curve: AppMotion.exit),
    );
    final size = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: AppMotion.enter),
      reverseCurve: const Interval(0, 0.6, curve: AppMotion.enter),
    );
    return SizeTransition(
      sizeFactor: size,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
              .animate(fade),
          child: widget.child,
        ),
      ),
    );
  }
}
