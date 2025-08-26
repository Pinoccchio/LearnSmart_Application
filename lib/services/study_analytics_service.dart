import 'dart:math';
import '../models/study_analytics_models.dart';
import '../models/active_recall_models.dart';
import '../models/pomodoro_models.dart';
import '../models/feynman_models.dart';
import '../models/course_models.dart';
import '../services/supabase_service.dart';
import '../services/gemini_ai_service.dart';

class StudyAnalyticsService {
  late final GeminiAIService _aiService;
  
  StudyAnalyticsService() {
    _aiService = GeminiAIService();
  }

  /// Get historical Pomodoro sessions for a user and module
  Future<List<PomodoroSession>> getHistoricalPomodoroSessions(String userId, String moduleId) async {
    try {
      print('📊 [HISTORICAL DATA] Fetching Pomodoro sessions for user: $userId, module: $moduleId');
      
      final response = await SupabaseService.client
          .from('pomodoro_sessions')
          .select('''
            *,
            pomodoro_cycles(*),
            pomodoro_notes(*)
          ''')
          .eq('user_id', userId)
          .eq('module_id', moduleId)
          .eq('status', 'completed')
          .order('started_at', ascending: false)
          .limit(20); // Last 20 sessions for analysis
      
      final sessions = response.map((sessionData) {
        return PomodoroSession.fromJson(sessionData);
      }).toList();
      
      print('✅ [HISTORICAL DATA] Found ${sessions.length} historical Pomodoro sessions');
      return sessions;
      
    } catch (e) {
      print('❌ [HISTORICAL DATA] Error fetching historical sessions: $e');
      return [];
    }
  }

  /// Aggregate performance data across multiple Pomodoro sessions
  Future<Map<String, dynamic>> aggregateModulePerformance(String userId, String moduleId) async {
    try {
      final sessions = await getHistoricalPomodoroSessions(userId, moduleId);
      
      if (sessions.isEmpty) {
        return _getEmptyPerformanceData();
      }
      
      // Calculate aggregated metrics
      final totalSessions = sessions.length;
      final totalCyclesPlanned = sessions.fold(0, (sum, session) => sum + session.totalCyclesPlanned);
      final totalCyclesCompleted = sessions.fold(0, (sum, session) => sum + session.cyclesCompleted);
      final totalStudyMinutes = sessions.fold(0, (sum, session) => 
        sum + (session.completedAt?.difference(session.startedAt).inMinutes ?? 0));
      
      // Get all cycles for detailed analysis
      final allCycles = <PomodoroCycle>[];
      for (final session in sessions) {
        final cyclesResponse = await SupabaseService.client
            .from('pomodoro_cycles')
            .select('*')
            .eq('session_id', session.id);
        
        final cycles = cyclesResponse.map((cycleData) => PomodoroCycle.fromJson(cycleData)).toList();
        allCycles.addAll(cycles);
      }
      
      // Calculate focus score trends
      final focusScores = allCycles
          .where((cycle) => cycle.focusScore != null && cycle.type == PomodoroCycleType.work)
          .map((cycle) => cycle.focusScore!.toDouble())
          .toList();
      
      final avgFocusScore = focusScores.isNotEmpty 
          ? focusScores.reduce((a, b) => a + b) / focusScores.length 
          : 0.0;
      
      // Calculate completion rate
      final completionRate = totalCyclesPlanned > 0 
          ? (totalCyclesCompleted / totalCyclesPlanned) * 100 
          : 0.0;
      
      // Analyze time patterns (best performing hour)
      final sessionsByHour = <int, List<double>>{};
      for (final session in sessions) {
        final hour = session.startedAt.hour;
        if (!sessionsByHour.containsKey(hour)) {
          sessionsByHour[hour] = [];
        }
        
        // Calculate session productivity score
        final sessionCycles = allCycles.where((c) => c.sessionId == session.id).toList();
        final sessionFocusScores = sessionCycles
            .where((c) => c.focusScore != null)
            .map((c) => c.focusScore!.toDouble())
            .toList();
        
        if (sessionFocusScores.isNotEmpty) {
          final sessionAvgFocus = sessionFocusScores.reduce((a, b) => a + b) / sessionFocusScores.length;
          sessionsByHour[hour]!.add(sessionAvgFocus);
        }
      }
      
      // Find best performing time
      String bestTimeOfDay = 'morning';
      double bestScore = 0.0;
      
      sessionsByHour.forEach((hour, scores) {
        final avgScore = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0;
        if (avgScore > bestScore) {
          bestScore = avgScore;
          if (hour >= 6 && hour < 12) bestTimeOfDay = 'morning';
          else if (hour >= 12 && hour < 18) bestTimeOfDay = 'afternoon';
          else bestTimeOfDay = 'evening';
        }
      });
      
      // Calculate optimal cycle length
      final workCycles = allCycles.where((c) => c.type == PomodoroCycleType.work).toList();
      final optimalCycleLength = _calculateOptimalCycleLength(workCycles);
      
      // Determine focus trend
      String focusTrend = 'stable';
      if (focusScores.length >= 4) {
        final firstHalf = focusScores.take(focusScores.length ~/ 2).toList();
        final secondHalf = focusScores.skip(focusScores.length ~/ 2).toList();
        
        final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
        final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
        
        if (secondAvg > firstAvg + 0.5) focusTrend = 'improving';
        else if (firstAvg > secondAvg + 0.5) focusTrend = 'declining';
      }
      
      print('📈 [PERFORMANCE AGGREGATION] Processed $totalSessions sessions, ${allCycles.length} cycles');
      
      return {
        'total_sessions': totalSessions,
        'total_cycles_planned': totalCyclesPlanned,
        'total_cycles_completed': totalCyclesCompleted,
        'total_study_minutes': totalStudyMinutes,
        'average_focus_score': avgFocusScore,
        'completion_rate': completionRate,
        'best_time_of_day': bestTimeOfDay,
        'focus_trend': focusTrend,
        'optimal_cycle_length': optimalCycleLength,
        'focus_scores': focusScores,
        'sessions_by_hour': sessionsByHour,
      };
      
    } catch (e) {
      print('❌ [PERFORMANCE AGGREGATION] Error aggregating module performance: $e');
      return _getEmptyPerformanceData();
    }
  }

  /// Calculate optimal cycle length based on focus score patterns
  int _calculateOptimalCycleLength(List<PomodoroCycle> workCycles) {
    if (workCycles.isEmpty) return 25; // Default Pomodoro length
    
    // Group cycles by duration and calculate average focus scores
    final durationGroups = <int, List<double>>{};
    
    for (final cycle in workCycles) {
      final duration = cycle.durationMinutes;
      if (cycle.focusScore != null) {
        if (!durationGroups.containsKey(duration)) {
          durationGroups[duration] = [];
        }
        durationGroups[duration]!.add(cycle.focusScore!.toDouble());
      }
    }
    
    // Find duration with highest average focus score
    int optimalDuration = 25;
    double bestAverageScore = 0.0;
    
    durationGroups.forEach((duration, scores) {
      if (scores.length >= 2) { // Need at least 2 data points
        final avgScore = scores.reduce((a, b) => a + b) / scores.length;
        if (avgScore > bestAverageScore) {
          bestAverageScore = avgScore;
          optimalDuration = duration;
        }
      }
    });
    
    return optimalDuration;
  }

  /// Get focus score trends for visualization
  Future<List<double>> getFocusScoreTrends(String userId, String moduleId) async {
    try {
      final sessions = await getHistoricalPomodoroSessions(userId, moduleId);
      final focusScores = <double>[];
      
      for (final session in sessions.reversed) { // Chronological order
        final cyclesResponse = await SupabaseService.client
            .from('pomodoro_cycles')
            .select('*')
            .eq('session_id', session.id)
            .eq('type', 'work')
            .order('started_at');
        
        final cycles = cyclesResponse.map((cycleData) => PomodoroCycle.fromJson(cycleData)).toList();
        
        for (final cycle in cycles) {
          if (cycle.focusScore != null) {
            focusScores.add(cycle.focusScore!.toDouble());
          }
        }
      }
      
      return focusScores;
      
    } catch (e) {
      print('❌ [FOCUS TRENDS] Error getting focus score trends: $e');
      return [];
    }
  }

  Map<String, dynamic> _getEmptyPerformanceData() {
    return {
      'total_sessions': 0,
      'total_cycles_planned': 0,
      'total_cycles_completed': 0,
      'total_study_minutes': 0,
      'average_focus_score': 0.0,
      'completion_rate': 0.0,
      'best_time_of_day': 'morning',
      'focus_trend': 'stable',
      'optimal_cycle_length': 25,
      'focus_scores': <double>[],
      'sessions_by_hour': <int, List<double>>{},
    };
  }

  /// Generate comprehensive analytics for a completed study session
  Future<StudySessionAnalytics> generateSessionAnalytics({
    required String sessionId,
    required String userId,
    required String moduleId,
    required List<ActiveRecallFlashcard> flashcards,
    required List<ActiveRecallAttempt> attempts,
    required Course course,
    required Module module,
  }) async {
    try {
      print('📊 [ANALYTICS] Starting comprehensive analysis for session: $sessionId');
      
      // Split attempts into pre and post study
      final preStudyAttempts = attempts.where((a) => a.isPreStudy).toList();
      final postStudyAttempts = attempts.where((a) => !a.isPreStudy).toList();
      
      print('📊 [ANALYTICS] Pre-study attempts: ${preStudyAttempts.length}, Post-study: ${postStudyAttempts.length}');

      // Calculate descriptive analytics
      final performanceMetrics = _calculatePerformanceMetrics(
        flashcards, preStudyAttempts, postStudyAttempts, module.materials
      );
      
      final learningPatterns = _analyzeLearningPatterns(
        flashcards, preStudyAttempts, postStudyAttempts
      );
      
      final behaviorAnalysis = _analyzeBehavior(attempts, flashcards);
      
      final cognitiveAnalysis = _analyzeCognition(attempts, flashcards);
      
      // Generate AI-powered insights and recommendations
      final aiResults = await _generateAIInsights(
        performanceMetrics, learningPatterns, behaviorAnalysis, 
        cognitiveAnalysis, course, module
      );
      
      // Create the analytics object (let database generate UUID)
      final analytics = StudySessionAnalytics(
        id: '', // Will be generated by database
        sessionId: sessionId,
        userId: userId,
        moduleId: moduleId,
        analyzedAt: DateTime.now(),
        performanceMetrics: performanceMetrics,
        learningPatterns: learningPatterns,
        behaviorAnalysis: behaviorAnalysis,
        cognitiveAnalysis: cognitiveAnalysis,
        recommendations: aiResults['recommendations'] as List<PersonalizedRecommendation>,
        insights: aiResults['insights'] as List<AnalyticsInsight>,
        suggestedStudyPlan: aiResults['studyPlan'] as StudyPlan,
      );
      
      // Save to database (but continue even if it fails)
      await _saveAnalyticsToDatabase(analytics, sessionType: 'active_recall');
      
      print('✅ [ANALYTICS] Analytics generation completed successfully');
      return analytics;
      
    } catch (e) {
      print('❌ [ANALYTICS] Error generating session analytics: $e');
      
      // Return basic analytics if full analysis fails
      return _generateFallbackAnalytics(sessionId, userId, moduleId, flashcards, attempts);
    }
  }

  /// Calculate performance metrics from session data
  PerformanceMetrics _calculatePerformanceMetrics(
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> preStudyAttempts,
    List<ActiveRecallAttempt> postStudyAttempts,
    List<CourseMaterial> materials,
  ) {
    // Basic accuracy calculations
    final preCorrect = preStudyAttempts.where((a) => a.isCorrect).length;
    final postCorrect = postStudyAttempts.where((a) => a.isCorrect).length;
    
    final preAccuracy = preStudyAttempts.isNotEmpty ? (preCorrect / preStudyAttempts.length) * 100 : 0.0;
    final postAccuracy = postStudyAttempts.isNotEmpty ? (postCorrect / postStudyAttempts.length) * 100 : 0.0;
    final improvement = postAccuracy - preAccuracy;
    
    // Average response time calculation
    final allAttempts = [...preStudyAttempts, ...postStudyAttempts];
    final avgResponseTime = allAttempts.isNotEmpty 
        ? allAttempts.map((a) => a.responseTimeSeconds).reduce((a, b) => a + b) / allAttempts.length 
        : 0.0;
    
    // Performance by difficulty
    final difficultyPerformance = _calculateDifficultyPerformance(flashcards, postStudyAttempts);
    
    // Material-specific performance
    final materialPerformance = _calculateMaterialPerformance(flashcards, postStudyAttempts, materials);
    
    // Concept mastery analysis
    final conceptMastery = _calculateConceptMastery(flashcards, postStudyAttempts);
    
    return PerformanceMetrics(
      preStudyAccuracy: preAccuracy,
      postStudyAccuracy: postAccuracy,
      improvementPercentage: improvement,
      averageResponseTime: avgResponseTime,
      accuracyByDifficulty: difficultyPerformance,
      materialPerformance: materialPerformance,
      conceptMastery: conceptMastery,
      overallLevel: AnalyticsCalculator.determinePerformanceLevel(postAccuracy),
    );
  }

  /// Analyze learning patterns
  LearningPatterns _analyzeLearningPatterns(
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> preStudyAttempts,
    List<ActiveRecallAttempt> postStudyAttempts,
  ) {
    final allAttempts = [...preStudyAttempts, ...postStudyAttempts];
    final attemptResults = postStudyAttempts.map((a) => a.isCorrect).toList();
    
    final preAccuracy = preStudyAttempts.isNotEmpty 
        ? (preStudyAttempts.where((a) => a.isCorrect).length / preStudyAttempts.length) * 100 
        : 0.0;
    final postAccuracy = postStudyAttempts.isNotEmpty 
        ? (postStudyAttempts.where((a) => a.isCorrect).length / postStudyAttempts.length) * 100 
        : 0.0;
    
    final avgResponseTime = allAttempts.isNotEmpty 
        ? allAttempts.map((a) => a.responseTimeSeconds).reduce((a, b) => a + b) / allAttempts.length 
        : 0.0;
    
    // Determine learning pattern type
    final patternType = AnalyticsCalculator.determineLearningPattern(
      preAccuracy, postAccuracy, avgResponseTime, attemptResults
    );
    
    // Calculate learning velocity (improvement per question)
    final learningVelocity = flashcards.isNotEmpty ? (postAccuracy - preAccuracy) / flashcards.length : 0.0;
    
    // Identify strong and weak concepts
    final conceptAnalysis = _analyzeConceptStrengths(flashcards, postStudyAttempts);
    
    // Calculate retention rates by question type
    final retentionRates = _calculateRetentionRates(flashcards, preStudyAttempts, postStudyAttempts);
    
    // Analyze temporal patterns (placeholder - would need historical data)
    final temporalPatterns = <TimeBasedPattern>[
      TimeBasedPattern(
        timeframe: 'current_session',
        performanceScore: postAccuracy,
        pattern: patternType.name,
        observations: ['This session performance pattern'],
      ),
    ];
    
    return LearningPatterns(
      patternType: patternType,
      learningVelocity: learningVelocity,
      strongConcepts: conceptAnalysis['strong']!,
      weakConcepts: conceptAnalysis['weak']!,
      retentionRates: retentionRates,
      temporalPatterns: temporalPatterns,
    );
  }

