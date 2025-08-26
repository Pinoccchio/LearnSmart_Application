import 'dart:async';
import 'package:flutter/foundation.dart';
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
      
      // Generate analytics if possible
      try {
        _sessionAnalytics = await _generateSessionAnalytics(
          session: completedSession,
          results: results,
        );
      } catch (e) {
        print('⚠️ [ANALYTICS] Failed to generate analytics: $e');
      }
      
      _currentSession = completedSession;
      
      print('✅ [SESSION COMPLETION] Session completed successfully');
      print('   Final accuracy: ${results.accuracyPercentage.toStringAsFixed(1)}%');
      print('   Improvement: ${results.improvementFromOriginal.toStringAsFixed(1)}%');
      print('   Mastered concepts: ${results.masteredConcepts.length}');
      
      notifyListeners();
      return results;
      
    } catch (e) {
      print('❌ [SESSION COMPLETION] Error completing session: $e');
      rethrow;
    }
  }

  /// Generate analytics for the remedial session
  Future<StudySessionAnalytics?> _generateSessionAnalytics({
    required RemedialSession session,
    required RemedialResults results,
  }) async {
    try {
      print('📊 [ANALYTICS] Generating remedial session analytics...');
      
      // Generate basic analytics for remedial session
      // Note: Full analytics requires course/module data and ActiveRecall format
      // For now, return null to indicate analytics are not available
      return null;
      
    } catch (e) {
      print('❌ [ANALYTICS] Error generating analytics: $e');
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

  /// Update remedial settings
  void updateSettings(RemedialSettings newSettings) {
    _settings = newSettings;
    print('⚙️ [SETTINGS] Remedial settings updated');
    notifyListeners();
  }
}