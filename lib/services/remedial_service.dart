import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import '../models/remedial_models.dart';
import '../models/active_recall_models.dart';
import '../models/course_models.dart';
import '../models/study_analytics_models.dart';
import '../services/supabase_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/study_analytics_service.dart';

class RemedialService extends ChangeNotifier {
  // Current session state
  RemedialSession? _currentSession;
  List<RemedialFlashcard> _sessionFlashcards = [];
  List<RemedialAttempt> _sessionAttempts = [];
  RemedialSettings _settings = RemedialSettings.defaults();
  int _currentFlashcardIndex = 0;
  bool _isProcessingAnswer = false;
  StudySessionAnalytics? _sessionAnalytics;
  
  // AI and analytics services
  late final GeminiAIService _aiService;
  late final StudyAnalyticsService _analyticsService;
  
  // Processing state
  bool _isGeneratingQuestions = false;
  String? _processingError;
  final _uuid = const Uuid();

  RemedialService() {
    _aiService = GeminiAIService();
    _analyticsService = StudyAnalyticsService();
  }
  
  // Getters
  RemedialSession? get currentSession => _currentSession;
  List<RemedialFlashcard> get sessionFlashcards => List.unmodifiable(_sessionFlashcards);
  List<RemedialAttempt> get sessionAttempts => List.unmodifiable(_sessionAttempts);
  RemedialSettings get settings => _settings;
  int get currentFlashcardIndex => _currentFlashcardIndex;
  bool get isProcessingAnswer => _isProcessingAnswer;
  StudySessionAnalytics? get sessionAnalytics => _sessionAnalytics;
  bool get isGeneratingQuestions => _isGeneratingQuestions;
  String? get processingError => _processingError;
  
  RemedialFlashcard? get currentFlashcard => 
      _sessionFlashcards.isNotEmpty && _currentFlashcardIndex < _sessionFlashcards.length 
          ? _sessionFlashcards[_currentFlashcardIndex] 
          : null;

  bool get hasMoreFlashcards => _currentFlashcardIndex < _sessionFlashcards.length - 1;
  double get progress => _sessionFlashcards.isEmpty 
      ? 0.0 
      : (_currentFlashcardIndex + 1) / _sessionFlashcards.length;
  
  bool get isSessionComplete => _currentFlashcardIndex >= _sessionFlashcards.length - 1;

  /// Check if a study session needs remedial work based on performance
  static bool needsRemedialWork(StudySessionResults results) {
    final accuracy = results.postStudyCorrect / results.totalFlashcards * 100;
    print('🔍 [REMEDIAL CHECK] Session accuracy: ${accuracy.toStringAsFixed(1)}%');
    return accuracy < 80.0; // Trigger remedial if below 80%
  }

  /// Analyze original session to identify missed concepts and weak areas
  Future<List<String>> analyzeMissedConcepts(
    String originalSessionId,
    List<ActiveRecallFlashcard> originalFlashcards,
    List<ActiveRecallAttempt> originalAttempts,
  ) async {
    try {
      print('🔍 [REMEDIAL ANALYSIS] Analyzing missed concepts from session: $originalSessionId');
      
      final missedConcepts = <String>[];
      
      // Group attempts by flashcard to find incorrect answers
      final attemptsByFlashcard = <String, List<ActiveRecallAttempt>>{};
      for (final attempt in originalAttempts) {
        attemptsByFlashcard.putIfAbsent(attempt.flashcardId, () => []).add(attempt);
      }
      
      // Analyze each flashcard for missed concepts
      for (final flashcard in originalFlashcards) {
        final flashcardAttempts = attemptsByFlashcard[flashcard.id] ?? [];
        
        // Check if any attempts were incorrect (focusing on post-study attempts)
        final postStudyAttempts = flashcardAttempts.where((a) => !a.isPreStudy).toList();
        final hasIncorrectAttempts = postStudyAttempts.any((a) => !a.isCorrect);
        
        if (hasIncorrectAttempts || postStudyAttempts.isEmpty) {
          // Extract concept from the question or use the flashcard type as concept
          String concept;
          
          // Try to extract meaningful concept from the question
          if (flashcard.question.length > 100) {
            // For longer questions, try to extract key terms
            concept = _extractConceptFromQuestion(flashcard.question, flashcard.answer);
          } else {
            // For shorter questions, use the answer as the concept
            concept = flashcard.answer.split('.').first.trim();
            if (concept.length > 50) {
              concept = concept.substring(0, 47) + '...';
            }
          }
          
          if (!missedConcepts.contains(concept)) {
            missedConcepts.add(concept);
            print('   → Found missed concept: $concept');
          }
        }
      }
      
      print('✅ [REMEDIAL ANALYSIS] Identified ${missedConcepts.length} missed concepts');
      return missedConcepts;
      
    } catch (e) {
      print('❌ [REMEDIAL ANALYSIS] Error analyzing missed concepts: $e');
      return [];
    }
  }

