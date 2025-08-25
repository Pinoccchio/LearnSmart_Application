
import 'package:equatable/equatable.dart';

/// Status of a Feynman session
enum FeynmanSessionStatus {
  preparing('preparing'),
  explaining('explaining'),
  reviewing('reviewing'),
  completed('completed'),
  paused('paused');

  const FeynmanSessionStatus(this.value);
  final String value;

  static FeynmanSessionStatus fromString(String value) {
    return FeynmanSessionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => FeynmanSessionStatus.preparing,
    );
  }

  String get displayName {
    switch (this) {
      case FeynmanSessionStatus.preparing:
        return 'Preparing';
      case FeynmanSessionStatus.explaining:
        return 'Explaining';
      case FeynmanSessionStatus.reviewing:
        return 'Reviewing';
      case FeynmanSessionStatus.completed:
        return 'Completed';
      case FeynmanSessionStatus.paused:
        return 'Paused';
    }
  }
}

/// Type of explanation input
enum ExplanationType {
  text('text'),
  voice('voice');

  const ExplanationType(this.value);
  final String value;

  static ExplanationType fromString(String value) {
    return ExplanationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ExplanationType.text,
    );
  }

  String get displayName {
    switch (this) {
      case ExplanationType.text:
        return 'Text';
      case ExplanationType.voice:
        return 'Voice';
    }
  }
}

/// Processing status for AI analysis
enum ProcessingStatus {
  pending('pending'),
  processing('processing'),
  completed('completed'),
  failed('failed');

  const ProcessingStatus(this.value);
  final String value;

  static ProcessingStatus fromString(String value) {
    return ProcessingStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ProcessingStatus.pending,
    );
  }
}

/// Type of feedback provided
enum FeynmanFeedbackType {
  clarity('clarity'),
  completeness('completeness'),
  accuracy('accuracy'),
  simplification('simplification'),
  examples('examples'),
  overall('overall');

  const FeynmanFeedbackType(this.value);
  final String value;

  static FeynmanFeedbackType fromString(String value) {
    return FeynmanFeedbackType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => FeynmanFeedbackType.overall,
    );
  }

  String get displayName {
    switch (this) {
      case FeynmanFeedbackType.clarity:
        return 'Clarity';
      case FeynmanFeedbackType.completeness:
        return 'Completeness';
      case FeynmanFeedbackType.accuracy:
        return 'Accuracy';
      case FeynmanFeedbackType.simplification:
        return 'Simplification';
      case FeynmanFeedbackType.examples:
        return 'Examples';
      case FeynmanFeedbackType.overall:
        return 'Overall';
    }
  }
}

/// Severity level of feedback
enum FeedbackSeverity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  const FeedbackSeverity(this.value);
  final String value;

  static FeedbackSeverity fromString(String value) {
    return FeedbackSeverity.values.firstWhere(
      (severity) => severity.value == value,
      orElse: () => FeedbackSeverity.medium,
    );
  }

  String get displayName {
    switch (this) {
      case FeedbackSeverity.low:
        return 'Low';
      case FeedbackSeverity.medium:
        return 'Medium';
      case FeedbackSeverity.high:
        return 'High';
      case FeedbackSeverity.critical:
        return 'Critical';
    }
  }
}

/// Type of study suggestion
enum StudySuggestionType {
  materialReview('material_review'),
  conceptPractice('concept_practice'),
  activeRecall('active_recall'),
  retrievalPractice('retrieval_practice'),
  additionalReading('additional_reading'),
  videoContent('video_content'),
  examplesPractice('examples_practice');

  const StudySuggestionType(this.value);
  final String value;

  static StudySuggestionType fromString(String value) {
    return StudySuggestionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => StudySuggestionType.materialReview,
    );
  }

  String get displayName {
    switch (this) {
      case StudySuggestionType.materialReview:
        return 'Material Review';
      case StudySuggestionType.conceptPractice:
        return 'Concept Practice';
      case StudySuggestionType.activeRecall:
        return 'Active Recall';
      case StudySuggestionType.retrievalPractice:
        return 'Retrieval Practice';
      case StudySuggestionType.additionalReading:
        return 'Additional Reading';
      case StudySuggestionType.videoContent:
        return 'Video Content';
      case StudySuggestionType.examplesPractice:
        return 'Examples Practice';
    }
  }
}

