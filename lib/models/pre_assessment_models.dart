// =====================================================
// Pre-Assessment Models
// =====================================================
// Models for course pre-assessment system

class PreAssessmentQuestion {
  final String? id;
  final int questionNumber;
  final String moduleName;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer; // "A", "B", "C", or "D"
  final String? difficultyLevel;

  PreAssessmentQuestion({
    this.id,
    required this.questionNumber,
    required this.moduleName,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    this.difficultyLevel,
  });

  // Create from Supabase database response
  factory PreAssessmentQuestion.fromSupabase(Map<String, dynamic> data) {
    return PreAssessmentQuestion(
      id: data['id'] as String?,
      questionNumber: data['question_number'] as int,
      moduleName: data['module_name'] as String,
      questionText: data['question_text'] as String,
      optionA: data['option_a'] as String,
      optionB: data['option_b'] as String,
      optionC: data['option_c'] as String,
      optionD: data['option_d'] as String,
      correctAnswer: data['correct_answer'] as String,
      difficultyLevel: data['difficulty_level'] as String?,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'questionNumber': questionNumber,
      'moduleName': moduleName,
      'questionText': questionText,
      'optionA': optionA,
      'optionB': optionB,
      'optionC': optionC,
      'optionD': optionD,
      'correctAnswer': correctAnswer,
      if (difficultyLevel != null) 'difficultyLevel': difficultyLevel,
    };
  }

  // Get answer text from letter
  String getAnswerText(String letter) {
    switch (letter.toUpperCase()) {
      case 'A':
        return optionA;
      case 'B':
        return optionB;
      case 'C':
        return optionC;
      case 'D':
        return optionD;
      default:
        return '';
    }
  }
}

class PreAssessmentAnswer {
  final int questionNumber;
  final String moduleName;
  final String userAnswer; // "A", "B", "C", or "D"
  final String correctAnswer;
  final bool isCorrect;
  final int timeTakenSeconds;

  PreAssessmentAnswer({
    required this.questionNumber,
    required this.moduleName,
    required this.userAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.timeTakenSeconds,
  });

  Map<String, dynamic> toJson() {
    return {
      'questionNumber': questionNumber,
      'moduleName': moduleName,
      'userAnswer': userAnswer,
      'correctAnswer': correctAnswer,
      'isCorrect': isCorrect,
      'timeTakenSeconds': timeTakenSeconds,
    };
  }

  factory PreAssessmentAnswer.fromJson(Map<String, dynamic> json) {
    return PreAssessmentAnswer(
      questionNumber: json['questionNumber'] as int,
      moduleName: json['moduleName'] as String,
      userAnswer: json['userAnswer'] as String,
      correctAnswer: json['correctAnswer'] as String,
      isCorrect: json['isCorrect'] as bool,
      timeTakenSeconds: json['timeTakenSeconds'] as int? ?? 0,
    );
  }
}

class PreAssessmentAttempt {
  final String? id;
  final String userId;
  final String courseId;
  final String status; // 'in_progress', 'completed', 'abandoned'
  final int totalQuestions;
  final int questionsAnswered;
  final int correctAnswers;
  final double? scorePercentage;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? timeTakenSeconds;
  final List<PreAssessmentAnswer> answers;

  PreAssessmentAttempt({
    this.id,
    required this.userId,
    required this.courseId,
    this.status = 'in_progress',
    required this.totalQuestions,
    this.questionsAnswered = 0,
    this.correctAnswers = 0,
    this.scorePercentage,
    required this.startedAt,
    this.completedAt,
    this.timeTakenSeconds,
    this.answers = const [],
  });