  /// Extract meaningful concept from a question and answer pair
  String _extractConceptFromQuestion(String question, String answer) {
    // Remove common question words and extract key concepts
    final cleanQuestion = question
        .replaceAll(RegExp(r'\b(what|where|when|why|how|which|who|define|explain|describe|identify)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[?.,!]'), '')
        .trim();
    
    // Use the first significant word from the answer
    final answerWords = answer.split(' ');
    if (answerWords.isNotEmpty) {
      return answerWords.first.trim();
    }
    
    // Fallback to first significant word from question
    final questionWords = cleanQuestion.split(' ').where((word) => word.length > 3).toList();
    if (questionWords.isNotEmpty) {
      return questionWords.first.trim();
    }
    
    return 'Concept';
  }

  /// Create a new remedial session from an original study session
  Future<RemedialSession?> createRemedialSession({
    required String originalSessionId,
    required String userId,
    required String moduleId,
    required List<ActiveRecallFlashcard> originalFlashcards,
    required List<ActiveRecallAttempt> originalAttempts,
    required List<CourseMaterial> materials,
    RemedialSettings? customSettings,
  }) async {
    try {
      print('🔄 [REMEDIAL SESSION] Creating remedial session for original: $originalSessionId');
      
      _processingError = null;
      _isGeneratingQuestions = true;
      notifyListeners();
      
      // Update settings
      _settings = customSettings ?? RemedialSettings.defaults();
      
      // Analyze missed concepts
      final missedConcepts = await analyzeMissedConcepts(
        originalSessionId,
        originalFlashcards,
        originalAttempts,
      );
      
      if (missedConcepts.isEmpty) {
        print('⚠️ [REMEDIAL SESSION] No missed concepts found, session not needed');
        _isGeneratingQuestions = false;
        notifyListeners();
        return null;
      }
      
      // Create remedial session
      final sessionId = _uuid.v4();
      final now = DateTime.now();
      
      final session = RemedialSession(
        id: sessionId,
        originalSessionId: originalSessionId,
        userId: userId,
        moduleId: moduleId,
        missedConcepts: missedConcepts,
        status: RemedialSessionStatus.preparing,
        startedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      
      // Generate remedial flashcards using AI
      print('🧠 [REMEDIAL SESSION] Generating remedial questions for ${missedConcepts.length} concepts...');
      final remedialFlashcards = await _generateRemedialFlashcards(
        session,
        originalFlashcards,
        materials,
        missedConcepts,
      );
      
      if (remedialFlashcards.isEmpty) {
        print('❌ [REMEDIAL SESSION] Failed to generate remedial questions');
        _processingError = 'Failed to generate remedial questions. Please try again.';
        _isGeneratingQuestions = false;
        notifyListeners();
        return null;
      }
      
      // Update session with flashcards
      final updatedSession = session.copyWith(
        flashcards: remedialFlashcards,
        status: RemedialSessionStatus.active,
        updatedAt: DateTime.now(),
      );
      
      // Save to database
      await _saveSessionToDatabase(updatedSession);
      
      // Initialize current session
      _currentSession = updatedSession;
      _sessionFlashcards = remedialFlashcards;
      _sessionAttempts = [];
      _currentFlashcardIndex = 0;
      _sessionAnalytics = null;
      
      print('✅ [REMEDIAL SESSION] Created session with ${remedialFlashcards.length} questions');
      _isGeneratingQuestions = false;
      notifyListeners();
      
      return updatedSession;
      
    } catch (e) {
      print('❌ [REMEDIAL SESSION] Error creating session: $e');
      _processingError = 'Failed to create remedial session: $e';
      _isGeneratingQuestions = false;
      notifyListeners();
      return null;
    }
  }

  /// Generate remedial flashcards using AI service
  Future<List<RemedialFlashcard>> _generateRemedialFlashcards(
    RemedialSession session,
    List<ActiveRecallFlashcard> originalFlashcards,
    List<CourseMaterial> materials,
    List<String> missedConcepts,
  ) async {
    try {
      // Find original flashcards that correspond to missed concepts
      final missedFlashcards = <ActiveRecallFlashcard>[];
      for (final concept in missedConcepts) {
        final relatedFlashcards = originalFlashcards.where((f) => 
          f.answer.toLowerCase().contains(concept.toLowerCase()) ||
          f.question.toLowerCase().contains(concept.toLowerCase())
        ).toList();
        missedFlashcards.addAll(relatedFlashcards);
      }
      
      if (missedFlashcards.isEmpty) {
        // Fallback: use all original flashcards
        missedFlashcards.addAll(originalFlashcards);
      }
      
      print('🧠 [AI GENERATION] Generating remedial questions for ${missedFlashcards.length} missed flashcards');
      
      // Generate remedial flashcards using AI
      final remedialFlashcards = await _aiService.generateRemedialFlashcardsFromMissedConcepts(
        originalFlashcards: missedFlashcards,
        materials: materials,
        missedConcepts: missedConcepts,
        settings: _settings,
      );
      
      // Create RemedialFlashcard objects
      final result = <RemedialFlashcard>[];
      for (int i = 0; i < remedialFlashcards.length; i++) {
        final aiFlashcard = remedialFlashcards[i];
        final concept = missedConcepts[i % missedConcepts.length];
        final originalFlashcard = missedFlashcards[i % missedFlashcards.length];
        
        final remedialFlashcard = RemedialFlashcard.fromAI(
          aiFlashcard,
          session.id,
          originalFlashcard.id,
          concept,
          index: i,
        );
        
        result.add(remedialFlashcard);
      }
      
      return result;
      
    } catch (e) {
      print('❌ [AI GENERATION] Error generating remedial flashcards: $e');
      return [];
    }
  }

  /// Process a user's answer to the current remedial flashcard
  Future<bool> processAnswer(String userAnswer) async {
    if (_currentSession == null || currentFlashcard == null) {
      return false;
    }
    
    try {
      _isProcessingAnswer = true;
      notifyListeners();
      
      final startTime = DateTime.now();
      final flashcard = currentFlashcard!;
      
      // Check if answer is correct
      final isCorrect = flashcard.isAnswerCorrect(userAnswer);
      
      // Calculate response time (simplified - in real app you'd track start time)
      final responseTime = DateTime.now().difference(startTime).inSeconds.clamp(1, 300);
      
      // Create attempt record
      final attempt = RemedialAttempt(
        id: _uuid.v4(),
        sessionId: _currentSession!.id,
        flashcardId: flashcard.id,
        userAnswer: userAnswer.trim(),
        isCorrect: isCorrect,
        responseTimeSeconds: responseTime,
        attemptedAt: DateTime.now(),
      );
      
      // Add attempt to list
      _sessionAttempts.add(attempt);
      
      // Save attempt to database
      await _saveAttemptToDatabase(attempt);
      
      print('📝 [ANSWER PROCESSING] Answer processed: ${isCorrect ? 'Correct' : 'Incorrect'}');
      
      _isProcessingAnswer = false;
      notifyListeners();
      
      return isCorrect;
      
    } catch (e) {
      print('❌ [ANSWER PROCESSING] Error processing answer: $e');
      _isProcessingAnswer = false;
      notifyListeners();
      return false;
    }
  }

  /// Move to the next flashcard in the remedial session
  void nextFlashcard() {
    if (hasMoreFlashcards) {
      _currentFlashcardIndex++;
      print('▶️ [NAVIGATION] Moved to flashcard ${_currentFlashcardIndex + 1}/${_sessionFlashcards.length}');
      notifyListeners();
    }
  }

  /// Complete the current remedial session
  Future<RemedialResults> completeSession({double originalAccuracy = 0.0}) async {
    if (_currentSession == null) {
      throw Exception('No active remedial session');
    }
    
    try {
      print('🏁 [SESSION COMPLETION] Completing remedial session...');
      
      // Calculate results
      final results = RemedialResults.calculate(
        _sessionFlashcards,
        _sessionAttempts,
        originalAccuracy,
      );
      
      // Update session status
      final completedSession = _currentSession!.copyWith(
        status: RemedialSessionStatus.completed,
        attempts: _sessionAttempts,
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Save updated session to database
      await _saveSessionToDatabase(completedSession);
      
      _currentSession = completedSession;
      
      print('✅ [SESSION COMPLETION] Session completed successfully');
      print('   Final accuracy: ${results.accuracyPercentage.toStringAsFixed(1)}%');
      print('   Improvement: ${results.improvementFromOriginal.toStringAsFixed(1)}%');
      print('   Mastered concepts: ${results.masteredConcepts.length}');
      
      // Use post-frame callback to notify listeners safely
      safeNotifyListeners();
      return results;
      
    } catch (e) {
      print('❌ [SESSION COMPLETION] Error completing session: $e');
      rethrow;
    }
  }

  /// Generate comprehensive analytics for the completed remedial session
  Future<void> generateAnalyticsForSession({double originalAccuracy = 0.0}) async {
    if (_currentSession == null) {
      print('⚠️ [ANALYTICS] No active session available for analytics generation');
      return;
    }
    
    try {
      print('📊 [ANALYTICS] Starting analytics generation for remedial session...');
      
      final results = RemedialResults.calculate(
        _sessionFlashcards,
        _sessionAttempts,
        originalAccuracy,
      );
      
      _sessionAnalytics = await _generateSessionAnalytics(
        session: _currentSession!,
        results: results,
      );
      
      print('✅ [ANALYTICS] Analytics generation completed successfully');
      
    } catch (e) {
      print('❌ [ANALYTICS] Failed to generate analytics: $e');
      
      // Generate fallback analytics to ensure some data is available
      try {
        _sessionAnalytics = await _generateFallbackAnalytics(
          session: _currentSession!,
          results: RemedialResults.calculate(_sessionFlashcards, _sessionAttempts, originalAccuracy),
        );
        print('✅ [ANALYTICS] Fallback analytics generated successfully');
      } catch (fallbackError) {
        print('❌ [ANALYTICS] Even fallback analytics failed: $fallbackError');
        _sessionAnalytics = null;
      }
    }
  }

  /// Generate analytics for the remedial session
  Future<StudySessionAnalytics?> _generateSessionAnalytics({
    required RemedialSession session,
    required RemedialResults results,
  }) async {
    try {
      print('📊 [ANALYTICS] Generating remedial session analytics...');
      
      // Get course and module data
      final course = await _getCourseData(session.moduleId);
      final module = await _getModuleData(session.moduleId);
      
      if (course == null || module == null) {
        print('⚠️ [ANALYTICS] Missing course/module data, cannot generate full analytics');
        return null;
      }
      
      // Generate comprehensive analytics using StudyAnalyticsService
      final analytics = await _analyticsService.generateRemedialAnalytics(
        sessionId: session.id,
        userId: session.userId,
        moduleId: session.moduleId,
        session: session,
        flashcards: session.flashcards,
        attempts: session.attempts,
        results: results,
        course: course,
        module: module,
      );
      
      print('✅ [ANALYTICS] Successfully generated remedial session analytics');
      return analytics;
      
    } catch (e) {
      print('❌ [ANALYTICS] Error generating analytics: $e');
      return null;
    }
  }

  /// Generate fallback analytics when full analytics generation fails
  Future<StudySessionAnalytics> _generateFallbackAnalytics({
    required RemedialSession session,
    required RemedialResults results,
  }) async {
    print('📊 [FALLBACK ANALYTICS] Generating basic analytics for remedial session...');
    
    return StudySessionAnalytics(
      id: '', // Database will generate UUID
      sessionId: session.id,
      userId: session.userId,
      moduleId: session.moduleId,
      analyzedAt: DateTime.now(),
      performanceMetrics: PerformanceMetrics(
        preStudyAccuracy: 0.0, // Not applicable for remedial
        postStudyAccuracy: results.accuracyPercentage,
        improvementPercentage: results.improvementFromOriginal,
        averageResponseTime: results.averageResponseTime.toDouble(),
        accuracyByDifficulty: 0.0,
        materialPerformance: {},
        conceptMastery: session.missedConcepts.asMap().map(
          (index, concept) => MapEntry(concept, results.masteredConcepts.contains(concept) ? 100.0 : 50.0)
        ),
        overallLevel: results.isPassing ? PerformanceLevel.good : PerformanceLevel.average,
      ),
      learningPatterns: LearningPatterns(
        patternType: LearningPatternType.strugglingConcepts,
        learningVelocity: results.accuracyPercentage / _sessionFlashcards.length,
        strongConcepts: results.masteredConcepts,
        weakConcepts: results.stillStrugglingConcepts,
        retentionRates: {},
        temporalPatterns: [],
      ),
      behaviorAnalysis: BehaviorAnalysis(
        totalStudyTime: Duration(seconds: results.averageResponseTime * _sessionFlashcards.length),
        hintUsageCount: 0,
        hintEffectiveness: 0.0,
        commonErrorTypes: results.stillStrugglingConcepts.isEmpty ? [] : ['Concept mastery needed'],
        questionAttemptPatterns: {
          'total': _sessionFlashcards.length,
          'correct': results.correctAnswers,
        },
        persistenceScore: results.isPassing ? 85.0 : 65.0,
        engagementLevel: results.accuracyPercentage > 70 ? 80.0 : 60.0,
      ),
      cognitiveAnalysis: CognitiveAnalysis(
        cognitiveLoadScore: 60.0,
        memoryRetentionByType: {},
        processingSpeed: 100 / results.averageResponseTime,
        cognitiveStrengths: results.masteredConcepts.isNotEmpty ? ['Concept remediation'] : [],
        cognitiveWeaknesses: results.stillStrugglingConcepts.isNotEmpty ? ['Areas needing more practice'] : [],
        attentionSpan: 70.0,
      ),
      recommendations: [
        PersonalizedRecommendation(
          id: 'fallback_remedial_rec',
          type: RecommendationType.studyTiming,
          title: results.isPassing ? 'Great Recovery!' : 'Keep Practicing',
          description: results.isPassing 
              ? 'You successfully improved your understanding through targeted practice!'
              : 'Continue working on the concepts you missed.',
          actionableAdvice: results.isPassing
              ? 'Review these concepts periodically to maintain mastery.'
              : 'Focus on the struggling concepts: ${results.stillStrugglingConcepts.join(', ')}',
          priority: 1,
          confidenceScore: 0.7,
          reasons: ['Basic remedial performance analysis'],
        ),
      ],
      insights: [
        AnalyticsInsight(
          id: 'fallback_remedial_insight',
          category: InsightCategory.performance,
          title: 'Remedial Session Summary',
          insight: 'You achieved ${results.accuracyPercentage.toStringAsFixed(1)}% accuracy in your remedial quiz, ${results.showsImprovement ? 'showing improvement' : 'maintaining performance'} from your original session.',
          significance: 0.8,
          supportingData: [
            'Original concepts missed: ${session.missedConcepts.length}',
            'Remedial score: ${results.accuracyPercentage.toStringAsFixed(1)}%',
            'Concepts mastered: ${results.masteredConcepts.length}',
            'Still practicing: ${results.stillStrugglingConcepts.length}',
          ],
        ),
      ],
      suggestedStudyPlan: StudyPlan(
        id: 'fallback_remedial_plan',
        activities: [
          StudyActivity(
            type: 'review',
            description: results.isPassing 
                ? 'Review mastered concepts to maintain understanding'
                : 'Continue practicing struggling concepts',
            duration: const Duration(minutes: 20),
            priority: 1,
            materials: results.stillStrugglingConcepts.isNotEmpty 
                ? results.stillStrugglingConcepts 
                : results.masteredConcepts,
          ),
        ],
        estimatedDuration: const Duration(minutes: 20),
        focusAreas: results.stillStrugglingConcepts.isNotEmpty 
            ? results.stillStrugglingConcepts.asMap().map((index, concept) => MapEntry(concept, 'Focus on understanding $concept'))
            : {'review': 'Periodic review of mastered concepts'},
        objectives: results.isPassing 
            ? ['Maintain mastery', 'Build confidence']
            : ['Improve concept understanding', 'Achieve passing score'],
      ),
    );
  }
  
  /// Get course data for analytics
  Future<Course?> _getCourseData(String moduleId) async {
    try {
      final response = await SupabaseService.client
          .from('modules')
          .select('''
            course_id,
            courses!inner(
              id,
              title,
              description,
              instructor_id,
              created_at,
              updated_at
            )
          ''')
          .eq('id', moduleId)
          .maybeSingle();
          
      if (response == null) return null;
      
      final courseData = response['courses'];
      return Course(
        id: courseData['id'],
        title: courseData['title'],
        description: courseData['description'] ?? '',
        instructorId: courseData['instructor_id'],
        createdAt: DateTime.parse(courseData['created_at']),
      );
      
    } catch (e) {
      print('❌ [COURSE DATA] Error fetching course data: $e');
      return null;
    }
  }
  
  /// Get module data for analytics
  Future<Module?> _getModuleData(String moduleId) async {
    try {
      final response = await SupabaseService.client
          .from('modules')
          .select('''
            id,
            title,
            description,
            course_id,
            order_index,
            created_at,
            updated_at,
            course_materials!inner(
              id,
              title,
              description,
              file_type,
              file_url,
              file_size,
              upload_date
            )
          ''')
          .eq('id', moduleId)
          .maybeSingle();
          
      if (response == null) return null;
      
      // Convert materials
      final materialsData = response['course_materials'] as List? ?? [];
      final materials = materialsData.map((materialData) => CourseMaterial(
        id: materialData['id'],
        moduleId: moduleId,
        title: materialData['title'],
        description: materialData['description'],
        fileUrl: materialData['file_url'],
        fileType: materialData['file_type'],
        fileName: materialData['file_name'] ?? materialData['title'],
        orderIndex: materialData['order_index'] ?? 0,
      )).toList();
      
      return Module(
        id: response['id'],
        courseId: response['course_id'],
        title: response['title'],
        description: response['description'] ?? '',
        orderIndex: response['order_index'] ?? 0,
        materials: materials,
      );
      
    } catch (e) {
      print('❌ [MODULE DATA] Error fetching module data: $e');
      return null;
    }
  }

  /// Save remedial session to database
  Future<void> _saveSessionToDatabase(RemedialSession session) async {
    try {
      print('💾 [DATABASE] Saving remedial session: ${session.id}');
      
      final sessionData = session.toJson();
      
      // Check if session exists
      final existingSession = await SupabaseService.client
          .from('remedial_sessions')
          .select('id')
          .eq('id', session.id)
          .maybeSingle();
      
      if (existingSession != null) {
        // Update existing session
        await SupabaseService.client
            .from('remedial_sessions')
            .update(sessionData)
            .eq('id', session.id);
        print('✅ [DATABASE] Updated existing remedial session');
      } else {
        // Insert new session
        await SupabaseService.client
            .from('remedial_sessions')
            .insert(sessionData);
        print('✅ [DATABASE] Inserted new remedial session');
      }
      
    } catch (e) {
      print('❌ [DATABASE] Error saving remedial session: $e');
      rethrow;
    }
  }

  /// Save remedial attempt to database (store in session data for now)
  Future<void> _saveAttemptToDatabase(RemedialAttempt attempt) async {
    try {
      // For now, attempts are stored as part of the session data
      // In a more complex setup, you might have a separate attempts table
      print('💾 [DATABASE] Attempt saved to session data: ${attempt.id}');
    } catch (e) {
      print('❌ [DATABASE] Error saving attempt: $e');
    }
  }

  /// Load existing remedial session for a user and module
  Future<RemedialSession?> getExistingRemedialSession(String userId, String moduleId) async {
    try {
      print('🔍 [DATABASE] Looking for existing remedial session for user: $userId, module: $moduleId');
      
      final response = await SupabaseService.client
          .from('remedial_sessions')
          .select('*')
          .eq('user_id', userId)
          .eq('module_id', moduleId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        final session = RemedialSession.fromJson(response);
        print('✅ [DATABASE] Found existing remedial session: ${session.id}');
        return session;
      }
      
      print('ℹ️ [DATABASE] No existing remedial session found');
      return null;
      
    } catch (e) {
      print('❌ [DATABASE] Error loading remedial session: $e');
      return null;
    }
  }

  /// Reset the current session state
  void resetSession() {
    _currentSession = null;
    _sessionFlashcards.clear();
    _sessionAttempts.clear();
    _currentFlashcardIndex = 0;
    _isProcessingAnswer = false;
    _sessionAnalytics = null;
    _isGeneratingQuestions = false;
    _processingError = null;
    
    print('🔄 [SESSION] Remedial session state reset');
    notifyListeners();
  }

  /// Safely complete session and return results without immediate notification
  Future<RemedialResults> completeSessionSilently({double originalAccuracy = 0.0}) async {
    final results = await completeSession(originalAccuracy: originalAccuracy);
    // Session is completed but listeners are not notified to avoid widget tree lock
    return results;
  }

  /// Notify listeners manually when it's safe to do so
  void safeNotifyListeners() {
    // Use post-frame callback to ensure widget tree is not locked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  /// Update remedial settings
  void updateSettings(RemedialSettings newSettings) {
    _settings = newSettings;
    print('⚙️ [SETTINGS] Remedial settings updated');
    notifyListeners();
  }
}