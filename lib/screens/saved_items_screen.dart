import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/quiz_data.dart';
import '../providers/progress_provider.dart';
import '../models/quiz_question.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({Key? key}) : super(key: key);

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  int? _expandedIndex;
  Map<String, dynamic> _selectedAnswers = {};
  Map<String, bool> _checkedAnswers = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressProvider>(
      builder: (context, progressProvider, child) {
        final savedQuestionIds = progressProvider.progress.savedQuestions;
        final savedQuestions = savedQuestionIds
            .map((id) => quizQuestions[id])
            .whereType<QuizQuestion>()
            .toList();
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Збережені'),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          body: savedQuestions.isEmpty
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
                  itemCount: savedQuestions.length,
                  itemBuilder: (context, index) {
                    final question = savedQuestions[index];
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
                                  IconButton(
                                    icon: Icon(
                                      Icons.favorite, 
                                      color: Colors.red
                                    ),
                                    onPressed: () {
                                      progressProvider.toggleSavedQuestion(question.id);
                                    },
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
                              
                            // Answer options
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: question.options.map((option) {
                                  bool isSelected = selectedAnswer == option;
                                  bool showResult = isAnswerChecked;
                                  bool isCorrectOption = option == question.correctAnswer;
                                  
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
                                  
                                  return GestureDetector(
                                    onTap: isAnswerChecked 
                                        ? null 
                                        : () {
                                            setState(() {
                                              _selectedAnswers[question.id] = option;
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
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          color: showResult && (isSelected || isCorrectOption) 
                                              ? Colors.white 
                                              : Colors.black,
                                        ),
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
                                    onPressed: selectedAnswer == null
                                        ? null
                                        : () {
                                            setState(() {
                                              _checkedAnswers[question.id] = 
                                                selectedAnswer == question.correctAnswer;
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
      },
    );
  }
}