/// Main Feynman session model
class FeynmanSession extends Equatable {
  final String id;
  final String userId;
  final String moduleId;
  final FeynmanSessionStatus status;
  final String topic;
  final String? initialExplanation;
  final String? finalExplanation;
  final int explanationCount;
  final Map<String, dynamic>? sessionData;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeynmanSession({
    required this.id,
    required this.userId,
    required this.moduleId,
    required this.status,
    required this.topic,
    this.initialExplanation,
    this.finalExplanation,
    required this.explanationCount,
    this.sessionData,
    required this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeynmanSession.fromJson(Map<String, dynamic> json) {
    return FeynmanSession(
      id: json['id'],
      userId: json['user_id'],
      moduleId: json['module_id'],
      status: FeynmanSessionStatus.fromString(json['status']),
      topic: json['topic'],
      initialExplanation: json['initial_explanation'],
      finalExplanation: json['final_explanation'],
      explanationCount: json['explanation_count'] ?? 0,
      sessionData: json['session_data'],
      startedAt: DateTime.parse(json['started_at']),
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
      'status': status.value,
      'topic': topic,
      'initial_explanation': initialExplanation,
      'final_explanation': finalExplanation,
      'explanation_count': explanationCount,
      'session_data': sessionData,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FeynmanSession copyWith({
    String? id,
    String? userId,
    String? moduleId,
    FeynmanSessionStatus? status,
    String? topic,
    String? initialExplanation,
    String? finalExplanation,
    int? explanationCount,
    Map<String, dynamic>? sessionData,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeynmanSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moduleId: moduleId ?? this.moduleId,
      status: status ?? this.status,
      topic: topic ?? this.topic,
      initialExplanation: initialExplanation ?? this.initialExplanation,
      finalExplanation: finalExplanation ?? this.finalExplanation,
      explanationCount: explanationCount ?? this.explanationCount,
      sessionData: sessionData ?? this.sessionData,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isCompleted => status == FeynmanSessionStatus.completed;
  bool get isActive => status == FeynmanSessionStatus.explaining || status == FeynmanSessionStatus.reviewing;
  bool get hasExplanations => explanationCount > 0;

  Duration get totalDuration {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt);
  }

  @override
  @override
  List<Object?> get props => [
    id,
    userId,
    moduleId,
    status,
    topic,
    initialExplanation,
    finalExplanation,
    explanationCount,
    sessionData,
    startedAt,
    completedAt,
    createdAt,
    updatedAt,
  ];
}

/// Feynman explanation model
class FeynmanExplanation extends Equatable {
  final String id;
  final String sessionId;
  final int attemptNumber;
  final String explanationText;
  final ExplanationType explanationType;
  final int wordCount;
  final double? clarityScore;
  final double? completenessScore;
  final double? conceptualAccuracyScore;
  final double? overallScore;
  final List<String> identifiedGaps;
  final List<String> strengths;
  final List<String> improvementAreas;
  final ProcessingStatus processingStatus;
  final Map<String, dynamic>? aiAnalysis;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeynmanExplanation({
    required this.id,
    required this.sessionId,
    required this.attemptNumber,
    required this.explanationText,
    required this.explanationType,
    required this.wordCount,
    this.clarityScore,
    this.completenessScore,
    this.conceptualAccuracyScore,
    this.overallScore,
    required this.identifiedGaps,
    required this.strengths,
    required this.improvementAreas,
    required this.processingStatus,
    this.aiAnalysis,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeynmanExplanation.fromJson(Map<String, dynamic> json) {
    return FeynmanExplanation(
      id: json['id'],
      sessionId: json['session_id'],
      attemptNumber: json['attempt_number'],
      explanationText: json['explanation_text'],
      explanationType: ExplanationType.fromString(json['explanation_type']),
      wordCount: json['word_count'] ?? 0,
      clarityScore: json['clarity_score']?.toDouble(),
      completenessScore: json['completeness_score']?.toDouble(),
      conceptualAccuracyScore: json['conceptual_accuracy_score']?.toDouble(),
      overallScore: json['overall_score']?.toDouble(),
      identifiedGaps: List<String>.from(json['identified_gaps'] ?? []),
      strengths: List<String>.from(json['strengths'] ?? []),
      improvementAreas: List<String>.from(json['improvement_areas'] ?? []),
      processingStatus: ProcessingStatus.fromString(json['processing_status']),
      aiAnalysis: json['ai_analysis'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'attempt_number': attemptNumber,
      'explanation_text': explanationText,
      'explanation_type': explanationType.value,
      'word_count': wordCount,
      'clarity_score': clarityScore,
      'completeness_score': completenessScore,
      'conceptual_accuracy_score': conceptualAccuracyScore,
      'overall_score': overallScore,
      'identified_gaps': identifiedGaps,
      'strengths': strengths,
      'improvement_areas': improvementAreas,
      'processing_status': processingStatus.value,
      'ai_analysis': aiAnalysis,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FeynmanExplanation copyWith({
    String? id,
    String? sessionId,
    int? attemptNumber,
    String? explanationText,
    ExplanationType? explanationType,
    int? wordCount,
    double? clarityScore,
    double? completenessScore,
    double? conceptualAccuracyScore,
    double? overallScore,
    List<String>? identifiedGaps,
    List<String>? strengths,
    List<String>? improvementAreas,
    ProcessingStatus? processingStatus,
    Map<String, dynamic>? aiAnalysis,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeynmanExplanation(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      explanationText: explanationText ?? this.explanationText,
      explanationType: explanationType ?? this.explanationType,
      wordCount: wordCount ?? this.wordCount,
      clarityScore: clarityScore ?? this.clarityScore,
      completenessScore: completenessScore ?? this.completenessScore,
      conceptualAccuracyScore: conceptualAccuracyScore ?? this.conceptualAccuracyScore,
      overallScore: overallScore ?? this.overallScore,
      identifiedGaps: identifiedGaps ?? this.identifiedGaps,
      strengths: strengths ?? this.strengths,
      improvementAreas: improvementAreas ?? this.improvementAreas,
      processingStatus: processingStatus ?? this.processingStatus,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isProcessed => processingStatus == ProcessingStatus.completed;
  bool get isProcessing => processingStatus == ProcessingStatus.processing;
  bool get hasScores => overallScore != null;
  bool get hasAnalysis => aiAnalysis != null && aiAnalysis!.isNotEmpty;

  double get averageScore {
    final scores = [clarityScore, completenessScore, conceptualAccuracyScore]
        .where((score) => score != null)
        .cast<double>()
        .toList();
    
    if (scores.isEmpty) return 0.0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  @override
  @override
  List<Object?> get props => [
    id,
    sessionId,
    attemptNumber,
    explanationText,
    explanationType,
    wordCount,
    clarityScore,
    completenessScore,
    conceptualAccuracyScore,
    overallScore,
    identifiedGaps,
    strengths,
    improvementAreas,
    processingStatus,
    aiAnalysis,
    createdAt,
    updatedAt,
  ];
}

/// Feynman feedback model
class FeynmanFeedback extends Equatable {
  final String id;
  final String explanationId;
  final FeynmanFeedbackType feedbackType;
  final String feedbackText;
  final FeedbackSeverity severity;
  final String? suggestedImprovement;
  final List<String> relatedConcepts;
  final int priority;
  final bool isAddressed;
  final DateTime createdAt;

  const FeynmanFeedback({
    required this.id,
    required this.explanationId,
    required this.feedbackType,
    required this.feedbackText,
    required this.severity,
    this.suggestedImprovement,
    required this.relatedConcepts,
    required this.priority,
    required this.isAddressed,
    required this.createdAt,
  });

  factory FeynmanFeedback.fromJson(Map<String, dynamic> json) {
    return FeynmanFeedback(
      id: json['id'],
      explanationId: json['explanation_id'],
      feedbackType: FeynmanFeedbackType.fromString(json['feedback_type']),
      feedbackText: json['feedback_text'],
      severity: FeedbackSeverity.fromString(json['severity']),
      suggestedImprovement: json['suggested_improvement'],
      relatedConcepts: List<String>.from(json['related_concepts'] ?? []),
      priority: json['priority'] ?? 1,
      isAddressed: json['is_addressed'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'explanation_id': explanationId,
      'feedback_type': feedbackType.value,
      'feedback_text': feedbackText,
      'severity': severity.value,
      'suggested_improvement': suggestedImprovement,
      'related_concepts': relatedConcepts,
      'priority': priority,
      'is_addressed': isAddressed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  FeynmanFeedback copyWith({
    String? id,
    String? explanationId,
    FeynmanFeedbackType? feedbackType,
    String? feedbackText,
    FeedbackSeverity? severity,
    String? suggestedImprovement,
    List<String>? relatedConcepts,
    int? priority,
    bool? isAddressed,
    DateTime? createdAt,
  }) {
    return FeynmanFeedback(
      id: id ?? this.id,
      explanationId: explanationId ?? this.explanationId,
      feedbackType: feedbackType ?? this.feedbackType,
      feedbackText: feedbackText ?? this.feedbackText,
      severity: severity ?? this.severity,
      suggestedImprovement: suggestedImprovement ?? this.suggestedImprovement,
      relatedConcepts: relatedConcepts ?? this.relatedConcepts,
      priority: priority ?? this.priority,
      isAddressed: isAddressed ?? this.isAddressed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  @override
  List<Object?> get props => [
    id,
    explanationId,
    feedbackType,
    feedbackText,
    severity,
    suggestedImprovement,
    relatedConcepts,
    priority,
    isAddressed,
    createdAt,
  ];
}

/// Feynman study suggestion model
class FeynmanStudySuggestion extends Equatable {
  final String id;
  final String sessionId;
  final StudySuggestionType suggestionType;
  final String title;
  final String description;
  final int priority;
  final int estimatedDurationMinutes;
  final List<String> relatedConcepts;
  final List<String> suggestedMaterials;
  final bool isCompleted;
  final String? completionNotes;
  final DateTime createdAt;
  final DateTime? completedAt;

  const FeynmanStudySuggestion({
    required this.id,
    required this.sessionId,
    required this.suggestionType,
    required this.title,
    required this.description,
    required this.priority,
    required this.estimatedDurationMinutes,
    required this.relatedConcepts,
    required this.suggestedMaterials,
    required this.isCompleted,
    this.completionNotes,
    required this.createdAt,
    this.completedAt,
  });

  factory FeynmanStudySuggestion.fromJson(Map<String, dynamic> json) {
    return FeynmanStudySuggestion(
      id: json['id'],
      sessionId: json['session_id'],
      suggestionType: StudySuggestionType.fromString(json['suggestion_type']),
      title: json['title'],
      description: json['description'],
      priority: json['priority'] ?? 1,
      estimatedDurationMinutes: json['estimated_duration_minutes'] ?? 15,
      relatedConcepts: List<String>.from(json['related_concepts'] ?? []),
      suggestedMaterials: List<String>.from(json['suggested_materials'] ?? []),
      isCompleted: json['is_completed'] ?? false,
      completionNotes: json['completion_notes'],
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'suggestion_type': suggestionType.value,
      'title': title,
      'description': description,
      'priority': priority,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'related_concepts': relatedConcepts,
      'suggested_materials': suggestedMaterials,
      'is_completed': isCompleted,
      'completion_notes': completionNotes,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  FeynmanStudySuggestion copyWith({
    String? id,
    String? sessionId,
    StudySuggestionType? suggestionType,
    String? title,
    String? description,
    int? priority,
    int? estimatedDurationMinutes,
    List<String>? relatedConcepts,
    List<String>? suggestedMaterials,
    bool? isCompleted,
    String? completionNotes,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return FeynmanStudySuggestion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      suggestionType: suggestionType ?? this.suggestionType,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      relatedConcepts: relatedConcepts ?? this.relatedConcepts,
      suggestedMaterials: suggestedMaterials ?? this.suggestedMaterials,
      isCompleted: isCompleted ?? this.isCompleted,
      completionNotes: completionNotes ?? this.completionNotes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  @override
  List<Object?> get props => [
    id,
    sessionId,
    suggestionType,
    title,
    description,
    priority,
    estimatedDurationMinutes,
    relatedConcepts,
    suggestedMaterials,
    isCompleted,
    completionNotes,
    createdAt,
    completedAt,
  ];
}

/// Results model for completed Feynman sessions
class FeynmanSessionResults extends Equatable {
  final FeynmanSession session;
  final List<FeynmanExplanation> explanations;
  final List<FeynmanFeedback> feedback;
  final List<FeynmanStudySuggestion> studySuggestions;
  final double averageExplanationScore;
  final double improvementTrend;
  final List<String> masteryConcepts;
  final List<String> needsWorkConcepts;
  final Map<String, double> conceptScores;

  const FeynmanSessionResults({
    required this.session,
    required this.explanations,
    required this.feedback,
    required this.studySuggestions,
    required this.averageExplanationScore,
    required this.improvementTrend,
    required this.masteryConcepts,
    required this.needsWorkConcepts,
    required this.conceptScores,
  });

  factory FeynmanSessionResults.calculate(
    FeynmanSession session,
    List<FeynmanExplanation> explanations,
    List<FeynmanFeedback> feedback,
    List<FeynmanStudySuggestion> studySuggestions,
  ) {
    // Calculate average explanation score
    final scoredExplanations = explanations.where((e) => e.overallScore != null);
    final averageScore = scoredExplanations.isNotEmpty
        ? scoredExplanations.map((e) => e.overallScore!).reduce((a, b) => a + b) / scoredExplanations.length
        : 0.0;

    // Calculate improvement trend
    double improvementTrend = 0.0;
    if (explanations.length >= 2) {
      final firstScore = explanations.first.overallScore ?? 0.0;
      final lastScore = explanations.last.overallScore ?? 0.0;
      improvementTrend = lastScore - firstScore;
    }

    // Identify mastery and needs work concepts
    final conceptScores = <String, double>{};
    final masteryConcepts = <String>[];
    final needsWorkConcepts = <String>[];

    for (final explanation in explanations) {
      if (explanation.overallScore != null) {
        // Add identified gaps to needs work
        needsWorkConcepts.addAll(explanation.identifiedGaps);
        
        // Add strengths to mastery (if score is high)
        if (explanation.overallScore! >= 7.0) {
          masteryConcepts.addAll(explanation.strengths);
        }
      }
    }

    // Remove duplicates and conflicting entries
    final uniqueMastery = masteryConcepts.toSet().difference(needsWorkConcepts.toSet()).toList();
    final uniqueNeedsWork = needsWorkConcepts.toSet().difference(masteryConcepts.toSet()).toList();

    return FeynmanSessionResults(
      session: session,
      explanations: explanations,
      feedback: feedback,
      studySuggestions: studySuggestions,
      averageExplanationScore: averageScore,
      improvementTrend: improvementTrend,
      masteryConcepts: uniqueMastery,
      needsWorkConcepts: uniqueNeedsWork,
      conceptScores: conceptScores,
    );
  }

  // Computed properties
  int get totalExplanations => explanations.length;
  int get totalWordsWritten => explanations.fold(0, (sum, e) => sum + e.wordCount);
  int get highQualityExplanations => explanations.where((e) => (e.overallScore ?? 0) >= 7.0).length;
  int get criticalFeedbackCount => feedback.where((f) => f.severity == FeedbackSeverity.critical).length;
  int get completedSuggestions => studySuggestions.where((s) => s.isCompleted).length;
  
  // Aliases for UI consistency
  double? get averageScore => averageExplanationScore;
  double? get bestScore {
    final scores = explanations.map((e) => e.overallScore).where((s) => s != null).cast<double>();
    return scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : null;
  }
  double? get improvementScore => improvementTrend;
  FeynmanSessionStatus get completionStatus => session.status;
  double? get conceptMasteryLevel {
    if (masteryConcepts.isEmpty && needsWorkConcepts.isEmpty) return null;
    final totalConcepts = masteryConcepts.length + needsWorkConcepts.length;
    return masteryConcepts.length / totalConcepts;
  }
  
  // Convenience getters
  List<String> get keyStrengths => masteryConcepts;
  List<String> get identifiedGaps => needsWorkConcepts;
  
  Duration get totalSessionTime => session.totalDuration;
  Duration get totalTimeSpent => session.totalDuration;
  String get performanceLevel {
    if (averageExplanationScore >= 8.0) return 'Excellent';
    if (averageExplanationScore >= 6.0) return 'Good';
    if (averageExplanationScore >= 4.0) return 'Fair';
    return 'Needs Improvement';
  }

  @override
  @override
  List<Object?> get props => [
    session,
    explanations,
    feedback,
    studySuggestions,
    averageExplanationScore,
    totalWordsWritten,
    bestScore,
    improvementScore,
    completionStatus,
    conceptMasteryLevel,
    keyStrengths,
    identifiedGaps,
    totalSessionTime,
    improvementTrend,
    masteryConcepts,
    needsWorkConcepts,
    conceptScores,
  ];
}