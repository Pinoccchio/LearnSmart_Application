import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/feynman_models.dart';
import '../models/course_models.dart';
import '../models/study_analytics_models.dart';
import '../services/supabase_service.dart';
import '../services/study_analytics_service.dart';
import '../services/gemini_ai_service.dart';

class FeynmanService extends ChangeNotifier {
  // Current session state
  FeynmanSession? _currentSession;
  FeynmanExplanation? _currentExplanation;
  final List<FeynmanExplanation> _sessionExplanations = [];
  final List<FeynmanFeedback> _sessionFeedback = [];
  final List<FeynmanStudySuggestion> _sessionSuggestions = [];
  StudySessionAnalytics? _sessionAnalytics;
  
  // AI service for explanation analysis
  late final GeminiAIService _aiService;
  
  // Processing state
  bool _isProcessingExplanation = false;
  String? _processingError;

  FeynmanService() {
    _aiService = GeminiAIService();
  }
  
  // Getters
  FeynmanSession? get currentSession => _currentSession;
  FeynmanExplanation? get currentExplanation => _currentExplanation;
  List<FeynmanExplanation> get sessionExplanations => List.unmodifiable(_sessionExplanations);
  List<FeynmanFeedback> get sessionFeedback => List.unmodifiable(_sessionFeedback);
  List<FeynmanStudySuggestion> get sessionSuggestions => List.unmodifiable(_sessionSuggestions);
  StudySessionAnalytics? get sessionAnalytics => _sessionAnalytics;
  bool get isProcessingExplanation => _isProcessingExplanation;
  String? get processingError => _processingError;
  
  bool get canSubmitExplanation => 
      _currentSession != null && 
      (_currentSession!.status == FeynmanSessionStatus.explaining || 
       _currentSession!.status == FeynmanSessionStatus.reviewing) &&
      !_isProcessingExplanation;

  String get currentPhaseTitle {
    final session = _currentSession;
    if (session == null) return 'Feynman Technique';
    
    switch (session.status) {
      case FeynmanSessionStatus.preparing:
        return 'Preparing Session...';
      case FeynmanSessionStatus.explaining:
        return 'Explain: ${session.topic}';
      case FeynmanSessionStatus.reviewing:
        return 'Reviewing & Improving';
      case FeynmanSessionStatus.completed:
        return 'Session Complete!';
      case FeynmanSessionStatus.paused:
        return 'Session Paused';
    }
  }

  String get currentPhaseDescription {
    final session = _currentSession;
    if (session == null) return 'Prepare to teach and learn!';
    
    switch (session.status) {
      case FeynmanSessionStatus.preparing:
        return 'Setting up your Feynman learning session...';
      case FeynmanSessionStatus.explaining:
        return 'Explain the topic in your own words as if teaching someone else.';
      case FeynmanSessionStatus.reviewing:
        return 'Review your explanation and identify areas for improvement.';
      case FeynmanSessionStatus.completed:
        return 'Great work! Review your learning insights below.';
      case FeynmanSessionStatus.paused:
        return 'Session is paused. Resume when ready.';
    }
  }

  /// Initialize a new Feynman session
  Future<FeynmanSession> initializeSession({
    required String userId,
    required Module module,
    required String topic,
    Map<String, dynamic>? customData,
  }) async {
    try {
      print('🧠 [FEYNMAN] Initializing session for module: ${module.title}, topic: $topic');
      
      // Validate topic
      if (topic.trim().isEmpty) {
        throw Exception('Topic cannot be empty');
      }
      
      // Create session in database
      final sessionData = {
        'user_id': userId,
        'module_id': module.id,
        'status': FeynmanSessionStatus.preparing.value,
        'topic': topic.trim(),
        'explanation_count': 0,
        'session_data': {
          'module_title': module.title,
          'total_materials': module.materials.length,
          'custom_data': customData ?? {},
        },
      };

      final response = await SupabaseService.client
          .from('feynman_sessions')
          .insert(sessionData)
          .select()
          .single();

      _currentSession = FeynmanSession.fromJson(response);
      _sessionExplanations.clear();
      _sessionFeedback.clear();
      _sessionSuggestions.clear();
      _currentExplanation = null;
      _sessionAnalytics = null;
      
      print('✅ [FEYNMAN] Session initialized with ID: ${_currentSession!.id}');
      notifyListeners();
      
      return _currentSession!;
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to initialize session: $e');
      rethrow;
    }
  }