  /// Analyze study behavior patterns
  BehaviorAnalysis _analyzeBehavior(
    List<ActiveRecallAttempt> attempts,
    List<ActiveRecallFlashcard> flashcards,
  ) {
    // Calculate total study time (approximate)
    final totalTime = attempts.fold<int>(0, (sum, attempt) => sum + attempt.responseTimeSeconds);
    
    // Hint usage analysis (placeholder - would need hint usage tracking)
    const hintUsageCount = 0;
    const hintEffectiveness = 0.0;
    
    // Common error types analysis
    final errorTypes = _identifyCommonErrorTypes(attempts, flashcards);
    
    // Question attempt patterns
    final attemptPatterns = _analyzeAttemptPatterns(attempts);
    
    // Persistence score (based on response times for incorrect answers)
    final persistenceScore = _calculatePersistenceScore(attempts);
    
    // Engagement level (based on response times and accuracy patterns)
    final engagementLevel = _calculateEngagementLevel(attempts);
    
    return BehaviorAnalysis(
      totalStudyTime: Duration(seconds: totalTime),
      hintUsageCount: hintUsageCount,
      hintEffectiveness: hintEffectiveness,
      commonErrorTypes: errorTypes,
      questionAttemptPatterns: attemptPatterns,
      persistenceScore: persistenceScore,
      engagementLevel: engagementLevel,
    );
  }

  /// Analyze cognitive patterns
  CognitiveAnalysis _analyzeCognition(
    List<ActiveRecallAttempt> attempts,
    List<ActiveRecallFlashcard> flashcards,
  ) {
    // Cognitive load score (based on response time variance)
    final cognitiveLoadScore = _calculateCognitiveLoad(attempts);
    
    // Memory retention by flashcard type
    final memoryRetentionByType = _calculateMemoryRetentionByType(flashcards, attempts);
    
    // Processing speed (inverse of average response time)
    final avgResponseTime = attempts.isNotEmpty 
        ? attempts.map((a) => a.responseTimeSeconds).reduce((a, b) => a + b) / attempts.length 
        : 30.0;
    final processingSpeed = avgResponseTime > 0 ? (60 / avgResponseTime) * 100 : 0.0;
    
    // Cognitive strengths and weaknesses
    final cognitiveProfile = _analyzeCognitiveProfile(attempts, flashcards);
    
    // Attention span (based on performance degradation over time)
    final attentionSpan = _calculateAttentionSpan(attempts);
    
    return CognitiveAnalysis(
      cognitiveLoadScore: cognitiveLoadScore,
      memoryRetentionByType: memoryRetentionByType,
      processingSpeed: processingSpeed,
      cognitiveStrengths: cognitiveProfile['strengths']!,
      cognitiveWeaknesses: cognitiveProfile['weaknesses']!,
      attentionSpan: attentionSpan,
    );
  }

  /// Generate AI-powered insights and recommendations
  Future<Map<String, dynamic>> _generateAIInsights(
    PerformanceMetrics performance,
    LearningPatterns patterns,
    BehaviorAnalysis behavior,
    CognitiveAnalysis cognitive,
    Course course,
    Module module,
  ) async {
    try {
      print('🤖 [AI INSIGHTS] Generating AI-powered recommendations and insights...');
      
      // Create comprehensive data summary for AI
      final analyticsData = {
        'course': course.title,
        'module': module.title,
        'performance': {
          'pre_study_accuracy': performance.preStudyAccuracy,
          'post_study_accuracy': performance.postStudyAccuracy,
          'improvement': performance.improvementPercentage,
          'avg_response_time': performance.averageResponseTime,
          'overall_level': performance.overallLevel.name,
        },
        'learning_patterns': {
          'pattern_type': patterns.patternType.name,
          'learning_velocity': patterns.learningVelocity,
          'strong_concepts': patterns.strongConcepts,
          'weak_concepts': patterns.weakConcepts,
        },
        'behavior': {
          'total_study_minutes': behavior.totalStudyTime.inMinutes,
          'persistence_score': behavior.persistenceScore,
          'engagement_level': behavior.engagementLevel,
          'common_errors': behavior.commonErrorTypes,
        },
        'cognitive': {
          'cognitive_load': cognitive.cognitiveLoadScore,
          'processing_speed': cognitive.processingSpeed,
          'attention_span': cognitive.attentionSpan,
          'strengths': cognitive.cognitiveStrengths,
          'weaknesses': cognitive.cognitiveWeaknesses,
        },
      };
      
      // Generate AI insights using the enhanced Gemini service
      final aiResults = await _aiService.generateStudyAnalyticsInsights(analyticsData);
      
      return aiResults;
      
    } catch (e) {
      print('❌ [AI INSIGHTS] Error generating AI insights: $e');
      
      // Return fallback insights
      return _generateFallbackInsights(performance, patterns, behavior, cognitive);
    }
  }

  /// Save analytics to database with session type
  Future<void> _saveAnalyticsToDatabase(StudySessionAnalytics analytics, {String sessionType = 'active_recall'}) async {
    try {
      print('💾 [ANALYTICS] Saving analytics to database with session type: $sessionType');
      print('💾 [ANALYTICS] Session ID: ${analytics.sessionId}');
      
      // Validate that session exists in the appropriate table before saving analytics
      final sessionExists = await _validateSessionExists(analytics.sessionId, sessionType);
      if (!sessionExists) {
        print('❌ [ANALYTICS] Session ${analytics.sessionId} not found in ${sessionType}_sessions table');
        print('💡 [ANALYTICS] Cannot save analytics due to missing session reference');
        print('💡 [ANALYTICS] This prevents the database trigger validation error');
        return; // Skip saving to avoid constraint violation
      }
      
      print('✅ [ANALYTICS] Session validation passed - session exists in database');
      
      final analyticsData = analytics.toJson();
      
      // Remove the empty id field to let database auto-generate UUID
      analyticsData.remove('id');
      
      // Add session_type to the data
      analyticsData['session_type'] = sessionType;
      
      await SupabaseService.client
          .from('study_session_analytics')
          .insert(analyticsData);
      
      print('✅ [ANALYTICS] Analytics saved to database successfully');
      
    } catch (e) {
      print('❌ [ANALYTICS] Error saving analytics to database: $e');
      
      // Provide detailed error information for debugging
      if (e.toString().contains('Invalid session_id for active_recall session type')) {
        print('💡 [ANALYTICS] Database trigger validation failed - session not found in active_recall_sessions table');
        print('💡 [ANALYTICS] This error should now be prevented by pre-validation');
      } else if (e.toString().contains('uuid')) {
        print('💡 [ANALYTICS] UUID format error - check ID generation');
      } else if (e.toString().contains('row-level security')) {
        print('💡 [ANALYTICS] RLS policy error - user may not have insert permission');
      } else if (e.toString().contains('foreign key')) {
        print('💡 [ANALYTICS] Foreign key constraint error - check session/user/module IDs');
      } else if (e.toString().contains('session_type')) {
        print('💡 [ANALYTICS] Session type error - check that session_type is valid');
      }
      
      // Don't throw - analytics generation should continue even if saving fails
    }
  }

  // Helper methods for specific calculations

  double _calculateDifficultyPerformance(
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> attempts,
  ) {
    if (attempts.isEmpty || flashcards.isEmpty) return 0.0;
    
    // Group attempts by flashcard difficulty
    final difficultyGroups = <String, List<bool>>{};
    
    for (final attempt in attempts) {
      final flashcard = flashcards.firstWhere(
        (f) => f.id == attempt.flashcardId,
        orElse: () => flashcards.first,
      );
      
      final difficulty = flashcard.difficulty.name;
      difficultyGroups[difficulty] ??= [];
      difficultyGroups[difficulty]!.add(attempt.isCorrect);
    }
    
    // Calculate weighted accuracy across difficulties
    double totalWeightedScore = 0.0;
    double totalWeight = 0.0;
    
    for (final entry in difficultyGroups.entries) {
      final accuracy = entry.value.where((correct) => correct).length / entry.value.length;
      final weight = entry.key == 'hard' ? 3.0 : entry.key == 'medium' ? 2.0 : 1.0;
      totalWeightedScore += accuracy * weight;
      totalWeight += weight;
    }
    
    return totalWeight > 0 ? (totalWeightedScore / totalWeight) * 100 : 0.0;
  }

  Map<String, double> _calculateMaterialPerformance(
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> attempts,
    List<CourseMaterial> materials,
  ) {
    final materialPerformance = <String, double>{};
    
    for (final material in materials) {
      final materialFlashcards = flashcards.where((f) => f.materialId == material.id).toList();
      final materialAttempts = attempts.where((a) => 
        materialFlashcards.any((f) => f.id == a.flashcardId)
      ).toList();
      
      if (materialAttempts.isNotEmpty) {
        final accuracy = materialAttempts.where((a) => a.isCorrect).length / materialAttempts.length;
        materialPerformance[material.title] = accuracy * 100;
      }
    }
    
    return materialPerformance;
  }

  Map<String, double> _calculateConceptMastery(
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> attempts,
  ) {
    // Group flashcards by type as a proxy for concept areas
    final conceptGroups = <String, List<String>>{};
    
    for (final flashcard in flashcards) {
      final concept = flashcard.type.name;
      conceptGroups[concept] ??= [];
      conceptGroups[concept]!.add(flashcard.id);
    }
    
    final conceptMastery = <String, double>{};
    
    for (final entry in conceptGroups.entries) {
      final conceptAttempts = attempts.where((a) => entry.value.contains(a.flashcardId)).toList();
      if (conceptAttempts.isNotEmpty) {
        final accuracy = conceptAttempts.where((a) => a.isCorrect).length / conceptAttempts.length;
        conceptMastery[entry.key] = accuracy * 100;
      }
    }
    
    return conceptMastery;
  }

  Map<String, List<String>> _analyzeConceptStrengths(
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> attempts,
  ) {
    final conceptPerformance = _calculateConceptMastery(flashcards, attempts);
    
    final strong = <String>[];
    final weak = <String>[];
    
    conceptPerformance.forEach((concept, accuracy) {
      if (accuracy >= 80) {
        strong.add(concept);
      } else if (accuracy < 60) {
        weak.add(concept);
      }
    });
    
    return {'strong': strong, 'weak': weak};
  }

  Map<String, double> _calculateRetentionRates(
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> preStudyAttempts,
    List<ActiveRecallAttempt> postStudyAttempts,
  ) {
    final retentionRates = <String, double>{};
    
    for (final flashcard in flashcards) {
      final preAttemptList = preStudyAttempts.where((a) => a.flashcardId == flashcard.id).toList();
      final postAttemptList = postStudyAttempts.where((a) => a.flashcardId == flashcard.id).toList();
      final preAttempt = preAttemptList.isNotEmpty ? preAttemptList.first : null;
      final postAttempt = postAttemptList.isNotEmpty ? postAttemptList.first : null;
      
      if (preAttempt != null && postAttempt != null) {
        // Calculate retention as improvement or maintenance of correct answers
        final retention = postAttempt.isCorrect ? 1.0 : (preAttempt.isCorrect ? 0.0 : 0.5);
        retentionRates[flashcard.type.name] = 
            (retentionRates[flashcard.type.name] ?? 0.0) + retention;
      }
    }
    
    // Average the retention rates
    final typeCounts = <String, int>{};
    for (final flashcard in flashcards) {
      typeCounts[flashcard.type.name] = (typeCounts[flashcard.type.name] ?? 0) + 1;
    }
    
    retentionRates.forEach((type, totalRetention) {
      final count = typeCounts[type] ?? 1;
      retentionRates[type] = (totalRetention / count) * 100;
    });
    
    return retentionRates;
  }

  List<String> _identifyCommonErrorTypes(
    List<ActiveRecallAttempt> attempts,
    List<ActiveRecallFlashcard> flashcards,
  ) {
    final errorTypes = <String>[];
    final incorrectAttempts = attempts.where((a) => !a.isCorrect).toList();
    
    if (incorrectAttempts.length > attempts.length * 0.3) {
      errorTypes.add('High error rate');
    }
    
    final slowAttempts = attempts.where((a) => a.responseTimeSeconds > 30).toList();
    if (slowAttempts.length > attempts.length * 0.4) {
      errorTypes.add('Slow processing');
    }
    
    // Analyze by question type
    final typeErrors = <String, int>{};
    for (final attempt in incorrectAttempts) {
      final flashcard = flashcards.firstWhere(
        (f) => f.id == attempt.flashcardId,
        orElse: () => flashcards.first,
      );
      typeErrors[flashcard.type.name] = (typeErrors[flashcard.type.name] ?? 0) + 1;
    }
    
    typeErrors.forEach((type, count) {
      if (count > incorrectAttempts.length * 0.4) {
        errorTypes.add('Difficulty with $type questions');
      }
    });
    
    return errorTypes.isEmpty ? ['No significant error patterns identified'] : errorTypes;
  }

  Map<String, int> _analyzeAttemptPatterns(List<ActiveRecallAttempt> attempts) {
    return {
      'total_attempts': attempts.length,
      'correct_attempts': attempts.where((a) => a.isCorrect).length,
      'quick_responses': attempts.where((a) => a.responseTimeSeconds < 10).length,
      'slow_responses': attempts.where((a) => a.responseTimeSeconds > 30).length,
    };
  }

