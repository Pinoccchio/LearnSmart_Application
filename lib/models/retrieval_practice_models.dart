import 'package:flutter/material.dart';

// Enums for Retrieval Practice
enum RetrievalQuestionType {
  multipleChoice,
  shortAnswer,
  fillInBlank,
  trueFalse,
}

enum RetrievalSessionStatus {
  preparing,
  active,
  completed,
  paused,
}

enum DifficultyLevel {
  easy(1),
  medium(2),
  hard(3);

  const DifficultyLevel(this.value);
  final int value;

  static DifficultyLevel fromValue(int value) {
    return DifficultyLevel.values.firstWhere(
      (level) => level.value == value,
      orElse: () => DifficultyLevel.easy,
    );
  }
}

// Retrieval Practice Session
class RetrievalPracticeSession {
  final String id;
  final String userId;
  final String moduleId;
  final RetrievalSessionStatus status;
  final int totalQuestionsPlanned;
  final int questionsCompleted;
  final int currentQuestionIndex;
  final Map<String, dynamic> sessionData;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  RetrievalPracticeSession({
    required this.id,
    required this.userId,
    required this.moduleId,
    required this.status,
    required this.totalQuestionsPlanned,
    required this.questionsCompleted,
    required this.currentQuestionIndex,
    required this.sessionData,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == RetrievalSessionStatus.completed;
  bool get isActive => status == RetrievalSessionStatus.active;
  double get progressPercentage => 
      totalQuestionsPlanned > 0 ? (questionsCompleted / totalQuestionsPlanned) * 100 : 0;

  factory RetrievalPracticeSession.fromJson(Map<String, dynamic> json) {
    return RetrievalPracticeSession(
      id: json['id'],
      userId: json['user_id'],
      moduleId: json['module_id'],
      status: RetrievalSessionStatus.values.byName(json['status']),
      totalQuestionsPlanned: json['total_questions_planned'] ?? 10,
      questionsCompleted: json['questions_completed'] ?? 0,
      currentQuestionIndex: json['current_question_index'] ?? 0,
      sessionData: Map<String, dynamic>.from(json['session_data'] ?? {}),
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'module_id': moduleId,
      'status': status.name,
      'total_questions_planned': totalQuestionsPlanned,
      'questions_completed': questionsCompleted,
      'current_question_index': currentQuestionIndex,
      'session_data': sessionData,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RetrievalPracticeSession copyWith({
    String? id,
    String? userId,
    String? moduleId,
    RetrievalSessionStatus? status,
    int? totalQuestionsPlanned,
    int? questionsCompleted,
    int? currentQuestionIndex,
    Map<String, dynamic>? sessionData,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RetrievalPracticeSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moduleId: moduleId ?? this.moduleId,
      status: status ?? this.status,
      totalQuestionsPlanned: totalQuestionsPlanned ?? this.totalQuestionsPlanned,
      questionsCompleted: questionsCompleted ?? this.questionsCompleted,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      sessionData: sessionData ?? this.sessionData,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Retrieval Practice Question
class RetrievalPracticeQuestion {
  final String id;
  final String sessionId;
  final String moduleId;
  final String materialId;
  final RetrievalQuestionType questionType;
  final String questionText;
  final String correctAnswer;
  final List<String>? options; // For multiple choice
  final DifficultyLevel difficultyLevel;
  final List<String> conceptTags;
  final Map<String, dynamic> questionMetadata;
  final DateTime createdAt;

  RetrievalPracticeQuestion({
    required this.id,
    required this.sessionId,
    required this.moduleId,
    required this.materialId,
    required this.questionType,
    required this.questionText,
    required this.correctAnswer,
    this.options,
    required this.difficultyLevel,
    required this.conceptTags,
    required this.questionMetadata,
    required this.createdAt,
  });

  bool get isMultipleChoice => questionType == RetrievalQuestionType.multipleChoice;
  bool get isShortAnswer => questionType == RetrievalQuestionType.shortAnswer;
  bool get isFillInBlank => questionType == RetrievalQuestionType.fillInBlank;
  bool get isTrueFalse => questionType == RetrievalQuestionType.trueFalse;

  String get difficultyString {
    switch (difficultyLevel) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Hard';
    }
  }

  Color get difficultyColor {
    switch (difficultyLevel) {
      case DifficultyLevel.easy:
        return Colors.green;
      case DifficultyLevel.medium:
        return Colors.orange;
      case DifficultyLevel.hard:
        return Colors.red;
    }
  }

  factory RetrievalPracticeQuestion.fromJson(Map<String, dynamic> json) {
    return RetrievalPracticeQuestion(
      id: json['id'],
      sessionId: json['session_id'],
      moduleId: json['module_id'],
      materialId: json['material_id'],
      questionType: RetrievalQuestionType.values.byName(json['question_type']),
      questionText: json['question_text'],
      correctAnswer: json['correct_answer'],
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      difficultyLevel: DifficultyLevel.fromValue(json['difficulty_level'] ?? 1),
      conceptTags: List<String>.from(json['concept_tags'] ?? []),
      questionMetadata: Map<String, dynamic>.from(json['question_metadata'] ?? {}),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'module_id': moduleId,
      'material_id': materialId,
      'question_type': questionType.name,
      'question_text': questionText,
      'correct_answer': correctAnswer,
      'options': options,
      'difficulty_level': difficultyLevel.value,
      'concept_tags': conceptTags,
      'question_metadata': questionMetadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Retrieval Practice Attempt
class RetrievalPracticeAttempt {
  final String id;
  final String sessionId;
  final String questionId;
  final String userId;
  final String userAnswer;
  final bool isCorrect;
  final int responseTimeSeconds;
  final int? confidenceLevel; // 1-5 scale
  final bool hintUsed;
  final Map<String, dynamic> attemptMetadata;
  final DateTime attemptedAt;

  RetrievalPracticeAttempt({
    required this.id,
    required this.sessionId,
    required this.questionId,
    required this.userId,
    required this.userAnswer,
    required this.isCorrect,
    required this.responseTimeSeconds,
    this.confidenceLevel,
    required this.hintUsed,
    required this.attemptMetadata,
    required this.attemptedAt,
  });

  double get responseTimeMinutes => responseTimeSeconds / 60.0;

  String get confidenceLevelString {
    if (confidenceLevel == null) return 'Not specified';
    switch (confidenceLevel!) {
      case 1:
        return 'Very Low';
      case 2:
        return 'Low';
      case 3:
        return 'Medium';
      case 4:
        return 'High';
      case 5:
        return 'Very High';
      default:
        return 'Unknown';
    }
  }

  factory RetrievalPracticeAttempt.fromJson(Map<String, dynamic> json) {
    return RetrievalPracticeAttempt(
      id: json['id'],
      sessionId: json['session_id'],
      questionId: json['question_id'],
      userId: json['user_id'],
      userAnswer: json['user_answer'],
      isCorrect: json['is_correct'],
      responseTimeSeconds: json['response_time_seconds'],
      confidenceLevel: json['confidence_level'],
      hintUsed: json['hint_used'] ?? false,
      attemptMetadata: Map<String, dynamic>.from(json['attempt_metadata'] ?? {}),
      attemptedAt: DateTime.parse(json['attempted_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'question_id': questionId,
      'user_id': userId,
      'user_answer': userAnswer,
      'is_correct': isCorrect,
      'response_time_seconds': responseTimeSeconds,
      'confidence_level': confidenceLevel,
      'hint_used': hintUsed,
      'attempt_metadata': attemptMetadata,
      'attempted_at': attemptedAt.toIso8601String(),
    };
  }
}

// Retrieval Practice Schedule (for spaced repetition)
class RetrievalPracticeSchedule {
  final String id;
  final String userId;
  final String moduleId;
  final String conceptTag;
  final double easinessFactor;
  final int repetitionNumber;
  final int interRepetitionInterval; // days
  final DateTime nextReviewDate;
  final DateTime? lastReviewDate;
  final int totalReviews;
  final int successStreak;
  final int failureCount;
  final Map<String, dynamic> scheduleMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  RetrievalPracticeSchedule({
    required this.id,
    required this.userId,
    required this.moduleId,
    required this.conceptTag,
    required this.easinessFactor,
    required this.repetitionNumber,
    required this.interRepetitionInterval,
    required this.nextReviewDate,
    this.lastReviewDate,
    required this.totalReviews,
    required this.successStreak,
    required this.failureCount,
    required this.scheduleMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDue => DateTime.now().isAfter(nextReviewDate);
  bool get isOverdue => DateTime.now().difference(nextReviewDate).inDays > 0;
  int get daysSinceLastReview => 
      lastReviewDate != null ? DateTime.now().difference(lastReviewDate!).inDays : 0;

  factory RetrievalPracticeSchedule.fromJson(Map<String, dynamic> json) {
    return RetrievalPracticeSchedule(
      id: json['id'],
      userId: json['user_id'],
      moduleId: json['module_id'],
      conceptTag: json['concept_tag'],
      easinessFactor: (json['easiness_factor'] ?? 2.5).toDouble(),
      repetitionNumber: json['repetition_number'] ?? 0,
      interRepetitionInterval: json['inter_repetition_interval'] ?? 1,
      nextReviewDate: DateTime.parse(json['next_review_date']),
      lastReviewDate: json['last_review_date'] != null 
          ? DateTime.parse(json['last_review_date']) 
          : null,
      totalReviews: json['total_reviews'] ?? 0,
      successStreak: json['success_streak'] ?? 0,
      failureCount: json['failure_count'] ?? 0,
      scheduleMetadata: Map<String, dynamic>.from(json['schedule_metadata'] ?? {}),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'module_id': moduleId,
      'concept_tag': conceptTag,
      'easiness_factor': easinessFactor,
      'repetition_number': repetitionNumber,
      'inter_repetition_interval': interRepetitionInterval,
      'next_review_date': nextReviewDate.toIso8601String().split('T')[0], // date only
      'last_review_date': lastReviewDate?.toIso8601String().split('T')[0],
      'total_reviews': totalReviews,
      'success_streak': successStreak,
      'failure_count': failureCount,
      'schedule_metadata': scheduleMetadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Retrieval Practice Settings
class RetrievalPracticeSettings {
  final int questionsPerSession;
  final bool mixQuestionTypes;
  final bool adaptiveDifficulty;
  final List<RetrievalQuestionType> preferredQuestionTypes;
  final bool enableSpacedRepetition;
  final bool showFeedbackAfterEach;
  final bool allowHints;
  final int maxHintsPerQuestion;
  final bool requireConfidenceRating;

  RetrievalPracticeSettings({
    this.questionsPerSession = 10,
    this.mixQuestionTypes = true,
    this.adaptiveDifficulty = true,
    this.preferredQuestionTypes = const [
      RetrievalQuestionType.multipleChoice,
      RetrievalQuestionType.shortAnswer,
    ],
    this.enableSpacedRepetition = true,
    this.showFeedbackAfterEach = true,
    this.allowHints = false,
    this.maxHintsPerQuestion = 1,
    this.requireConfidenceRating = false,
  });

  factory RetrievalPracticeSettings.fromJson(Map<String, dynamic> json) {
    return RetrievalPracticeSettings(
      questionsPerSession: json['questions_per_session'] ?? 10,
      mixQuestionTypes: json['mix_question_types'] ?? true,
      adaptiveDifficulty: json['adaptive_difficulty'] ?? true,
      preferredQuestionTypes: (json['preferred_question_types'] as List?)
          ?.map((type) => RetrievalQuestionType.values.byName(type))
          .toList() ?? [RetrievalQuestionType.multipleChoice, RetrievalQuestionType.shortAnswer],
      enableSpacedRepetition: json['enable_spaced_repetition'] ?? true,
      showFeedbackAfterEach: json['show_feedback_after_each'] ?? true,
      allowHints: json['allow_hints'] ?? false,
      maxHintsPerQuestion: json['max_hints_per_question'] ?? 1,
      requireConfidenceRating: json['require_confidence_rating'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'questions_per_session': questionsPerSession,
      'mix_question_types': mixQuestionTypes,
      'adaptive_difficulty': adaptiveDifficulty,
      'preferred_question_types': preferredQuestionTypes.map((type) => type.name).toList(),
      'enable_spaced_repetition': enableSpacedRepetition,
      'show_feedback_after_each': showFeedbackAfterEach,
      'allow_hints': allowHints,
      'max_hints_per_question': maxHintsPerQuestion,
      'require_confidence_rating': requireConfidenceRating,
    };
  }

  RetrievalPracticeSettings copyWith({
    int? questionsPerSession,
    bool? mixQuestionTypes,
    bool? adaptiveDifficulty,
    List<RetrievalQuestionType>? preferredQuestionTypes,
    bool? enableSpacedRepetition,
    bool? showFeedbackAfterEach,
    bool? allowHints,
    int? maxHintsPerQuestion,
    bool? requireConfidenceRating,
  }) {
    return RetrievalPracticeSettings(
      questionsPerSession: questionsPerSession ?? this.questionsPerSession,
      mixQuestionTypes: mixQuestionTypes ?? this.mixQuestionTypes,
      adaptiveDifficulty: adaptiveDifficulty ?? this.adaptiveDifficulty,
      preferredQuestionTypes: preferredQuestionTypes ?? this.preferredQuestionTypes,
      enableSpacedRepetition: enableSpacedRepetition ?? this.enableSpacedRepetition,
      showFeedbackAfterEach: showFeedbackAfterEach ?? this.showFeedbackAfterEach,
      allowHints: allowHints ?? this.allowHints,
      maxHintsPerQuestion: maxHintsPerQuestion ?? this.maxHintsPerQuestion,
      requireConfidenceRating: requireConfidenceRating ?? this.requireConfidenceRating,
    );
  }
}

// Retrieval Practice Results
class RetrievalPracticeResults {
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final double accuracy;
  final Duration totalTime;
  final Duration averageTimePerQuestion;
  final Map<RetrievalQuestionType, int> questionTypeBreakdown;
  final Map<RetrievalQuestionType, double> accuracyByType;
  final Map<DifficultyLevel, double> accuracyByDifficulty;
  final List<String> strongConcepts;
  final List<String> weakConcepts;
  final int hintsUsed;
  final double? averageConfidence;

  RetrievalPracticeResults({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.accuracy,
    required this.totalTime,
    required this.averageTimePerQuestion,
    required this.questionTypeBreakdown,
    required this.accuracyByType,
    required this.accuracyByDifficulty,
    required this.strongConcepts,
    required this.weakConcepts,
    required this.hintsUsed,
    this.averageConfidence,
  });

  String get performanceLevel {
    if (accuracy >= 90) return 'Excellent';
    if (accuracy >= 80) return 'Good';
    if (accuracy >= 70) return 'Average';
    if (accuracy >= 60) return 'Needs Improvement';
    return 'Poor';
  }

  Color get performanceColor {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.lightGreen;
    if (accuracy >= 70) return Colors.orange;
    if (accuracy >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  static RetrievalPracticeResults calculate(
    List<RetrievalPracticeQuestion> questions,
    List<RetrievalPracticeAttempt> attempts,
  ) {
    if (questions.isEmpty || attempts.isEmpty) {
      return RetrievalPracticeResults(
        totalQuestions: 0,
        correctAnswers: 0,
        wrongAnswers: 0,
        accuracy: 0.0,
        totalTime: Duration.zero,
        averageTimePerQuestion: Duration.zero,
        questionTypeBreakdown: {},
        accuracyByType: {},
        accuracyByDifficulty: {},
        strongConcepts: [],
        weakConcepts: [],
        hintsUsed: 0,
      );
    }

    final correctAnswers = attempts.where((a) => a.isCorrect).length;
    final wrongAnswers = attempts.length - correctAnswers;
    final accuracy = (correctAnswers / attempts.length) * 100;

    final totalSeconds = attempts.fold<int>(0, (sum, attempt) => sum + attempt.responseTimeSeconds);
    final totalTime = Duration(seconds: totalSeconds);
    final averageTimePerQuestion = Duration(seconds: totalSeconds ~/ attempts.length);

    // Question type breakdown
    final questionTypeBreakdown = <RetrievalQuestionType, int>{};
    final typeAccuracy = <RetrievalQuestionType, List<bool>>{};
    
    for (final question in questions) {
      questionTypeBreakdown[question.questionType] = 
          (questionTypeBreakdown[question.questionType] ?? 0) + 1;
      
      final questionAttempts = attempts.where((a) => a.questionId == question.id);
      for (final attempt in questionAttempts) {
        typeAccuracy[question.questionType] ??= [];
        typeAccuracy[question.questionType]!.add(attempt.isCorrect);
      }
    }

    final accuracyByType = <RetrievalQuestionType, double>{};
    typeAccuracy.forEach((type, results) {
      final correct = results.where((r) => r).length;
      accuracyByType[type] = (correct / results.length) * 100;
    });

    // Difficulty breakdown
    final difficultyAccuracy = <DifficultyLevel, List<bool>>{};
    for (final question in questions) {
      final questionAttempts = attempts.where((a) => a.questionId == question.id);
      for (final attempt in questionAttempts) {
        difficultyAccuracy[question.difficultyLevel] ??= [];
        difficultyAccuracy[question.difficultyLevel]!.add(attempt.isCorrect);
      }
    }

    final accuracyByDifficulty = <DifficultyLevel, double>{};
    difficultyAccuracy.forEach((level, results) {
      final correct = results.where((r) => r).length;
      accuracyByDifficulty[level] = (correct / results.length) * 100;
    });

    // Concept analysis
    final conceptPerformance = <String, List<bool>>{};
    for (final question in questions) {
      final questionAttempts = attempts.where((a) => a.questionId == question.id);
      for (final attempt in questionAttempts) {
        for (final tag in question.conceptTags) {
          conceptPerformance[tag] ??= [];
          conceptPerformance[tag]!.add(attempt.isCorrect);
        }
      }
    }

    final strongConcepts = <String>[];
    final weakConcepts = <String>[];
    conceptPerformance.forEach((concept, results) {
      final accuracy = (results.where((r) => r).length / results.length) * 100;
      if (accuracy >= 80) {
        strongConcepts.add(concept);
      } else if (accuracy < 60) {
        weakConcepts.add(concept);
      }
    });

    final hintsUsed = attempts.where((a) => a.hintUsed).length;
    
    final confidenceRatings = attempts
        .where((a) => a.confidenceLevel != null)
        .map((a) => a.confidenceLevel!)
        .toList();
    final averageConfidence = confidenceRatings.isNotEmpty
        ? confidenceRatings.reduce((a, b) => a + b) / confidenceRatings.length
        : null;

    return RetrievalPracticeResults(
      totalQuestions: questions.length,
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      accuracy: accuracy,
      totalTime: totalTime,
      averageTimePerQuestion: averageTimePerQuestion,
      questionTypeBreakdown: questionTypeBreakdown,
      accuracyByType: accuracyByType,
      accuracyByDifficulty: accuracyByDifficulty,
      strongConcepts: strongConcepts,
      weakConcepts: weakConcepts,
      hintsUsed: hintsUsed,
      averageConfidence: averageConfidence,
    );
  }
}