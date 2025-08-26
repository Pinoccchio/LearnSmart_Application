import 'dart:async';
import '../models/user_progress_models.dart';
import '../models/course_models.dart';
import '../services/supabase_service.dart';

class UserProgressService {
  /// Get all module progress for a user in a specific course
  static Future<List<UserModuleProgress>> getUserModuleProgress(
    String userId,
    String courseId,
  ) async {
    try {
      print('📊 [PROGRESS] Loading module progress for user: $userId, course: $courseId');
      
      final response = await SupabaseService.client
          .from('user_module_progress')
          .select('*')
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .order('created_at', ascending: true);

      final progressList = response
          .map<UserModuleProgress>((json) => UserModuleProgress.fromJson(json))
          .toList();

      print('✅ [PROGRESS] Loaded ${progressList.length} module progress records');
      return progressList;

    } catch (e) {
      print('❌ [PROGRESS] Error loading module progress: $e');
      return [];
    }
  }

  /// Get course progress summary with completion statistics
  static Future<CourseProgress> getCourseProgress(
    String userId,
    String courseId,
  ) async {
    try {
      print('📊 [PROGRESS] Loading course progress for user: $userId, course: $courseId');
      
      final moduleProgresses = await getUserModuleProgress(userId, courseId);
      final courseProgress = CourseProgress.fromModuleProgresses(
        courseId,
        userId,
        moduleProgresses,
      );

      print('✅ [PROGRESS] Course progress: ${courseProgress.completedModules}/${courseProgress.totalModules} modules completed');
      return courseProgress;

    } catch (e) {
      print('❌ [PROGRESS] Error loading course progress: $e');
      return CourseProgress.fromModuleProgresses(courseId, userId, []);
    }
  }

  /// Initialize module progress for a user when they enroll in a course
  static Future<void> initializeUserModuleProgress(
    String userId,
    Course course,
  ) async {
    try {
      print('🔄 [PROGRESS] Initializing module progress for user: $userId, course: ${course.id}');

      // Sort modules by order_index to ensure proper sequential unlocking
      final sortedModules = [...course.modules];
      sortedModules.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      final progressRecords = <Map<String, dynamic>>[];
      
      for (int i = 0; i < sortedModules.length; i++) {
        final module = sortedModules[i];
        final isFirstModule = i == 0;
        
        progressRecords.add({
          'user_id': userId,
          'course_id': course.id,
          'module_id': module.id,
          'status': isFirstModule ? 'available' : 'locked',
          'attempt_count': 0,
          'passed': false,
          'needs_remedial': false,
          'remedial_completed': false,
          'remedial_sessions_count': 0,
          'unlocked_at': isFirstModule ? DateTime.now().toIso8601String() : null,
        });
      }

      // Use upsert to handle existing records gracefully
      await SupabaseService.client
          .from('user_module_progress')
          .upsert(progressRecords, onConflict: 'user_id,course_id,module_id');

      print('✅ [PROGRESS] Initialized progress for ${sortedModules.length} modules');
      
    } catch (e) {
      print('❌ [PROGRESS] Error initializing module progress: $e');
      rethrow;
    }
  }

  /// Update module progress when a study session is completed
  static Future<void> updateModuleProgress({
    required String userId,
    required String moduleId,
    required double score,
    required String technique,
    required String sessionId,
    int passingThreshold = 80,
  }) async {
    try {
      print('📈 [PROGRESS] Updating module progress: user=$userId, module=$moduleId, score=$score');

      final isPassing = score >= passingThreshold;
      final now = DateTime.now().toIso8601String();

      // Get existing progress
      final existingProgress = await SupabaseService.client
          .from('user_module_progress')
          .select('*')
          .eq('user_id', userId)
          .eq('module_id', moduleId)
          .maybeSingle();

      if (existingProgress == null) {
        throw Exception('Module progress record not found for user: $userId, module: $moduleId');
      }

      final currentBestScore = existingProgress['best_score']?.toDouble();
      final currentAttemptCount = existingProgress['attempt_count'] ?? 0;
      final wasAlreadyPassed = existingProgress['passed'] ?? false;

      // Determine if this is a new best score
      final isNewBestScore = currentBestScore == null || score > currentBestScore;
      final needsRemedial = !isPassing && score < 80;

      // Prepare update data
      final updateData = <String, dynamic>{
        'latest_score': score,
        'latest_session_id': sessionId,
        'attempt_count': currentAttemptCount + 1,
        'last_attempt_at': now,
        'needs_remedial': needsRemedial,
        'updated_at': now,
      };

      // Set first attempt timestamp if this is the first attempt
      if (currentAttemptCount == 0) {
        updateData['first_attempt_at'] = now;
        updateData['status'] = 'in_progress';
      }

      // Update best score related fields if this is a new best
      if (isNewBestScore) {
        updateData['best_score'] = score;
        updateData['best_score_technique'] = technique;
        updateData['best_session_id'] = sessionId;
      }

      // Handle module completion
      if (isPassing && !wasAlreadyPassed) {
        updateData['passed'] = true;
        updateData['status'] = 'completed';
        updateData['completed_at'] = now;
        
        print('🎉 [PROGRESS] Module completed! Unlocking next module...');
        
        // Update current module
        await SupabaseService.client
            .from('user_module_progress')
            .update(updateData)
            .eq('user_id', userId)
            .eq('module_id', moduleId);

        // Unlock next module in sequence
        await _unlockNextModule(userId, moduleId);
        
      } else {
        // Just update current module
        await SupabaseService.client
            .from('user_module_progress')
            .update(updateData)
            .eq('user_id', userId)
            .eq('module_id', moduleId);
      }

      print('✅ [PROGRESS] Module progress updated successfully');
      
    } catch (e) {
      print('❌ [PROGRESS] Error updating module progress: $e');
      rethrow;
    }
  }

