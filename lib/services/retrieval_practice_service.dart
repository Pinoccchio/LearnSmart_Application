import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/course_models.dart';
import '../models/retrieval_practice_models.dart';
import '../models/study_analytics_models.dart';
import '../services/supabase_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/study_analytics_service.dart';

class RetrievalPracticeService extends ChangeNotifier {
  RetrievalPracticeSession? _currentSession;
  List<RetrievalPracticeQuestion> _sessionQuestions = [];
  List<RetrievalPracticeAttempt> _sessionAttempts = [];
  RetrievalPracticeSettings _settings = RetrievalPracticeSettings();
  int _currentQuestionIndex = 0;
  bool _isProcessingAnswer = false;
  
  final GeminiAIService _geminiService = GeminiAIService();
  final StudyAnalyticsService _analyticsService = StudyAnalyticsService();
  final Uuid _uuid = const Uuid();

  // Getters
  RetrievalPracticeSession? get currentSession => _currentSession;
  List<RetrievalPracticeQuestion> get sessionQuestions => _sessionQuestions;
  List<RetrievalPracticeAttempt> get sessionAttempts => _sessionAttempts;
  RetrievalPracticeSettings get settings => _settings;
  int get currentQuestionIndex => _currentQuestionIndex;
  bool get isProcessingAnswer => _isProcessingAnswer;
  
  RetrievalPracticeQuestion? get currentQuestion => 
      _sessionQuestions.isNotEmpty && _currentQuestionIndex < _sessionQuestions.length 
          ? _sessionQuestions[_currentQuestionIndex] 
          : null;

  bool get hasMoreQuestions => _currentQuestionIndex < _sessionQuestions.length - 1;
  double get progress => _sessionQuestions.isEmpty 
      ? 0.0 
      : (_currentQuestionIndex / _sessionQuestions.length).clamp(0.0, 1.0);

  /// Initialize a new Retrieval Practice session
  Future<void> initializeSession({
    required String userId,
    required Module module,
    RetrievalPracticeSettings? customSettings,
  }) async {
    try {
      // Initializing retrieval practice session
      
      _settings = customSettings ?? RetrievalPracticeSettings();
      
      if (customSettings != null) {
        print('✅ [SERVICE] Using custom settings: ${_settings.questionsPerSession} questions');
      } else {
        print('⚠️ [SERVICE] Using default settings: ${_settings.questionsPerSession} questions (no custom settings provided)');
      }
      
      // Create session in database
      final sessionData = {
        'user_id': userId,
        'module_id': module.id,
        'status': RetrievalSessionStatus.preparing.name,
        'total_questions_planned': _settings.questionsPerSession,
        'questions_completed': 0,
        'current_question_index': 0,
        'session_data': _settings.toJson(),
      };

      final response = await SupabaseService.client
          .from('retrieval_practice_sessions')
          .insert(sessionData)
          .select()
          .single();

      _currentSession = RetrievalPracticeSession.fromJson(response);
      
      // Generate questions for the session
      await _generateQuestions(module);
      
      // Session initialized successfully
      notifyListeners();
      
    } catch (e) {
      // Failed to initialize session: $e
      rethrow;
    }
  }

  /// Generate questions for the session using AI
  Future<void> _generateQuestions(Module module) async {
    try {
      // Generating questions using AI
      
      final questions = <RetrievalPracticeQuestion>[];
      
      // Generate questions from each material
      for (final material in module.materials) {
        final questionsPerMaterial = (_settings.questionsPerSession / module.materials.length).ceil();
        
        final materialQuestions = await _generateQuestionsForMaterial(
          material,
          module,
          questionsPerMaterial,
        );
        
        questions.addAll(materialQuestions);
      }
      
      // Shuffle and trim to desired count
      questions.shuffle();
      _sessionQuestions = questions.take(_settings.questionsPerSession).toList();
      
      // Save questions to database
      await _saveQuestionsToDatabase();
      
      // Questions generated successfully
      
    } catch (e) {
      // Failed to generate questions: $e
      rethrow;
    }
  }