  /// Start the explanation phase
  Future<void> startExplanationPhase() async {
    if (_currentSession == null) {
      throw Exception('No session initialized');
    }

    try {
      print('🧠 [FEYNMAN] Starting explanation phase');
      
      await _updateSessionStatus(FeynmanSessionStatus.explaining);
      
      print('✅ [FEYNMAN] Explanation phase started');
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to start explanation phase: $e');
      rethrow;
    }
  }

  /// Submit an explanation
  Future<FeynmanExplanation> submitExplanation({
    required String explanationText,
    ExplanationType explanationType = ExplanationType.text,
  }) async {
    if (_currentSession == null) {
      throw Exception('No active session');
    }

    if (explanationText.trim().isEmpty) {
      throw Exception('Explanation cannot be empty');
    }

    try {
      setState(() {
        _isProcessingExplanation = true;
        _processingError = null;
      });

      print('🧠 [FEYNMAN] Submitting explanation attempt ${_currentSession!.explanationCount + 1}');
      
      // Calculate word count
      final wordCount = explanationText.trim().split(RegExp(r'\s+')).length;
      
      // Create explanation in database
      final explanationData = {
        'session_id': _currentSession!.id,
        'attempt_number': _currentSession!.explanationCount + 1,
        'explanation_text': explanationText.trim(),
        'explanation_type': explanationType.value,
        'word_count': wordCount,
        'processing_status': ProcessingStatus.pending.value,
      };

      final response = await SupabaseService.client
          .from('feynman_explanations')
          .insert(explanationData)
          .select()
          .single();

      _currentExplanation = FeynmanExplanation.fromJson(response);
      _sessionExplanations.add(_currentExplanation!);

      // Update session explanation count
      await _updateSessionExplanationCount(_currentSession!.explanationCount + 1);

      // Start AI analysis in background
      unawaited(_processExplanationWithAI(_currentExplanation!));

      print('✅ [FEYNMAN] Explanation submitted, starting AI analysis');
      
      return _currentExplanation!;
      
    } catch (e) {
      setState(() {
        _isProcessingExplanation = false;
        _processingError = 'Failed to submit explanation: $e';
      });
      print('❌ [FEYNMAN] Failed to submit explanation: $e');
      rethrow;
    }
  }

  /// Process explanation with AI analysis
  Future<void> _processExplanationWithAI(FeynmanExplanation explanation) async {
    try {
      print('🤖 [FEYNMAN AI] Processing explanation ${explanation.attemptNumber}');
      
      // Update status to processing
      await _updateExplanationProcessingStatus(explanation.id, ProcessingStatus.processing);
      
      // Prepare analysis data
      final analysisData = {
        'explanation_text': explanation.explanationText,
        'topic': _currentSession!.topic,
        'attempt_number': explanation.attemptNumber,
        'word_count': explanation.wordCount,
        'explanation_type': explanation.explanationType.value,
      };

      // Get AI analysis
      final aiResults = await _aiService.analyzeFeynmanExplanation(analysisData);
      
      // Update explanation with AI results
      await _updateExplanationWithAIResults(explanation.id, aiResults);
      
      // Generate feedback and suggestions
      await _generateFeedbackAndSuggestions(explanation.id, aiResults);
      
      // Update processing status to completed
      await _updateExplanationProcessingStatus(explanation.id, ProcessingStatus.completed);
      
      // Update local state
      final index = _sessionExplanations.indexWhere((e) => e.id == explanation.id);
      if (index != -1) {
        // Refresh explanation from database
        final updatedExplanation = await _getExplanationById(explanation.id);
        if (updatedExplanation != null) {
          _sessionExplanations[index] = updatedExplanation;
          if (_currentExplanation?.id == explanation.id) {
            _currentExplanation = updatedExplanation;
          }
        }
      }

      setState(() {
        _isProcessingExplanation = false;
        _processingError = null;
      });
      
      print('✅ [FEYNMAN AI] Explanation analysis completed');
      
    } catch (e) {
      print('❌ [FEYNMAN AI] Failed to process explanation: $e');
      
      await _updateExplanationProcessingStatus(explanation.id, ProcessingStatus.failed);
      
      setState(() {
        _isProcessingExplanation = false;
        _processingError = 'AI analysis failed: $e';
      });
    }
  }