  double _calculatePersistenceScore(List<ActiveRecallAttempt> attempts) {
    if (attempts.isEmpty) return 0.0;
    
    // Calculate based on response time consistency and error recovery
    final responseTimes = attempts.map((a) => a.responseTimeSeconds.toDouble()).toList();
    final avgTime = responseTimes.reduce((a, b) => a + b) / responseTimes.length;
    
    final consistency = 1.0 - (_calculateStandardDeviation(responseTimes) / avgTime);
    final errorRecovery = _calculateErrorRecoveryRate(attempts);
    
    return ((consistency + errorRecovery) / 2) * 100;
  }

  double _calculateEngagementLevel(List<ActiveRecallAttempt> attempts) {
    if (attempts.isEmpty) return 0.0;
    
    // High engagement = consistent response times + good accuracy
    final avgResponseTime = attempts.map((a) => a.responseTimeSeconds).reduce((a, b) => a + b) / attempts.length;
    final accuracy = attempts.where((a) => a.isCorrect).length / attempts.length;
    
    // Optimal response time is between 10-25 seconds
    final timeScore = avgResponseTime >= 10 && avgResponseTime <= 25 ? 1.0 : 
                     avgResponseTime < 5 ? 0.3 : // Too fast might indicate guessing
                     avgResponseTime > 45 ? 0.5 : 0.8; // Too slow might indicate disengagement
    
    return ((timeScore + accuracy) / 2) * 100;
  }

  double _calculateCognitiveLoad(List<ActiveRecallAttempt> attempts) {
    if (attempts.length < 2) return 0.0;
    
    final responseTimes = attempts.map((a) => a.responseTimeSeconds.toDouble()).toList();
    final variance = _calculateVariance(responseTimes);
    
    // Higher variance suggests higher cognitive load
    return min(100.0, (variance / 100) * 100);
  }

  Map<String, double> _calculateMemoryRetentionByType(
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> attempts,
  ) {
    final retentionByType = <String, double>{};
    
    for (final type in FlashcardType.values) {
      final typeFlashcards = flashcards.where((f) => f.type == type).toList();
      final typeAttempts = attempts.where((a) => 
        typeFlashcards.any((f) => f.id == a.flashcardId)
      ).toList();
      
      if (typeAttempts.isNotEmpty) {
        final accuracy = typeAttempts.where((a) => a.isCorrect).length / typeAttempts.length;
        retentionByType[type.name] = accuracy * 100;
      }
    }
    
    return retentionByType;
  }

  Map<String, List<String>> _analyzeCognitiveProfile(
    List<ActiveRecallAttempt> attempts,
    List<ActiveRecallFlashcard> flashcards,
  ) {
    final strengths = <String>[];
    final weaknesses = <String>[];
    
    // Analyze processing speed
    final avgResponseTime = attempts.isNotEmpty 
        ? attempts.map((a) => a.responseTimeSeconds).reduce((a, b) => a + b) / attempts.length 
        : 30;
    
    if (avgResponseTime < 15) {
      strengths.add('Fast processing speed');
    } else if (avgResponseTime > 35) {
      weaknesses.add('Slow processing speed');
    }
    
    // Analyze consistency
    final accuracy = attempts.isNotEmpty 
        ? attempts.where((a) => a.isCorrect).length / attempts.length 
        : 0.0;
    
    if (accuracy > 0.8) {
      strengths.add('High accuracy');
    } else if (accuracy < 0.5) {
      weaknesses.add('Low accuracy');
    }
    
    // Analyze memory types based on flashcard performance
    final memoryRetention = _calculateMemoryRetentionByType(flashcards, attempts);
    memoryRetention.forEach((type, retention) {
      if (retention > 80) {
        strengths.add('Strong $type memory');
      } else if (retention < 50) {
        weaknesses.add('Weak $type memory');
      }
    });
    
    return {
      'strengths': strengths.isEmpty ? ['Consistent performance'] : strengths,
      'weaknesses': weaknesses.isEmpty ? ['No significant weaknesses identified'] : weaknesses,
    };
  }

  double _calculateAttentionSpan(List<ActiveRecallAttempt> attempts) {
    if (attempts.length < 3) return 100.0;
    
    // Analyze performance degradation over time
    final firstHalf = attempts.take(attempts.length ~/ 2).toList();
    final secondHalf = attempts.skip(attempts.length ~/ 2).toList();
    
    final firstHalfAccuracy = firstHalf.where((a) => a.isCorrect).length / firstHalf.length;
    final secondHalfAccuracy = secondHalf.where((a) => a.isCorrect).length / secondHalf.length;
    
    // If performance remains stable, attention span is good
    final degradation = firstHalfAccuracy - secondHalfAccuracy;
    return max(0.0, min(100.0, (1.0 - degradation.abs()) * 100));
  }

  // Statistical helper methods
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((value) => pow(value - mean, 2)).toList();
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  double _calculateStandardDeviation(List<double> values) {
    return sqrt(_calculateVariance(values));
  }

  double _calculateErrorRecoveryRate(List<ActiveRecallAttempt> attempts) {
    if (attempts.length < 2) return 1.0;
    
    int recoveries = 0;
    int errorOpportunities = 0;
    
    for (int i = 1; i < attempts.length; i++) {
      if (!attempts[i - 1].isCorrect) {
        errorOpportunities++;
        if (attempts[i].isCorrect) {
          recoveries++;
        }
      }
    }
    
    return errorOpportunities > 0 ? recoveries / errorOpportunities : 1.0;
  }

  /// Generate fallback insights when AI generation fails
  Map<String, dynamic> _generateFallbackInsights(
    PerformanceMetrics performance,
    LearningPatterns patterns,
    BehaviorAnalysis behavior,
    CognitiveAnalysis cognitive,
  ) {
    final recommendations = <PersonalizedRecommendation>[
      PersonalizedRecommendation(
        id: 'fallback_rec_1',
        type: RecommendationType.studyTiming,
        title: 'Optimize Study Schedule',
        description: 'Based on your performance patterns, consider adjusting your study timing.',
        actionableAdvice: performance.improvementPercentage > 20 
            ? 'Continue with your current study schedule - it\'s working well!'
            : 'Try studying during your peak focus hours for better retention.',
        priority: 1,
        confidenceScore: 0.7,
        reasons: ['Performance analysis', 'Timing patterns'],
      ),
    ];
    
    final insights = <AnalyticsInsight>[
      AnalyticsInsight(
        id: 'fallback_insight_1',
        category: InsightCategory.performance,
        title: 'Session Performance Summary',
        insight: 'You showed a ${performance.improvementPercentage.toStringAsFixed(1)}% improvement from pre-study to post-study.',
        significance: 0.8,
        supportingData: ['Pre-study: ${performance.preStudyAccuracy.toStringAsFixed(1)}%', 'Post-study: ${performance.postStudyAccuracy.toStringAsFixed(1)}%'],
      ),
    ];
    
    final studyPlan = StudyPlan(
      id: 'fallback_plan_1',
      activities: [
        StudyActivity(
          type: 'review',
          description: 'Review weak concept areas',
          duration: const Duration(minutes: 30),
          priority: 1,
          materials: patterns.weakConcepts,
        ),
      ],
      estimatedDuration: const Duration(minutes: 30),
      focusAreas: {'weak_concepts': patterns.weakConcepts.join(', ')},
      objectives: ['Improve weak areas', 'Maintain strong performance'],
    );
    
    return {
      'recommendations': recommendations,
      'insights': insights,
      'studyPlan': studyPlan,
    };
  }

  /// Generate comprehensive analytics for a completed Pomodoro session
  Future<StudySessionAnalytics> generatePomodoroAnalytics({
    required String sessionId,
    required String userId,
    required String moduleId,
    required PomodoroSession session,
    required List<PomodoroCycle> cycles,
    required List<PomodoroNote> notes,
    required Course course,
    required Module module,
  }) async {
    try {
      print('📊 [POMODORO ANALYTICS] Starting comprehensive analysis for session: $sessionId');
      
      // Calculate descriptive analytics with historical context
      final performanceMetrics = await _calculatePomodoroPerformanceMetrics(session, cycles, notes);
      
      final learningPatterns = _analyzePomodoroLearningPatterns(session, cycles, notes);
      
      final behaviorAnalysis = _analyzePomodoroBehavior(session, cycles, notes);
      
      final cognitiveAnalysis = _analyzePomodoroCognition(session, cycles, notes);
      
      // Generate AI-powered insights and recommendations
      final aiResults = await _generatePomodoroAIInsights(
        performanceMetrics, learningPatterns, behaviorAnalysis, 
        cognitiveAnalysis, course, module, session, cycles, notes
      );
      
      // Create the analytics object
      final analytics = StudySessionAnalytics(
        id: '', // Will be generated by database
        sessionId: sessionId,
        userId: userId,
        moduleId: moduleId,
        analyzedAt: DateTime.now(),
        performanceMetrics: performanceMetrics,
        learningPatterns: learningPatterns,
        behaviorAnalysis: behaviorAnalysis,
        cognitiveAnalysis: cognitiveAnalysis,
        recommendations: aiResults['recommendations'] as List<PersonalizedRecommendation>,
        insights: aiResults['insights'] as List<AnalyticsInsight>,
        suggestedStudyPlan: aiResults['studyPlan'] as StudyPlan,
      );
      
      // Save to database (but continue even if it fails)
      await _saveAnalyticsToDatabase(analytics, sessionType: 'pomodoro');
      
      print('✅ [POMODORO ANALYTICS] Analytics generation completed successfully');
      return analytics;
      
    } catch (e) {
      print('❌ [POMODORO ANALYTICS] Error generating session analytics: $e');
      
      // Return basic analytics if full analysis fails
      return await _generateFallbackPomodoroAnalytics(sessionId, userId, moduleId, session, cycles, notes);
    }
  }

  /// Calculate performance metrics from Pomodoro session data with historical context
  Future<PerformanceMetrics> _calculatePomodoroPerformanceMetrics(
    PomodoroSession session,
    List<PomodoroCycle> cycles,
    List<PomodoroNote> notes,
  ) async {
    // Focus score analysis for current session
    final focusScores = cycles
        .where((c) => c.focusScore != null)
        .map((c) => c.focusScore!)
        .toList();
    
    final avgFocusScore = focusScores.isNotEmpty 
        ? focusScores.reduce((a, b) => a + b) / focusScores.length 
        : 0.0;
    
    // Completion rate for current session
    final completedCycles = cycles.where((c) => c.actualDuration >= c.plannedDuration).length;
    final completionRate = cycles.isNotEmpty ? (completedCycles / cycles.length) * 100 : 0.0;
    
    // Get historical performance data for this module
    final historicalData = await aggregateModulePerformance(session.userId, session.moduleId);
    
    // Track number of Pomodoro cycles completed per module (current + historical)
    final totalCyclesInModule = historicalData['total_cycles_completed'] as int;
    final totalSessionsInModule = historicalData['total_sessions'] as int;
    final avgCyclesPerSession = totalSessionsInModule > 0 ? totalCyclesInModule / totalSessionsInModule : 0.0;
    
    // Calculate improvement based on focus score progression within session
    final earlyFocusScores = focusScores.take(focusScores.length ~/ 2).toList();
    final lateFocusScores = focusScores.skip(focusScores.length ~/ 2).toList();
    
    final earlyAvg = earlyFocusScores.isNotEmpty ? earlyFocusScores.reduce((a, b) => a + b) / earlyFocusScores.length : avgFocusScore;
    final lateAvg = lateFocusScores.isNotEmpty ? lateFocusScores.reduce((a, b) => a + b) / lateFocusScores.length : avgFocusScore;
    final sessionImprovement = lateAvg - earlyAvg;
    
    // Compare current session performance to historical average
    final historicalAvgFocus = historicalData['average_focus_score'] as double;
    final historicalCompletionRate = historicalData['completion_rate'] as double;
    final focusImprovement = avgFocusScore * 10 - historicalAvgFocus;
    final completionImprovement = completionRate - historicalCompletionRate;
    
    // Productivity score (based on completion rate and focus scores)
    final productivityScore = ((completionRate + avgFocusScore * 10) / 2);
    
    // Record time spent and productivity per session
    final sessionTimeMinutes = session.totalDuration.inMinutes;
    final productivityPerMinute = sessionTimeMinutes > 0 ? productivityScore / sessionTimeMinutes : 0.0;
    
    // Calculate overall improvement (session + historical context)
    final overallImprovement = (sessionImprovement * 10 + focusImprovement + completionImprovement) / 3;
    
    print('📊 [ENHANCED POMODORO ANALYTICS] Current session: ${cycles.length} cycles, ${sessionTimeMinutes}min');
    print('📊 [ENHANCED POMODORO ANALYTICS] Module totals: ${totalCyclesInModule} cycles across ${totalSessionsInModule} sessions');
    print('📊 [ENHANCED POMODORO ANALYTICS] Focus improvement vs history: ${focusImprovement.toStringAsFixed(1)}%');
    
    return PerformanceMetrics(
      preStudyAccuracy: earlyAvg * 10, // Convert to percentage scale
      postStudyAccuracy: lateAvg * 10,
      improvementPercentage: overallImprovement,
      averageResponseTime: session.totalDuration.inMinutes / max(1, cycles.length).toDouble(),
      accuracyByDifficulty: productivityScore,
      materialPerformance: {
        'Current Focus Score': avgFocusScore * 10,
        'Current Completion Rate': completionRate,
        'Historical Avg Focus': historicalAvgFocus,
        'Historical Completion Rate': historicalCompletionRate,
        'Cycles This Module': totalCyclesInModule.toDouble(),
        'Sessions This Module': totalSessionsInModule.toDouble(),
        'Avg Cycles Per Session': avgCyclesPerSession,
        'Productivity Per Minute': productivityPerMinute,
        'Focus vs History': focusImprovement,
        'Completion vs History': completionImprovement,
      },
      conceptMastery: _analyzePomodoroConceptMastery(notes),
      overallLevel: AnalyticsCalculator.determinePerformanceLevel(productivityScore),
    );
  }

