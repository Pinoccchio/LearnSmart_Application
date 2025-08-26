enum RemedialQuestionType {
  identification,
  shortAnswer,
  fillInBlank,
  matching,
  trueFalse,
  essay,
}

enum RemedialSessionStatus {
  preparing,
  active,
  completed,
  abandoned,
}

enum RemedialDifficulty {
  review,
  practice,
  challenge,
}

extension RemedialQuestionTypeExtension on RemedialQuestionType {
  String get value {
    switch (this) {
      case RemedialQuestionType.identification:
        return 'identification';
      case RemedialQuestionType.shortAnswer:
        return 'short_answer';
      case RemedialQuestionType.fillInBlank:
        return 'fill_in_blank';
      case RemedialQuestionType.matching:
        return 'matching';
      case RemedialQuestionType.trueFalse:
        return 'true_false';
      case RemedialQuestionType.essay:
        return 'essay';
    }
  }

  static RemedialQuestionType fromString(String value) {
    switch (value) {
      case 'identification':
        return RemedialQuestionType.identification;
      case 'short_answer':
        return RemedialQuestionType.shortAnswer;
      case 'fill_in_blank':
        return RemedialQuestionType.fillInBlank;
      case 'matching':
        return RemedialQuestionType.matching;
      case 'true_false':
        return RemedialQuestionType.trueFalse;
      case 'essay':
        return RemedialQuestionType.essay;
      default:
        return RemedialQuestionType.identification;
    }
  }

  String get displayName {
    switch (this) {
      case RemedialQuestionType.identification:
        return 'Identification';
      case RemedialQuestionType.shortAnswer:
        return 'Short Answer';
      case RemedialQuestionType.fillInBlank:
        return 'Fill in the Blank';
      case RemedialQuestionType.matching:
        return 'Matching';
      case RemedialQuestionType.trueFalse:
        return 'True/False';
      case RemedialQuestionType.essay:
        return 'Essay';
    }
  }
}

extension RemedialDifficultyExtension on RemedialDifficulty {
  String get value {
    switch (this) {
      case RemedialDifficulty.review:
        return 'review';
      case RemedialDifficulty.practice:
        return 'practice';
      case RemedialDifficulty.challenge:
        return 'challenge';
    }
  }

  static RemedialDifficulty fromString(String value) {
    switch (value) {
      case 'review':
        return RemedialDifficulty.review;
      case 'practice':
        return RemedialDifficulty.practice;
      case 'challenge':
        return RemedialDifficulty.challenge;
      default:
        return RemedialDifficulty.review;
    }
  }
}

