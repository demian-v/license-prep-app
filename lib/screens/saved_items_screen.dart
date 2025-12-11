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

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({Key? key}) : super(key: key);

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> with TickerProviderStateMixin {
  int? _expandedIndex;
  Map<String, Set<String>> _selectedAnswers = {}; // Changed to Set<String> for multiple selections
  Map<String, bool> _checkedAnswers = {};
  List<QuizQuestion> _savedQuestions = [];
  bool _isLoading = true;
  String _error = '';
  
  // Animation controllers
  late AnimationController _titleAnimationController;
  late Animation<double> _titlePulseAnimation;
  late AnimationController _cardAnimationController;
  late Animation<double> _cardScaleAnimation;
  
  // Animation state
  double _heartAnimationValue = 1.0;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _titleAnimationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    
    _titlePulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _cardScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(_cardAnimationController);
    
    // Start animations
    _titleAnimationController.repeat(reverse: true);
    
    // Check if we need to migrate saved questions from old to new structure
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? '';
      
      progressProvider.migrateSavedQuestionsIfNeeded(userId);
      _loadSavedQuestions();
    });
  }

  @override
  void dispose() {
    _titleAnimationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  // Gradient helper methods to match Tests screen exactly
  LinearGradient _getCardGradient(int index) {
    Color startColor = Colors.white;
    Color endColor;
    
    // Cycle through colors like Tests screen: blue, green, orange, purple
    switch (index % 4) {
      case 0: // Blue
        endColor = Colors.blue.shade50.withOpacity(0.4);
        break;
      case 1: // Green
        endColor = Colors.green.shade50.withOpacity(0.4);
        break;
      case 2: // Orange
        endColor = Colors.orange.shade50.withOpacity(0.4);
        break;
      case 3: // Purple
        endColor = Colors.purple.shade50.withOpacity(0.4);
        break;
      default:
        endColor = Colors.blue.shade50.withOpacity(0.4);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  // Clean minimal helper methods to match Tests screen
  Color _getNumberCircleBackgroundColor(int index) {
    switch (index % 4) {
      case 0: return Colors.blue.shade50.withOpacity(0.8);
      case 1: return Colors.green.shade50.withOpacity(0.8);
      case 2: return Colors.orange.shade50.withOpacity(0.8);
      case 3: return Colors.purple.shade50.withOpacity(0.8);
      default: return Colors.blue.shade50.withOpacity(0.8);
    }
  }

  Color _getNumberCircleTextColor(int index) {
    switch (index % 4) {
      case 0: return Colors.blue.shade600;
      case 1: return Colors.green.shade600;
      case 2: return Colors.orange.shade600;
      case 3: return Colors.purple.shade600;
      default: return Colors.blue.shade600;
    }
  }

  // Clean minimal title widget
  Widget _buildCleanTitle() {
    return AnimatedBuilder(
      animation: _titlePulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _titlePulseAnimation.value,
          child: Text(
            AppLocalizations.of(context).translate('saved'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        );
      },
    );
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA), // Clean light grey background like screenshots 1-4
      appBar: AppBar(
        title: _buildCleanTitle(),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? Center(
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      spreadRadius: 0,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400),
                ),
              ),
            )
          : _error.isNotEmpty 
              ? Center(
                  child: Container(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.05),
                                spreadRadius: 0,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade400,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          _error,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _savedQuestions.isEmpty
                  ? Center(
                      child: Container(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.05),
                                    spreadRadius: 0,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.favorite_border,
                                size: 64,
                                color: Colors.red.shade300,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              AppLocalizations.of(context).translate('no_saved_questions'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 12),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                AppLocalizations.of(context).translate('tap_heart_to_save'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _savedQuestions.length,
                      itemBuilder: (context, index) {
                        final question = _savedQuestions[index];
                        bool isExpanded = _expandedIndex == index;

                        bool isAnswerChecked = _checkedAnswers.containsKey(question.id);
                        bool? isCorrect = _checkedAnswers[question.id];
                        
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: _getCardGradient(index), // Tests screen gradient
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade200, // Subtle border
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 0,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                // Clean minimal header with question number and title
                                InkWell(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  onTap: () {
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
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        // Clean minimal number circle
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _getNumberCircleBackgroundColor(index), // Subtle pastel background
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: _getNumberCircleTextColor(index), // Darker text color
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 16),
                                            child: Text(
                                              question.questionText,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Simple heart icon without shadows
                                        Consumer<ProgressProvider>(
                                          builder: (context, provider, _) => AnimatedScale(
                                            scale: _heartAnimationValue,
                                            duration: Duration(milliseconds: 150),
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.favorite,
                                                color: Colors.red.shade400,
                                                size: 24,
                                              ),
                                              onPressed: () {
                                                // Add animation trigger
                                                setState(() {
                                                  _heartAnimationValue = 0.8;
                                                });
                                                Future.delayed(Duration(milliseconds: 150), () {
                                                  setState(() {
                                                    _heartAnimationValue = 1.0;
                                                  });
                                                });
                                                
                                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                                final userId = authProvider.user?.id ?? '';
                                                provider.toggleSavedQuestionWithUserId(question.id, userId);
                                                // Reload the questions after a short delay
                                                Future.delayed(Duration(milliseconds: 500), () {
                                                  _loadSavedQuestions();
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        AnimatedRotation(
                                          turns: isExpanded ? 0.5 : 0.0,
                                          duration: Duration(milliseconds: 300),
                                          child: Icon(
                                            Icons.keyboard_arrow_down,
                                            color: Colors.grey,
                                            size: 28,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // Clean expanded content with minimal animation
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  height: isExpanded ? null : 0,
                                  child: isExpanded ? Column(
                                    children: [
                                      // Question image (if available)
                                      if (question.imagePath != null)
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: AdaptiveQuestionImage(
                                            imagePath: question.imagePath!,
                                            assetFallback: question.imagePath,
                                          ),
                                        ),
                                      
                                      // Clean multiple choice indicator if applicable
                                      if (question.type == QuestionType.multipleChoice)
                                        Container(
                                          margin: EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50.withOpacity(0.5), // Very subtle background
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.blue.shade100,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            AppLocalizations.of(context).translate('select_all_correct_answers'),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        
                                      // Clean minimal answer options
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16),
                                        child: Column(
                                          children: question.options.map((option) {
                                            // Initialize the set if it doesn't exist yet
                                            if (!_selectedAnswers.containsKey(question.id)) {
                                              _selectedAnswers[question.id] = <String>{};
                                            }
                                            
                                            bool isSelected = _selectedAnswers[question.id]?.contains(option) ?? false;
                                            bool showResult = isAnswerChecked;
                                            bool isCorrectOption = false;
                                            
                                            // Check if this option is a correct answer
                                            if (question.correctAnswer is List<String>) {
                                              isCorrectOption = (question.correctAnswer as List<String>).contains(option);
                                            } else {
                                              isCorrectOption = option == question.correctAnswer.toString();
                                            }
                                            
                                            Color backgroundColor = Colors.white;
                                            Color textColor = Colors.black87;
                                            Color borderColor = Colors.grey.shade200;
                                            
                                            if (showResult) {
                                              if (isSelected && isCorrectOption) {
                                                backgroundColor = Colors.green.shade50; // Very subtle green
                                                borderColor = Colors.green.shade200;
                                                textColor = Colors.green.shade800;
                                              } else if (isSelected && !isCorrectOption) {
                                                backgroundColor = Colors.red.shade50; // Very subtle red
                                                borderColor = Colors.red.shade200;
                                                textColor = Colors.red.shade800;
                                              } else if (isCorrectOption) {
                                                backgroundColor = Colors.green.shade50;
                                                borderColor = Colors.green.shade200;
                                                textColor = Colors.green.shade800;
                                              }
                                            } else if (isSelected) {
                                              backgroundColor = Colors.blue.shade50.withOpacity(0.3); // Very subtle blue tint
                                              borderColor = Colors.blue.shade200;
                                            }
                                            
                                            // Clean minimal selection indicator
                                            Widget selectionIndicator = Container(
                                              width: 24,
                                              height: 24,
                                              margin: EdgeInsets.only(right: 12),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected ? Colors.blue.shade400 : Colors.white,
                                                border: Border.all(
                                                  color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
                                                  width: 2,
                                                ),
                                              ),
                                              child: isSelected
                                                ? Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 14,
                                                  )
                                                : null,
                                            );
                                            
                                            return GestureDetector(
                                              onTap: isAnswerChecked 
                                                  ? null 
                                                  : () {
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
                                                    },
                                              child: Container(
                                                width: double.infinity,
                                                margin: EdgeInsets.only(bottom: 12),
                                                padding: EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: backgroundColor,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: borderColor,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    selectionIndicator,
                                                    Expanded(
                                                      child: Text(
                                                        option,
                                                        style: TextStyle(
                                                          color: textColor,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      
                                      // Explanation section matching first screenshot design
                                      if (isAnswerChecked && question.explanation != null)
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Blue lightbulb header like first screenshot
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.lightbulb_outline,
                                                    color: Colors.blue.shade600,
                                                    size: 18,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    AppLocalizations.of(context).translate('explanation'),
                                                    style: TextStyle(
                                                      color: Colors.blue.shade600,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              // Blue rule reference link like first screenshot
                                              if (question.ruleReference != null)
                                                Text(
                                                  question.ruleReference!,
                                                  style: TextStyle(
                                                    color: Colors.blue.shade600,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              if (question.ruleReference != null)
                                                SizedBox(height: 8),
                                              // Explanation text in black like first screenshot
                                              Text(
                                                question.explanation!,
                                                style: TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 14,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      
                                      // Clean minimal action buttons
                                      Padding(
                                        padding: EdgeInsets.all(16),
                                        child: isAnswerChecked
                                          ? Container(
                                              width: double.infinity,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100, // Light grey background
                                                borderRadius: BorderRadius.circular(24),
                                                border: Border.all(
                                                  color: Colors.grey.shade200,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(24),
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedAnswers.remove(question.id);
                                                      _checkedAnswers.remove(question.id);
                                                    });
                                                  },
                                                  child: Center(
                                                    child: Text(
                                                      AppLocalizations.of(context).translate('try_again'),
                                                      style: TextStyle(
                                                        color: Colors.grey.shade700,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: double.infinity,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: (_selectedAnswers[question.id]?.isEmpty ?? true)
                                                  ? Colors.grey.shade200 // Light grey when disabled
                                                  : Colors.blue.shade50, // Very subtle blue when enabled
                                                borderRadius: BorderRadius.circular(24),
                                                border: Border.all(
                                                  color: (_selectedAnswers[question.id]?.isEmpty ?? true)
                                                    ? Colors.grey.shade300
                                                    : Colors.blue.shade200,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(24),
                                                  onTap: (_selectedAnswers[question.id]?.isEmpty ?? true)
                                                    ? null
                                                    : () {
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
                                                      },
                                                  child: Center(
                                                    child: Text(
                                                      AppLocalizations.of(context).translate('check'),
                                                      style: TextStyle(
                                                        color: (_selectedAnswers[question.id]?.isEmpty ?? true)
                                                          ? Colors.grey.shade500
                                                          : Colors.blue.shade700,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                      ),
                                    ],
                                  ) : SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
