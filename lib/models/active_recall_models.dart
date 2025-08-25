enum FlashcardType {
  fillInBlank,
  definitionRecall,
  conceptApplication,
}

enum FlashcardDifficulty {
  easy,
  medium,
  hard,
}

enum StudySessionStatus {
  preparing,
  preStudy,
  studying,
  postStudy,
  generatingAnalytics,
  completed,
  paused,
}

extension FlashcardTypeExtension on FlashcardType {
  String get value {
    switch (this) {
      case FlashcardType.fillInBlank:
        return 'fill_in_blank';
      case FlashcardType.definitionRecall:
        return 'definition_recall';
      case FlashcardType.conceptApplication:
        return 'concept_application';
    }
  }

  static FlashcardType fromString(String value) {
    switch (value) {
      case 'fill_in_blank':
        return FlashcardType.fillInBlank;
      case 'definition_recall':
        return FlashcardType.definitionRecall;
      case 'concept_application':
        return FlashcardType.conceptApplication;
      default:
        return FlashcardType.definitionRecall;
    }
  }
}

extension FlashcardDifficultyExtension on FlashcardDifficulty {
  String get value {
    switch (this) {
      case FlashcardDifficulty.easy:
        return 'easy';
      case FlashcardDifficulty.medium:
        return 'medium';
      case FlashcardDifficulty.hard:
        return 'hard';
    }
  }

  static FlashcardDifficulty fromString(String value) {
    switch (value) {
      case 'easy':
        return FlashcardDifficulty.easy;
      case 'medium':
        return FlashcardDifficulty.medium;
      case 'hard':
        return FlashcardDifficulty.hard;
      default:
        return FlashcardDifficulty.medium;
    }
  }
}

class ActiveRecallSession {
  final String id;
  final String userId;
  final String moduleId;
  final StudySessionStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<ActiveRecallFlashcard> flashcards;
  final Map<String, dynamic> sessionData;

  ActiveRecallSession({
    required this.id,
    required this.userId,
    required this.moduleId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.flashcards = const [],
    this.sessionData = const {},
  });

  factory ActiveRecallSession.fromJson(Map<String, dynamic> json) {
    return ActiveRecallSession(
      id: json['id'],
      userId: json['user_id'],
      moduleId: json['module_id'],
      status: StudySessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => StudySessionStatus.preparing,
      ),
      startedAt: DateTime.parse(json['started_at']),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'])
          : null,
      sessionData: json['session_data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'module_id': moduleId,
      'status': status.name,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'session_data': sessionData,
    };
  }

  ActiveRecallSession copyWith({
    String? id,
    String? userId,
    String? moduleId,
    StudySessionStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    List<ActiveRecallFlashcard>? flashcards,
    Map<String, dynamic>? sessionData,
  }) {
    return ActiveRecallSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moduleId: moduleId ?? this.moduleId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      flashcards: flashcards ?? this.flashcards,
      sessionData: sessionData ?? this.sessionData,
    );
  }
}

class ActiveRecallFlashcard {
  final String id;
  final String materialId;
  final String moduleId;
  final FlashcardType type;
  final String question;
  final String answer;
  final List<String> hints;
  final FlashcardDifficulty difficulty;
  final String explanation;
  final DateTime createdAt;

  ActiveRecallFlashcard({
    required this.id,
    required this.materialId,
    required this.moduleId,
    required this.type,
    required this.question,
    required this.answer,
    this.hints = const [],
    required this.difficulty,
    required this.explanation,
    required this.createdAt,
  });