  /// Generate questions for a specific material using AI - respecting user settings
  Future<List<RetrievalPracticeQuestion>> _generateQuestionsForMaterial(
    CourseMaterial material,
    Module module,
    int questionCount,
  ) async {
    try {
      // Build prompt with user's preferred question types
      final preferredTypes = _settings.preferredQuestionTypes.map((type) => type.name).join(', ');
      
      final prompt = '''
Generate $questionCount diverse practice questions from the following educational material:

Material Title: ${material.title}
Material Type: ${material.fileType}
Module: ${module.title}

User Preferences:
- Preferred question types: $preferredTypes
- Questions per session: ${_settings.questionsPerSession}
- Allow hints: ${_settings.allowHints}
- Require confidence rating: ${_settings.requireConfidenceRating}

Requirements:
1. ONLY create question types from: $preferredTypes
2. Vary difficulty levels (easy, medium, hard)
3. Focus on key concepts and important details
4. Ensure questions test retrieval, not just recognition
5. Include concept tags for each question

For each question, provide:
- Question type (MUST be from: $preferredTypes)
- Question text
- Correct answer
- Options (REQUIRED for multiple choice - provide exactly 4 options)
- Difficulty level (1=easy, 2=medium, 3=hard)
- Concept tags (array of key concepts)

Format as JSON array with this structure:
[
  {
    "question_type": "multipleChoice",
    "question_text": "What is...",
    "correct_answer": "Option A",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "difficulty_level": 2,
    "concept_tags": ["concept1", "concept2"]
  }
]

Material content will be extracted and processed for question generation.
''';

      final response = await _geminiService.generateContentFromMaterials(
        [material],
        prompt,
      );

      return _parseAIQuestionsResponse(response, material, module);
      
    } catch (e) {
      // Failed to generate questions for material: $e
      // Return fallback questions if AI fails
      return _generateFallbackQuestions(material, module, questionCount);
    }
  }

  /// Parse AI response and create question objects
  List<RetrievalPracticeQuestion> _parseAIQuestionsResponse(
    String response,
    CourseMaterial material,
    Module module,
  ) {
    try {
      print('🔍 [AI PARSING] Starting to parse AI response for material: ${material.title}');
      print('📝 [AI PARSING] Raw response length: ${response.length} characters');
      
      // Extract JSON from response (handle potential markdown formatting)
      String jsonString = response;
      if (response.contains('```json')) {
        final startIndex = response.indexOf('```json') + 7;
        final endIndex = response.lastIndexOf('```');
        jsonString = response.substring(startIndex, endIndex).trim();
        print('📋 [AI PARSING] Extracted JSON from markdown formatting');
      }

      print('🔧 [AI PARSING] JSON string to parse: ${jsonString.length > 500 ? jsonString.substring(0, 500) + '...' : jsonString}');
      
      final questionsJson = List<Map<String, dynamic>>.from(
        jsonDecode(jsonString),
      );
      
      print('✅ [AI PARSING] Successfully decoded ${questionsJson.length} questions from AI response');

      return questionsJson.map((questionData) {
        final questionType = _parseQuestionType(questionData['question_type']);
        List<String>? options = questionData['options'] != null 
            ? List<String>.from(questionData['options'])
            : null;
            
        // Critical validation: Multiple choice questions MUST have options
        if (questionType == RetrievalQuestionType.multipleChoice) {
          if (options == null || options.isEmpty) {
            print('⚠️ [AI PARSING] Multiple choice question missing options, generating fallback options');
            print('   Question: ${questionData['question_text']}');
            print('   Original options: $options');
            
            // Generate fallback options
            final correctAnswer = questionData['correct_answer'] ?? 'Unknown';
            options = [
              correctAnswer,
              'Alternative option A',
              'Alternative option B', 
              'Alternative option C',
            ];
          }
          
          // Ensure we have exactly 4 options
          if (options.length < 4) {
            final missingCount = 4 - options.length;
            for (int i = 0; i < missingCount; i++) {
              options.add('Additional option ${String.fromCharCode(65 + options.length)}');
            }
          }
          
          print('✅ [AI PARSING] Multiple choice question validated with ${options.length} options');
        }
        
        return RetrievalPracticeQuestion(
          id: _generateQuestionId(),
          sessionId: _currentSession!.id,
          moduleId: module.id,
          materialId: material.id,
          questionType: questionType,
          questionText: questionData['question_text'],
          correctAnswer: questionData['correct_answer'],
          options: options,
          difficultyLevel: DifficultyLevel.fromValue(questionData['difficulty_level'] ?? 1),
          conceptTags: List<String>.from(questionData['concept_tags'] ?? []),
          questionMetadata: {
            'generated_by': 'ai',
            'material_title': material.title,
            'generation_timestamp': DateTime.now().toIso8601String(),
            'options_validated': questionType == RetrievalQuestionType.multipleChoice,
          },
          createdAt: DateTime.now(),
        );
      }).toList();

    } catch (e) {
      print('❌ [AI PARSING] Failed to parse AI response: $e');
      print('📋 [AI PARSING] Raw response that failed: ${response.length > 1000 ? response.substring(0, 1000) + '...' : response}');
      print('🔧 [AI PARSING] Using fallback question generation');
      return _generateFallbackQuestions(material, module, 2);
    }
  }

