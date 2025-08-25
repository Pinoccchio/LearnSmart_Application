
// Enums for analytics categorization
enum PerformanceLevel {
  excellent,
  good,
  average,
  needsImprovement,
  poor,
}

enum LearningPatternType {
  quickLearner,
  steadyProgression,
  slowStarter,
  inconsistent,
  strugglingConcepts,
  acceleratedLearning,
  fatiguePattern,
}

enum RecommendationType {
  studyTiming,
  materialFocus,
  studyTechnique,
  practiceFrequency,
  difficultyAdjustment,
  conceptReinforcement,
  studyMethods,
  pomodoroOptimization,
  focusImprovement,
  cycleManagement,
  breakStrategy,
  timeBlocking,
  distractionControl,
}

enum InsightCategory {
  performance,
  behavior,
  cognitive,
  temporal,
  material,
}

// Core Analytics Models
class StudySessionAnalytics {
  final String id;
  final String sessionId;
  final String userId;
  final String moduleId;
  final DateTime analyzedAt;
  
  // Descriptive Analytics Data
  final PerformanceMetrics performanceMetrics;
  final LearningPatterns learningPatterns;
  final BehaviorAnalysis behaviorAnalysis;
  final CognitiveAnalysis cognitiveAnalysis;
  
  // Prescriptive Analytics Data
  final List<PersonalizedRecommendation> recommendations;
  final List<AnalyticsInsight> insights;
  final StudyPlan suggestedStudyPlan;
  
  // Metadata
  final Map<String, dynamic> additionalData;

  StudySessionAnalytics({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.moduleId,
    required this.analyzedAt,
    required this.performanceMetrics,
    required this.learningPatterns,
    required this.behaviorAnalysis,
    required this.cognitiveAnalysis,
    required this.recommendations,
    required this.insights,
    required this.suggestedStudyPlan,
    this.additionalData = const {},
  });

  factory StudySessionAnalytics.fromJson(Map<String, dynamic> json) {
    return StudySessionAnalytics(
      id: json['id'],
      sessionId: json['session_id'],
      userId: json['user_id'],
      moduleId: json['module_id'],
      analyzedAt: DateTime.parse(json['analyzed_at']),
      performanceMetrics: PerformanceMetrics.fromJson(json['performance_metrics']),
      learningPatterns: LearningPatterns.fromJson(json['learning_patterns']),
      behaviorAnalysis: BehaviorAnalysis.fromJson(json['behavior_analysis']),
      cognitiveAnalysis: CognitiveAnalysis.fromJson(json['cognitive_analysis']),
      recommendations: (json['recommendations'] as List)
          .map((r) => PersonalizedRecommendation.fromJson(r))
          .toList(),
      insights: (json['insights'] as List)
          .map((i) => AnalyticsInsight.fromJson(i))
          .toList(),
      suggestedStudyPlan: StudyPlan.fromJson(json['suggested_study_plan']),
      additionalData: json['additional_data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'user_id': userId,
      'module_id': moduleId,
      'analyzed_at': analyzedAt.toIso8601String(),
      'performance_metrics': performanceMetrics.toJson(),
      'learning_patterns': learningPatterns.toJson(),
      'behavior_analysis': behaviorAnalysis.toJson(),
      'cognitive_analysis': cognitiveAnalysis.toJson(),
      'recommendations': recommendations.map((r) => r.toJson()).toList(),
      'insights': insights.map((i) => i.toJson()).toList(),
      'suggested_study_plan': suggestedStudyPlan.toJson(),
      'additional_data': additionalData,
    };
  }
}

// Performance Metrics
class PerformanceMetrics {
  final double preStudyAccuracy;
  final double postStudyAccuracy;
  final double improvementPercentage;
  final double averageResponseTime;
  final double accuracyByDifficulty;
  final Map<String, double> materialPerformance;
  final Map<String, double> conceptMastery;
  final PerformanceLevel overallLevel;