  factory ActiveRecallFlashcard.fromJson(Map<String, dynamic> json) {
    return ActiveRecallFlashcard(
      id: json['id'],
      materialId: json['material_id'],
      moduleId: json['module_id'],
      type: FlashcardTypeExtension.fromString(json['type']),
      question: json['question'],
      answer: json['answer'],
      hints: List<String>.from(json['hints'] ?? []),
      difficulty: FlashcardDifficultyExtension.fromString(json['difficulty']),
      explanation: json['explanation'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  factory ActiveRecallFlashcard.fromAI(
    Map<String, dynamic> aiJson,
    String materialId,
    String moduleId, {
    int? index,
  }) {
    final now = DateTime.now();
    final uniqueId = index != null 
        ? '${materialId}_${index}_${now.millisecondsSinceEpoch}'
        : '${materialId}_${now.microsecondsSinceEpoch}'; // Use microseconds for better uniqueness
    
    return ActiveRecallFlashcard(
      id: uniqueId,
      materialId: materialId,
      moduleId: moduleId,
      type: FlashcardTypeExtension.fromString(aiJson['type']),
      question: aiJson['question'],
      answer: aiJson['answer'],
      hints: List<String>.from(aiJson['hints'] ?? []),
      difficulty: FlashcardDifficultyExtension.fromString(aiJson['difficulty']),
      explanation: aiJson['explanation'] ?? '',
      createdAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'material_id': materialId,
      'module_id': moduleId,
      'type': type.value,
      'question': question,
      'answer': answer,
      'hints': hints,
      'difficulty': difficulty.value,
      'explanation': explanation,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ActiveRecallAttempt {
  final String id;
  final String sessionId;
  final String flashcardId;
  final String userAnswer;
  final bool isCorrect;
  final int responseTimeSeconds;
  final DateTime attemptedAt;
  final bool isPreStudy;

  ActiveRecallAttempt({
    required this.id,
    required this.sessionId,
    required this.flashcardId,
    required this.userAnswer,
    required this.isCorrect,
    required this.responseTimeSeconds,
    required this.attemptedAt,
    this.isPreStudy = false,
  });

  factory ActiveRecallAttempt.fromJson(Map<String, dynamic> json) {
    return ActiveRecallAttempt(
      id: json['id'],
      sessionId: json['session_id'],
      flashcardId: json['flashcard_id'],
      userAnswer: json['user_answer'],
      isCorrect: json['is_correct'],
      responseTimeSeconds: json['response_time_seconds'],
      attemptedAt: DateTime.parse(json['attempted_at']),
      isPreStudy: json['is_pre_study'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'flashcard_id': flashcardId,
      'user_answer': userAnswer,
      'is_correct': isCorrect,
      'response_time_seconds': responseTimeSeconds,
      'attempted_at': attemptedAt.toIso8601String(),
      'is_pre_study': isPreStudy,
    };
  }
}

class StudySessionResults {
  final int totalFlashcards;
  final int preStudyCorrect;
  final int postStudyCorrect;
  final double improvementPercentage;
  final int averageResponseTime;
  final Map<FlashcardDifficulty, int> difficultyBreakdown;
  final Map<FlashcardType, int> typeBreakdown;

  StudySessionResults({
    required this.totalFlashcards,
    required this.preStudyCorrect,
    required this.postStudyCorrect,
    required this.improvementPercentage,
    required this.averageResponseTime,
    required this.difficultyBreakdown,
    required this.typeBreakdown,
  });

  static StudySessionResults calculate(
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> attempts,
  ) {
    print('🔍 [RESULTS DEBUG] Calculating session results...');
    print('   Total flashcards: ${flashcards.length}');
    print('   Total attempts: ${attempts.length}');
    
    final preStudyAttempts = attempts.where((a) => a.isPreStudy).toList();
    final postStudyAttempts = attempts.where((a) => !a.isPreStudy).toList();
    
    print('   Pre-study attempts: ${preStudyAttempts.length}');
    print('   Post-study attempts: ${postStudyAttempts.length}');
    
    final preStudyCorrect = preStudyAttempts.where((a) => a.isCorrect).length;
    final postStudyCorrect = postStudyAttempts.where((a) => a.isCorrect).length;
    
    print('   Pre-study correct: $preStudyCorrect');
    print('   Post-study correct: $postStudyCorrect');
    
    final preStudyPercentage = flashcards.isNotEmpty 
        ? (preStudyCorrect / flashcards.length) * 100
        : 0.0;
    final postStudyPercentage = flashcards.isNotEmpty 
        ? (postStudyCorrect / flashcards.length) * 100
        : 0.0;
    
    print('   Pre-study percentage: ${preStudyPercentage.toStringAsFixed(1)}%');
    print('   Post-study percentage: ${postStudyPercentage.toStringAsFixed(1)}%');
    
    final improvement = postStudyPercentage - preStudyPercentage;
    print('   Improvement: ${improvement.toStringAsFixed(1)}%');
    
    final avgResponseTime = attempts.isNotEmpty 
        ? attempts.map((a) => a.responseTimeSeconds).reduce((a, b) => a + b) ~/ attempts.length
        : 0;
    
    final difficultyBreakdown = <FlashcardDifficulty, int>{};
    final typeBreakdown = <FlashcardType, int>{};
    
    for (final flashcard in flashcards) {
      difficultyBreakdown[flashcard.difficulty] = 
          (difficultyBreakdown[flashcard.difficulty] ?? 0) + 1;
      typeBreakdown[flashcard.type] = 
          (typeBreakdown[flashcard.type] ?? 0) + 1;
    }
    
    return StudySessionResults(
      totalFlashcards: flashcards.length,
      preStudyCorrect: preStudyCorrect,
      postStudyCorrect: postStudyCorrect,
      improvementPercentage: improvement,
      averageResponseTime: avgResponseTime,
      difficultyBreakdown: difficultyBreakdown,
      typeBreakdown: typeBreakdown,
    );
  }
}