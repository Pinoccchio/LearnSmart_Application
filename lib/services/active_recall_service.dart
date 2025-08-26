import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/active_recall_models.dart';
import '../models/course_models.dart';
import '../models/study_analytics_models.dart';
import '../services/supabase_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/study_analytics_service.dart';

class ActiveRecallService extends ChangeNotifier {
  // Current session state
  ActiveRecallSession? _currentSession;
  List<ActiveRecallFlashcard> _sessionFlashcards = [];
  List<ActiveRecallAttempt> _sessionAttempts = [];
  ActiveRecallSettings _settings = const ActiveRecallSettings();
  int _currentFlashcardIndex = 0;
  bool _isProcessingAnswer = false;
  StudySessionAnalytics? _sessionAnalytics;
  
  // AI and analytics services
  late final GeminiAIService _aiService;
  late final StudyAnalyticsService _analyticsService;
  
  // Processing state
  bool _isGeneratingFlashcards = false;
  String? _processingError;

  ActiveRecallService() {
    _aiService = GeminiAIService();
    _analyticsService = StudyAnalyticsService();
  }
  
  // Getters
  ActiveRecallSession? get currentSession => _currentSession;
  List<ActiveRecallFlashcard> get sessionFlashcards => List.unmodifiable(_sessionFlashcards);
  List<ActiveRecallAttempt> get sessionAttempts => List.unmodifiable(_sessionAttempts);
  ActiveRecallSettings get settings => _settings;
  int get currentFlashcardIndex => _currentFlashcardIndex;
  bool get isProcessingAnswer => _isProcessingAnswer;
  StudySessionAnalytics? get sessionAnalytics => _sessionAnalytics;
  bool get isGeneratingFlashcards => _isGeneratingFlashcards;
  String? get processingError => _processingError;
  
  ActiveRecallFlashcard? get currentFlashcard => 
      _sessionFlashcards.isNotEmpty && _currentFlashcardIndex < _sessionFlashcards.length 
          ? _sessionFlashcards[_currentFlashcardIndex] 
          : null;

  bool get hasMoreFlashcards => _currentFlashcardIndex < _sessionFlashcards.length - 1;
  double get progress => _sessionFlashcards.isEmpty 
      ? 0.0 
      : (_currentFlashcardIndex / _sessionFlashcards.length).clamp(0.0, 1.0);

  String get currentPhaseTitle {
    final session = _currentSession;
    if (session == null) return 'Active Recall';
    
    switch (session.status) {
      case StudySessionStatus.preparing:
        return 'Preparing Session...';
      case StudySessionStatus.preStudy:
        return 'Pre-Study Assessment';
      case StudySessionStatus.studying:
        return 'Study Phase - Review Materials';
      case StudySessionStatus.postStudy:
        return 'Post-Study Assessment';
      case StudySessionStatus.generatingAnalytics:
        return 'Generating Analytics...';
      case StudySessionStatus.completed:
        return 'Session Complete!';
      case StudySessionStatus.paused:
        return 'Session Paused';
    }
  }

  String get currentPhaseDescription {
    final session = _currentSession;
    if (session == null) return 'Get ready to practice active recall!';
    
    switch (session.status) {
      case StudySessionStatus.preparing:
        return 'Setting up your Active Recall session with personalized flashcards...';
      case StudySessionStatus.preStudy:
        return 'Test your current knowledge before studying the materials.';
      case StudySessionStatus.studying:
        return 'Review your study materials, then proceed to the post-study assessment.';
      case StudySessionStatus.postStudy:
        return 'Test your knowledge after studying to measure improvement.';
      case StudySessionStatus.generatingAnalytics:
        return 'Analyzing your learning progress and generating insights...';
      case StudySessionStatus.completed:
        return 'Great work! Review your learning analytics below.';
      case StudySessionStatus.paused:
        return 'Session is paused. Resume when ready.';
    }
  }