  PerformanceMetrics({
    required this.preStudyAccuracy,
    required this.postStudyAccuracy,
    required this.improvementPercentage,
    required this.averageResponseTime,
    required this.accuracyByDifficulty,
    required this.materialPerformance,
    required this.conceptMastery,
    required this.overallLevel,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return PerformanceMetrics(
      preStudyAccuracy: json['pre_study_accuracy'].toDouble(),
      postStudyAccuracy: json['post_study_accuracy'].toDouble(),
      improvementPercentage: json['improvement_percentage'].toDouble(),
      averageResponseTime: json['average_response_time'].toDouble(),
      accuracyByDifficulty: json['accuracy_by_difficulty'].toDouble(),
      materialPerformance: Map<String, double>.from(json['material_performance']),
      conceptMastery: Map<String, double>.from(json['concept_mastery']),
      overallLevel: PerformanceLevel.values.byName(json['overall_level']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pre_study_accuracy': preStudyAccuracy,
      'post_study_accuracy': postStudyAccuracy,
      'improvement_percentage': improvementPercentage,
      'average_response_time': averageResponseTime,
      'accuracy_by_difficulty': accuracyByDifficulty,
      'material_performance': materialPerformance,
      'concept_mastery': conceptMastery,
      'overall_level': overallLevel.name,
    };
  }
}

// Learning Patterns Analysis
class LearningPatterns {
  final LearningPatternType patternType;
  final double learningVelocity;
  final List<String> strongConcepts;
  final List<String> weakConcepts;
  final Map<String, double> retentionRates;
  final List<TimeBasedPattern> temporalPatterns;

  LearningPatterns({
    required this.patternType,
    required this.learningVelocity,
    required this.strongConcepts,
    required this.weakConcepts,
    required this.retentionRates,
    required this.temporalPatterns,
  });

  factory LearningPatterns.fromJson(Map<String, dynamic> json) {
    return LearningPatterns(
      patternType: LearningPatternType.values.byName(json['pattern_type']),
      learningVelocity: json['learning_velocity'].toDouble(),
      strongConcepts: List<String>.from(json['strong_concepts']),
      weakConcepts: List<String>.from(json['weak_concepts']),
      retentionRates: Map<String, double>.from(json['retention_rates']),
      temporalPatterns: (json['temporal_patterns'] as List)
          .map((p) => TimeBasedPattern.fromJson(p))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pattern_type': patternType.name,
      'learning_velocity': learningVelocity,
      'strong_concepts': strongConcepts,
      'weak_concepts': weakConcepts,
      'retention_rates': retentionRates,
      'temporal_patterns': temporalPatterns.map((p) => p.toJson()).toList(),
    };
  }
}

// Behavior Analysis
class BehaviorAnalysis {
  final Duration totalStudyTime;
  final int hintUsageCount;
  final double hintEffectiveness;
  final List<String> commonErrorTypes;
  final Map<String, int> questionAttemptPatterns;
  final double persistenceScore;
  final double engagementLevel;

  BehaviorAnalysis({
    required this.totalStudyTime,
    required this.hintUsageCount,
    required this.hintEffectiveness,
    required this.commonErrorTypes,
    required this.questionAttemptPatterns,
    required this.persistenceScore,
    required this.engagementLevel,
  });

  factory BehaviorAnalysis.fromJson(Map<String, dynamic> json) {
    return BehaviorAnalysis(
      totalStudyTime: Duration(seconds: json['total_study_time_seconds']),
      hintUsageCount: json['hint_usage_count'],
      hintEffectiveness: json['hint_effectiveness'].toDouble(),
      commonErrorTypes: List<String>.from(json['common_error_types']),
      questionAttemptPatterns: Map<String, int>.from(json['question_attempt_patterns']),
      persistenceScore: json['persistence_score'].toDouble(),
      engagementLevel: json['engagement_level'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_study_time_seconds': totalStudyTime.inSeconds,
      'hint_usage_count': hintUsageCount,
      'hint_effectiveness': hintEffectiveness,
      'common_error_types': commonErrorTypes,
      'question_attempt_patterns': questionAttemptPatterns,
      'persistence_score': persistenceScore,
      'engagement_level': engagementLevel,
    };
  }
}

// Cognitive Analysis
class CognitiveAnalysis {
  final double cognitiveLoadScore;
  final Map<String, double> memoryRetentionByType;
  final double processingSpeed;
  final List<String> cognitiveStrengths;
  final List<String> cognitiveWeaknesses;
  final double attentionSpan;

  CognitiveAnalysis({
    required this.cognitiveLoadScore,
    required this.memoryRetentionByType,
    required this.processingSpeed,
    required this.cognitiveStrengths,
    required this.cognitiveWeaknesses,
    required this.attentionSpan,
  });

  factory CognitiveAnalysis.fromJson(Map<String, dynamic> json) {
    return CognitiveAnalysis(
      cognitiveLoadScore: json['cognitive_load_score'].toDouble(),
      memoryRetentionByType: Map<String, double>.from(json['memory_retention_by_type']),
      processingSpeed: json['processing_speed'].toDouble(),
      cognitiveStrengths: List<String>.from(json['cognitive_strengths']),
      cognitiveWeaknesses: List<String>.from(json['cognitive_weaknesses']),
      attentionSpan: json['attention_span'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cognitive_load_score': cognitiveLoadScore,
      'memory_retention_by_type': memoryRetentionByType,
      'processing_speed': processingSpeed,
      'cognitive_strengths': cognitiveStrengths,
      'cognitive_weaknesses': cognitiveWeaknesses,
      'attention_span': attentionSpan,
    };
  }
}

// Personalized Recommendations
class PersonalizedRecommendation {
  final String id;
  final RecommendationType type;
  final String title;
  final String description;
  final String actionableAdvice;
  final int priority;
  final double confidenceScore;
  final List<String> reasons;
  final Map<String, dynamic> parameters;

  PersonalizedRecommendation({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.actionableAdvice,
    required this.priority,
    required this.confidenceScore,
    required this.reasons,
    this.parameters = const {},
  });

  factory PersonalizedRecommendation.fromJson(Map<String, dynamic> json) {
    return PersonalizedRecommendation(
      id: json['id'],
      type: RecommendationType.values.byName(json['type']),
      title: json['title'],
      description: json['description'],
      actionableAdvice: json['actionable_advice'],
      priority: json['priority'],
      confidenceScore: json['confidence_score'].toDouble(),
      reasons: List<String>.from(json['reasons']),
      parameters: json['parameters'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'actionable_advice': actionableAdvice,
      'priority': priority,
      'confidence_score': confidenceScore,
      'reasons': reasons,
      'parameters': parameters,
    };
  }
}

// Analytics Insights
class AnalyticsInsight {
  final String id;
  final InsightCategory category;
  final String title;
  final String insight;
  final double significance;
  final List<String> supportingData;
  final Map<String, dynamic> visualizationData;

  AnalyticsInsight({
    required this.id,
    required this.category,
    required this.title,
    required this.insight,
    required this.significance,
    required this.supportingData,
    this.visualizationData = const {},
  });

  factory AnalyticsInsight.fromJson(Map<String, dynamic> json) {
    return AnalyticsInsight(
      id: json['id'],
      category: InsightCategory.values.byName(json['category']),
      title: json['title'],
      insight: json['insight'],
      significance: json['significance'].toDouble(),
      supportingData: List<String>.from(json['supporting_data']),
      visualizationData: json['visualization_data'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'title': title,
      'insight': insight,
      'significance': significance,
      'supporting_data': supportingData,
      'visualization_data': visualizationData,
    };
  }
}

// Study Plan
class StudyPlan {
  final String id;
  final List<StudyActivity> activities;
  final Duration estimatedDuration;
  final Map<String, String> focusAreas;
  final List<String> objectives;

  StudyPlan({
    required this.id,
    required this.activities,
    required this.estimatedDuration,
    required this.focusAreas,
    required this.objectives,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    return StudyPlan(
      id: json['id'],
      activities: (json['activities'] as List)
          .map((a) => StudyActivity.fromJson(a))
          .toList(),
      estimatedDuration: Duration(minutes: json['estimated_duration_minutes']),
      focusAreas: Map<String, String>.from(json['focus_areas']),
      objectives: List<String>.from(json['objectives']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activities': activities.map((a) => a.toJson()).toList(),
      'estimated_duration_minutes': estimatedDuration.inMinutes,
      'focus_areas': focusAreas,
      'objectives': objectives,
    };
  }
}

// Study Activity
class StudyActivity {
  final String type;
  final String description;
  final Duration duration;
  final int priority;
  final List<String> materials;

  StudyActivity({
    required this.type,
    required this.description,
    required this.duration,
    required this.priority,
    required this.materials,
  });

  factory StudyActivity.fromJson(Map<String, dynamic> json) {
    return StudyActivity(
      type: json['type'],
      description: json['description'],
      duration: Duration(minutes: json['duration_minutes']),
      priority: json['priority'],
      materials: List<String>.from(json['materials']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'duration_minutes': duration.inMinutes,
      'priority': priority,
      'materials': materials,
    };
  }
}

// Time-based Pattern
class TimeBasedPattern {
  final String timeframe;
  final double performanceScore;
  final String pattern;
  final List<String> observations;

  TimeBasedPattern({
    required this.timeframe,
    required this.performanceScore,
    required this.pattern,
    required this.observations,
  });

  factory TimeBasedPattern.fromJson(Map<String, dynamic> json) {
    return TimeBasedPattern(
      timeframe: json['timeframe'],
      performanceScore: json['performance_score'].toDouble(),
      pattern: json['pattern'],
      observations: List<String>.from(json['observations']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timeframe': timeframe,
      'performance_score': performanceScore,
      'pattern': pattern,
      'observations': observations,
    };
  }
}

// Helper class for analytics calculations
class AnalyticsCalculator {
  static PerformanceLevel determinePerformanceLevel(double accuracy) {
    if (accuracy >= 90) return PerformanceLevel.excellent;
    if (accuracy >= 80) return PerformanceLevel.good;
    if (accuracy >= 70) return PerformanceLevel.average;
    if (accuracy >= 60) return PerformanceLevel.needsImprovement;
    return PerformanceLevel.poor;
  }

  static LearningPatternType determineLearningPattern(
    double preAccuracy,
    double postAccuracy,
    double avgResponseTime,
    List<bool> attemptResults,
  ) {
    final improvement = postAccuracy - preAccuracy;
    final consistency = _calculateConsistency(attemptResults);
    
    if (improvement > 30 && avgResponseTime < 15) return LearningPatternType.quickLearner;
    if (improvement > 20 && consistency > 0.7) return LearningPatternType.steadyProgression;
    if (improvement > 15 && preAccuracy < 50) return LearningPatternType.slowStarter;
    if (consistency < 0.5) return LearningPatternType.inconsistent;
    return LearningPatternType.strugglingConcepts;
  }

  static double _calculateConsistency(List<bool> results) {
    if (results.isEmpty) return 0.0;
    
    int streakCount = 0;
    int maxStreak = 0;
    bool lastResult = results.first;
    
    for (bool result in results) {
      if (result == lastResult) {
        streakCount++;
      } else {
        maxStreak = maxStreak > streakCount ? maxStreak : streakCount;
        streakCount = 1;
        lastResult = result;
      }
    }
    
    return maxStreak / results.length;
  }
}