  /// Analyze Pomodoro learning patterns
  LearningPatterns _analyzePomodoroLearningPatterns(
    PomodoroSession session,
    List<PomodoroCycle> cycles,
    List<PomodoroNote> notes,
  ) {
    // Focus progression pattern
    final focusScores = cycles
        .where((c) => c.focusScore != null)
        .map((c) => c.focusScore!.toDouble())
        .toList();
    
    // Determine pattern type based on focus progression
    LearningPatternType patternType = LearningPatternType.steadyProgression;
    if (focusScores.length >= 3) {
      final trend = _calculateTrend(focusScores);
      if (trend > 0.5) {
        patternType = LearningPatternType.acceleratedLearning;
      } else if (trend < -0.5) {
        patternType = LearningPatternType.fatiguePattern;
      } else {
        patternType = LearningPatternType.steadyProgression;
      }
    }
    
    // Learning velocity (focus improvement per cycle)
    final learningVelocity = focusScores.length > 1 
        ? (focusScores.last - focusScores.first) / focusScores.length 
        : 0.0;
    
    // Strong and weak concepts from notes
    final conceptAnalysis = _analyzePomodoroNotePatterns(notes);
    
    // Retention based on note types and timing
    final retentionRates = _calculatePomodoroRetentionRates(cycles, notes);
    
    // Temporal patterns
    final temporalPatterns = _analyzePomodoroTemporalPatterns(session, cycles);
    
    return LearningPatterns(
      patternType: patternType,
      learningVelocity: learningVelocity,
      strongConcepts: conceptAnalysis['strong']!,
      weakConcepts: conceptAnalysis['weak']!,
      retentionRates: retentionRates,
      temporalPatterns: temporalPatterns,
    );
  }

  /// Analyze Pomodoro study behavior patterns
  BehaviorAnalysis _analyzePomodoroBehavior(
    PomodoroSession session,
    List<PomodoroCycle> cycles,
    List<PomodoroNote> notes,
  ) {
    // Total study time
    final totalStudyTime = session.totalDuration;
    
    // Break adherence (how well breaks were taken)
    final breakCycles = cycles.where((c) => 
        c.cycleType == PomodoroCycleType.shortBreak || 
        c.cycleType == PomodoroCycleType.longBreak
    ).toList();
    
    final breakAdherence = breakCycles.isNotEmpty 
        ? breakCycles.where((c) => c.actualDuration >= c.plannedDuration * 0.8).length / breakCycles.length
        : 0.0;
    
    // Focus consistency (variance in focus scores)
    final focusScores = cycles
        .where((c) => c.focusScore != null)
        .map((c) => c.focusScore!.toDouble())
        .toList();
    
    // Focus consistency is calculated but not used in current implementation
    // final focusConsistency = focusScores.length > 1 
    //     ? 100 - min(100.0, _calculateStandardDeviation(focusScores) * 10)
    //     : 100.0;
    
    // Note-taking patterns
    final notePatterns = _analyzeNotePatterns(notes, cycles);
    
    // Error types (based on low focus scores and incomplete cycles)
    final errorTypes = <String>[];
    final lowFocusCycles = cycles.where((c) => c.focusScore != null && c.focusScore! <= 3).length;
    final incompleteCycles = cycles.where((c) => c.actualDuration < c.plannedDuration * 0.8).length;
    
    if (lowFocusCycles > cycles.length * 0.3) {
      errorTypes.add('Frequent focus challenges');
    }
    if (incompleteCycles > cycles.length * 0.2) {
      errorTypes.add('Difficulty completing cycles');
    }
    if (breakAdherence < 0.5) {
      errorTypes.add('Inadequate break management');
    }
    
    // Persistence based on cycle completion despite difficulties
    final persistenceScore = cycles.isNotEmpty 
        ? (cycles.where((c) => c.isCompleted).length / cycles.length) * 100
        : 0.0;
    
    // Engagement level based on note-taking and focus scores
    final avgFocus = focusScores.isNotEmpty ? focusScores.reduce((a, b) => a + b) / focusScores.length : 5.0;
    final noteEngagement = notes.isNotEmpty ? min(100.0, notes.length * 10) : 0.0;
    final engagementLevel = ((avgFocus * 10 + noteEngagement) / 2);
    
    return BehaviorAnalysis(
      totalStudyTime: totalStudyTime,
      hintUsageCount: notes.where((n) => n.noteType == PomodoroNoteType.reflection).length,
      hintEffectiveness: breakAdherence,
      commonErrorTypes: errorTypes.isEmpty ? ['No significant behavioral issues'] : errorTypes,
      questionAttemptPatterns: notePatterns,
      persistenceScore: persistenceScore,
      engagementLevel: engagementLevel,
    );
  }

  /// Analyze Pomodoro cognitive patterns
  CognitiveAnalysis _analyzePomodoroCognition(
    PomodoroSession session,
    List<PomodoroCycle> cycles,
    List<PomodoroNote> notes,
  ) {
    // Cognitive load based on focus score variance and cycle completion
    final focusScores = cycles
        .where((c) => c.focusScore != null)
        .map((c) => c.focusScore!.toDouble())
        .toList();
    
    final cognitiveLoadScore = focusScores.length > 1 
        ? min(100.0, _calculateVariance(focusScores) * 20)
        : 50.0;
    
    // Processing speed based on cycle efficiency
    final workCycles = cycles.where((c) => c.cycleType == PomodoroCycleType.work).toList();
    final avgEfficiency = workCycles.isNotEmpty 
        ? workCycles.map((c) => c.actualDuration.inMilliseconds.toDouble() / c.plannedDuration.inMilliseconds.toDouble()).reduce((a, b) => a + b) / workCycles.length
        : 1.0;
    final processingSpeed = (avgEfficiency * 100).clamp(0.0, 150.0);
    
    // Memory retention by note type
    final memoryRetentionByType = <String, double>{};
    for (final noteType in PomodoroNoteType.values) {
      final typeNotes = notes.where((n) => n.noteType == noteType).toList();
      if (typeNotes.isNotEmpty) {
        // Calculate retention based on note frequency and timing distribution
        final retention = min(100.0, (typeNotes.length * 20).toDouble());
        memoryRetentionByType[noteType.name] = retention;
      }
    }
    
    // Cognitive profile analysis
    final cognitiveProfile = _analyzePomodoroCognitiveProfile(session, cycles, notes, focusScores);
    
    // Attention span based on focus score decline over time
    final attentionSpan = _calculatePomodoroAttentionSpan(cycles, focusScores);
    
    return CognitiveAnalysis(
      cognitiveLoadScore: cognitiveLoadScore,
      memoryRetentionByType: memoryRetentionByType,
      processingSpeed: processingSpeed,
      cognitiveStrengths: cognitiveProfile['strengths']!,
      cognitiveWeaknesses: cognitiveProfile['weaknesses']!,
      attentionSpan: attentionSpan,
    );
  }

  /// Generate AI-powered insights for Pomodoro sessions with historical context
  Future<Map<String, dynamic>> _generatePomodoroAIInsights(
    PerformanceMetrics performance,
    LearningPatterns patterns,
    BehaviorAnalysis behavior,
    CognitiveAnalysis cognitive,
    Course course,
    Module module,
    PomodoroSession session,
    List<PomodoroCycle> cycles,
    List<PomodoroNote> notes,
  ) async {
    try {
      print('🤖 [POMODORO AI INSIGHTS] Generating AI-powered recommendations with historical context...');
      
      // Get historical context for enhanced AI prompts
      final historicalData = await aggregateModulePerformance(session.userId, session.moduleId);
      final focusTrends = await getFocusScoreTrends(session.userId, session.moduleId);
      
      // Create comprehensive data summary for AI with historical context
      final analyticsData = {
        'technique': 'pomodoro',
        'course': course.title,
        'module': module.title,
        'session_data': {
          'total_cycles': cycles.length,
          'completed_cycles': cycles.where((c) => c.isCompleted).length,
          'total_duration_minutes': session.totalDuration.inMinutes,
          'work_cycles': cycles.where((c) => c.cycleType == PomodoroCycleType.work).length,
          'break_cycles': cycles.where((c) => c.cycleType != PomodoroCycleType.work).length,
          'notes_taken': notes.length,
        },
        'focus_analysis': {
          'average_focus_score': cycles.where((c) => c.focusScore != null).isNotEmpty 
              ? cycles.where((c) => c.focusScore != null).map((c) => c.focusScore!).reduce((a, b) => a + b) / cycles.where((c) => c.focusScore != null).length
              : 0.0,
          'focus_progression': patterns.learningVelocity,
          'pattern_type': patterns.patternType.name,
        },
        'performance': {
          'productivity_score': performance.accuracyByDifficulty,
          'completion_rate': performance.materialPerformance['Completion Rate'] ?? 0.0,
          'improvement': performance.improvementPercentage,
        },
        'behavior': {
          'persistence_score': behavior.persistenceScore,
          'engagement_level': behavior.engagementLevel,
          'break_adherence': behavior.hintEffectiveness,
          'common_challenges': behavior.commonErrorTypes,
        },
        'cognitive': {
          'cognitive_load': cognitive.cognitiveLoadScore,
          'processing_efficiency': cognitive.processingSpeed,
          'attention_span': cognitive.attentionSpan,
          'strengths': cognitive.cognitiveStrengths,
          'weaknesses': cognitive.cognitiveWeaknesses,
        },
        'notes_analysis': {
          'study_notes': notes.where((n) => n.noteType == PomodoroNoteType.studyNote).length,
          'reflections': notes.where((n) => n.noteType == PomodoroNoteType.reflection).length,
          // Note: quiz_answers removed - not applicable to Pomodoro technique
        },
        'historical_context': {
          'total_module_sessions': historicalData['total_sessions'],
          'total_module_cycles': historicalData['total_cycles_completed'],
          'historical_avg_focus': historicalData['average_focus_score'],
          'historical_completion_rate': historicalData['completion_rate'],
          'optimal_cycle_length': historicalData['optimal_cycle_length'],
          'focus_trend': historicalData['focus_trend'],
          'best_time_of_day': historicalData['best_time_of_day'],
          'focus_score_trends': focusTrends.length > 5 ? focusTrends.sublist(focusTrends.length - 5) : focusTrends,
          'avg_cycles_per_session': historicalData['total_sessions'] > 0 
              ? historicalData['total_cycles_completed'] / historicalData['total_sessions'] 
              : 0.0,
        },
      };
      
      // Generate AI insights using the enhanced Gemini service
      final aiResults = await _aiService.generatePomodoroAnalyticsInsights(analyticsData);
      
      return aiResults;
      
    } catch (e) {
      print('❌ [POMODORO AI INSIGHTS] Error generating AI insights: $e');
      
      // Return fallback insights
      return _generateFallbackPomodoroInsights(performance, patterns, behavior, cognitive, session, cycles, notes);
    }
  }

  // Helper methods for Pomodoro analytics

  Map<String, double> _analyzePomodoroConceptMastery(List<PomodoroNote> notes) {
    final conceptMastery = <String, double>{};
    
    // Analyze note types as concept indicators
    for (final noteType in PomodoroNoteType.values) {
      final typeNotes = notes.where((n) => n.noteType == noteType).toList();
      if (typeNotes.isNotEmpty) {
        // Higher note count indicates better engagement with concept
        final mastery = min(100.0, (typeNotes.length * 15).toDouble());
        conceptMastery[noteType.displayName] = mastery;
      }
    }
    
    return conceptMastery;
  }

  double _calculateTrend(List<double> values) {
    if (values.length < 2) return 0.0;
    
    // Simple linear trend calculation
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    
    for (int i = 0; i < values.length; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumXX += i * i;
    }
    
    final n = values.length;
    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    
    return slope;
  }

  Map<String, List<String>> _analyzePomodoroNotePatterns(List<PomodoroNote> notes) {
    // Identify strong areas (many notes) and weak areas (few notes)
    final notesByType = <PomodoroNoteType, List<PomodoroNote>>{};
    
    for (final note in notes) {
      notesByType[note.noteType] ??= [];
      notesByType[note.noteType]!.add(note);
    }
    
    final strong = <String>[];
    final weak = <String>[];
    
    for (final type in PomodoroNoteType.values) {
      final count = notesByType[type]?.length ?? 0;
      if (count >= 3) {
        strong.add(type.displayName);
      } else if (count == 0) {
        weak.add(type.displayName);
      }
    }
    
    return {'strong': strong, 'weak': weak};
  }

  Map<String, double> _calculatePomodoroRetentionRates(List<PomodoroCycle> cycles, List<PomodoroNote> notes) {
    final retentionRates = <String, double>{};
    
    // Calculate retention based on consistent focus scores
    final workCycles = cycles.where((c) => c.cycleType == PomodoroCycleType.work).toList();
    if (workCycles.isNotEmpty) {
      final focusScores = workCycles
          .where((c) => c.focusScore != null)
          .map((c) => c.focusScore!.toDouble())
          .toList();
      
      if (focusScores.isNotEmpty) {
        final avgFocus = focusScores.reduce((a, b) => a + b) / focusScores.length;
        retentionRates['Focus Consistency'] = avgFocus * 10;
      }
    }
    
    // Note-based retention
    final noteTypes = notes.map((n) => n.noteType).toSet();
    for (final type in noteTypes) {
      final typeNotes = notes.where((n) => n.noteType == type).length;
      retentionRates[type.displayName] = min(100.0, typeNotes * 20);
    }
    
    return retentionRates;
  }

  List<TimeBasedPattern> _analyzePomodoroTemporalPatterns(PomodoroSession session, List<PomodoroCycle> cycles) {
    final patterns = <TimeBasedPattern>[];
    
    // Analyze productivity by time periods
    if (cycles.isNotEmpty) {
      final earlyPerformance = cycles.take(cycles.length ~/ 2).toList();
      final latePerformance = cycles.skip(cycles.length ~/ 2).toList();
      
      final earlyFocus = _calculateAverageFocus(earlyPerformance);
      final lateFocus = _calculateAverageFocus(latePerformance);
      
      patterns.add(TimeBasedPattern(
        timeframe: 'early_session',
        performanceScore: earlyFocus * 10,
        pattern: earlyFocus > 6 ? 'high_early_focus' : 'low_early_focus',
        observations: ['Early session focus level: ${earlyFocus.toStringAsFixed(1)}/10'],
      ));
      
      patterns.add(TimeBasedPattern(
        timeframe: 'late_session',
        performanceScore: lateFocus * 10,
        pattern: lateFocus > earlyFocus ? 'improving_focus' : 'declining_focus',
        observations: ['Late session focus level: ${lateFocus.toStringAsFixed(1)}/10'],
      ));
    }
    
    return patterns;
  }

  Map<String, int> _analyzeNotePatterns(List<PomodoroNote> notes, List<PomodoroCycle> cycles) {
    return {
      'total_notes': notes.length,
      'study_notes': notes.where((n) => n.noteType == PomodoroNoteType.studyNote).length,
      'reflections': notes.where((n) => n.noteType == PomodoroNoteType.reflection).length,
      // Note: quiz_answers removed - not applicable to Pomodoro technique
      'notes_per_cycle': cycles.isNotEmpty ? (notes.length / cycles.length).round() : 0,
    };
  }

