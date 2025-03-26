import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/quiz_question.dart';
import '../providers/progress_provider.dart';
import '../providers/auth_provider.dart';
import '../services/service_locator.dart';

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
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? '';
      
      // Get saved question IDs from both old and new structure
      List<String> savedQuestionIds = [];
      
      // Add questions from new structure (preferred)
      if (progressProvider.progress.savedItems.containsKey('question')) {
        savedQuestionIds.addAll(progressProvider.progress.savedItems['question'] ?? []);
      }
      
      // Add any remaining questions from old structure that aren't already included
      for (final id in progressProvider.progress.savedQuestions) {
        if (!savedQuestionIds.contains(id)) {
          savedQuestionIds.add(id);
        }
      }

      // Load questions from Firebase
      List<QuizQuestion> questions = [];
      
      if (savedQuestionIds.isNotEmpty) {
        // Use Firebase to fetch questions from all topics
        for (final topicId in ['q_topic_il_ua_01', 'q_topic_il_ua_02', 'q_topic_il_ua_03', 'q_topic_il_ua_04']) {
          try {
            final topicQuestions = await serviceLocator.content.getQuizQuestions(
              topicId, // First parameter is topicId
              'uk',   // Second parameter is language
              'IL'    // Third parameter is state
            );
            
            // Only add questions that are in the saved question IDs
            for (final question in topicQuestions) {
              if (savedQuestionIds.contains(question.id)) {
                questions.add(question);
              }
            }
          } catch (e) {
            print('Error loading questions for topic $topicId: $e');
          }
        }
        
        // Sort the questions by the order they were saved (if available)
        // This ensures that most recently added questions appear last in the list
        final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
        questions.sort((a, b) {
          final orderA = progressProvider.getQuestionSaveOrder(a.id);
          final orderB = progressProvider.getQuestionSaveOrder(b.id);
          return orderA.compareTo(orderB); // Ascending order - older items first, newer last
        });
      }

      setState(() {
        _savedQuestions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load saved questions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Збережені'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : _error.isNotEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(_error, textAlign: TextAlign.center),
                    ],
                  ),
                )
              : _savedQuestions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Немає збережених питань',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Text(
                              'Натисніть на сердечко в питаннях, щоб додати їх до списку збережених',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _savedQuestions.length,
                      itemBuilder: (context, index) {
                        final question = _savedQuestions[index];
                        bool isExpanded = _expandedIndex == index;
                        dynamic selectedAnswer = _selectedAnswers[question.id];
                        bool isAnswerChecked = _checkedAnswers.containsKey(question.id);
                        bool? isCorrect = _checkedAnswers[question.id];
                        
                        return Card(
                          margin: EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              // Header with question number and title
                              InkWell(
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
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade800,
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
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Consumer<ProgressProvider>(
                                        builder: (context, provider, _) => IconButton(
                                          icon: Icon(
                                            Icons.favorite, 
                                            color: Colors.red
                                          ),
                                          onPressed: () {
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
                                      Icon(
                                        isExpanded 
                                            ? Icons.keyboard_arrow_up 
                                            : Icons.keyboard_arrow_down,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                                // Expanded content with answer options
                              if (isExpanded) ...[
                                // Question image (if available)
                                if (question.imagePath != null)
                                  Container(
                                    width: double.infinity,
                                    height: 150,
                                    child: Image.asset(
                                      question.imagePath!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => 
                                        Center(child: Icon(Icons.broken_image, size: 50)),
                                    ),
                                  ),
                                
                                // Multiple choice indicator if applicable
                                if (question.type == QuestionType.multipleChoice)
                                  Padding(
                                    padding: EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
                                    child: Text(
                                      "Оберіть всі правильні відповіді",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                  
                                // Answer options
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
                                      if (showResult) {
                                        if (isSelected && isCorrectOption) {
                                          backgroundColor = Colors.green;
                                        } else if (isSelected && !isCorrectOption) {
                                          backgroundColor = Colors.red;
                                        } else if (isCorrectOption) {
                                          backgroundColor = Colors.green;
                                        }
                                      } else if (isSelected) {
                                        backgroundColor = Colors.blue.shade100;
                                      }
                                      
                                      // Use circular indicators for both single and multiple choice
                                      Widget selectionIndicator = Container(
                                        width: 24,
                                        height: 24,
                                        margin: EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.grey),
                                        ),
                                        child: isSelected
                                            ? Container(
                                                margin: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.blue,
                                                ),
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
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: backgroundColor,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected ? Colors.blue : Colors.grey.shade300,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              selectionIndicator,
                                              Expanded(
                                                child: Text(
                                                  option,
                                                  style: TextStyle(
                                                    color: showResult && (isSelected || isCorrectOption) 
                                                        ? Colors.white 
                                                        : Colors.black,
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
                                
                                // Explanation (if answer checked)
                                if (isAnswerChecked && question.explanation != null)
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    margin: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (question.ruleReference != null)
                                          Text(
                                            question.ruleReference!,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        SizedBox(height: 8),
                                        Text(question.explanation!),
                                      ],
                                    ),
                                  ),
                                
                                // Action buttons
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: isAnswerChecked
                                    ? ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedAnswers.remove(question.id);
                                            _checkedAnswers.remove(question.id);
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          minimumSize: Size(double.infinity, 48),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                        ),
                                        child: Text('Спробувати ще раз'),
                                      )
                                    : ElevatedButton(
                                        onPressed: (_selectedAnswers[question.id]?.isEmpty ?? true)
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
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          minimumSize: Size(double.infinity, 48),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                        ),
                                        child: Text('Перевірити'),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
