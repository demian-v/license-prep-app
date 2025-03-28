class LocalizedContent {
  final Map<String, String> titles;
  final Map<String, String> descriptions;
  final String id;
  final String type;
  final Map<String, dynamic> metadata;

  LocalizedContent({
    required this.id,
    required this.type,
    required this.titles,
    required this.descriptions,
    this.metadata = const {},
  });

  factory LocalizedContent.fromJson(Map<String, dynamic> json) {
    return LocalizedContent(
      id: json['id'] as String,
      type: json['type'] as String,
      titles: Map<String, String>.from(json['titles'] ?? {}),
      descriptions: Map<String, String>.from(json['descriptions'] ?? {}),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'titles': titles,
      'descriptions': descriptions,
      'metadata': metadata,
    };
  }

  /// Get title in the specified language, fallback to English if not available
  String getTitleForLanguage(String languageCode) {
    return titles[languageCode] ?? titles['en'] ?? 'Missing Title';
  }

  /// Get description in the specified language, fallback to English if not available
  String getDescriptionForLanguage(String languageCode) {
    return descriptions[languageCode] ?? descriptions['en'] ?? 'Missing Description';
  }
}

/// Example data model for theory content that contains state-specific, localized content
class TheoryContent {
  final String id;
  final Map<String, Map<String, LocalizedContent>> contentByStateAndLanguage;
  
  TheoryContent({
    required this.id,
    required this.contentByStateAndLanguage,
  });
  
  factory TheoryContent.fromJson(Map<String, dynamic> json) {
    final Map<String, Map<String, LocalizedContent>> contentMap = {};
    
    final contentData = json['contentByStateAndLanguage'] as Map<String, dynamic>;
    
    contentData.forEach((state, languageMap) {
      contentMap[state] = {};
      (languageMap as Map<String, dynamic>).forEach((language, contentJson) {
        contentMap[state]![language] = LocalizedContent.fromJson(contentJson);
      });
    });
    
    return TheoryContent(
      id: json['id'] as String,
      contentByStateAndLanguage: contentMap,
    );
  }
  
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> stateMap = {};
    
    contentByStateAndLanguage.forEach((state, languageMap) {
      final Map<String, dynamic> langContentMap = {};
      languageMap.forEach((language, content) {
        langContentMap[language] = content.toJson();
      });
      stateMap[state] = langContentMap;
    });
    
    return {
      'id': id,
      'contentByStateAndLanguage': stateMap,
    };
  }
  
  /// Get content for a specific state and language
  /// Falls back to English if the requested language is not available
  LocalizedContent? getContent(String state, String language) {
    if (contentByStateAndLanguage.containsKey(state)) {
      return contentByStateAndLanguage[state]?[language] ?? 
             contentByStateAndLanguage[state]?['en'];
    }
    return null;
  }
}

/// Example data model for a question with translations
class QuizQuestion {
  final String id;
  final Map<String, String> question;
  final Map<String, List<String>> options;
  final int correctOptionIndex;
  final Map<String, String> explanation;
  final String state;
  final List<String> tags;
  
  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.state,
    this.tags = const [],
  });
  
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final Map<String, List<String>> parsedOptions = {};
    
    (json['options'] as Map<String, dynamic>).forEach((lang, opts) {
      parsedOptions[lang] = List<String>.from(opts as List);
    });
    
    return QuizQuestion(
      id: json['id'] as String,
      question: Map<String, String>.from(json['question'] as Map),
      options: parsedOptions,
      correctOptionIndex: json['correctOptionIndex'] as int,
      explanation: Map<String, String>.from(json['explanation'] as Map),
      state: json['state'] as String,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'state': state,
      'tags': tags,
    };
  }

  /// Get question text in the specified language
  String getQuestionForLanguage(String languageCode) {
    return question[languageCode] ?? question['en'] ?? 'Missing Question';
  }

  /// Get options in the specified language
  List<String> getOptionsForLanguage(String languageCode) {
    return options[languageCode] ?? options['en'] ?? ['Missing Options'];
  }
  
  /// Get explanation in the specified language
  String getExplanationForLanguage(String languageCode) {
    return explanation[languageCode] ?? explanation['en'] ?? 'Missing Explanation';
  }
}
