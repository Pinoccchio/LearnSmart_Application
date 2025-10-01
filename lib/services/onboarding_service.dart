import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/onboarding_models.dart';

class OnboardingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // Hardcoded Onboarding Questions (20 questions)
  // =====================================================
  static List<OnboardingQuestion> getOnboardingQuestions() {
    return [
      // Active Recall (Questions 1-5)
      OnboardingQuestion(
        questionNumber: 1,
        questionText: 'I prefer to close my notes and try to recall key concepts after studying a topic.',
        techniqueCategory: 'active_recall',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 2,
        questionText: 'I try to write down everything I remember after studying a topic without looking at my notes.',
        techniqueCategory: 'active_recall',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 3,
        questionText: 'I prefer reciting important ideas aloud without checking my materials.',
        techniqueCategory: 'active_recall',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 4,
        questionText: 'I usually just reread my notes instead of trying to recall the information from memory.',
        techniqueCategory: 'active_recall',
        isReverseCoded: true, // REVERSE-CODED
      ),
      OnboardingQuestion(
        questionNumber: 5,
        questionText: 'I cover key points in my notes and attempt to recall them from memory.',
        techniqueCategory: 'active_recall',
        isReverseCoded: false,
      ),

      // Pomodoro Technique (Questions 6-10)
      OnboardingQuestion(
        questionNumber: 6,
        questionText: 'I focus better when I study in short, timed intervals with scheduled breaks.',
        techniqueCategory: 'pomodoro',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 7,
        questionText: 'I prefer studying continuously for long periods without taking short breaks.',
        techniqueCategory: 'pomodoro',
        isReverseCoded: true, // REVERSE-CODED
      ),
      OnboardingQuestion(
        questionNumber: 8,
        questionText: 'I lose focus if I study for long periods without taking breaks.',
        techniqueCategory: 'pomodoro',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 9,
        questionText: 'I find it easier to concentrate when I use a timer to structure my study time.',
        techniqueCategory: 'pomodoro',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 10,
        questionText: 'I feel more productive when I follow a fixed cycle of study and rest.',
        techniqueCategory: 'pomodoro',
        isReverseCoded: false,
      ),

      // Feynman Technique (Questions 11-15)
      OnboardingQuestion(
        questionNumber: 11,
        questionText: 'I learn best when I try to explain the topic as if I were teaching someone else.',
        techniqueCategory: 'feynman',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 12,
        questionText: 'I rarely try to explain topics in my own words because it doesn\'t help me understand better.',
        techniqueCategory: 'feynman',
        isReverseCoded: true, // REVERSE-CODED
      ),
      OnboardingQuestion(
        questionNumber: 13,
        questionText: 'I find it helpful to identify parts of a topic that I can\'t explain simply.',
        techniqueCategory: 'feynman',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 14,
        questionText: 'I often use simple, everyday examples to explain complex topics.',
        techniqueCategory: 'feynman',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 15,
        questionText: 'I feel more confident with a topic after I\'ve explained it aloud or in writing.',
        techniqueCategory: 'feynman',
        isReverseCoded: false,
      ),

      // Retrieval Practice (Questions 16-20)
      OnboardingQuestion(
        questionNumber: 16,
        questionText: 'I regularly quiz myself on lessons to check how much I remember.',
        techniqueCategory: 'retrieval_practice',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 17,
        questionText: 'I use flashcards to test what I have studied.',
        techniqueCategory: 'retrieval_practice',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 18,
        questionText: 'I revisit topics after several days to strengthen what I learned.',
        techniqueCategory: 'retrieval_practice',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 19,
        questionText: 'I remember information better when I test myself multiple times.',
        techniqueCategory: 'retrieval_practice',
        isReverseCoded: false,
      ),
      OnboardingQuestion(
        questionNumber: 20,
        questionText: 'I find that practice tests are not useful for remembering what I studied.',
        techniqueCategory: 'retrieval_practice',
        isReverseCoded: true, // REVERSE-CODED
      ),
    ];
  }

  // =====================================================
  // Database Methods
  // =====================================================

  /// Save a single response to the database (upsert to allow updating)
  Future<void> saveResponse(OnboardingResponse response) async {
    try {
      await _supabase
          .from('user_onboarding_responses')
          .upsert(response.toJson());
    } catch (e) {
      throw Exception('Failed to save onboarding response: $e');
    }
  }

  /// Save multiple responses in batch
  Future<void> saveAllResponses(List<OnboardingResponse> responses) async {
    try {
      final jsonList = responses.map((r) => r.toJson()).toList();
      await _supabase.from('user_onboarding_responses').upsert(jsonList);
    } catch (e) {
      throw Exception('Failed to save onboarding responses: $e');
    }
  }

  /// Get all responses for a user
  Future<List<OnboardingResponse>> getUserResponses(String userId) async {
    try {
      final response = await _supabase
          .from('user_onboarding_responses')
          .select()
          .eq('user_id', userId)
          .order('question_number');

      return (response as List)
          .map((json) => OnboardingResponse.fromSupabase(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch onboarding responses: $e');
    }
  }

  /// Calculate scores from responses and save results
  Future<OnboardingResult> calculateAndSaveResults(String userId) async {
    try {
      // Get all user responses
      final responses = await getUserResponses(userId);

      if (responses.length != 20) {
        throw Exception('All 20 questions must be answered before calculating results');
      }

      // Calculate scores for each technique
      int activeRecallScore = 0;
      int pomodoroScore = 0;
      int feynmanScore = 0;
      int retrievalPracticeScore = 0;

      for (final response in responses) {
        // Apply reverse coding if needed
        int scoreValue = response.responseValue;
        if (response.isReverseCoded) {
          scoreValue = 6 - scoreValue; // Reverse: 1→5, 2→4, 3→3, 4→2, 5→1
        }

        // Add to appropriate technique score
        switch (response.techniqueCategory) {
          case 'active_recall':
            activeRecallScore += scoreValue;
            break;
          case 'pomodoro':
            pomodoroScore += scoreValue;
            break;
          case 'feynman':
            feynmanScore += scoreValue;
            break;
          case 'retrieval_practice':
            retrievalPracticeScore += scoreValue;
            break;
        }
      }

      // Determine top technique
      final scores = {
        'active_recall': activeRecallScore,
        'pomodoro': pomodoroScore,
        'feynman': feynmanScore,
        'retrieval_practice': retrievalPracticeScore,
      };

      final topTechnique = scores.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      // Create result object
      final result = OnboardingResult(
        userId: userId,
        activeRecallScore: activeRecallScore,
        pomodoroScore: pomodoroScore,
        feynmanScore: feynmanScore,
        retrievalPracticeScore: retrievalPracticeScore,
        topTechnique: topTechnique,
        completedAt: DateTime.now(),
      );

      // Save result to database
      await _supabase
          .from('user_onboarding_results')
          .upsert(result.toJson());

      // Update user's onboarding_completed flag
      await _supabase
          .from('users')
          .update({
            'onboarding_completed': true,
            'onboarding_completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      return result;
    } catch (e) {
      throw Exception('Failed to calculate onboarding results: $e');
    }
  }

  /// Get saved results for a user
  Future<OnboardingResult?> getUserResults(String userId) async {
    try {
      final response = await _supabase
          .from('user_onboarding_results')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return OnboardingResult.fromSupabase(response);
    } catch (e) {
      throw Exception('Failed to fetch onboarding results: $e');
    }
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('onboarding_completed')
          .eq('id', userId)
          .single();

      return response['onboarding_completed'] as bool? ?? false;
    } catch (e) {
      throw Exception('Failed to check onboarding status: $e');
    }
  }

  /// Get response count for user (for progress tracking)
  Future<int> getResponseCount(String userId) async {
    try {
      final response = await _supabase
          .from('user_onboarding_responses')
          .select()
          .eq('user_id', userId);

      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to get response count: $e');
    }
  }
}