  /// Initialize a new Active Recall session
  Future<ActiveRecallSession> initializeSession({
    required String userId,
    required Module module,
    ActiveRecallSettings? customSettings,
  }) async {
    try {
      print('🧠 [ACTIVE RECALL] Initializing session for module: ${module.title}');
      
      // Load or use provided settings
      _settings = customSettings ?? await getUserActiveRecallSettings(userId);
      print('🧠 [ACTIVE RECALL] Using settings: $_settings');
      
      // Validate settings
      final validationError = _settings.validate();
      if (validationError != null) {
        throw Exception('Invalid Active Recall settings: $validationError');
      }
      
      // Create session in database
      final sessionData = {
        'user_id': userId,
        'module_id': module.id,
        'status': StudySessionStatus.preparing.name,
        'session_data': {
          'module_title': module.title,
          'total_materials': module.materials.length,
          'settings': _settings.toJson(),
        },
      };

      final response = await SupabaseService.client
          .from('active_recall_sessions')
          .insert(sessionData)
          .select()
          .single();

      _currentSession = ActiveRecallSession.fromJson(response);
      _sessionFlashcards.clear();
      _sessionAttempts.clear();
      _currentFlashcardIndex = 0;
      _sessionAnalytics = null;
      _processingError = null;
      
      // Generate flashcards based on settings
      await _generateFlashcards(module);
      
      print('✅ [ACTIVE RECALL] Session initialized with ID: ${_currentSession!.id}');
      print('📚 [ACTIVE RECALL] Generated ${_sessionFlashcards.length} flashcards');
      notifyListeners();
      
      return _currentSession!;
      
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to initialize session: $e');
      _processingError = 'Failed to initialize session: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Generate flashcards based on user settings
  Future<void> _generateFlashcards(Module module) async {
    try {
      _isGeneratingFlashcards = true;
      notifyListeners();
      
      print('🧠 [ACTIVE RECALL] Generating flashcards with settings: ${_settings.flashcardsPerSession} cards');
      
      // Use AI service to generate flashcards with settings
      final flashcards = await _aiService.generateFlashcardsFromMaterials(
        module.materials,
        module.title,
        settings: _settings, // Pass settings to AI service
      );
      
      // Filter by preferred types and difficulties
      final filteredFlashcards = flashcards.where((flashcard) {
        return _settings.preferredFlashcardTypes.contains(flashcard.type) &&
               _settings.preferredDifficulties.contains(flashcard.difficulty);
      }).toList();
      
      // Take the desired number of flashcards
      _sessionFlashcards = filteredFlashcards.take(_settings.flashcardsPerSession).toList();
      
      // If we don't have enough flashcards after filtering, add more
      if (_sessionFlashcards.length < _settings.flashcardsPerSession) {
        final needed = _settings.flashcardsPerSession - _sessionFlashcards.length;
        final remaining = flashcards.where((f) => !_sessionFlashcards.contains(f)).take(needed);
        _sessionFlashcards.addAll(remaining);
      }
      
      // Save flashcards to database
      await _saveFlashcardsToDatabase();
      
      print('✅ [ACTIVE RECALL] Generated ${_sessionFlashcards.length} flashcards matching user preferences');
      
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to generate flashcards: $e');
      _processingError = 'Failed to generate flashcards: $e';
      rethrow;
    } finally {
      _isGeneratingFlashcards = false;
      notifyListeners();
    }
  }

  /// Start the pre-study assessment
  Future<void> startPreStudyAssessment() async {
    if (_currentSession == null) {
      throw Exception('No session initialized');
    }

    try {
      print('🧠 [ACTIVE RECALL] Starting pre-study assessment');
      
      await _updateSessionStatus(StudySessionStatus.preStudy);
      _currentFlashcardIndex = 0;
      
      print('✅ [ACTIVE RECALL] Pre-study assessment started');
      
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to start pre-study assessment: $e');
      rethrow;
    }
  }

  /// Submit answer for current flashcard
  Future<void> submitAnswer({
    required String userAnswer,
    required int responseTimeSeconds,
    bool isPreStudy = false,
  }) async {
    if (_currentSession == null || currentFlashcard == null) {
      throw Exception('No active session or current flashcard');
    }

    try {
      _isProcessingAnswer = true;
      notifyListeners();

      final flashcard = currentFlashcard!;
      final isCorrect = _evaluateAnswer(userAnswer, flashcard);

      // Create attempt record
      final attempt = ActiveRecallAttempt(
        id: '${_currentSession!.id}_${flashcard.id}_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: _currentSession!.id,
        flashcardId: flashcard.id,
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        responseTimeSeconds: responseTimeSeconds,
        attemptedAt: DateTime.now(),
        isPreStudy: isPreStudy,
      );

      _sessionAttempts.add(attempt);

      // Save attempt to database
      await _saveAttemptToDatabase(attempt);

      print('📝 [ACTIVE RECALL] Answer submitted: ${isCorrect ? '✅ CORRECT' : '❌ WRONG'} (${isPreStudy ? 'Pre' : 'Post'}-study)');

    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to submit answer: $e');
      _processingError = 'Failed to submit answer: $e';
      rethrow;
    } finally {
      _isProcessingAnswer = false;
      notifyListeners();
    }
  }

  /// Move to next flashcard
  Future<void> nextFlashcard() async {
    if (_currentSession == null) return;

    _currentFlashcardIndex++;
    
    // Check if we've completed all flashcards in current phase
    if (_currentFlashcardIndex >= _sessionFlashcards.length) {
      if (_currentSession!.status == StudySessionStatus.preStudy) {
        // Always proceed to study phase after pre-study assessment
        await _updateSessionStatus(StudySessionStatus.studying);
      } else if (_currentSession!.status == StudySessionStatus.postStudy) {
        // Complete session after post-study assessment
        await _completeSession();
      }
    }

    notifyListeners();
  }

  /// Start the study phase (review materials)
  Future<void> startStudyPhase() async {
    if (_currentSession == null) {
      throw Exception('No session initialized');
    }

    try {
      print('🧠 [ACTIVE RECALL] Starting study phase');
      
      await _updateSessionStatus(StudySessionStatus.studying);
      
      print('✅ [ACTIVE RECALL] Study phase started');
      
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to start study phase: $e');
      rethrow;
    }
  }

  /// Start the post-study assessment
  Future<void> startPostStudyAssessment() async {
    if (_currentSession == null) {
      throw Exception('No session initialized');
    }

    try {
      print('🧠 [ACTIVE RECALL] Starting post-study assessment');
      
      await _updateSessionStatus(StudySessionStatus.postStudy);
      _currentFlashcardIndex = 0; // Reset to start flashcards again
      
      print('✅ [ACTIVE RECALL] Post-study assessment started');
      
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to start post-study assessment: $e');
      rethrow;
    }
  }

  /// Complete the session
  Future<void> _completeSession() async {
    if (_currentSession == null) return;

    try {
      print('🧠 [ACTIVE RECALL] Completing session');
      
      await _updateSessionStatus(StudySessionStatus.completed);
      
      await SupabaseService.client
          .from('active_recall_sessions')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(
        status: StudySessionStatus.completed,
        completedAt: DateTime.now(),
      );
      
      print('🎉 [ACTIVE RECALL] Session completed!');
      notifyListeners();
      
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to complete session: $e');
      rethrow;
    }
  }

  /// Get session results
  Future<StudySessionResults> getSessionResults() async {
    if (_currentSession == null) {
      throw Exception('No session available');
    }

    return StudySessionResults.calculate(_sessionFlashcards, _sessionAttempts);
  }

  /// Generate comprehensive analytics for the session
  Future<StudySessionAnalytics?> generateSessionAnalytics({
    required String userId,
    required Module module,
    required Course course,
  }) async {
    if (_currentSession == null) return null;

    try {
      print('📊 [ACTIVE RECALL ANALYTICS] Generating session analytics...');
      
      await _updateSessionStatus(StudySessionStatus.generatingAnalytics);
      
      // Use the existing StudyAnalyticsService
      _sessionAnalytics = await _analyticsService.generateSessionAnalytics(
        sessionId: _currentSession!.id,
        userId: userId,
        moduleId: module.id,
        flashcards: _sessionFlashcards,
        attempts: _sessionAttempts,
        course: course,
        module: module,
      );
      
      print('✅ [ACTIVE RECALL ANALYTICS] Analytics generated successfully');
      notifyListeners();
      
      return _sessionAnalytics;
      
    } catch (e) {
      print('❌ [ACTIVE RECALL ANALYTICS] Failed to generate analytics: $e');
      return null;
    }
  }

  /// Force stop the session
  Future<void> forceStopSession() async {
    if (_currentSession == null) return;

    try {
      await _updateSessionStatus(StudySessionStatus.paused);
      _reset();
      print('⏹️ [ACTIVE RECALL] Session force stopped');
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to stop session: $e');
    }
  }

  /// Reset service state
  void _reset() {
    _currentSession = null;
    _sessionFlashcards.clear();
    _sessionAttempts.clear();
    _currentFlashcardIndex = 0;
    _isProcessingAnswer = false;
    _isGeneratingFlashcards = false;
    _sessionAnalytics = null;
    _processingError = null;
    notifyListeners();
  }

  /// Save user Active Recall settings to database
  Future<void> saveUserActiveRecallSettings(String userId, ActiveRecallSettings settings) async {
    try {
      print('💾 [ACTIVE RECALL SETTINGS] Saving settings for user: $userId');
      
      // Validate settings first
      final validationError = settings.validate();
      if (validationError != null) {
        throw ArgumentError('Invalid settings: $validationError');
      }
      
      // Validate user ID
      if (userId.isEmpty) {
        throw ArgumentError('User ID cannot be empty');
      }
      
      final settingsData = {
        'user_id': userId,
        ...settings.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if user settings exist
      final existingSettings = await SupabaseService.client
          .from('user_active_recall_settings')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingSettings != null) {
        // Update existing settings
        await SupabaseService.client
            .from('user_active_recall_settings')
            .update(settingsData)
            .eq('user_id', userId);
        print('✅ [ACTIVE RECALL SETTINGS] Settings updated for existing user');
      } else {
        // Insert new settings
        settingsData['created_at'] = DateTime.now().toIso8601String();
        await SupabaseService.client
            .from('user_active_recall_settings')
            .insert(settingsData);
        print('✅ [ACTIVE RECALL SETTINGS] Settings created for new user');
      }

      // Update local settings
      _settings = settings;
      notifyListeners();

      print('✅ [ACTIVE RECALL SETTINGS] Settings saved successfully');
      
    } catch (e) {
      print('❌ [ACTIVE RECALL SETTINGS] Failed to save settings: $e');
      
      // Provide more specific error messages
      if (e.toString().contains('check constraint')) {
        throw Exception('Settings contain invalid values that violate database constraints. Please adjust your settings.');
      } else if (e.toString().contains('foreign key')) {
        throw Exception('User not found. Please ensure you are logged in.');
      } else if (e.toString().contains('duplicate key')) {
        throw Exception('Settings conflict detected. Please try again.');
      } else if (e is ArgumentError) {
        rethrow; // Re-throw validation errors as-is
      } else {
        throw Exception('Failed to save settings. Please check your connection and try again.');
      }
    }
  }

  /// Load user Active Recall settings from database
  Future<ActiveRecallSettings> getUserActiveRecallSettings(String userId) async {
    try {
      print('📖 [ACTIVE RECALL SETTINGS] Loading settings for user: $userId');
      
      final response = await SupabaseService.client
          .from('user_active_recall_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final settings = ActiveRecallSettings.fromJson(response);
        print('✅ [ACTIVE RECALL SETTINGS] Settings loaded: $settings');
        return settings;
      } else {
        print('📝 [ACTIVE RECALL SETTINGS] No saved settings found, using defaults');
        return const ActiveRecallSettings();
      }
      
    } catch (e) {
      print('❌ [ACTIVE RECALL SETTINGS] Failed to load settings: $e, using defaults');
      return const ActiveRecallSettings();
    }
  }

  // Helper methods

  /// Update session status in database
  Future<void> _updateSessionStatus(StudySessionStatus status) async {
    if (_currentSession == null) return;

    try {
      await SupabaseService.client
          .from('active_recall_sessions')
          .update({'status': status.name})
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(status: status);
      notifyListeners();
      
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to update session status: $e');
      rethrow;
    }
  }

  /// Evaluate user answer against flashcard
  bool _evaluateAnswer(String userAnswer, ActiveRecallFlashcard flashcard) {
    final userLower = userAnswer.toLowerCase().trim();
    final correctLower = flashcard.answer.toLowerCase().trim();
    
    switch (flashcard.type) {
      case FlashcardType.fillInBlank:
      case FlashcardType.definitionRecall:
        // Check for exact match first
        if (userLower == correctLower) return true;
        
        // Check for partial match with key words for more flexible evaluation
        final correctWords = correctLower.split(' ').where((w) => w.length > 3).toList();
        final userWords = userLower.split(' ');
        
        int matches = 0;
        for (final word in correctWords) {
          if (userWords.any((uw) => uw.contains(word) || word.contains(uw))) {
            matches++;
          }
        }
        
        // Consider correct if at least 60% of key words match
        return correctWords.isNotEmpty && (matches / correctWords.length) >= 0.6;
        
      case FlashcardType.conceptApplication:
        // For concept application, be more lenient with evaluation
        if (userLower == correctLower) return true;
        
        // Check if user answer contains key concepts from the correct answer
        final correctWords = correctLower.split(' ').where((w) => w.length > 4).toList();
        final userWords = userLower.split(' ');
        
        int matches = 0;
        for (final word in correctWords) {
          if (userWords.any((uw) => uw.contains(word) || word.contains(uw))) {
            matches++;
          }
        }
        
        // Consider correct if at least 40% of key concepts match (more lenient for application questions)
        return correctWords.isNotEmpty && (matches / correctWords.length) >= 0.4;
    }
  }

  /// Save flashcards to database
  Future<void> _saveFlashcardsToDatabase() async {
    try {
      final flashcardsData = _sessionFlashcards.map((f) => f.toJson()).toList();
      
      await SupabaseService.client
          .from('active_recall_flashcards')
          .insert(flashcardsData);
          
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to save flashcards: $e');
      rethrow;
    }
  }

  /// Save attempt to database
  Future<void> _saveAttemptToDatabase(ActiveRecallAttempt attempt) async {
    try {
      await SupabaseService.client
          .from('active_recall_attempts')
          .insert(attempt.toJson());
          
    } catch (e) {
      print('❌ [ACTIVE RECALL] Failed to save attempt: $e');
      rethrow;
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    _reset();
    super.dispose();
  }
}