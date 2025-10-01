// =====================================================
// Pre-Assessment Service
// =====================================================
// Service for managing course pre-assessment questions and attempts

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pre_assessment_models.dart';

class PreAssessmentService {
  final _supabase = Supabase.instance.client;

  // =====================================================
  // FETCH QUESTIONS FROM API (DYNAMIC)
  // =====================================================

  /// Get all active questions for a specific course from database
  Future<List<PreAssessmentQuestion>> getQuestionsForCourse(String courseId) async {
    try {
      final response = await _supabase
          .from('pre_assessment_questions')
          .select()
          .eq('course_id', courseId)
          .eq('is_active', true)
          .order('question_number', ascending: true);

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((questionData) => PreAssessmentQuestion.fromSupabase(questionData))
          .toList();
    } catch (e) {
      print('Error fetching pre-assessment questions: $e');
      rethrow;
    }
  }

  /// Get question count for a course (for displaying before starting)
  Future<int> getQuestionCount(String courseId) async {
    try {
      final response = await _supabase
          .from('pre_assessment_questions')
          .select()
          .eq('course_id', courseId)
          .eq('is_active', true)
          .count();

      return response.count;
    } catch (e) {
      print('Error fetching question count: $e');
      return 0;
    }
  }

  /// Get module breakdown for a course (for showing module info)
  Future<Map<String, int>> getModuleBreakdown(String courseId) async {
    try {
      final response = await _supabase
          .from('pre_assessment_questions')
          .select('module_name')
          .eq('course_id', courseId)
          .eq('is_active', true);

      final Map<String, int> breakdown = {};
      for (var item in response) {
        final module = item['module_name'] as String;
        breakdown[module] = (breakdown[module] ?? 0) + 1;
      }

      return breakdown;
    } catch (e) {
      print('Error fetching module breakdown: $e');
      return {};
    }
  }

  // =====================================================
  // NOTE: All hardcoded questions have been removed.
  // Questions are now fetched dynamically from the database.
  // Instructors can manage questions via the web interface.
  // =====================================================
  /// Start a new pre-assessment attempt
  Future<PreAssessmentAttempt> startAttempt({
    required String userId,
    required String courseId,
    required int totalQuestions,
  }) async {
    final attempt = PreAssessmentAttempt(
      userId: userId,
      courseId: courseId,
      totalQuestions: totalQuestions,
      startedAt: DateTime.now(),
    );

    final response = await _supabase
        .from('user_pre_assessment_attempts')
        .insert(attempt.toJson())
        .select()
        .single();

    return PreAssessmentAttempt.fromSupabase(response);
  }

  /// Save an answer and update attempt
  Future<PreAssessmentAttempt> saveAnswer({
    required String attemptId,
    required PreAssessmentAnswer answer,
    required PreAssessmentAttempt currentAttempt,
  }) async {
    final updatedAttempt = currentAttempt.addAnswer(answer);

    final response = await _supabase
        .from('user_pre_assessment_attempts')
        .update(updatedAttempt.toJson())
        .eq('id', attemptId)
        .select()
        .single();

    return PreAssessmentAttempt.fromSupabase(response);
  }

  /// Complete attempt and save result
  Future<PreAssessmentResult> completeAttempt({
    required String attemptId,
    required PreAssessmentAttempt attempt,
  }) async {
    // Calculate final score
    final totalTime = DateTime.now().difference(attempt.startedAt).inSeconds;
    final scorePercentage = attempt.totalQuestions > 0
        ? (attempt.correctAnswers / attempt.totalQuestions) * 100
        : 0.0;

    // Update attempt status
    await _supabase.from('user_pre_assessment_attempts').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'time_taken_seconds': totalTime,
      'score_percentage': scorePercentage,
    }).eq('id', attemptId);

    // Calculate module scores
    final moduleScoresMap = <String, double>{};
    final weakModules = <String>[];
    final strongModules = <String>[];

    // Group answers by module
    final answersByModule = <String, List<PreAssessmentAnswer>>{};
    for (var answer in attempt.answers) {
      if (!answersByModule.containsKey(answer.moduleName)) {
        answersByModule[answer.moduleName] = [];
      }
      answersByModule[answer.moduleName]!.add(answer);
    }

    // Calculate scores per module
    answersByModule.forEach((moduleName, moduleAnswers) {
      final correct = moduleAnswers.where((a) => a.isCorrect).length;
      final percentage = (correct / moduleAnswers.length) * 100;
      moduleScoresMap[moduleName] = percentage;

      if (percentage < 70) {
        weakModules.add(moduleName);
      } else {
        strongModules.add(moduleName);
      }
    });

    // Create and save result
    final result = PreAssessmentResult(
      userId: attempt.userId,
      courseId: attempt.courseId,
      attemptId: attemptId,
      scorePercentage: scorePercentage,
      totalQuestions: attempt.totalQuestions,
      correctAnswers: attempt.correctAnswers,
      passed: scorePercentage >= 70,
      weakModules: weakModules,
      strongModules: strongModules,
      moduleScores: moduleScoresMap,
      completedAt: DateTime.now(),
    );

    final response = await _supabase
        .from('user_pre_assessment_results')
        .insert(result.toJson())
        .select()
        .single();

    // Update course enrollment
    await _supabase.from('course_enrollments').update({
      'pre_assessment_completed': true,
      'pre_assessment_score': scorePercentage,
      'pre_assessment_passed': scorePercentage >= 70,
    }).eq('user_id', attempt.userId).eq('course_id', attempt.courseId);

    return PreAssessmentResult.fromSupabase(response);
  }

  /// Get attempt by ID
  Future<PreAssessmentAttempt?> getAttempt(String attemptId) async {
    final response = await _supabase
        .from('user_pre_assessment_attempts')
        .select()
        .eq('id', attemptId)
        .maybeSingle();

    if (response == null) return null;
    return PreAssessmentAttempt.fromSupabase(response);
  }

  /// Get in-progress attempt for a course
  Future<PreAssessmentAttempt?> getInProgressAttempt({
    required String userId,
    required String courseId,
  }) async {
    final response = await _supabase
        .from('user_pre_assessment_attempts')
        .select()
        .eq('user_id', userId)
        .eq('course_id', courseId)
        .eq('status', 'in_progress')
        .maybeSingle();

    if (response == null) return null;
    return PreAssessmentAttempt.fromSupabase(response);
  }

  /// Get result for a course
  Future<PreAssessmentResult?> getResult({
    required String userId,
    required String courseId,
  }) async {
    final response = await _supabase
        .from('user_pre_assessment_results')
        .select()
        .eq('user_id', userId)
        .eq('course_id', courseId)
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return PreAssessmentResult.fromSupabase(response);
  }

  /// Check if pre-assessment is completed for a course
  Future<bool> isPreAssessmentCompleted({
    required String userId,
    required String courseId,
  }) async {
    final enrollment = await _supabase
        .from('course_enrollments')
        .select('pre_assessment_completed')
        .eq('user_id', userId)
        .eq('course_id', courseId)
        .maybeSingle();

    return enrollment?['pre_assessment_completed'] ?? false;
  }

  /// Abandon current attempt
  Future<void> abandonAttempt(String attemptId) async {
    await _supabase
        .from('user_pre_assessment_attempts')
        .update({'status': 'abandoned'})
        .eq('id', attemptId);
  }
}
