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

  /// Generate questions for a specific material using AI
  Future<List<RetrievalPracticeQuestion>> _generateQuestionsForMaterial(
    CourseMaterial material,
    Module module,
    int questionCount,
  ) async {
    try {
      // Create prompt for AI question generation
      final prompt = '''
Generate $questionCount diverse practice questions from the following educational material:

Material Title: ${material.title}
Material Type: ${material.fileType}
Module: ${module.title}

Requirements:
1. Create a mix of question types: multiple choice, short answer, fill-in-the-blank, true/false
2. Vary difficulty levels (easy, medium, hard)
3. Focus on key concepts and important details
4. Ensure questions test retrieval, not just recognition
5. Include concept tags for each question

For each question, provide:
- Question type
- Question text
- Correct answer
- Options (for multiple choice)
- Difficulty level (1=easy, 2=medium, 3=hard)
- Concept tags (array of key concepts)

Format as JSON array with this structure:
[
  {
    "question_type": "multiple_choice",
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
      // Extract JSON from response (handle potential markdown formatting)
      String jsonString = response;
      if (response.contains('```json')) {
        final startIndex = response.indexOf('```json') + 7;
        final endIndex = response.lastIndexOf('```');
        jsonString = response.substring(startIndex, endIndex).trim();
      }

      final questionsJson = List<Map<String, dynamic>>.from(
        jsonDecode(jsonString),
      );

      return questionsJson.map((questionData) {
        return RetrievalPracticeQuestion(
          id: _generateQuestionId(),
          sessionId: _currentSession!.id,
          moduleId: module.id,
          materialId: material.id,
          questionType: _parseQuestionType(questionData['question_type']),
          questionText: questionData['question_text'],
          correctAnswer: questionData['correct_answer'],
          options: questionData['options'] != null 
              ? List<String>.from(questionData['options'])
              : null,
          difficultyLevel: DifficultyLevel.fromValue(questionData['difficulty_level'] ?? 1),
          conceptTags: List<String>.from(questionData['concept_tags'] ?? []),
          questionMetadata: {
            'generated_by': 'ai',
            'material_title': material.title,
            'generation_timestamp': DateTime.now().toIso8601String(),
          },
          createdAt: DateTime.now(),
        );
      }).toList();

    } catch (e) {
      // Failed to parse AI response: $e
      return _generateFallbackQuestions(material, module, 2);
    }
  }

  /// Generate fallback questions when AI fails
  List<RetrievalPracticeQuestion> _generateFallbackQuestions(
    CourseMaterial material,
    Module module,
    int questionCount,
  ) {
    final questions = <RetrievalPracticeQuestion>[];
    
    // Generate basic questions based on material title and module
    for (int i = 0; i < questionCount; i++) {
      questions.add(
        RetrievalPracticeQuestion(
          id: _generateQuestionId(),
          sessionId: _currentSession!.id,
          moduleId: module.id,
          materialId: material.id,
          questionType: RetrievalQuestionType.shortAnswer,
          questionText: 'What are the key concepts covered in "${material.title}"?',
          correctAnswer: 'Key concepts from ${material.title}',
          difficultyLevel: DifficultyLevel.medium,
          conceptTags: [material.title.toLowerCase().replaceAll(' ', '_')],
          questionMetadata: {
            'generated_by': 'fallback',
            'material_title': material.title,
          },
          createdAt: DateTime.now(),
        ),
      );
    }
    
    return questions;
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
      case 'multiple_choice':
        return RetrievalQuestionType.multipleChoice;
      case 'short_answer':
        return RetrievalQuestionType.shortAnswer;
      case 'fill_in_blank':
        return RetrievalQuestionType.fillInBlank;
      case 'true_false':
        return RetrievalQuestionType.trueFalse;
      default:
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

  @override
  void dispose() {
    _reset();
    super.dispose();
  }
}