  factory PreAssessmentAttempt.fromSupabase(Map<String, dynamic> data) {
    // Parse answers from JSONB
    List<PreAssessmentAnswer> answersList = [];
    if (data['answers_data'] != null) {
      final answersJson = data['answers_data'] as List;
      answersList = answersJson
          .map((json) => PreAssessmentAnswer.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    return PreAssessmentAttempt(
      id: data['id'] as String?,
      userId: data['user_id'] as String,
      courseId: data['course_id'] as String,
      status: data['status'] as String? ?? 'in_progress',
      totalQuestions: data['total_questions'] as int,
      questionsAnswered: data['questions_answered'] as int? ?? 0,
      correctAnswers: data['correct_answers'] as int? ?? 0,
      scorePercentage: data['score_percentage'] != null
          ? (data['score_percentage'] as num).toDouble()
          : null,
      startedAt: DateTime.parse(data['started_at'] as String),
      completedAt: data['completed_at'] != null
          ? DateTime.parse(data['completed_at'] as String)
          : null,
      timeTakenSeconds: data['time_taken_seconds'] as int?,
      answers: answersList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'course_id': courseId,
      'status': status,
      'total_questions': totalQuestions,
      'questions_answered': questionsAnswered,
      'correct_answers': correctAnswers,
      if (scorePercentage != null) 'score_percentage': scorePercentage,
      'started_at': startedAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (timeTakenSeconds != null) 'time_taken_seconds': timeTakenSeconds,
      'answers_data': answers.map((a) => a.toJson()).toList(),
    };
  }

  // Check if attempt is completed
  bool get isCompleted => status == 'completed';

  // Get current progress percentage
  double get progressPercentage {
    if (totalQuestions == 0) return 0.0;
    return (questionsAnswered / totalQuestions) * 100;
  }

  // Add an answer to the attempt
  PreAssessmentAttempt addAnswer(PreAssessmentAnswer answer) {
    final updatedAnswers = List<PreAssessmentAnswer>.from(answers);

    // Remove existing answer for this question if any
    updatedAnswers.removeWhere((a) => a.questionNumber == answer.questionNumber);

    // Add new answer
    updatedAnswers.add(answer);

    // Calculate new stats
    final newCorrectAnswers = updatedAnswers.where((a) => a.isCorrect).length;

    return PreAssessmentAttempt(
      id: id,
      userId: userId,
      courseId: courseId,
      status: status,
      totalQuestions: totalQuestions,
      questionsAnswered: updatedAnswers.length,
      correctAnswers: newCorrectAnswers,
      scorePercentage: scorePercentage,
      startedAt: startedAt,
      completedAt: completedAt,
      timeTakenSeconds: timeTakenSeconds,
      answers: updatedAnswers,
    );
  }

  // Get answer for a specific question number
  PreAssessmentAnswer? getAnswer(int questionNumber) {
    try {
      return answers.firstWhere((a) => a.questionNumber == questionNumber);
    } catch (e) {
      return null;
    }
  }
}

class ModuleScore {
  final String moduleName;
  final int totalQuestions;
  final int correctAnswers;
  final double scorePercentage;
  final bool passed; // >= 70%

  ModuleScore({
    required this.moduleName,
    required this.totalQuestions,
    required this.correctAnswers,
  })  : scorePercentage = totalQuestions > 0
            ? (correctAnswers / totalQuestions) * 100
            : 0.0,
        passed = totalQuestions > 0
            ? (correctAnswers / totalQuestions) * 100 >= 70
            : false;

  Map<String, dynamic> toJson() {
    return {
      'moduleName': moduleName,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'scorePercentage': scorePercentage,
      'passed': passed,
    };
  }

  factory ModuleScore.fromJson(Map<String, dynamic> json) {
    return ModuleScore(
      moduleName: json['moduleName'] as String,
      totalQuestions: json['totalQuestions'] as int,
      correctAnswers: json['correctAnswers'] as int,
    );
  }

  // Get status color based on score
  String get statusLevel {
    if (scorePercentage >= 70) return 'strong';
    if (scorePercentage >= 50) return 'moderate';
    return 'weak';
  }
}

class PreAssessmentResult {
  final String? id;
  final String userId;
  final String courseId;
  final String? attemptId;
  final double scorePercentage;
  final int totalQuestions;
  final int correctAnswers;
  final bool passed; // >= 70%
  final List<String> weakModules;
  final List<String> strongModules;
  final Map<String, double> moduleScores;
  final DateTime completedAt;
  final DateTime? createdAt;

  PreAssessmentResult({
    this.id,
    required this.userId,
    required this.courseId,
    this.attemptId,
    required this.scorePercentage,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.passed,
    this.weakModules = const [],
    this.strongModules = const [],
    this.moduleScores = const {},
    required this.completedAt,
    this.createdAt,
  });

  factory PreAssessmentResult.fromSupabase(Map<String, dynamic> data) {
    // Parse weak modules
    List<String> weakModulesList = [];
    if (data['weak_modules'] != null) {
      weakModulesList = List<String>.from(data['weak_modules'] as List);
    }

    // Parse strong modules
    List<String> strongModulesList = [];
    if (data['strong_modules'] != null) {
      strongModulesList = List<String>.from(data['strong_modules'] as List);
    }

    // Parse module scores
    Map<String, double> moduleScoresMap = {};
    if (data['module_scores'] != null) {
      final scoresJson = data['module_scores'] as Map<String, dynamic>;
      scoresJson.forEach((key, value) {
        moduleScoresMap[key] = (value as num).toDouble();
      });
    }

    return PreAssessmentResult(
      id: data['id'] as String?,
      userId: data['user_id'] as String,
      courseId: data['course_id'] as String,
      attemptId: data['attempt_id'] as String?,
      scorePercentage: (data['score_percentage'] as num).toDouble(),
      totalQuestions: data['total_questions'] as int,
      correctAnswers: data['correct_answers'] as int,
      passed: data['passed'] as bool? ?? false,
      weakModules: weakModulesList,
      strongModules: strongModulesList,
      moduleScores: moduleScoresMap,
      completedAt: DateTime.parse(data['completed_at'] as String),
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'course_id': courseId,
      if (attemptId != null) 'attempt_id': attemptId,
      'score_percentage': scorePercentage,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'passed': passed,
      'weak_modules': weakModules,
      'strong_modules': strongModules,
      'module_scores': moduleScores,
      'completed_at': completedAt.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  // Get module score details
  List<ModuleScore> getModuleScoreDetails(List<PreAssessmentAnswer> answers) {
    Map<String, List<PreAssessmentAnswer>> answersByModule = {};

    for (var answer in answers) {
      if (!answersByModule.containsKey(answer.moduleName)) {
        answersByModule[answer.moduleName] = [];
      }
      answersByModule[answer.moduleName]!.add(answer);
    }

    List<ModuleScore> moduleScoresList = [];
    answersByModule.forEach((moduleName, moduleAnswers) {
      final correct = moduleAnswers.where((a) => a.isCorrect).length;
      moduleScoresList.add(ModuleScore(
        moduleName: moduleName,
        totalQuestions: moduleAnswers.length,
        correctAnswers: correct,
      ));
    });

    // Sort by score descending
    moduleScoresList.sort((a, b) => b.scorePercentage.compareTo(a.scorePercentage));

    return moduleScoresList;
  }

  // Get performance summary text
  String get performanceSummary {
    if (scorePercentage >= 90) return 'Excellent';
    if (scorePercentage >= 80) return 'Very Good';
    if (scorePercentage >= 70) return 'Good';
    if (scorePercentage >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  // Get number of weak modules
  int get weakModuleCount => weakModules.length;

  // Get number of strong modules
  int get strongModuleCount => strongModules.length;
}