  /// Unlock the next module in sequence after completing current module
  static Future<void> _unlockNextModule(String userId, String completedModuleId) async {
    try {
      print('🔓 [UNLOCK] Finding next module to unlock after: $completedModuleId');

      // Get the completed module info
      final completedModuleInfo = await SupabaseService.client
          .from('user_module_progress')
          .select('course_id')
          .eq('user_id', userId)
          .eq('module_id', completedModuleId)
          .single();

      final courseId = completedModuleInfo['course_id'];

      // Get current module's order_index
      final currentModule = await SupabaseService.client
          .from('modules')
          .select('order_index')
          .eq('id', completedModuleId)
          .single();

      final currentOrderIndex = currentModule['order_index'];

      // Find the next module in order
      final nextModule = await SupabaseService.client
          .from('modules')
          .select('id, title, order_index')
          .eq('course_id', courseId)
          .eq('order_index', currentOrderIndex + 1)
          .maybeSingle();

      if (nextModule != null) {
        final nextModuleId = nextModule['id'];
        final now = DateTime.now().toIso8601String();

        // Unlock the next module
        await SupabaseService.client
            .from('user_module_progress')
            .update({
              'status': 'available',
              'unlocked_at': now,
              'updated_at': now,
            })
            .eq('user_id', userId)
            .eq('module_id', nextModuleId);

        print('✅ [UNLOCK] Next module unlocked: ${nextModule['title']} (order: ${nextModule['order_index']})');
      } else {
        print('ℹ️ [UNLOCK] No more modules to unlock - course completed!');
      }

    } catch (e) {
      print('❌ [UNLOCK] Error unlocking next module: $e');
      // Don't rethrow - this shouldn't fail the main progress update
    }
  }

  /// Check if a module is accessible by a user
  static Future<bool> canAccessModule(String userId, String moduleId) async {
    try {
      final progress = await SupabaseService.client
          .from('user_module_progress')
          .select('status')
          .eq('user_id', userId)
          .eq('module_id', moduleId)
          .maybeSingle();

      if (progress == null) {
        return false; // No progress record means not accessible
      }

      final status = ModuleProgressStatusExtension.fromString(progress['status']);
      return status == ModuleProgressStatus.available || 
             status == ModuleProgressStatus.inProgress ||
             status == ModuleProgressStatus.completed;

    } catch (e) {
      print('❌ [ACCESS] Error checking module access: $e');
      return false;
    }
  }

  /// Get specific module progress
  static Future<UserModuleProgress?> getModuleProgress(
    String userId,
    String moduleId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('user_module_progress')
          .select('*')
          .eq('user_id', userId)
          .eq('module_id', moduleId)
          .maybeSingle();

      if (response == null) return null;
      
      return UserModuleProgress.fromJson(response);
      
    } catch (e) {
      print('❌ [PROGRESS] Error getting module progress: $e');
      return null;
    }
  }

  /// Update remedial progress
  static Future<void> updateRemedialProgress({
    required String userId,
    required String moduleId,
    required bool remedialCompleted,
    int? remedialSessionsCount,
  }) async {
    try {
      print('🔄 [REMEDIAL] Updating remedial progress: user=$userId, module=$moduleId, completed=$remedialCompleted');

      final updateData = <String, dynamic>{
        'remedial_completed': remedialCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (remedialSessionsCount != null) {
        updateData['remedial_sessions_count'] = remedialSessionsCount;
      }

      // If remedial is completed, clear the needs_remedial flag
      if (remedialCompleted) {
        updateData['needs_remedial'] = false;
      }

      await SupabaseService.client
          .from('user_module_progress')
          .update(updateData)
          .eq('user_id', userId)
          .eq('module_id', moduleId);

      print('✅ [REMEDIAL] Remedial progress updated successfully');
      
    } catch (e) {
      print('❌ [REMEDIAL] Error updating remedial progress: $e');
      rethrow;
    }
  }

  /// Reset module progress (for development/testing)
  static Future<void> resetModuleProgress(String userId, String moduleId) async {
    try {
      print('🔄 [RESET] Resetting module progress: user=$userId, module=$moduleId');

      await SupabaseService.client
          .from('user_module_progress')
          .update({
            'status': 'locked',
            'best_score': null,
            'latest_score': null,
            'attempt_count': 0,
            'passed': false,
            'needs_remedial': false,
            'remedial_completed': false,
            'remedial_sessions_count': 0,
            'best_score_technique': null,
            'latest_session_id': null,
            'best_session_id': null,
            'first_attempt_at': null,
            'last_attempt_at': null,
            'completed_at': null,
            'unlocked_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('module_id', moduleId);

      print('✅ [RESET] Module progress reset successfully');
      
    } catch (e) {
      print('❌ [RESET] Error resetting module progress: $e');
      rethrow;
    }
  }
}