  Map<String, List<String>> _analyzePomodoroCognitiveProfile(
    PomodoroSession session,
    List<PomodoroCycle> cycles,
    List<PomodoroNote> notes,
    List<double> focusScores,
  ) {
    final strengths = <String>[];
    final weaknesses = <String>[];
    
    // Analyze focus consistency
    if (focusScores.isNotEmpty) {
      final avgFocus = focusScores.reduce((a, b) => a + b) / focusScores.length;
      final focusVariance = _calculateVariance(focusScores);
      
      if (avgFocus >= 7) {
        strengths.add('High average focus');
      } else if (avgFocus < 4) {
        weaknesses.add('Low average focus');
      }
      
      if (focusVariance < 2) {
        strengths.add('Consistent focus levels');
      } else if (focusVariance > 4) {
        weaknesses.add('Inconsistent focus levels');
      }
    }
    
    // Analyze cycle completion
    final completionRate = cycles.isNotEmpty 
        ? cycles.where((c) => c.isCompleted).length / cycles.length
        : 0.0;
    
    if (completionRate > 0.8) {
      strengths.add('Excellent cycle completion');
    } else if (completionRate < 0.5) {
      weaknesses.add('Difficulty completing cycles');
    }
    
    // Analyze note-taking engagement
    if (notes.length > cycles.length) {
      strengths.add('Active note-taking');
    } else if (notes.isEmpty && cycles.isNotEmpty) {
      weaknesses.add('Limited note-taking');
    }
    
    return {
      'strengths': strengths.isEmpty ? ['Completed study session'] : strengths,
      'weaknesses': weaknesses.isEmpty ? ['No significant weaknesses identified'] : weaknesses,
    };
  }

  double _calculatePomodoroAttentionSpan(List<PomodoroCycle> cycles, List<double> focusScores) {
    if (focusScores.length < 3) return 100.0;
    
    // Check if focus declines over time
    final firstThird = focusScores.take(focusScores.length ~/ 3).toList();
    final lastThird = focusScores.skip((focusScores.length * 2) ~/ 3).toList();
    
    final earlyAvg = firstThird.reduce((a, b) => a + b) / firstThird.length;
    final lateAvg = lastThird.reduce((a, b) => a + b) / lastThird.length;
    
    // Good attention span if focus is maintained or improved
    final attentionScore = lateAvg >= earlyAvg ? 100.0 : ((lateAvg / earlyAvg) * 100);
    
    return attentionScore.clamp(0.0, 100.0);
  }

  double _calculateAverageFocus(List<PomodoroCycle> cycles) {
    final focusScores = cycles
        .where((c) => c.focusScore != null)
        .map((c) => c.focusScore!)
        .toList();
    
    return focusScores.isNotEmpty 
        ? focusScores.reduce((a, b) => a + b) / focusScores.length
        : 5.0;
  }

  /// Generate fallback insights for Pomodoro when AI generation fails
  Future<Map<String, dynamic>> _generateFallbackPomodoroInsights(
    PerformanceMetrics performance,
    LearningPatterns patterns,
    BehaviorAnalysis behavior,
    CognitiveAnalysis cognitive,
    PomodoroSession session,
    List<PomodoroCycle> cycles,
    List<PomodoroNote> notes,
  ) async {
    final avgFocus = performance.materialPerformance['Current Focus Score'] ?? 50.0;
    final completionRate = performance.materialPerformance['Current Completion Rate'] ?? 0.0;
    final optimalCycleLength = performance.materialPerformance['Cycles This Module'] != null 
        ? await _getOptimalCycleLengthRecommendation(session.userId, session.moduleId, avgFocus, completionRate)
        : 25; // Default Pomodoro length
    final currentCycleLength = cycles.isNotEmpty ? cycles.first.plannedDuration.inMinutes : 25;
    
    final recommendations = <PersonalizedRecommendation>[
      PersonalizedRecommendation(
        id: 'pomodoro_fallback_rec_1',
        type: RecommendationType.studyTiming,
        title: 'Optimize Pomodoro Cycle Length',
        description: 'Based on your session performance and historical data, adjust your Pomodoro cycle length for optimal focus.',
        actionableAdvice: _getCycleLengthAdvice(currentCycleLength, optimalCycleLength, avgFocus, completionRate),
        priority: 1,
        confidenceScore: 0.8,
        reasons: ['Focus score analysis', 'Completion rate patterns', 'Historical performance data'],
      ),
      PersonalizedRecommendation(
        id: 'pomodoro_fallback_rec_2',
        type: RecommendationType.studyMethods,
        title: 'Enhance Note-Taking',
        description: 'Improve learning retention through structured note-taking.',
        actionableAdvice: notes.isEmpty 
            ? 'Take at least one note per work cycle to enhance retention.'
            : notes.length < cycles.length 
                ? 'Increase note-taking frequency for better learning outcomes.'
                : 'Excellent note-taking! Consider organizing notes by topic.',
        priority: 2,
        confidenceScore: 0.7,
        reasons: ['Note-taking analysis', 'Learning effectiveness'],
      ),
    ];
    
    final insights = <AnalyticsInsight>[
      AnalyticsInsight(
        id: 'pomodoro_fallback_insight_1',
        category: InsightCategory.performance,
        title: 'Focus Performance',
        insight: 'Your average focus score was ${avgFocus.toStringAsFixed(1)}/10 across ${cycles.length} cycles.',
        significance: 0.9,
        supportingData: [
          'Completed cycles: ${cycles.where((c) => c.isCompleted).length}/${cycles.length}',
          'Notes taken: ${notes.length}',
          'Total study time: ${session.totalDuration.inMinutes} minutes'
        ],
      ),
      AnalyticsInsight(
        id: 'pomodoro_fallback_insight_2',
        category: InsightCategory.behavior,
        title: 'Study Behavior Patterns',
        insight: 'You maintained a ${behavior.engagementLevel.toStringAsFixed(1)}% engagement level throughout the session.',
        significance: 0.7,
        supportingData: [
          'Persistence score: ${behavior.persistenceScore.toStringAsFixed(1)}%',
          'Break adherence: ${(behavior.hintEffectiveness * 100).toStringAsFixed(1)}%'
        ],
      ),
    ];
    
    final studyPlan = StudyPlan(
      id: 'pomodoro_fallback_plan',
      activities: [
        StudyActivity(
          type: 'focused_review',
          description: avgFocus < 50 
              ? 'Practice focus-building exercises before next session'
              : 'Continue with current focus strategies',
          duration: const Duration(minutes: 25),
          priority: 1,
          materials: patterns.weakConcepts.isEmpty ? ['Review session notes'] : patterns.weakConcepts,
        ),
        if (notes.isEmpty || notes.length < cycles.length)
          StudyActivity(
            type: 'note_taking',
            description: 'Implement structured note-taking during work cycles',
            duration: const Duration(minutes: 5),
            priority: 2,
            materials: ['Note-taking templates', 'Review prompts'],
          ),
      ],
      estimatedDuration: Duration(minutes: notes.isEmpty ? 30 : 25),
      focusAreas: {
        'focus_improvement': avgFocus < 50 ? 'Priority' : 'Maintain',
        'note_taking': notes.length < cycles.length ? 'Increase' : 'Continue',
        'cycle_completion': completionRate < 80 ? 'Improve' : 'Maintain',
      },
      objectives: [
        if (avgFocus < 50) 'Improve focus consistency',
        if (completionRate < 80) 'Increase cycle completion rate',
        if (notes.isEmpty) 'Begin regular note-taking practice',
        'Maintain productive study habits',
      ],
    );
    
    return {
      'recommendations': recommendations,
      'insights': insights,
      'studyPlan': studyPlan,
    };
  }

  /// Get optimal cycle length recommendation based on historical data and current performance
  Future<int> _getOptimalCycleLengthRecommendation(String userId, String moduleId, double avgFocus, double completionRate) async {
    try {
      final historicalData = await aggregateModulePerformance(userId, moduleId);
      final optimalLength = historicalData['optimal_cycle_length'] as int;
      
      // Adjust based on current performance
      if (avgFocus < 40 || completionRate < 60) {
        // Low performance - recommend shorter cycles
        return (optimalLength * 0.75).round().clamp(15, 25);
      } else if (avgFocus > 70 && completionRate > 85) {
        // High performance - could handle longer cycles
        return (optimalLength * 1.2).round().clamp(25, 45);
      }
      
      return optimalLength;
    } catch (e) {
      print('⚠️ [CYCLE OPTIMIZATION] Error getting optimal length: $e');
      return 25; // Default
    }
  }
  
  /// Generate cycle length advice based on performance data
  String _getCycleLengthAdvice(int currentLength, int optimalLength, double avgFocus, double completionRate) {
    if (currentLength == optimalLength) {
      if (avgFocus > 70 && completionRate > 85) {
        return 'Your current ${currentLength}-minute cycles are optimal! Consider extending to ${optimalLength + 5} minutes if you want to challenge yourself further.';
      } else {
        return 'Your ${currentLength}-minute cycles are well-suited for your current performance level. Focus on consistency and minimizing distractions.';
      }
    } else if (currentLength > optimalLength) {
      return 'Consider shortening your cycles from ${currentLength} to ${optimalLength} minutes. Based on your focus patterns, shorter cycles may improve completion rates and maintain better attention.';
    } else {
      return 'You could benefit from extending your cycles from ${currentLength} to ${optimalLength} minutes. Your focus scores suggest you can maintain attention for longer periods.';
    }
  }

  /// Generate fallback Pomodoro analytics when full analysis fails
  Future<StudySessionAnalytics> _generateFallbackPomodoroAnalytics(
    String sessionId,
    String userId,
    String moduleId,
    PomodoroSession session,
    List<PomodoroCycle> cycles,
    List<PomodoroNote> notes,
  ) async {
    // Basic calculations
    final focusScores = cycles
        .where((c) => c.focusScore != null)
        .map((c) => c.focusScore!)
        .toList();
    
    final avgFocusScore = focusScores.isNotEmpty 
        ? focusScores.reduce((a, b) => a + b) / focusScores.length 
        : 5.0;
    
    final completionRate = cycles.isNotEmpty 
        ? (cycles.where((c) => c.isCompleted).length / cycles.length) * 100
        : 0.0;
    
    // Try to get basic historical context even in fallback
    final historicalData = await aggregateModulePerformance(userId, moduleId);
    final totalModuleCycles = historicalData['total_cycles_completed'] as int;
    
    final basicPerformance = PerformanceMetrics(
      preStudyAccuracy: avgFocusScore * 10,
      postStudyAccuracy: avgFocusScore * 10,
      improvementPercentage: 0.0,
      averageResponseTime: session.totalDuration.inMinutes / max(1, cycles.length).toDouble(),
      accuracyByDifficulty: (avgFocusScore * 10 + completionRate) / 2,
      materialPerformance: {
        'Focus Score': avgFocusScore * 10, 
        'Completion Rate': completionRate,
        'Total Module Cycles': totalModuleCycles.toDouble(),
      },
      conceptMastery: {},
      overallLevel: AnalyticsCalculator.determinePerformanceLevel(avgFocusScore * 10),
    );
    
    return StudySessionAnalytics(
      id: '', // Database will generate UUID
      sessionId: sessionId,
      userId: userId,
      moduleId: moduleId,
      analyzedAt: DateTime.now(),
      performanceMetrics: basicPerformance,
      learningPatterns: LearningPatterns(
        patternType: LearningPatternType.steadyProgression,
        learningVelocity: 0.0,
        strongConcepts: [],
        weakConcepts: [],
        retentionRates: {},
        temporalPatterns: [],
      ),
      behaviorAnalysis: BehaviorAnalysis(
        totalStudyTime: session.totalDuration,
        hintUsageCount: notes.where((n) => n.noteType == PomodoroNoteType.reflection).length,
        hintEffectiveness: 0.75,
        commonErrorTypes: [],
        questionAttemptPatterns: {},
        persistenceScore: completionRate,
        engagementLevel: avgFocusScore * 10,
      ),
      cognitiveAnalysis: CognitiveAnalysis(
        cognitiveLoadScore: 50.0,
        memoryRetentionByType: {},
        processingSpeed: completionRate,
        cognitiveStrengths: [],
        cognitiveWeaknesses: [],
        attentionSpan: avgFocusScore * 10,
      ),
      recommendations: [],
      insights: [],
      suggestedStudyPlan: StudyPlan(
        id: 'pomodoro_fallback_plan',
        activities: [],
        estimatedDuration: const Duration(minutes: 25),
        focusAreas: {},
        objectives: [],
      ),
    );
  }

  /// Generate fallback analytics when full analysis fails
  StudySessionAnalytics _generateFallbackAnalytics(
    String sessionId,
    String userId,
    String moduleId,
    List<ActiveRecallFlashcard> flashcards,
    List<ActiveRecallAttempt> attempts,
  ) {
    // Basic calculations
    final preStudyAttempts = attempts.where((a) => a.isPreStudy).toList();
    final postStudyAttempts = attempts.where((a) => !a.isPreStudy).toList();
    
    final preAccuracy = preStudyAttempts.isNotEmpty ? (preStudyAttempts.where((a) => a.isCorrect).length / preStudyAttempts.length) * 100 : 0.0;
    final postAccuracy = postStudyAttempts.isNotEmpty ? (postStudyAttempts.where((a) => a.isCorrect).length / postStudyAttempts.length) * 100 : 0.0;
    final improvementPercentage = postAccuracy - preAccuracy;
    final averageResponseTime = attempts.isNotEmpty ? attempts.map((a) => a.responseTimeSeconds).reduce((a, b) => a + b) / attempts.length : 0.0;
    
    final basicPerformance = PerformanceMetrics(
      preStudyAccuracy: preAccuracy,
      postStudyAccuracy: postAccuracy,
      improvementPercentage: improvementPercentage,
      averageResponseTime: averageResponseTime,
      accuracyByDifficulty: 0.0,
      materialPerformance: {},
      conceptMastery: {},
      overallLevel: AnalyticsCalculator.determinePerformanceLevel(postAccuracy),
    );
    
    return StudySessionAnalytics(
      id: '', // Database will generate UUID
      sessionId: sessionId,
      userId: userId,
      moduleId: moduleId,
      analyzedAt: DateTime.now(),
      performanceMetrics: basicPerformance,
      learningPatterns: LearningPatterns(
        patternType: LearningPatternType.steadyProgression,
        learningVelocity: 0.0,
        strongConcepts: [],
        weakConcepts: [],
        retentionRates: {},
        temporalPatterns: [],
      ),
      behaviorAnalysis: BehaviorAnalysis(
        totalStudyTime: Duration(seconds: attempts.fold<int>(0, (sum, a) => sum + a.responseTimeSeconds)),
        hintUsageCount: 0,
        hintEffectiveness: 0.0,
        commonErrorTypes: [],
        questionAttemptPatterns: {},
        persistenceScore: 75.0,
        engagementLevel: 75.0,
      ),
      cognitiveAnalysis: CognitiveAnalysis(
        cognitiveLoadScore: 50.0,
        memoryRetentionByType: {},
        processingSpeed: 50.0,
        cognitiveStrengths: [],
        cognitiveWeaknesses: [],
        attentionSpan: 75.0,
      ),
      recommendations: [],
      insights: [],
      suggestedStudyPlan: StudyPlan(
        id: 'fallback_plan',
        activities: [],
        estimatedDuration: const Duration(minutes: 30),
        focusAreas: {},
        objectives: [],
      ),
    );
  }