class RemedialSession {
  final String id;
  final String originalSessionId;
  final String userId;
  final String moduleId;
  final List<String> missedConcepts;
  final List<RemedialFlashcard> flashcards;
  final List<RemedialAttempt> attempts;
  final RemedialSessionStatus status;
  final Map<String, dynamic> sessionData;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  RemedialSession({
    required this.id,
    required this.originalSessionId,
    required this.userId,
    required this.moduleId,
    required this.missedConcepts,
    this.flashcards = const [],
    this.attempts = const [],
    required this.status,
    this.sessionData = const {},
    required this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemedialSession.fromJson(Map<String, dynamic> json) {
    return RemedialSession(
      id: json['id'],
      originalSessionId: json['original_session_id'],
      userId: json['user_id'],
      moduleId: json['module_id'],
      missedConcepts: List<String>.from(json['missed_concepts'] ?? []),
      flashcards: (json['remedial_flashcards'] as List?)
          ?.map((f) => RemedialFlashcard.fromJson(f))
          .toList() ?? [],
      attempts: (json['remedial_attempts'] as List?)
          ?.map((a) => RemedialAttempt.fromJson(a))
          .toList() ?? [],
      status: RemedialSessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RemedialSessionStatus.preparing,
      ),
      sessionData: json['session_data'] ?? {},
      startedAt: DateTime.parse(json['started_at']),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'original_session_id': originalSessionId,
      'user_id': userId,
      'module_id': moduleId,
      'missed_concepts': missedConcepts,
      'remedial_flashcards': flashcards.map((f) => f.toJson()).toList(),
      'remedial_attempts': attempts.map((a) => a.toJson()).toList(),
      'status': status.name,
      'session_data': sessionData,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RemedialSession copyWith({
    String? id,
    String? originalSessionId,
    String? userId,
    String? moduleId,
    List<String>? missedConcepts,
    List<RemedialFlashcard>? flashcards,
    List<RemedialAttempt>? attempts,
    RemedialSessionStatus? status,
    Map<String, dynamic>? sessionData,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RemedialSession(
      id: id ?? this.id,
      originalSessionId: originalSessionId ?? this.originalSessionId,
      userId: userId ?? this.userId,
      moduleId: moduleId ?? this.moduleId,
      missedConcepts: missedConcepts ?? this.missedConcepts,
      flashcards: flashcards ?? this.flashcards,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
      sessionData: sessionData ?? this.sessionData,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RemedialFlashcard {
  final String id;
  final String sessionId;
  final String originalFlashcardId;
  final String concept;
  final RemedialQuestionType type;
  final String question;
  final String correctAnswer;
  final List<String> options; // For multiple choice or matching
  final List<String> acceptableAnswers; // For flexible answer checking
  final String explanation;
  final RemedialDifficulty difficulty;
  final Map<String, dynamic> questionData;
  final DateTime createdAt;

  RemedialFlashcard({
    required this.id,
    required this.sessionId,
    required this.originalFlashcardId,
    required this.concept,
    required this.type,
    required this.question,
    required this.correctAnswer,
    this.options = const [],
    this.acceptableAnswers = const [],
    required this.explanation,
    required this.difficulty,
    this.questionData = const {},
    required this.createdAt,
  });

  factory RemedialFlashcard.fromJson(Map<String, dynamic> json) {
    return RemedialFlashcard(
      id: json['id'],
      sessionId: json['session_id'],
      originalFlashcardId: json['original_flashcard_id'],
      concept: json['concept'],
      type: RemedialQuestionTypeExtension.fromString(json['type']),
      question: json['question'],
      correctAnswer: json['correct_answer'],
      options: List<String>.from(json['options'] ?? []),
      acceptableAnswers: List<String>.from(json['acceptable_answers'] ?? []),
      explanation: json['explanation'],
      difficulty: RemedialDifficultyExtension.fromString(json['difficulty']),
      questionData: json['question_data'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  factory RemedialFlashcard.fromAI(
    Map<String, dynamic> aiJson,
    String sessionId,
    String originalFlashcardId,
    String concept, {
    int? index,
  }) {
    final now = DateTime.now();
    final uniqueId = index != null 
        ? '${sessionId}_${index}_${now.millisecondsSinceEpoch}'
        : '${sessionId}_${now.microsecondsSinceEpoch}';
    
    return RemedialFlashcard(
      id: uniqueId,
      sessionId: sessionId,
      originalFlashcardId: originalFlashcardId,
      concept: concept,
      type: RemedialQuestionTypeExtension.fromString(aiJson['type']),
      question: aiJson['question'],
      correctAnswer: aiJson['correct_answer'],
      options: List<String>.from(aiJson['options'] ?? []),
      acceptableAnswers: List<String>.from(aiJson['acceptable_answers'] ?? [aiJson['correct_answer']]),
      explanation: aiJson['explanation'] ?? '',
      difficulty: RemedialDifficultyExtension.fromString(aiJson['difficulty'] ?? 'review'),
      questionData: aiJson['question_data'] ?? {},
      createdAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'original_flashcard_id': originalFlashcardId,
      'concept': concept,
      'type': type.value,
      'question': question,
      'correct_answer': correctAnswer,
      'options': options,
      'acceptable_answers': acceptableAnswers,
      'explanation': explanation,
      'difficulty': difficulty.value,
      'question_data': questionData,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool isAnswerCorrect(String userAnswer) {
    final normalizedUserAnswer = userAnswer.trim().toLowerCase();
    final normalizedCorrectAnswer = correctAnswer.trim().toLowerCase();
    
    // Check exact match first
    if (normalizedUserAnswer == normalizedCorrectAnswer) {
      return true;
    }
    
    // Check acceptable answers
    for (final acceptable in acceptableAnswers) {
      if (normalizedUserAnswer == acceptable.trim().toLowerCase()) {
        return true;
      }
    }
    
    // For fill-in-blank, check if user answer contains the correct answer
    if (type == RemedialQuestionType.fillInBlank) {
      return normalizedUserAnswer.contains(normalizedCorrectAnswer) ||
             normalizedCorrectAnswer.contains(normalizedUserAnswer);
    }
    
    return false;
  }
}

class RemedialAttempt {
  final String id;
  final String sessionId;
  final String flashcardId;
  final String userAnswer;
  final bool isCorrect;
  final int responseTimeSeconds;
  final DateTime attemptedAt;
  final Map<String, dynamic> attemptData;

  RemedialAttempt({
    required this.id,
    required this.sessionId,
    required this.flashcardId,
    required this.userAnswer,
    required this.isCorrect,
    required this.responseTimeSeconds,
    required this.attemptedAt,
    this.attemptData = const {},
  });

  factory RemedialAttempt.fromJson(Map<String, dynamic> json) {
    return RemedialAttempt(
      id: json['id'],
      sessionId: json['session_id'],
      flashcardId: json['flashcard_id'],
      userAnswer: json['user_answer'],
      isCorrect: json['is_correct'],
      responseTimeSeconds: json['response_time_seconds'],
      attemptedAt: DateTime.parse(json['attempted_at']),
      attemptData: json['attempt_data'] ?? {},
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
      'attempt_data': attemptData,
    };
  }
}

class RemedialResults {
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final double accuracyPercentage;
  final double improvementFromOriginal;
  final int averageResponseTime;
  final Map<String, bool> conceptMastery;
  final Map<RemedialQuestionType, int> questionTypeBreakdown;
  final List<String> masteredConcepts;
  final List<String> stillStrugglingConcepts;

  RemedialResults({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.accuracyPercentage,
    required this.improvementFromOriginal,
    required this.averageResponseTime,
    required this.conceptMastery,
    required this.questionTypeBreakdown,
    required this.masteredConcepts,
    required this.stillStrugglingConcepts,
  });

  static RemedialResults calculate(
    List<RemedialFlashcard> flashcards,
    List<RemedialAttempt> attempts,
    double originalAccuracy,
  ) {
    print('🔄 [REMEDIAL RESULTS] Calculating remedial session results...');
    print('   Total flashcards: ${flashcards.length}');
    print('   Total attempts: ${attempts.length}');
    
    final correctAttempts = attempts.where((a) => a.isCorrect).toList();
    final correctAnswers = correctAttempts.length;
    final incorrectAnswers = attempts.length - correctAnswers;
    
    print('   Correct answers: $correctAnswers');
    print('   Incorrect answers: $incorrectAnswers');
    
    final accuracy = flashcards.isNotEmpty 
        ? (correctAnswers / flashcards.length) * 100
        : 0.0;
    
    final improvement = accuracy - originalAccuracy;
    
    print('   Remedial accuracy: ${accuracy.toStringAsFixed(1)}%');
    print('   Original accuracy: ${originalAccuracy.toStringAsFixed(1)}%');
    print('   Improvement: ${improvement.toStringAsFixed(1)}%');
    
    final avgResponseTime = attempts.isNotEmpty 
        ? attempts.map((a) => a.responseTimeSeconds).reduce((a, b) => a + b) ~/ attempts.length
        : 0;
    
    // Calculate concept mastery
    final conceptMastery = <String, bool>{};
    final conceptAttempts = <String, List<RemedialAttempt>>{};
    
    for (final flashcard in flashcards) {
      final flashcardAttempts = attempts.where((a) => a.flashcardId == flashcard.id).toList();
      conceptAttempts[flashcard.concept] = flashcardAttempts;
      
      // Concept is mastered if the student got it right
      conceptMastery[flashcard.concept] = flashcardAttempts.isNotEmpty && 
                                          flashcardAttempts.any((a) => a.isCorrect);
    }
    
    final masteredConcepts = conceptMastery.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    
    final stillStrugglingConcepts = conceptMastery.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
    
    // Calculate question type breakdown
    final questionTypeBreakdown = <RemedialQuestionType, int>{};
    for (final flashcard in flashcards) {
      questionTypeBreakdown[flashcard.type] = 
          (questionTypeBreakdown[flashcard.type] ?? 0) + 1;
    }
    
    return RemedialResults(
      totalQuestions: flashcards.length,
      correctAnswers: correctAnswers,
      incorrectAnswers: incorrectAnswers,
      accuracyPercentage: accuracy,
      improvementFromOriginal: improvement,
      averageResponseTime: avgResponseTime,
      conceptMastery: conceptMastery,
      questionTypeBreakdown: questionTypeBreakdown,
      masteredConcepts: masteredConcepts,
      stillStrugglingConcepts: stillStrugglingConcepts,
    );
  }

  bool get isPassing => accuracyPercentage >= 80.0;
  bool get showsImprovement => improvementFromOriginal > 0;
  
  String get performanceLevel {
    if (accuracyPercentage >= 90) return 'Excellent';
    if (accuracyPercentage >= 80) return 'Good';
    if (accuracyPercentage >= 70) return 'Fair';
    return 'Needs More Practice';
  }
}

class RemedialSettings {
  final int maxQuestionsPerConcept;
  final List<RemedialQuestionType> preferredQuestionTypes;
  final bool allowHints;
  final bool requireExplanationReview;
  final RemedialDifficulty startingDifficulty;
  final bool adaptiveDifficulty;

  const RemedialSettings({
    this.maxQuestionsPerConcept = 3,
    this.preferredQuestionTypes = const [
      RemedialQuestionType.identification,
      RemedialQuestionType.shortAnswer,
      RemedialQuestionType.fillInBlank,
    ],
    this.allowHints = true,
    this.requireExplanationReview = true,
    this.startingDifficulty = RemedialDifficulty.review,
    this.adaptiveDifficulty = false,
  });

  factory RemedialSettings.defaults() => const RemedialSettings();

  factory RemedialSettings.focused() => const RemedialSettings(
    maxQuestionsPerConcept: 2,
    preferredQuestionTypes: [
      RemedialQuestionType.identification,
      RemedialQuestionType.fillInBlank,
    ],
    allowHints: false,
    startingDifficulty: RemedialDifficulty.practice,
  );

  factory RemedialSettings.comprehensive() => const RemedialSettings(
    maxQuestionsPerConcept: 5,
    preferredQuestionTypes: [
      RemedialQuestionType.identification,
      RemedialQuestionType.shortAnswer,
      RemedialQuestionType.fillInBlank,
      RemedialQuestionType.trueFalse,
    ],
    requireExplanationReview: true,
    adaptiveDifficulty: true,
  );

  factory RemedialSettings.fromJson(Map<String, dynamic> json) {
    return RemedialSettings(
      maxQuestionsPerConcept: json['max_questions_per_concept'] ?? 3,
      preferredQuestionTypes: (json['preferred_question_types'] as List? ?? ['identification', 'short_answer', 'fill_in_blank'])
          .map((type) => RemedialQuestionTypeExtension.fromString(type as String))
          .toList(),
      allowHints: json['allow_hints'] ?? true,
      requireExplanationReview: json['require_explanation_review'] ?? true,
      startingDifficulty: RemedialDifficultyExtension.fromString(json['starting_difficulty'] ?? 'review'),
      adaptiveDifficulty: json['adaptive_difficulty'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'max_questions_per_concept': maxQuestionsPerConcept,
      'preferred_question_types': preferredQuestionTypes.map((type) => type.value).toList(),
      'allow_hints': allowHints,
      'require_explanation_review': requireExplanationReview,
      'starting_difficulty': startingDifficulty.value,
      'adaptive_difficulty': adaptiveDifficulty,
    };
  }
}