  /// Start review phase
  Future<void> startReviewPhase() async {
    if (_currentSession == null) {
      throw Exception('No session initialized');
    }

    try {
      print('🧠 [FEYNMAN] Starting review phase');
      
      await _updateSessionStatus(FeynmanSessionStatus.reviewing);
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to start review phase: $e');
      rethrow;
    }
  }

  /// Complete the session
  Future<void> completeSession() async {
    if (_currentSession == null) {
      throw Exception('No session initialized');
    }

    try {
      print('🧠 [FEYNMAN] Completing session');
      
      await _updateSessionStatus(FeynmanSessionStatus.completed);
      
      await SupabaseService.client
          .from('feynman_sessions')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
            'final_explanation': _sessionExplanations.isNotEmpty 
                ? _sessionExplanations.last.explanationText 
                : null,
          })
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(
        status: FeynmanSessionStatus.completed,
        completedAt: DateTime.now(),
        finalExplanation: _sessionExplanations.isNotEmpty 
            ? _sessionExplanations.last.explanationText 
            : null,
      );
      
      print('🎉 [FEYNMAN] Session completed!');
      notifyListeners();
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to complete session: $e');
      rethrow;
    }
  }

  /// Get session results
  Future<FeynmanSessionResults> getSessionResults() async {
    if (_currentSession == null) {
      throw Exception('No session available');
    }

    try {
      // Fetch complete session data
      final sessionResponse = await SupabaseService.client
          .from('feynman_sessions')
          .select('''
            *,
            feynman_explanations(*),
            feynman_study_suggestions(*)
          ''')
          .eq('id', _currentSession!.id)
          .single();

      final session = FeynmanSession.fromJson(sessionResponse);
      
      // Extract explanations from response
      final explanations = (sessionResponse['feynman_explanations'] as List? ?? [])
          .map((e) => FeynmanExplanation.fromJson(e))
          .toList();
      
      // Get feedback for all explanations
      final feedback = <FeynmanFeedback>[];
      if (explanations.isNotEmpty) {
        final explanationIds = explanations.map((e) => e.id).toList();
        final feedbackResponse = await SupabaseService.client
            .from('feynman_feedback')
            .select()
            .inFilter('explanation_id', explanationIds);
        
        feedback.addAll(
          feedbackResponse.map((f) => FeynmanFeedback.fromJson(f)).toList()
        );
      }
      
      // Extract suggestions from response
      final suggestions = (sessionResponse['feynman_study_suggestions'] as List? ?? [])
          .map((s) => FeynmanStudySuggestion.fromJson(s))
          .toList();
      
      return FeynmanSessionResults.calculate(
        session,
        explanations,
        feedback,
        suggestions,
      );
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to get session results: $e');
      rethrow;
    }
  }

  /// Generate comprehensive analytics for the session
  Future<StudySessionAnalytics?> generateSessionAnalytics({
    required String userId,
    required Module module,
    required Course course,
  }) async {
    if (_currentSession == null) return null;

    try {
      print('📊 [FEYNMAN ANALYTICS] Generating session analytics...');
      
      // Get session results with complete data
      final sessionResults = await getSessionResults();
      
      // Use the existing StudyAnalyticsService with Feynman extension
      final analyticsService = StudyAnalyticsService();
      
      // Generate analytics using the Feynman-specific method
      _sessionAnalytics = await analyticsService.generateFeynmanAnalytics(
        sessionId: _currentSession!.id,
        userId: userId,
        moduleId: module.id,
        session: sessionResults.session,
        explanations: sessionResults.explanations,
        feedback: sessionResults.feedback,
        suggestions: sessionResults.studySuggestions,
        course: course,
        module: module,
      );
      
      print('✅ [FEYNMAN ANALYTICS] Analytics generated successfully');
      notifyListeners();
      
      return _sessionAnalytics;
      
    } catch (e) {
      print('❌ [FEYNMAN ANALYTICS] Failed to generate analytics: $e');
      return null;
    }
  }

  /// Mark a study suggestion as completed
  Future<void> markSuggestionCompleted(String suggestionId, {String? notes}) async {
    try {
      await SupabaseService.client
          .from('feynman_study_suggestions')
          .update({
            'is_completed': true,
            'completed_at': DateTime.now().toIso8601String(),
            'completion_notes': notes,
          })
          .eq('id', suggestionId);

      // Update local state
      final index = _sessionSuggestions.indexWhere((s) => s.id == suggestionId);
      if (index != -1) {
        _sessionSuggestions[index] = _sessionSuggestions[index].copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
          completionNotes: notes,
        );
        notifyListeners();
      }
      
      print('✅ [FEYNMAN] Study suggestion marked as completed');
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to mark suggestion as completed: $e');
      rethrow;
    }
  }

  // Helper methods

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Update session status in database
  Future<void> _updateSessionStatus(FeynmanSessionStatus status) async {
    if (_currentSession == null) return;

    try {
      await SupabaseService.client
          .from('feynman_sessions')
          .update({'status': status.value})
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(status: status);
      notifyListeners();
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to update session status: $e');
      rethrow;
    }
  }

  /// Update session explanation count
  Future<void> _updateSessionExplanationCount(int count) async {
    if (_currentSession == null) return;

    try {
      await SupabaseService.client
          .from('feynman_sessions')
          .update({'explanation_count': count})
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(explanationCount: count);
      notifyListeners();
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to update explanation count: $e');
      rethrow;
    }
  }

  /// Update explanation processing status
  Future<void> _updateExplanationProcessingStatus(String explanationId, ProcessingStatus status) async {
    try {
      await SupabaseService.client
          .from('feynman_explanations')
          .update({'processing_status': status.value})
          .eq('id', explanationId);
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to update processing status: $e');
      rethrow;
    }
  }

  /// Update explanation with AI analysis results
  Future<void> _updateExplanationWithAIResults(String explanationId, Map<String, dynamic> aiResults) async {
    try {
      final updateData = {
        'clarity_score': aiResults['scores']?['clarity'],
        'completeness_score': aiResults['scores']?['completeness'],
        'conceptual_accuracy_score': aiResults['scores']?['conceptual_accuracy'],
        'overall_score': aiResults['scores']?['overall'],
        'identified_gaps': aiResults['identified_gaps'] ?? [],
        'strengths': aiResults['strengths'] ?? [],
        'improvement_areas': aiResults['improvement_areas'] ?? [],
        'ai_analysis': aiResults,
      };

      await SupabaseService.client
          .from('feynman_explanations')
          .update(updateData)
          .eq('id', explanationId);
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to update explanation with AI results: $e');
      rethrow;
    }
  }

  /// Generate feedback and suggestions based on AI analysis
  Future<void> _generateFeedbackAndSuggestions(String explanationId, Map<String, dynamic> aiResults) async {
    try {
      // Generate feedback items
      final feedbackItems = aiResults['feedback'] as List<dynamic>? ?? [];
      for (final item in feedbackItems) {
        final feedbackData = {
          'explanation_id': explanationId,
          'feedback_type': _validateFeedbackType(item['type']),
          'feedback_text': item['text'] ?? '',
          'severity': item['severity'] ?? 'medium',
          'suggested_improvement': item['suggestion'],
          'related_concepts': item['related_concepts'] ?? [],
          'priority': item['priority'] ?? 1,
        };

        await SupabaseService.client
            .from('feynman_feedback')
            .insert(feedbackData);
      }

      // Generate study suggestions if this is for the current session
      if (_currentSession != null) {
        final suggestions = aiResults['study_suggestions'] as List<dynamic>? ?? [];
        for (final suggestion in suggestions) {
          final suggestionData = {
            'session_id': _currentSession!.id,
            'suggestion_type': _validateSuggestionType(suggestion['type']),
            'title': suggestion['title'] ?? '',
            'description': suggestion['description'] ?? '',
            'priority': suggestion['priority'] ?? 1,
            'estimated_duration_minutes': suggestion['duration_minutes'] ?? 15,
            'related_concepts': suggestion['related_concepts'] ?? [],
            'suggested_materials': suggestion['suggested_materials'] ?? [],
          };

          await SupabaseService.client
              .from('feynman_study_suggestions')
              .insert(suggestionData);
        }
      }
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to generate feedback and suggestions: $e');
      // Don't rethrow - this is not critical for the main flow
    }
  }

  /// Get explanation by ID
  Future<FeynmanExplanation?> _getExplanationById(String explanationId) async {
    try {
      final response = await SupabaseService.client
          .from('feynman_explanations')
          .select()
          .eq('id', explanationId)
          .maybeSingle();

      return response != null ? FeynmanExplanation.fromJson(response) : null;
      
    } catch (e) {
      print('❌ [FEYNMAN] Failed to get explanation by ID: $e');
      return null;
    }
  }

  /// Force stop session (for emergencies)
  Future<void> forceStopSession() async {
    if (_currentSession != null) {
      await _updateSessionStatus(FeynmanSessionStatus.paused);
    }
    print('🛑 [FEYNMAN] Session force stopped');
  }

  /// Validate and map AI feedback types to database-allowed values
  String _validateFeedbackType(dynamic type) {
    if (type == null) return 'overall';
    
    final typeString = type.toString().toLowerCase();
    
    // Map AI response types to valid enum values
    switch (typeString) {
      case 'clarity':
        return 'clarity';
      case 'completeness':
        return 'completeness';
      case 'accuracy':
      case 'conceptual_accuracy':
        return 'accuracy';
      case 'simplification':
        return 'simplification';
      case 'examples':
        return 'examples';
      case 'overall':
        return 'overall';
      default:
        // Default to 'overall' for unknown types
        print('⚠️ [FEYNMAN] Unknown feedback type: $typeString, defaulting to overall');
        return 'overall';
    }
  }

  /// Validate and map AI suggestion types to database-allowed values
  String _validateSuggestionType(dynamic type) {
    if (type == null) return 'material_review';
    
    final typeString = type.toString().toLowerCase();
    
    // Map AI response types to valid enum values
    switch (typeString) {
      case 'material_review':
        return 'material_review';
      case 'concept_practice':
        return 'concept_practice';
      case 'active_recall':
        return 'active_recall';
      case 'retrieval_practice':
        return 'retrieval_practice';
      case 'additional_reading':
        return 'additional_reading';
      case 'video_content':
        return 'video_content';
      case 'examples_practice':
        return 'examples_practice';
      case 'concept_mapping':
      case 'mind_mapping':
        return 'concept_practice';
      default:
        // Default to 'material_review' for unknown types
        print('⚠️ [FEYNMAN] Unknown suggestion type: $typeString, defaulting to material_review');
        return 'material_review';
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    super.dispose();
  }
}