  // FEYNMAN TECHNIQUE ANALYTICS METHODS

  /// Get historical Feynman sessions for a user and module
  Future<List<FeynmanSession>> getHistoricalFeynmanSessions(String userId, String moduleId) async {
    try {
      print('📊 [FEYNMAN HISTORICAL] Fetching Feynman sessions for user: $userId, module: $moduleId');
      
      final response = await SupabaseService.client
          .from('feynman_sessions')
          .select('''
            *,
            feynman_explanations(*),
            feynman_study_suggestions(*)
          ''')
          .eq('user_id', userId)
          .eq('module_id', moduleId)
          .eq('status', 'completed')
          .order('started_at', ascending: false)
          .limit(15); // Last 15 sessions for analysis
      
      final sessions = response.map((sessionData) {
        return FeynmanSession.fromJson(sessionData);
      }).toList();
      
      print('✅ [FEYNMAN HISTORICAL] Found ${sessions.length} historical Feynman sessions');
      return sessions;
      
    } catch (e) {
      print('❌ [FEYNMAN HISTORICAL] Error fetching historical sessions: $e');
      return [];
    }
  }

  /// Aggregate Feynman performance data across multiple sessions
  Future<Map<String, dynamic>> aggregateFeynmanModulePerformance(String userId, String moduleId) async {
    try {
      final sessions = await getHistoricalFeynmanSessions(userId, moduleId);
      
      if (sessions.isEmpty) {
        return _getEmptyFeynmanPerformanceData();
      }
      
      // Get all explanations for detailed analysis
      final allExplanations = <FeynmanExplanation>[];
      for (final session in sessions) {
        final explanationsResponse = await SupabaseService.client
            .from('feynman_explanations')
            .select('*')
            .eq('session_id', session.id);
        
        final explanations = explanationsResponse.map((expData) => FeynmanExplanation.fromJson(expData)).toList();
        allExplanations.addAll(explanations);
      }
      
      // Calculate aggregated metrics
      final totalSessions = sessions.length;
      final totalExplanations = allExplanations.length;
      final totalStudyTime = sessions.fold(0, (sum, session) => 
        sum + (session.completedAt?.difference(session.startedAt).inMinutes ?? 0));
      
      // Calculate average explanation quality scores
      final scoredExplanations = allExplanations.where((e) => e.overallScore != null);
      final avgOverallScore = scoredExplanations.isNotEmpty 
          ? scoredExplanations.map((e) => e.overallScore!).reduce((a, b) => a + b) / scoredExplanations.length 
          : 0.0;
      
      final avgClarityScore = scoredExplanations.isNotEmpty 
          ? scoredExplanations.where((e) => e.clarityScore != null).map((e) => e.clarityScore!).fold(0.0, (a, b) => a + b) / scoredExplanations.where((e) => e.clarityScore != null).length
          : 0.0;
      
      final avgCompletenessScore = scoredExplanations.isNotEmpty 
          ? scoredExplanations.where((e) => e.completenessScore != null).map((e) => e.completenessScore!).fold(0.0, (a, b) => a + b) / scoredExplanations.where((e) => e.completenessScore != null).length
          : 0.0;
      
      // Calculate improvement trend
      String improvementTrend = 'stable';
      if (scoredExplanations.length >= 4) {
        final sessionScores = sessions.map((session) {
          final sessionExplanations = allExplanations.where((e) => e.sessionId == session.id);
          if (sessionExplanations.isNotEmpty) {
            final avgSessionScore = sessionExplanations.where((e) => e.overallScore != null)
                .map((e) => e.overallScore!)
                .fold(0.0, (a, b) => a + b) / sessionExplanations.where((e) => e.overallScore != null).length;
            return avgSessionScore;
          }
          return 0.0;
        }).where((score) => score > 0).toList();
        
        if (sessionScores.length >= 3) {
          final firstHalf = sessionScores.take(sessionScores.length ~/ 2).toList();
          final secondHalf = sessionScores.skip(sessionScores.length ~/ 2).toList();
          
          final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
          final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
          
          if (secondAvg > firstAvg + 0.5) improvementTrend = 'improving';
          else if (firstAvg > secondAvg + 0.5) improvementTrend = 'declining';
        }
      }
      
      // Calculate concept mastery patterns
      final strongConcepts = <String>{};
      final strugglingConcepts = <String>{};
      
      for (final explanation in allExplanations) {
        if (explanation.overallScore != null) {
          if (explanation.overallScore! >= 7.0) {
            strongConcepts.addAll(explanation.strengths);
          } else if (explanation.overallScore! < 5.0) {
            strugglingConcepts.addAll(explanation.identifiedGaps);
          }
        }
      }
      
      // Calculate average explanation length and complexity
      final avgWordCount = allExplanations.isNotEmpty 
          ? allExplanations.map((e) => e.wordCount).reduce((a, b) => a + b) / allExplanations.length 
          : 0.0;
      
      // Determine best performing topics (if multiple topics studied)
      final topicPerformance = <String, List<double>>{};
      for (final session in sessions) {
        final sessionExplanations = allExplanations.where((e) => e.sessionId == session.id && e.overallScore != null);
        if (sessionExplanations.isNotEmpty) {
          final avgScore = sessionExplanations.map((e) => e.overallScore!).reduce((a, b) => a + b) / sessionExplanations.length;
          if (!topicPerformance.containsKey(session.topic)) {
            topicPerformance[session.topic] = [];
          }
          topicPerformance[session.topic]!.add(avgScore);
        }
      }
      
      String bestTopic = 'General';
      double bestTopicScore = 0.0;
      topicPerformance.forEach((topic, scores) {
        final avgScore = scores.reduce((a, b) => a + b) / scores.length;
        if (avgScore > bestTopicScore) {
          bestTopicScore = avgScore;
          bestTopic = topic;
        }
      });
      
      print('📈 [FEYNMAN PERFORMANCE] Processed $totalSessions sessions, $totalExplanations explanations');
      
      return {
        'total_sessions': totalSessions,
        'total_explanations': totalExplanations,
        'total_study_minutes': totalStudyTime,
        'average_overall_score': avgOverallScore,
        'average_clarity_score': avgClarityScore,
        'average_completeness_score': avgCompletenessScore,
        'improvement_trend': improvementTrend,
        'strong_concepts': strongConcepts.toList(),
        'struggling_concepts': strugglingConcepts.toList(),
        'average_word_count': avgWordCount,
        'best_topic': bestTopic,
        'best_topic_score': bestTopicScore,
        'topic_performance': topicPerformance,
        'sessions_by_topic': sessions.fold<Map<String, int>>({}, (map, session) {
          map[session.topic] = (map[session.topic] ?? 0) + 1;
          return map;
        }),
      };
      
    } catch (e) {
      print('❌ [FEYNMAN PERFORMANCE] Error aggregating performance: $e');
      return _getEmptyFeynmanPerformanceData();
    }
  }

  /// Generate comprehensive analytics for a completed Feynman session
  Future<StudySessionAnalytics> generateFeynmanAnalytics({
    required String sessionId,
    required String userId,
    required String moduleId,
    required FeynmanSession session,
    required List<FeynmanExplanation> explanations,
    required List<FeynmanFeedback> feedback,
    required List<FeynmanStudySuggestion> suggestions,
    required Course course,
    required Module module,
  }) async {
    try {
      print('📊 [FEYNMAN ANALYTICS] Starting comprehensive analysis for session: $sessionId');
      
      // Calculate descriptive analytics with historical context
      final performanceMetrics = await _calculateFeynmanPerformanceMetrics(session, explanations, feedback);
      
      final learningPatterns = _analyzeFeynmanLearningPatterns(session, explanations, feedback);
      
      final behaviorAnalysis = _analyzeFeynmanBehavior(session, explanations, feedback);
      
      final cognitiveAnalysis = _analyzeFeynmanCognition(session, explanations, feedback);
      
      // Generate AI-powered insights and recommendations
      final aiResults = await _generateFeynmanAIInsights(
        performanceMetrics, learningPatterns, behaviorAnalysis, 
        cognitiveAnalysis, course, module, session, explanations, feedback, suggestions
      );
      
      // Create the analytics object
      final analytics = StudySessionAnalytics(
        id: '', // Will be generated by database
        sessionId: sessionId,
        userId: userId,
        moduleId: moduleId,
        analyzedAt: DateTime.now(),
        performanceMetrics: performanceMetrics,
        learningPatterns: learningPatterns,
        behaviorAnalysis: behaviorAnalysis,
        cognitiveAnalysis: cognitiveAnalysis,
        recommendations: aiResults['recommendations'] as List<PersonalizedRecommendation>,
        insights: aiResults['insights'] as List<AnalyticsInsight>,
        suggestedStudyPlan: aiResults['studyPlan'] as StudyPlan,
      );
      
      // Save to database
      await _saveAnalyticsToDatabase(analytics, sessionType: 'feynman');
      
      print('✅ [FEYNMAN ANALYTICS] Analytics generation completed successfully');
      return analytics;
      
    } catch (e) {
      print('❌ [FEYNMAN ANALYTICS] Error generating session analytics: $e');
      
      // Return basic analytics if full analysis fails
      return await _generateFallbackFeynmanAnalytics(sessionId, userId, moduleId, session, explanations, feedback);
    }
  }

  /// Calculate performance metrics from Feynman session data
  Future<PerformanceMetrics> _calculateFeynmanPerformanceMetrics(
    FeynmanSession session,
    List<FeynmanExplanation> explanations,
    List<FeynmanFeedback> feedback,
  ) async {
    // Explanation quality analysis
    final scoredExplanations = explanations.where((e) => e.overallScore != null);
    final avgOverallScore = scoredExplanations.isNotEmpty 
        ? scoredExplanations.map((e) => e.overallScore!).reduce((a, b) => a + b) / scoredExplanations.length 
        : 0.0;
    
    // Calculate improvement from first to last explanation
    double improvementPercentage = 0.0;
    if (explanations.length >= 2) {
      final firstScore = explanations.first.overallScore ?? 0.0;
      final lastScore = explanations.last.overallScore ?? 0.0;
      improvementPercentage = ((lastScore - firstScore) / max(firstScore, 1.0)) * 100;
    }
    
    // Get historical performance data for context
    final historicalData = await aggregateFeynmanModulePerformance(session.userId, session.moduleId);
    
    // Calculate concept mastery scores
    final conceptMastery = _calculateFeynmanConceptMastery(explanations, feedback);
    
    // Calculate difficulty performance (based on feedback severity)
    final difficultyPerformance = _calculateFeynmanDifficultyPerformance(feedback);
    
    // Material performance (explanation quality by attempt)
    final materialPerformance = <String, double>{};
    for (int i = 0; i < explanations.length; i++) {
      final explanation = explanations[i];
      if (explanation.overallScore != null) {
        materialPerformance['Attempt ${explanation.attemptNumber}'] = explanation.overallScore! * 10; // Scale to 100
      }
    }
    
    // Add historical context
    materialPerformance['Current Session Avg'] = avgOverallScore * 10;
    materialPerformance['Historical Avg'] = (historicalData['average_overall_score'] as double) * 10;
    materialPerformance['Total Sessions'] = (historicalData['total_sessions'] as int).toDouble();
    materialPerformance['Total Explanations'] = (historicalData['total_explanations'] as int).toDouble();
    
    // Average response time (time between explanations)
    double avgResponseTime = 0.0;
    if (explanations.length > 1) {
      final intervals = <int>[];
      for (int i = 1; i < explanations.length; i++) {
        final interval = explanations[i].createdAt.difference(explanations[i-1].createdAt).inMinutes;
        intervals.add(interval);
      }
      avgResponseTime = intervals.isNotEmpty ? intervals.reduce((a, b) => a + b) / intervals.length : 0.0;
    }
    
    print('📊 [FEYNMAN METRICS] Session: ${explanations.length} explanations, avg score: ${avgOverallScore.toStringAsFixed(1)}');
    
    return PerformanceMetrics(
      preStudyAccuracy: explanations.isNotEmpty ? (explanations.first.overallScore ?? 0.0) * 10 : 0.0,
      postStudyAccuracy: explanations.isNotEmpty ? (explanations.last.overallScore ?? 0.0) * 10 : 0.0,
      improvementPercentage: improvementPercentage,
      averageResponseTime: avgResponseTime,
      accuracyByDifficulty: difficultyPerformance,
      materialPerformance: materialPerformance,
      conceptMastery: conceptMastery,
      overallLevel: AnalyticsCalculator.determinePerformanceLevel(avgOverallScore * 10),
    );
  }

  /// Analyze Feynman learning patterns
  LearningPatterns _analyzeFeynmanLearningPatterns(
    FeynmanSession session,
    List<FeynmanExplanation> explanations,
    List<FeynmanFeedback> feedback,
  ) {
    // Determine pattern type based on score progression
    LearningPatternType patternType = LearningPatternType.steadyProgression;
    if (explanations.length >= 2) {
      final scores = explanations.where((e) => e.overallScore != null).map((e) => e.overallScore!).toList();
      if (scores.length >= 2) {
        final trend = _calculateTrend(scores);
        if (trend > 0.5) {
          patternType = LearningPatternType.acceleratedLearning;
        } else if (trend < -0.5) {
          patternType = LearningPatternType.strugglingConcepts;
        }
      }
    }
    
    // Learning velocity (improvement per explanation)
    final learningVelocity = explanations.length > 1 && explanations.first.overallScore != null && explanations.last.overallScore != null
        ? (explanations.last.overallScore! - explanations.first.overallScore!) / explanations.length 
        : 0.0;
    
    // Strong and weak concepts from explanations
    final conceptAnalysis = _analyzeFeynmanConceptPatterns(explanations);
    
    // Retention based on explanation consistency
    final retentionRates = _calculateFeynmanRetentionRates(explanations);
    
    // Temporal patterns
    final temporalPatterns = _analyzeFeynmanTemporalPatterns(session, explanations);
    
    return LearningPatterns(
      patternType: patternType,
      learningVelocity: learningVelocity,
      strongConcepts: conceptAnalysis['strong']!,
      weakConcepts: conceptAnalysis['weak']!,
      retentionRates: retentionRates,
      temporalPatterns: temporalPatterns,
    );
  }