  /// Generate fallback questions when AI fails - respecting user settings
  List<RetrievalPracticeQuestion> _generateFallbackQuestions(
    CourseMaterial material,
    Module module,
    int questionCount,
  ) {
    final questions = <RetrievalPracticeQuestion>[];
    
    // Use user's preferred question types for fallback
    final preferredTypes = _settings.preferredQuestionTypes;
    
    // Generate questions based on user preferences
    for (int i = 0; i < questionCount; i++) {
      final questionType = preferredTypes[i % preferredTypes.length];
      
      final question = _generateFallbackQuestionOfType(
        questionType,
        material,
        module,
        i,
      );
      
      questions.add(question);
    }
    
    return questions;
  }

  /// Generate a single fallback question of specified type
  RetrievalPracticeQuestion _generateFallbackQuestionOfType(
    RetrievalQuestionType questionType,
    CourseMaterial material,
    Module module,
    int questionIndex,
  ) {
    final materialTitle = material.title;
    String questionText;
    String correctAnswer;
    List<String>? options;
    
    switch (questionType) {
      case RetrievalQuestionType.multipleChoice:
        questionText = 'What is a key concept covered in "$materialTitle"?';
        correctAnswer = 'Key concepts and principles';
        options = [
          'Key concepts and principles', // Correct answer
          'Unrelated administrative details',
          'Historical background information', 
          'Technical specifications only',
        ];
        break;
        
      case RetrievalQuestionType.trueFalse:
        questionText = 'The material "$materialTitle" contains important educational content relevant to this module.';
        correctAnswer = 'True';
        break;
        
      case RetrievalQuestionType.shortAnswer:
        questionText = 'Describe the main topics covered in "$materialTitle".';
        correctAnswer = 'Main topics include key concepts and principles from $materialTitle';
        break;
        
      case RetrievalQuestionType.fillInBlank:
        questionText = 'The material titled "[BLANK]" covers important concepts for this module.';
        correctAnswer = materialTitle;
        break;
    }
    
    return RetrievalPracticeQuestion(
      id: _generateQuestionId(),
      sessionId: _currentSession!.id,
      moduleId: module.id,
      materialId: material.id,
      questionType: questionType,
      questionText: questionText,
      correctAnswer: correctAnswer,
      options: options,
      difficultyLevel: DifficultyLevel.values[questionIndex % 3], // Vary difficulty
      conceptTags: [materialTitle.toLowerCase().replaceAll(' ', '_')],
      questionMetadata: {
        'generated_by': 'fallback',
        'material_title': materialTitle,
        'question_type': questionType.name,
      },
      createdAt: DateTime.now(),
    );
  }

