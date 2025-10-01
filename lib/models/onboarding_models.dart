// =====================================================
// Onboarding Models
// =====================================================
// Models for the user onboarding questionnaire system

class OnboardingQuestion {
  final int questionNumber;
  final String questionText;
  final String techniqueCategory; // active_recall, pomodoro, feynman, retrieval_practice
  final bool isReverseCoded;

  OnboardingQuestion({
    required this.questionNumber,
    required this.questionText,
    required this.techniqueCategory,
    required this.isReverseCoded,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_number': questionNumber,
      'question_text': questionText,
      'technique_category': techniqueCategory,
      'is_reverse_coded': isReverseCoded,
    };
  }
}

class OnboardingResponse {
  final String? id;
  final String userId;
  final int questionNumber;
  final String techniqueCategory;
  final int responseValue; // 1-5 Likert scale
  final bool isReverseCoded;
  final DateTime? createdAt;

  OnboardingResponse({
    this.id,
    required this.userId,
    required this.questionNumber,
    required this.techniqueCategory,
    required this.responseValue,
    required this.isReverseCoded,
    this.createdAt,
  });

  factory OnboardingResponse.fromSupabase(Map<String, dynamic> data) {
    return OnboardingResponse(
      id: data['id'] as String?,
      userId: data['user_id'] as String,
      questionNumber: data['question_number'] as int,
      techniqueCategory: data['technique_category'] as String,
      responseValue: data['response_value'] as int,
      isReverseCoded: data['is_reverse_coded'] as bool? ?? false,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'question_number': questionNumber,
      'technique_category': techniqueCategory,
      'response_value': responseValue,
      'is_reverse_coded': isReverseCoded,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

class TechniqueScore {
  final String technique;
  final String techniqueName;
  final int score;
  final String level; // Strong, Moderate, Low, Very Low

  TechniqueScore({
    required this.technique,
    required this.techniqueName,
    required this.score,
    required this.level,
  });

  String get description {
    switch (technique) {
      case 'active_recall':
        return 'Active recall is a learning technique that involves retrieving information from memory without looking at study materials.';
      case 'pomodoro':
        return 'The Pomodoro Technique involves breaking study time into focused intervals (typically 25 minutes) separated by short breaks.';
      case 'feynman':
        return 'The Feynman Technique is a learning method that involves explaining concepts in simple terms, as if teaching someone else.';
      case 'retrieval_practice':
        return 'Retrieval practice involves actively recalling information through self-testing, quizzes, and spaced repetition.';
      default:
        return '';
    }
  }

  String get levelDescription {
    switch (level) {
      case 'Strong':
        return 'Strong preference - This technique aligns well with your natural learning habits';
      case 'Moderate':
        return 'Moderate preference - You occasionally use this technique';
      case 'Low':
        return 'Low preference - This technique rarely fits your current study habits';
      case 'Very Low':
        return 'Very low preference - This technique is not aligned with your current habits';
      default:
        return '';
    }
  }

  static String getLevelFromScore(int score) {
    if (score >= 20) return 'Strong';
    if (score >= 15) return 'Moderate';
    if (score >= 10) return 'Low';
    return 'Very Low';
  }
}

class OnboardingResult {
  final String? id;
  final String userId;
  final int activeRecallScore;
  final int pomodoroScore;
  final int feynmanScore;
  final int retrievalPracticeScore;
  final String topTechnique;
  final DateTime? completedAt;
  final DateTime? createdAt;

  OnboardingResult({
    this.id,
    required this.userId,
    required this.activeRecallScore,
    required this.pomodoroScore,
    required this.feynmanScore,
    required this.retrievalPracticeScore,
    required this.topTechnique,
    this.completedAt,
    this.createdAt,
  });

  factory OnboardingResult.fromSupabase(Map<String, dynamic> data) {
    return OnboardingResult(
      id: data['id'] as String?,
      userId: data['user_id'] as String,
      activeRecallScore: data['active_recall_score'] as int,
      pomodoroScore: data['pomodoro_score'] as int,
      feynmanScore: data['feynman_score'] as int,
      retrievalPracticeScore: data['retrieval_practice_score'] as int,
      topTechnique: data['top_technique'] as String,
      completedAt: data['completed_at'] != null
          ? DateTime.parse(data['completed_at'] as String)
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'active_recall_score': activeRecallScore,
      'pomodoro_score': pomodoroScore,
      'feynman_score': feynmanScore,
      'retrieval_practice_score': retrievalPracticeScore,
      'top_technique': topTechnique,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  List<TechniqueScore> getTechniqueScores() {
    return [
      TechniqueScore(
        technique: 'active_recall',
        techniqueName: 'Active Recall',
        score: activeRecallScore,
        level: TechniqueScore.getLevelFromScore(activeRecallScore),
      ),
      TechniqueScore(
        technique: 'pomodoro',
        techniqueName: 'Pomodoro Technique',
        score: pomodoroScore,
        level: TechniqueScore.getLevelFromScore(pomodoroScore),
      ),
      TechniqueScore(
        technique: 'feynman',
        techniqueName: 'Feynman Technique',
        score: feynmanScore,
        level: TechniqueScore.getLevelFromScore(feynmanScore),
      ),
      TechniqueScore(
        technique: 'retrieval_practice',
        techniqueName: 'Retrieval Practice',
        score: retrievalPracticeScore,
        level: TechniqueScore.getLevelFromScore(retrievalPracticeScore),
      ),
    ];
  }

  TechniqueScore getTopTechniqueScore() {
    final scores = getTechniqueScores();
    return scores.firstWhere((s) => s.technique == topTechnique);
  }

  String getTopTechniqueName() {
    switch (topTechnique) {
      case 'active_recall':
        return 'Active Recall';
      case 'pomodoro':
        return 'Pomodoro Technique';
      case 'feynman':
        return 'Feynman Technique';
      case 'retrieval_practice':
        return 'Retrieval Practice';
      default:
        return '';
    }
  }
}