  /// Analyze Feynman study behavior patterns
  BehaviorAnalysis _analyzeFeynmanBehavior(
    FeynmanSession session,
    List<FeynmanExplanation> explanations,
    List<FeynmanFeedback> feedback,
  ) {
    // Total study time
    final totalStudyTime = session.totalDuration;
    
    // Explanation effort (word count patterns)
    final avgWordCount = explanations.isNotEmpty 
        ? explanations.map((e) => e.wordCount).reduce((a, b) => a + b) / explanations.length 
        : 0;
    
    // Feedback engagement (how they respond to AI feedback)
    final criticalFeedbackCount = feedback.where((f) => f.severity == FeedbackSeverity.critical).length;
    final highPriorityFeedbackCount = feedback.where((f) => f.priority >= 4).length;
    
    // Common error types from feedback
    final errorTypes = _identifyFeynmanErrorTypes(feedback);
    
    // Question attempt patterns (explanation iterations)
    final attemptPatterns = {
      'total_explanations': explanations.length,
      'avg_word_count': avgWordCount.round(),
      'improvement_attempts': explanations.length > 1 ? explanations.length - 1 : 0,
      'critical_feedback': criticalFeedbackCount,
    };
    
    // Persistence score (continued explanations despite challenges)
    final persistenceScore = explanations.length > 1 && criticalFeedbackCount > 0 
        ? min(100.0, (explanations.length / max(criticalFeedbackCount, 1)) * 25) 
        : 75.0;
    
    // Engagement level (based on explanation quality and effort)
    final avgScore = explanations.where((e) => e.overallScore != null).isNotEmpty
        ? explanations.where((e) => e.overallScore != null).map((e) => e.overallScore!).reduce((a, b) => a + b) / explanations.where((e) => e.overallScore != null).length
        : 5.0;
    final effortScore = avgWordCount > 50 ? min(100.0, avgWordCount / 2) : avgWordCount * 2;
    final engagementLevel = ((avgScore * 10 + effortScore) / 2);
    
    return BehaviorAnalysis(
      totalStudyTime: totalStudyTime,
      hintUsageCount: highPriorityFeedbackCount, // High-priority feedback as "hints"
      hintEffectiveness: explanations.length > 1 ? 75.0 : 50.0, // Improvement attempts as effectiveness
      commonErrorTypes: errorTypes,
      questionAttemptPatterns: attemptPatterns,
      persistenceScore: persistenceScore,
      engagementLevel: engagementLevel,
    );
  }

  /// Analyze Feynman cognitive patterns
  CognitiveAnalysis _analyzeFeynmanCognition(
    FeynmanSession session,
    List<FeynmanExplanation> explanations,
    List<FeynmanFeedback> feedback,
  ) {
    // Cognitive load (complexity handling)
    final avgWordCount = explanations.isNotEmpty 
        ? explanations.map((e) => e.wordCount).reduce((a, b) => a + b) / explanations.length 
        : 0;
    final cognitiveLoadScore = min(100.0, max(0.0, 100 - (avgWordCount / 5))); // Higher word count = lower cognitive load
    
    // Memory retention by explanation type
    final memoryRetentionByType = <String, double>{};
    final textExplanations = explanations.where((e) => e.explanationType == ExplanationType.text);
    if (textExplanations.isNotEmpty) {
      final avgTextScore = textExplanations.where((e) => e.overallScore != null).isNotEmpty
          ? textExplanations.where((e) => e.overallScore != null).map((e) => e.overallScore!).reduce((a, b) => a + b) / textExplanations.where((e) => e.overallScore != null).length
          : 5.0;
      memoryRetentionByType['Text Explanations'] = avgTextScore * 10;
    }
    
    // Processing speed (explanation generation efficiency)
    final processingSpeed = avgWordCount > 0 ? min(150.0, avgWordCount / 2) : 50.0;
    
    // Cognitive profile analysis
    final cognitiveProfile = _analyzeFeynmanCognitiveProfile(explanations, feedback);
    
    // Attention span (consistency across explanations)
    final attentionSpan = _calculateFeynmanAttentionSpan(explanations);
    
    return CognitiveAnalysis(
      cognitiveLoadScore: cognitiveLoadScore,
      memoryRetentionByType: memoryRetentionByType,
      processingSpeed: processingSpeed,
      cognitiveStrengths: cognitiveProfile['strengths']!,
      cognitiveWeaknesses: cognitiveProfile['weaknesses']!,
      attentionSpan: attentionSpan,
    );
  }

  /// Generate AI-powered insights for Feynman sessions
  Future<Map<String, dynamic>> _generateFeynmanAIInsights(
    PerformanceMetrics performance,
    LearningPatterns patterns,
    BehaviorAnalysis behavior,
    CognitiveAnalysis cognitive,
    Course course,
    Module module,
    FeynmanSession session,
    List<FeynmanExplanation> explanations,
    List<FeynmanFeedback> feedback,
    List<FeynmanStudySuggestion> suggestions,
  ) async {
    try {
      print('🤖 [FEYNMAN AI INSIGHTS] Generating AI-powered recommendations...');
      
      // Get historical context for enhanced AI prompts
      final historicalData = await aggregateFeynmanModulePerformance(session.userId, session.moduleId);
      
      // Create comprehensive data summary for AI with null safety
      final analyticsData = {
        'technique': 'feynman',
        'course': course.title ?? 'Unknown Course',
        'module': module.title ?? 'Unknown Module',
        'session_data': {
          'topic': session.topic ?? 'Unknown Topic',
          'total_explanations': explanations.length,
          'session_duration_minutes': session.totalDuration.inMinutes,
          'explanation_types': explanations.map((e) => e.explanationType.value).toSet().toList(),
        },
        'explanation_analysis': {
          'average_overall_score': explanations.where((e) => e.overallScore != null).isNotEmpty
              ? explanations.where((e) => e.overallScore != null).map((e) => e.overallScore!).reduce((a, b) => a + b) / explanations.where((e) => e.overallScore != null).length
              : 0.0,
          'average_clarity_score': explanations.where((e) => e.clarityScore != null).isNotEmpty
              ? explanations.where((e) => e.clarityScore != null).map((e) => e.clarityScore!).reduce((a, b) => a + b) / explanations.where((e) => e.clarityScore != null).length
              : 0.0,
          'average_completeness_score': explanations.where((e) => e.completenessScore != null).isNotEmpty
              ? explanations.where((e) => e.completenessScore != null).map((e) => e.completenessScore!).reduce((a, b) => a + b) / explanations.where((e) => e.completenessScore != null).length
              : 0.0,
          'improvement_trend': patterns.learningVelocity,
          'average_word_count': explanations.isNotEmpty ? explanations.map((e) => e.wordCount).reduce((a, b) => a + b) / explanations.length : 0,
        },
        'performance': {
          'overall_improvement': performance.improvementPercentage,
          'pattern_type': patterns.patternType.name,
          'strong_concepts': patterns.strongConcepts,
          'weak_concepts': patterns.weakConcepts,
        },
        'behavior': {
          'persistence_score': behavior.persistenceScore,
          'engagement_level': behavior.engagementLevel,
          'total_study_minutes': behavior.totalStudyTime.inMinutes,
          'common_challenges': behavior.commonErrorTypes,
        },
        'cognitive': {
          'cognitive_load': cognitive.cognitiveLoadScore,
          'processing_speed': cognitive.processingSpeed,
          'attention_span': cognitive.attentionSpan,
          'strengths': cognitive.cognitiveStrengths,
          'weaknesses': cognitive.cognitiveWeaknesses,
        },
        'feedback_analysis': {
          'total_feedback': feedback.length,
          'critical_issues': feedback.where((f) => f.severity == FeedbackSeverity.critical).length,
          'high_priority_items': feedback.where((f) => f.priority >= 4).length,
          'feedback_categories': feedback.map((f) => f.feedbackType.value).toSet().toList(),
        },
        'historical_context': {
          'total_module_sessions': historicalData['total_sessions'],
          'total_module_explanations': historicalData['total_explanations'],
          'historical_avg_score': historicalData['average_overall_score'],
          'improvement_trend': historicalData['improvement_trend'],
          'strong_concepts_history': historicalData['strong_concepts'],
          'struggling_concepts_history': historicalData['struggling_concepts'],
          'best_topic': historicalData['best_topic'],
          'sessions_by_topic': historicalData['sessions_by_topic'],
        },
      };
      
      // Validate and clean analytics data before sending to AI
      final cleanedAnalyticsData = _validateAndCleanAnalyticsData(analyticsData);
      
      // Generate AI insights using the Gemini service
      final aiResults = await _aiService.generateFeynmanAnalyticsInsights(cleanedAnalyticsData);
      
      return aiResults;
      
    } catch (e) {
      print('❌ [FEYNMAN AI INSIGHTS] Error generating AI insights: $e');
      
      // Return fallback insights
      return _generateFallbackFeynmanInsights(performance, patterns, behavior, cognitive, session, explanations, feedback);
    }
  }

  /// Validate and clean analytics data to prevent null value errors
  Map<String, dynamic> _validateAndCleanAnalyticsData(Map<String, dynamic> data) {
    // Recursively clean the data structure
    return _cleanMapData(data);
  }
  
  dynamic _cleanMapData(dynamic value) {
    if (value == null) {
      return 'Unknown';
    }
    
    if (value is Map<String, dynamic>) {
      final cleaned = <String, dynamic>{};
      for (final entry in value.entries) {
        cleaned[entry.key] = _cleanMapData(entry.value);
      }
      return cleaned;
    }
    
    if (value is List) {
      return value.map((item) => _cleanMapData(item)).toList();
    }
    
    if (value is String && value.isEmpty) {
      return 'Not specified';
    }
    
    return value;
  }

  // Helper methods for Feynman analytics

  Map<String, dynamic> _getEmptyFeynmanPerformanceData() {
    return {
      'total_sessions': 0,
      'total_explanations': 0,
      'total_study_minutes': 0,
      'average_overall_score': 0.0,
      'average_clarity_score': 0.0,
      'average_completeness_score': 0.0,
      'improvement_trend': 'stable',
      'strong_concepts': <String>[],
      'struggling_concepts': <String>[],
      'average_word_count': 0.0,
      'best_topic': 'General',
      'best_topic_score': 0.0,
      'topic_performance': <String, List<double>>{},
      'sessions_by_topic': <String, int>{},
    };
  }

  Map<String, double> _calculateFeynmanConceptMastery(List<FeynmanExplanation> explanations, List<FeynmanFeedback> feedback) {
    final conceptMastery = <String, double>{};
    
    // Analyze strengths from explanations
    final allStrengths = explanations.expand((e) => e.strengths).toList();
    final strengthCounts = <String, int>{};
    for (final strength in allStrengths) {
      strengthCounts[strength] = (strengthCounts[strength] ?? 0) + 1;
    }
    
    strengthCounts.forEach((concept, count) {
      final masteryScore = min(100.0, (count / explanations.length) * 100);
      conceptMastery[concept] = masteryScore;
    });
    
    return conceptMastery;
  }

  double _calculateFeynmanDifficultyPerformance(List<FeynmanFeedback> feedback) {
    if (feedback.isEmpty) return 75.0;
    
    final severityScores = feedback.map((f) {
      switch (f.severity) {
        case FeedbackSeverity.low:
          return 1.0;
        case FeedbackSeverity.medium:
          return 0.7;
        case FeedbackSeverity.high:
          return 0.4;
        case FeedbackSeverity.critical:
          return 0.1;
      }
    }).toList();
    
    final avgSeverityScore = severityScores.reduce((a, b) => a + b) / severityScores.length;
    return avgSeverityScore * 100;
  }

  Map<String, List<String>> _analyzeFeynmanConceptPatterns(List<FeynmanExplanation> explanations) {
    final strong = <String>{};
    final weak = <String>{};
    
    for (final explanation in explanations) {
      if (explanation.overallScore != null) {
        if (explanation.overallScore! >= 7.0) {
          strong.addAll(explanation.strengths);
        } else if (explanation.overallScore! < 5.0) {
          weak.addAll(explanation.identifiedGaps);
        }
      }
    }
    
    return {'strong': strong.toList(), 'weak': weak.toList()};
  }

  Map<String, double> _calculateFeynmanRetentionRates(List<FeynmanExplanation> explanations) {
    final retentionRates = <String, double>{};
    
    if (explanations.length >= 2) {
      // Compare concept coverage across explanations
      final firstExplanation = explanations.first;
      final lastExplanation = explanations.last;
      
      final firstConcepts = {...firstExplanation.strengths, ...firstExplanation.identifiedGaps};
      final lastConcepts = {...lastExplanation.strengths, ...lastExplanation.identifiedGaps};
      
      final retainedConcepts = firstConcepts.intersection(lastConcepts);
      final retentionRate = firstConcepts.isNotEmpty 
          ? (retainedConcepts.length / firstConcepts.length) * 100 
          : 0.0;
      
      retentionRates['Concept Retention'] = retentionRate;
      
      // Quality retention
      if (firstExplanation.overallScore != null && lastExplanation.overallScore != null) {
        final qualityRetention = (lastExplanation.overallScore! / max(firstExplanation.overallScore!, 1.0)) * 100;
        retentionRates['Quality Retention'] = qualityRetention.clamp(0.0, 200.0);
      }
    }
    
    return retentionRates;
  }