  /// Start the practice session
  Future<void> startSession() async {
    if (_currentSession == null) {
      throw Exception('No session to start');
    }

    try {
      await SupabaseService.client
          .from('retrieval_practice_sessions')
          .update({
            'status': RetrievalSessionStatus.active.name,
            'started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(
        status: RetrievalSessionStatus.active,
        startedAt: DateTime.now(),
      );

      // Session started successfully
      notifyListeners();

    } catch (e) {
      // Failed to start session: $e
      rethrow;
    }
  }

  /// Submit answer for current question
  Future<void> submitAnswer({
    required String userAnswer,
    required int responseTimeSeconds,
    int? confidenceLevel,
    bool hintUsed = false,
  }) async {
    if (_currentSession == null || currentQuestion == null) {
      throw Exception('No active session or current question');
    }

    try {
      _isProcessingAnswer = true;
      notifyListeners();

      final question = currentQuestion!;
      final isCorrect = _evaluateAnswer(userAnswer, question);

      // Create attempt record
      final attempt = RetrievalPracticeAttempt(
        id: _generateAttemptId(),
        sessionId: _currentSession!.id,
        questionId: question.id,
        userId: _currentSession!.userId,
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        responseTimeSeconds: responseTimeSeconds,
        confidenceLevel: confidenceLevel,
        hintUsed: hintUsed,
        attemptMetadata: {
          'question_type': question.questionType.name,
          'difficulty': question.difficultyLevel.name,
          'concept_tags': question.conceptTags,
        },
        attemptedAt: DateTime.now(),
      );

      _sessionAttempts.add(attempt);

      // Save attempt to database
      await _saveAttemptToDatabase(attempt);

      // Update spaced repetition schedule if enabled
      if (_settings.enableSpacedRepetition) {
        await _updateSpacedRepetitionSchedule(question, isCorrect);
      }

      print('📝 [ANSWER SUBMITTED] Question ${_currentQuestionIndex + 1}: ${isCorrect ? '✅ CORRECT' : '❌ WRONG'}');

    } catch (e) {
      print('❌ [SUBMIT ANSWER] Failed to submit answer: $e');
      rethrow;
    } finally {
      _isProcessingAnswer = false;
      notifyListeners();
    }
  }

  /// Move to next question
  Future<void> nextQuestion() async {
    if (_currentSession == null) return;

    _currentQuestionIndex++;
    
    // Update session progress
    await SupabaseService.client
        .from('retrieval_practice_sessions')
        .update({
          'current_question_index': _currentQuestionIndex,
          'questions_completed': _sessionAttempts.length,
        })
        .eq('id', _currentSession!.id);

    _currentSession = _currentSession!.copyWith(
      currentQuestionIndex: _currentQuestionIndex,
      questionsCompleted: _sessionAttempts.length,
    );

    // Check if session is complete
    if (_currentQuestionIndex >= _sessionQuestions.length) {
      await _completeSession();
    }

    notifyListeners();
  }

  /// Complete the session
  Future<void> _completeSession() async {
    if (_currentSession == null) return;

    try {
      await SupabaseService.client
          .from('retrieval_practice_sessions')
          .update({
            'status': RetrievalSessionStatus.completed.name,
            'completed_at': DateTime.now().toIso8601String(),
            'questions_completed': _sessionAttempts.length,
          })
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(
        status: RetrievalSessionStatus.completed,
        completedAt: DateTime.now(),
        questionsCompleted: _sessionAttempts.length,
      );

      print('🎉 [RETRIEVAL PRACTICE] Session completed');
      notifyListeners();

    } catch (e) {
      print('❌ [COMPLETE SESSION] Failed to complete session: $e');
      rethrow;
    }
  }

  /// Get session results
  Future<RetrievalPracticeResults> getSessionResults() async {
    if (_currentSession == null) {
      throw Exception('No active session');
    }

    return RetrievalPracticeResults.calculate(_sessionQuestions, _sessionAttempts);
  }

  /// Generate comprehensive analytics for the session
  Future<StudySessionAnalytics> generateSessionAnalytics({
    required String userId,
    required Module module,
    required Course course,
  }) async {
    return await _analyticsService.generateSessionAnalytics(
      sessionId: _currentSession!.id,
      userId: userId,
      moduleId: module.id,
      flashcards: [], // Retrieval Practice uses questions instead of flashcards
      attempts: [], // Retrieval Practice tracks attempts differently
      course: course,
      module: module,
    );
  }

  /// Force stop the session
  Future<void> forceStopSession() async {
    if (_currentSession == null) return;

    try {
      await SupabaseService.client
          .from('retrieval_practice_sessions')
          .update({
            'status': RetrievalSessionStatus.paused.name,
          })
          .eq('id', _currentSession!.id);

      _reset();
      print('⏹️ [RETRIEVAL PRACTICE] Session force stopped');

    } catch (e) {
      print('❌ [FORCE STOP] Failed to stop session: $e');
    }
  }

  /// Reset service state
  void _reset() {
    _currentSession = null;
    _sessionQuestions.clear();
    _sessionAttempts.clear();
    _currentQuestionIndex = 0;
    _isProcessingAnswer = false;
    notifyListeners();
  }

  // Spaced Repetition Implementation (SM-2 Algorithm)
  Future<void> _updateSpacedRepetitionSchedule(
    RetrievalPracticeQuestion question,
    bool isCorrect,
  ) async {
    try {
      for (final conceptTag in question.conceptTags) {
        await _updateConceptSchedule(conceptTag, isCorrect);
      }
    } catch (e) {
      print('❌ [SPACED REPETITION] Failed to update schedule: $e');
    }
  }

  Future<void> _updateConceptSchedule(String conceptTag, bool isCorrect) async {
    try {
      // Get existing schedule or create new one
      final response = await SupabaseService.client
          .from('retrieval_practice_schedules')
          .select()
          .eq('user_id', _currentSession!.userId)
          .eq('module_id', _currentSession!.moduleId)
          .eq('concept_tag', conceptTag)
          .maybeSingle();

      RetrievalPracticeSchedule schedule;
      
      if (response != null) {
        schedule = RetrievalPracticeSchedule.fromJson(response);
        schedule = _calculateNextReview(schedule, isCorrect);
        
        // Update existing schedule
        await SupabaseService.client
            .from('retrieval_practice_schedules')
            .update(schedule.toJson())
            .eq('id', schedule.id);
      } else {
        // Create new schedule
        schedule = _createInitialSchedule(conceptTag, isCorrect);
        
        await SupabaseService.client
            .from('retrieval_practice_schedules')
            .insert(schedule.toJson());
      }

    } catch (e) {
      print('❌ [SPACED REPETITION] Failed to update concept schedule: $e');
    }
  }

  RetrievalPracticeSchedule _createInitialSchedule(String conceptTag, bool isCorrect) {
    final now = DateTime.now();
    final nextReview = isCorrect ? now.add(const Duration(days: 1)) : now;
    
    return RetrievalPracticeSchedule(
      id: _generateScheduleId(),
      userId: _currentSession!.userId,
      moduleId: _currentSession!.moduleId,
      conceptTag: conceptTag,
      easinessFactor: 2.5,
      repetitionNumber: isCorrect ? 1 : 0,
      interRepetitionInterval: isCorrect ? 1 : 0,
      nextReviewDate: nextReview,
      lastReviewDate: now,
      totalReviews: 1,
      successStreak: isCorrect ? 1 : 0,
      failureCount: isCorrect ? 0 : 1,
      scheduleMetadata: {'initial_result': isCorrect},
      createdAt: now,
      updatedAt: now,
    );
  }

  RetrievalPracticeSchedule _calculateNextReview(
    RetrievalPracticeSchedule schedule,
    bool isCorrect,
  ) {
    final now = DateTime.now();
    
    if (isCorrect) {
      // Successful recall - increase interval
      final newEasiness = schedule.easinessFactor + (0.1 - (5 - 4) * (0.08 + (5 - 4) * 0.02));
      final clampedEasiness = newEasiness.clamp(1.3, 2.5);
      
      int newInterval;
      final newRepetition = schedule.repetitionNumber + 1;
      
      if (newRepetition == 1) {
        newInterval = 1;
      } else if (newRepetition == 2) {
        newInterval = 6;
      } else {
        newInterval = (schedule.interRepetitionInterval * clampedEasiness).round();
      }
      
      return RetrievalPracticeSchedule(
        id: schedule.id,
        userId: schedule.userId,
        moduleId: schedule.moduleId,
        conceptTag: schedule.conceptTag,
        easinessFactor: clampedEasiness,
        repetitionNumber: newRepetition,
        interRepetitionInterval: newInterval,
        nextReviewDate: now.add(Duration(days: newInterval)),
        lastReviewDate: now,
        totalReviews: schedule.totalReviews + 1,
        successStreak: schedule.successStreak + 1,
        failureCount: schedule.failureCount,
        scheduleMetadata: {
          ...schedule.scheduleMetadata,
          'last_result': isCorrect,
          'updated_at': now.toIso8601String(),
        },
        createdAt: schedule.createdAt,
        updatedAt: now,
      );
    } else {
      // Failed recall - reset to beginning
      return RetrievalPracticeSchedule(
        id: schedule.id,
        userId: schedule.userId,
        moduleId: schedule.moduleId,
        conceptTag: schedule.conceptTag,
        easinessFactor: schedule.easinessFactor,
        repetitionNumber: 0,
        interRepetitionInterval: 0,
        nextReviewDate: now,
        lastReviewDate: now,
        totalReviews: schedule.totalReviews + 1,
        successStreak: 0,
        failureCount: schedule.failureCount + 1,
        scheduleMetadata: {
          ...schedule.scheduleMetadata,
          'last_result': isCorrect,
          'reset_at': now.toIso8601String(),
        },
        createdAt: schedule.createdAt,
        updatedAt: now,
      );
    }
  }

  // Helper methods
  bool _evaluateAnswer(String userAnswer, RetrievalPracticeQuestion question) {
    final userLower = userAnswer.toLowerCase().trim();
    final correctLower = question.correctAnswer.toLowerCase().trim();
    
    switch (question.questionType) {
      case RetrievalQuestionType.multipleChoice:
      case RetrievalQuestionType.trueFalse:
        return userLower == correctLower;
        
      case RetrievalQuestionType.shortAnswer:
      case RetrievalQuestionType.fillInBlank:
        // Check for exact match first
        if (userLower == correctLower) return true;
        
        // Check for partial match with key words
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
    }
  }

  RetrievalQuestionType _parseQuestionType(String typeString) {
    switch (typeString.toLowerCase()) {
      // Handle both snake_case and camelCase formats
      case 'multiple_choice':
      case 'multiplechoice':
        return RetrievalQuestionType.multipleChoice;
      case 'short_answer':
      case 'shortanswer':
        return RetrievalQuestionType.shortAnswer;
      case 'fill_in_blank':
      case 'fillinblank':
        return RetrievalQuestionType.fillInBlank;
      case 'true_false':
      case 'truefalse':
        return RetrievalQuestionType.trueFalse;
      default:
        print('⚠️ [QUESTION PARSING] Unknown question type: "$typeString", defaulting to multipleChoice');
        return RetrievalQuestionType.multipleChoice;
    }
  }

  String _generateQuestionId() => _uuid.v4();
  String _generateAttemptId() => _uuid.v4();
  String _generateScheduleId() => _uuid.v4();

  Future<void> _saveQuestionsToDatabase() async {
    try {
      final questionsData = _sessionQuestions.map((q) => q.toJson()).toList();
      
      await SupabaseService.client
          .from('retrieval_practice_questions')
          .insert(questionsData);
          
    } catch (e) {
      print('❌ [DATABASE] Failed to save questions: $e');
    }
  }

  Future<void> _saveAttemptToDatabase(RetrievalPracticeAttempt attempt) async {
    try {
      await SupabaseService.client
          .from('retrieval_practice_attempts')
          .insert(attempt.toJson());
          
    } catch (e) {
      print('❌ [DATABASE] Failed to save attempt: $e');
    }
  }

  /// Save user Retrieval Practice settings to database
  Future<void> saveUserRetrievalPracticeSettings(String userId, RetrievalPracticeSettings settings) async {
    try {
      print('💾 [RETRIEVAL SETTINGS] Saving settings for user: $userId');
      
      // Validate settings first
      final validationError = _validateSettings(settings);
      if (validationError != null) {
        throw ArgumentError('Invalid settings: $validationError');
      }
      
      // Validate user ID
      if (userId.isEmpty) {
        throw ArgumentError('User ID cannot be empty');
      }
      
      final settingsData = {
        'user_id': userId,
        'questions_per_session': settings.questionsPerSession,
        'preferred_question_types': settings.preferredQuestionTypes.map((type) => type.name).toList(),
        'allow_hints': settings.allowHints,
        'require_confidence_rating': settings.requireConfidenceRating,
        'show_feedback_after_each': settings.showFeedbackAfterEach,
        'adaptive_difficulty': settings.adaptiveDifficulty,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if user settings exist
      final existingSettings = await SupabaseService.client
          .from('user_retrieval_practice_settings')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existingSettings != null) {
        // Update existing settings
        await SupabaseService.client
            .from('user_retrieval_practice_settings')
            .update(settingsData)
            .eq('user_id', userId);
        print('✅ [RETRIEVAL SETTINGS] Settings updated for existing user');
      } else {
        // Insert new settings
        settingsData['created_at'] = DateTime.now().toIso8601String();
        await SupabaseService.client
            .from('user_retrieval_practice_settings')
            .insert(settingsData);
        print('✅ [RETRIEVAL SETTINGS] Settings created for new user');
      }

    } catch (e) {
      print('❌ [RETRIEVAL SETTINGS] Failed to save settings: $e');
      rethrow;
    }
  }

  /// Load user Retrieval Practice settings from database
  Future<RetrievalPracticeSettings> getUserRetrievalPracticeSettings(String userId) async {
    try {
      print('📖 [RETRIEVAL SETTINGS] Loading settings for user: $userId');
      
      final response = await SupabaseService.client
          .from('user_retrieval_practice_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final settings = RetrievalPracticeSettings(
          questionsPerSession: response['questions_per_session'] ?? 10,
          preferredQuestionTypes: (response['preferred_question_types'] as List? ?? ['multipleChoice', 'trueFalse', 'shortAnswer', 'fillInBlank'])
              .map((type) => _parseQuestionTypeFromString(type as String))
              .toList(),
          allowHints: response['allow_hints'] ?? true,
          requireConfidenceRating: response['require_confidence_rating'] ?? false,
          showFeedbackAfterEach: response['show_feedback_after_each'] ?? true,
          adaptiveDifficulty: response['adaptive_difficulty'] ?? false,
        );
        print('✅ [RETRIEVAL SETTINGS] Settings loaded: $settings');
        return settings;
      } else {
        print('📝 [RETRIEVAL SETTINGS] No saved settings found, using defaults');
        return RetrievalPracticeSettings();
      }
      
    } catch (e) {
      print('❌ [RETRIEVAL SETTINGS] Failed to load settings: $e, using defaults');
      return RetrievalPracticeSettings();
    }
  }

  /// Parse question type from string name  
  RetrievalQuestionType _parseQuestionTypeFromString(String typeName) {
    // Handle exact enum.name format (camelCase) which is what gets saved
    switch (typeName) {
      case 'multipleChoice':
        return RetrievalQuestionType.multipleChoice;
      case 'shortAnswer':
        return RetrievalQuestionType.shortAnswer;
      case 'fillInBlank':
        return RetrievalQuestionType.fillInBlank;
      case 'trueFalse':
        return RetrievalQuestionType.trueFalse;
      // Fallback for lowercase versions (backwards compatibility)
      case 'multiplechoice':
        return RetrievalQuestionType.multipleChoice;
      case 'shortanswer':
        return RetrievalQuestionType.shortAnswer;
      case 'fillinblank':
        return RetrievalQuestionType.fillInBlank;
      case 'truefalse':
        return RetrievalQuestionType.trueFalse;
      default:
        return RetrievalQuestionType.multipleChoice;
    }
  }

  /// Validate Retrieval Practice settings and return detailed error message if invalid
  String? _validateSettings(RetrievalPracticeSettings settings) {
    // Check questions per session
    if (settings.questionsPerSession < 5 || settings.questionsPerSession > 20) {
      return 'Questions per session must be between 5 and 20';
    }
    
    // Check that at least one question type is selected
    if (settings.preferredQuestionTypes.isEmpty) {
      return 'At least one question type must be selected';
    }
    
    return null; // All validations passed
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }
}