  List<TimeBasedPattern> _analyzeFeynmanTemporalPatterns(FeynmanSession session, List<FeynmanExplanation> explanations) {
    final patterns = <TimeBasedPattern>[];
    
    if (explanations.isNotEmpty) {
      // Analyze performance by explanation sequence
      for (int i = 0; i < explanations.length; i++) {
        final explanation = explanations[i];
        if (explanation.overallScore != null) {
          patterns.add(TimeBasedPattern(
            timeframe: 'explanation_${explanation.attemptNumber}',
            performanceScore: explanation.overallScore! * 10,
            pattern: explanation.overallScore! >= 7.0 ? 'high_quality' : explanation.overallScore! >= 5.0 ? 'moderate_quality' : 'needs_improvement',
            observations: ['Explanation ${explanation.attemptNumber}: ${explanation.overallScore!.toStringAsFixed(1)}/10'],
          ));
        }
      }
      
      // Overall session pattern
      final avgScore = explanations.where((e) => e.overallScore != null).isNotEmpty
          ? explanations.where((e) => e.overallScore != null).map((e) => e.overallScore!).reduce((a, b) => a + b) / explanations.where((e) => e.overallScore != null).length
          : 0.0;
      
      patterns.add(TimeBasedPattern(
        timeframe: 'session_overall',
        performanceScore: avgScore * 10,
        pattern: explanations.length > 1 ? 'iterative_improvement' : 'single_attempt',
        observations: ['${explanations.length} explanations over ${session.totalDuration.inMinutes} minutes'],
      ));
    }
    
    return patterns;
  }

  List<String> _identifyFeynmanErrorTypes(List<FeynmanFeedback> feedback) {
    final errorTypes = <String>[];
    
    // Count feedback by type
    final typeCounts = <FeynmanFeedbackType, int>{};
    for (final item in feedback) {
      typeCounts[item.feedbackType] = (typeCounts[item.feedbackType] ?? 0) + 1;
    }
    
    // Identify common issues
    typeCounts.forEach((type, count) {
      if (count > feedback.length * 0.3) {
        errorTypes.add('Frequent ${type.displayName.toLowerCase()} issues');
      }
    });
    
    // Check for critical issues
    final criticalCount = feedback.where((f) => f.severity == FeedbackSeverity.critical).length;
    if (criticalCount > 0) {
      errorTypes.add('Critical understanding gaps');
    }
    
    // Check for high-priority issues
    final highPriorityCount = feedback.where((f) => f.priority >= 4).length;
    if (highPriorityCount > feedback.length * 0.4) {
      errorTypes.add('Multiple high-priority improvements needed');
    }
    
    return errorTypes.isEmpty ? ['No significant error patterns identified'] : errorTypes;
  }

  Map<String, List<String>> _analyzeFeynmanCognitiveProfile(List<FeynmanExplanation> explanations, List<FeynmanFeedback> feedback) {
    final strengths = <String>[];
    final weaknesses = <String>[];
    
    // Analyze explanation quality
    final avgScore = explanations.where((e) => e.overallScore != null).isNotEmpty
        ? explanations.where((e) => e.overallScore != null).map((e) => e.overallScore!).reduce((a, b) => a + b) / explanations.where((e) => e.overallScore != null).length
        : 0.0;
    
    if (avgScore >= 7.0) {
      strengths.add('Strong conceptual understanding');
    } else if (avgScore < 4.0) {
      weaknesses.add('Needs deeper conceptual understanding');
    }
    
    // Analyze explanation length and detail
    final avgWordCount = explanations.isNotEmpty 
        ? explanations.map((e) => e.wordCount).reduce((a, b) => a + b) / explanations.length 
        : 0;
    
    if (avgWordCount > 150) {
      strengths.add('Detailed explanations');
    } else if (avgWordCount < 50) {
      weaknesses.add('Brief explanations may lack detail');
    }
    
    // Analyze clarity scores specifically
    final avgClarityScore = explanations.where((e) => e.clarityScore != null).isNotEmpty
        ? explanations.where((e) => e.clarityScore != null).map((e) => e.clarityScore!).reduce((a, b) => a + b) / explanations.where((e) => e.clarityScore != null).length
        : 0.0;
    
    if (avgClarityScore >= 7.0) {
      strengths.add('Clear communication');
    } else if (avgClarityScore < 5.0) {
      weaknesses.add('Needs clearer explanations');
    }
    
    // Analyze improvement pattern
    if (explanations.length > 1) {
      final firstScore = explanations.first.overallScore ?? 0.0;
      final lastScore = explanations.last.overallScore ?? 0.0;
      if (lastScore > firstScore + 1.0) {
        strengths.add('Quick learning adaptation');
      } else if (firstScore > lastScore + 1.0) {
        weaknesses.add('Difficulty maintaining explanation quality');
      }
    }
    
    return {
      'strengths': strengths.isEmpty ? ['Completed explanation attempts'] : strengths,
      'weaknesses': weaknesses.isEmpty ? ['No significant weaknesses identified'] : weaknesses,
    };
  }

  double _calculateFeynmanAttentionSpan(List<FeynmanExplanation> explanations) {
    if (explanations.length < 2) return 100.0;
    
    // Analyze quality consistency across explanations
    final scores = explanations.where((e) => e.overallScore != null).map((e) => e.overallScore!).toList();
    if (scores.length < 2) return 100.0;
    
    final variance = _calculateVariance(scores);
    final consistencyScore = max(0.0, 100.0 - (variance * 20)); // Lower variance = higher consistency
    
    return consistencyScore;
  }

  /// Generate fallback insights when AI generation fails
  Map<String, dynamic> _generateFallbackFeynmanInsights(
    PerformanceMetrics performance,
    LearningPatterns patterns,
    BehaviorAnalysis behavior,
    CognitiveAnalysis cognitive,
    FeynmanSession session,
    List<FeynmanExplanation> explanations,
    List<FeynmanFeedback> feedback,
  ) {
    final avgScore = explanations.where((e) => e.overallScore != null).isNotEmpty
        ? explanations.where((e) => e.overallScore != null).map((e) => e.overallScore!).reduce((a, b) => a + b) / explanations.where((e) => e.overallScore != null).length
        : 0.0;
    
    final recommendations = <PersonalizedRecommendation>[
      PersonalizedRecommendation(
        id: 'feynman_fallback_rec_1',
        type: RecommendationType.studyMethods,
        title: 'Continue Feynman Practice',
        description: 'Based on your explanation quality, optimize your Feynman technique approach.',
        actionableAdvice: avgScore >= 7.0 
            ? 'Excellent explanations! Try tackling more complex topics using the same approach.'
            : avgScore >= 5.0 
                ? 'Good progress! Focus on adding more examples and simplifying complex concepts.'
                : 'Practice breaking down topics into simpler components and use more analogies.',
        priority: 1,
        confidenceScore: 0.8,
        reasons: ['Explanation quality analysis', 'Learning pattern recognition'],
      ),
      PersonalizedRecommendation(
        id: 'feynman_fallback_rec_2',
        type: RecommendationType.studyTiming,
        title: 'Optimize Explanation Sessions',
        description: 'Improve your explanation technique based on session analysis.',
        actionableAdvice: explanations.length == 1 
            ? 'Try multiple explanation attempts to refine your understanding.'
            : feedback.where((f) => f.severity == FeedbackSeverity.critical).isNotEmpty
                ? 'Address critical feedback before moving to new topics.'
                : 'Continue with your current explanation approach.',
        priority: 2,
        confidenceScore: 0.7,
        reasons: ['Session behavior analysis', 'Feedback patterns'],
      ),
    ];
    
    final insights = <AnalyticsInsight>[
      AnalyticsInsight(
        id: 'feynman_fallback_insight_1',
        category: InsightCategory.performance,
        title: 'Explanation Quality',
        insight: 'Your average explanation score was ${avgScore.toStringAsFixed(1)}/10 across ${explanations.length} attempts.',
        significance: 0.9,
        supportingData: [
          'Total explanations: ${explanations.length}',
          'Session topic: ${session.topic}',
          'Study time: ${session.totalDuration.inMinutes} minutes'
        ],
      ),
      AnalyticsInsight(
        id: 'feynman_fallback_insight_2',
        category: InsightCategory.behavior,
        title: 'Learning Approach',
        insight: 'You demonstrated ${behavior.persistenceScore.toStringAsFixed(0)}% persistence in explaining concepts.',
        significance: 0.7,
        supportingData: [
          'Engagement level: ${behavior.engagementLevel.toStringAsFixed(0)}%',
          'Critical feedback items: ${feedback.where((f) => f.severity == FeedbackSeverity.critical).length}'
        ],
      ),
    ];
    
    final studyPlan = StudyPlan(
      id: 'feynman_fallback_plan',
      activities: [
        StudyActivity(
          type: 'concept_review',
          description: avgScore < 6.0 
              ? 'Review core concepts and practice explaining with simple analogies'
              : 'Expand explanations with real-world examples and applications',
          duration: const Duration(minutes: 30),
          priority: 1,
          materials: patterns.weakConcepts.isEmpty ? ['Study materials'] : patterns.weakConcepts,
        ),
        if (explanations.length == 1)
          StudyActivity(
            type: 'explanation_practice',
            description: 'Attempt multiple explanations of the same topic to refine understanding',
            duration: const Duration(minutes: 20),
            priority: 2,
            materials: [session.topic],
          ),
      ],
      estimatedDuration: Duration(minutes: explanations.length == 1 ? 50 : 30),
      focusAreas: {
        'explanation_quality': avgScore < 6.0 ? 'Improve' : 'Maintain',
        'concept_clarity': patterns.weakConcepts.isNotEmpty ? 'Address gaps' : 'Continue practice',
        'feedback_response': feedback.where((f) => f.severity == FeedbackSeverity.critical).isNotEmpty ? 'Critical' : 'Monitor',
      },
      objectives: [
        if (avgScore < 6.0) 'Improve explanation clarity and completeness',
        if (patterns.weakConcepts.isNotEmpty) 'Address identified knowledge gaps',
        if (explanations.length == 1) 'Practice iterative explanation refinement',
        'Continue developing teaching-based learning approach',
      ],
    );
    
    return {
      'recommendations': recommendations,
      'insights': insights,
      'studyPlan': studyPlan,
    };
  }

  /// Generate fallback analytics when full analysis fails
  Future<StudySessionAnalytics> _generateFallbackFeynmanAnalytics(
    String sessionId,
    String userId,
    String moduleId,
    FeynmanSession session,
    List<FeynmanExplanation> explanations,
    List<FeynmanFeedback> feedback,
  ) async {
    // Basic calculations
    final avgScore = explanations.where((e) => e.overallScore != null).isNotEmpty
        ? explanations.where((e) => e.overallScore != null).map((e) => e.overallScore!).reduce((a, b) => a + b) / explanations.where((e) => e.overallScore != null).length
        : 0.0;
    
    final avgWordCount = explanations.isNotEmpty 
        ? explanations.map((e) => e.wordCount).reduce((a, b) => a + b) / explanations.length 
        : 0.0;
    
    // Try to get basic historical context
    final historicalData = await aggregateFeynmanModulePerformance(userId, moduleId);
    final historicalAvgScore = historicalData['average_overall_score'] as double;
    
    final basicPerformance = PerformanceMetrics(
      preStudyAccuracy: explanations.isNotEmpty ? (explanations.first.overallScore ?? 0.0) * 10 : 0.0,
      postStudyAccuracy: explanations.isNotEmpty ? (explanations.last.overallScore ?? 0.0) * 10 : 0.0,
      improvementPercentage: explanations.length > 1 && explanations.first.overallScore != null && explanations.last.overallScore != null
          ? ((explanations.last.overallScore! - explanations.first.overallScore!) / max(explanations.first.overallScore!, 1.0)) * 100
          : 0.0,
      averageResponseTime: session.totalDuration.inMinutes / max(1, explanations.length).toDouble(),
      accuracyByDifficulty: avgScore * 10,
      materialPerformance: {
        'Explanation Quality': avgScore * 10,
        'Average Word Count': avgWordCount,
        'Historical Average': historicalAvgScore * 10,
      },
      conceptMastery: {},
      overallLevel: AnalyticsCalculator.determinePerformanceLevel(avgScore * 10),
    );
    
    return StudySessionAnalytics(
      id: '', // Database will generate UUID
      sessionId: sessionId,
      userId: userId,
      moduleId: moduleId,
      analyzedAt: DateTime.now(),
      performanceMetrics: basicPerformance,
      learningPatterns: LearningPatterns(
        patternType: LearningPatternType.steadyProgression,
        learningVelocity: 0.0,
        strongConcepts: [],
        weakConcepts: [],
        retentionRates: {},
        temporalPatterns: [],
      ),
      behaviorAnalysis: BehaviorAnalysis(
        totalStudyTime: session.totalDuration,
        hintUsageCount: feedback.where((f) => f.priority >= 4).length,
        hintEffectiveness: 0.75,
        commonErrorTypes: [],
        questionAttemptPatterns: {},
        persistenceScore: explanations.length > 1 ? 85.0 : 75.0,
        engagementLevel: avgScore * 10,
      ),
      cognitiveAnalysis: CognitiveAnalysis(
        cognitiveLoadScore: 50.0,
        memoryRetentionByType: {},
        processingSpeed: min(150.0, avgWordCount / 2),
        cognitiveStrengths: [],
        cognitiveWeaknesses: [],
        attentionSpan: avgScore * 10,
      ),
      recommendations: [],
      insights: [],
      suggestedStudyPlan: StudyPlan(
        id: 'feynman_fallback_plan',
        activities: [],
        estimatedDuration: const Duration(minutes: 30),
        focusAreas: {},
        objectives: [],
      ),
    );
  }

  /// Validate that a session exists in the appropriate session table
  Future<bool> _validateSessionExists(String sessionId, String sessionType) async {
    try {
      print('🔍 [ANALYTICS] Validating session exists: $sessionId for type: $sessionType');
      
      // Determine which table to check based on session type
      String tableName;
      switch (sessionType) {
        case 'active_recall':
          tableName = 'active_recall_sessions';
          break;
        case 'pomodoro':
          tableName = 'pomodoro_sessions';
          break;
        case 'feynman':
          tableName = 'feynman_sessions';
          break;
        default:
          print('❌ [ANALYTICS] Unknown session type: $sessionType');
          return false;
      }
      
      print('🔍 [ANALYTICS] Checking table: $tableName for session: $sessionId');
      
      final response = await SupabaseService.client
          .from(tableName)
          .select('id')
          .eq('id', sessionId)
          .maybeSingle();
      
      final exists = response != null;
      print('✅ [ANALYTICS] Session $sessionId exists in $tableName: $exists');
      return exists;
      
    } catch (e) {
      print('❌ [ANALYTICS] Error validating session existence: $e');
      return false; // Assume session doesn't exist if we can't validate
    }
  }
}