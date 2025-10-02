import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/user.dart' as app_user;
import '../models/course_models.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // Auth methods
  static User? get currentAuthUser => client.auth.currentUser;
  
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    print('🔍 [AUTH] Attempting sign up for email: $email');
    final startTime = DateTime.now();
    
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      
      final duration = DateTime.now().difference(startTime);
      print('✅ [AUTH SUCCESS] Sign up completed in ${duration.inMilliseconds}ms, User ID: ${response.user?.id}');
      return response;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [AUTH ERROR] Sign up failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      rethrow;
    }
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    print('🔍 [AUTH] Attempting sign in for email: $email');
    final startTime = DateTime.now();
    
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      final duration = DateTime.now().difference(startTime);
      print('✅ [AUTH SUCCESS] Sign in completed in ${duration.inMilliseconds}ms, User ID: ${response.user?.id}');
      return response;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [AUTH ERROR] Sign in failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Profile methods
  static Future<app_user.User> createUserProfile({
    required String authUserId,
    required String name,
    required String email,
    String role = 'student',
    String? profilePicture,
  }) async {
    final response = await client
        .from('users')
        .insert({
          'id': authUserId,
          'name': name,
          'email': email,
          'role': role,
          'profile_picture': profilePicture,
          'onboarding_completed': false,
        })
        .select()
        .single();

    return app_user.User.fromSupabase(response);
  }

  static Future<app_user.User?> getUserProfile(String userId) async {
    print('🔍 [SUPABASE] Fetching user profile for: $userId');
    final startTime = DateTime.now();

    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      final duration = DateTime.now().difference(startTime);
      final user = app_user.User.fromSupabase(response);
      print('✅ [SUPABASE] User profile loaded in ${duration.inMilliseconds}ms - ${user.email}, onboarding: ${user.onboardingCompleted}');
      return user;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [SUPABASE] Failed to fetch user profile after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');

      // Better error handling: distinguish between "not found" vs "database error"
      if (e.toString().contains('Not found') || e.toString().contains('No rows')) {
        print('⚠️ [SUPABASE] User profile does not exist for ID: $userId');
      } else {
        print('⚠️ [SUPABASE] Database error while fetching user profile - may be temporary');
      }

      return null;
    }
  }

  static Future<app_user.User> updateUserProfile({
    required String userId,
    String? name,
    String? role,
    String? profilePicture,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (role != null) updates['role'] = role;
    if (profilePicture != null) updates['profile_picture'] = profilePicture;
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await client
        .from('users')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return app_user.User.fromSupabase(response);
  }

  // Combined auth and profile creation for signup
  static Future<({AuthResponse authResponse, app_user.User? userProfile})> signUpWithProfile({
    required String email,
    required String password,
    required String name,
    String role = 'student',
  }) async {
    try {
      // Step 1: Create auth user
      final authResponse = await signUp(
        email: email,
        password: password,
      );

      // Step 2: Create user profile if auth was successful
      app_user.User? userProfile;
      if (authResponse.user != null) {
        try {
          userProfile = await createUserProfile(
            authUserId: authResponse.user!.id,
            name: name,
            email: email,
            role: role,
          );
        } catch (profileError) {
          // If profile creation fails, we should clean up the auth user
          // but for now, we'll just return the auth response
        }
      }

      return (authResponse: authResponse, userProfile: userProfile);
    } catch (e) {
      rethrow;
    }
  }

  // Combined auth and profile retrieval for signin
  static Future<({AuthResponse authResponse, app_user.User? userProfile})> signInWithProfile({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Sign in
      final authResponse = await signIn(
        email: email,
        password: password,
      );

      // Step 2: Get user profile
      app_user.User? userProfile;
      if (authResponse.user != null) {
        userProfile = await getUserProfile(authResponse.user!.id);
      }

      return (authResponse: authResponse, userProfile: userProfile);
    } catch (e) {
      rethrow;
    }
  }

  // Course methods
  static Future<List<Course>> getEnrolledCourses(String userId) async {
    print('🔍 [SUPABASE] Getting enrolled courses for user: $userId');
    final startTime = DateTime.now();
    
    try {
      const query = '''
            *,
            courses (
              *,
              modules (*),
              instructor:users!courses_instructor_id_fkey (
                id, name, email
              )
            )
          ''';
      
      print('📤 [QUERY] course_enrollments.select($query).eq(user_id, $userId).eq(status, active)');
      
      final response = await client
          .from('course_enrollments')
          .select(query)
          .eq('user_id', userId)
          .eq('status', 'active');

      final duration = DateTime.now().difference(startTime);
      print('📥 [RESPONSE] Received ${response.length} enrollment records in ${duration.inMilliseconds}ms');
      print('📊 [RAW DATA] ${response.toString()}');

      List<Course> courses = [];
      for (final enrollment in response) {
        final courseData = enrollment['courses'];
        print('🔄 [PROCESSING] Enrollment: ${enrollment['id']}, Course: ${courseData?['id']}');
        
        if (courseData != null) {
          final course = Course.fromJson(courseData);
          print('📖 [COURSE] ${course.title} (${course.modules.length} modules, Instructor: ${course.instructorName ?? 'None'})');
          
          // Calculate progress and update course with actual progress
          final progress = await _calculateCourseProgress(userId, course.id);
          print('📈 [PROGRESS] Course ${course.id}: ${(progress * 100).toInt()}%');
          
          // Use copyWith to create a new course with the calculated progress
          final courseWithProgress = course.copyWith(progress: progress);
          courses.add(courseWithProgress);
        } else {
          print('⚠️ [WARNING] Enrollment ${enrollment['id']} has no course data');
        }
      }

      print('✅ [SUCCESS] getEnrolledCourses returned ${courses.length} courses');
      return courses;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] getEnrolledCourses failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return [];
    }
  }

  static Future<List<Course>> getAvailableCourses(String userId) async {
    print('🔍 [SUPABASE] Getting available courses for user: $userId');
    final startTime = DateTime.now();
    
    try {
      const courseQuery = '''
            *,
            modules (*),
            instructor:users!courses_instructor_id_fkey (
              id, name, email
            )
          ''';
      
      print('📤 [QUERY 1] courses.select($courseQuery).eq(status, active)');
      final response = await client
          .from('courses')
          .select(courseQuery)
          .eq('status', 'active');
      
      final courseDuration = DateTime.now().difference(startTime);
      print('📥 [RESPONSE 1] Received ${response.length} courses in ${courseDuration.inMilliseconds}ms');

      // Get enrolled course IDs
      print('📤 [QUERY 2] course_enrollments.select(course_id).eq(user_id, $userId)');
      final enrolledStartTime = DateTime.now();
      final enrolledResponse = await client
          .from('course_enrollments')
          .select('course_id')
          .eq('user_id', userId);
      
      final enrolledDuration = DateTime.now().difference(enrolledStartTime);
      print('📥 [RESPONSE 2] Received ${enrolledResponse.length} enrollments in ${enrolledDuration.inMilliseconds}ms');

      final enrolledCourseIds = enrolledResponse.map((e) => e['course_id']).toSet();
      print('🔒 [FILTER] Enrolled course IDs: $enrolledCourseIds');

      final availableCourses = response
          .where((courseData) => !enrolledCourseIds.contains(courseData['id']))
          .map((json) {
            final course = Course.fromJson(json);
            print('📖 [AVAILABLE] ${course.title} (${course.modules.length} modules, Instructor: ${course.instructorName ?? 'None'})');
            return course;
          })
          .toList();

      final totalDuration = DateTime.now().difference(startTime);
      print('✅ [SUCCESS] getAvailableCourses returned ${availableCourses.length} courses in ${totalDuration.inMilliseconds}ms');
      return availableCourses;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] getAvailableCourses failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return [];
    }
  }

  static Future<List<Module>> getCourseModules(String courseId) async {
    print('🔍 [SUPABASE] Getting modules for course: $courseId');
    final startTime = DateTime.now();
    
    try {
      const query = '''
            *,
            course_materials (*)
          ''';
      
      print('📤 [QUERY] modules.select($query).eq(course_id, $courseId).order(order_index)');
      final response = await client
          .from('modules')
          .select(query)
          .eq('course_id', courseId)
          .order('order_index');

      final duration = DateTime.now().difference(startTime);
      print('📥 [RESPONSE] Received ${response.length} modules in ${duration.inMilliseconds}ms');

      final modules = response.map((json) {
        final module = Module.fromJson(json);
        print('📚 [MODULE] ${module.title} (${module.materials.length} materials, Order: ${module.orderIndex})');
        return module;
      }).toList();

      print('✅ [SUCCESS] getCourseModules returned ${modules.length} modules');
      return modules;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] getCourseModules failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return [];
    }
  }

  static Future<bool> enrollInCourse(String userId, String courseId) async {
    print('🔍 [SUPABASE] Enrolling user $userId in course $courseId');
    final startTime = DateTime.now();
    
    try {
      final enrollmentData = {
        'user_id': userId,
        'course_id': courseId,
        'status': 'active',
        'enrolled_at': DateTime.now().toIso8601String(),
      };
      
      print('📤 [INSERT] course_enrollments.insert($enrollmentData)');
      await client.from('course_enrollments').insert(enrollmentData);
      
      final duration = DateTime.now().difference(startTime);
      print('✅ [SUCCESS] User enrolled successfully in ${duration.inMilliseconds}ms');
      return true;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] enrollInCourse failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return false;
    }
  }

  static Future<double> _calculateCourseProgress(String userId, String courseId) async {
    print('🔍 [SUPABASE] Calculating progress for user $userId, course $courseId');
    final startTime = DateTime.now();
    
    try {
      // Get all modules for this course
      print('📤 [QUERY] modules.select(id).eq(course_id, $courseId)');
      final modulesResponse = await client
          .from('modules')
          .select('id')
          .eq('course_id', courseId);

      final moduleDuration = DateTime.now().difference(startTime);
      print('📥 [RESPONSE] Found ${modulesResponse.length} modules in ${moduleDuration.inMilliseconds}ms');

      if (modulesResponse.isEmpty) {
        print('⚠️ [WARNING] No modules found for course $courseId');
        return 0.0;
      }

      // Get user's progress for these modules
      final moduleIds = modulesResponse.map((m) => m['id']).toList();
      
      print('📤 [QUERY] user_module_progress.select(passed).eq(user_id, $userId).eq(course_id, $courseId)');
      final progressResponse = await client
          .from('user_module_progress')
          .select('passed, status')
          .eq('user_id', userId)
          .eq('course_id', courseId);

      final progressDuration = DateTime.now().difference(startTime);
      print('📥 [RESPONSE] Found ${progressResponse.length} progress records in ${progressDuration.inMilliseconds}ms');

      // Calculate actual progress
      if (progressResponse.isEmpty) {
        print('⚠️ [WARNING] No progress records found - returning 0%');
        return 0.0;
      }

      final completedCount = progressResponse
          .where((p) => p['passed'] == true || p['status'] == 'completed')
          .length;
      
      final totalModules = modulesResponse.length;
      final actualProgress = totalModules > 0 ? completedCount / totalModules : 0.0;
      
      print('📊 [PROGRESS] Calculated progress: ${completedCount}/${totalModules} = ${(actualProgress * 100).toInt()}%');
      return actualProgress;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] _calculateCourseProgress failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return 0.0;
    }
  }

  // Get course with full module and material details
  static Future<Course?> getCourseWithModulesAndMaterials(String courseId) async {
    print('🔍 [SUPABASE] Getting course with modules and materials for course: $courseId');
    final startTime = DateTime.now();
    
    try {
      const query = '''
        *,
        modules (
          *,
          course_materials (*)
        ),
        instructor:users!courses_instructor_id_fkey (
          id, name, email
        )
      ''';
      
      print('📤 [QUERY] courses.select($query).eq(id, $courseId).single()');
      
      final response = await client
          .from('courses')
          .select(query)
          .eq('id', courseId)
          .single();

      final duration = DateTime.now().difference(startTime);
      print('📥 [RESPONSE] Received course data in ${duration.inMilliseconds}ms');

      final course = Course.fromJson(response);
      print('📖 [COURSE] ${course.title} with ${course.modules.length} modules');
      
      return course;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] getCourseWithModulesAndMaterials failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return null;
    }
  }

  // Get module with materials
  static Future<Module?> getModuleWithMaterials(String moduleId) async {
    print('🔍 [SUPABASE] Getting module with materials for module: $moduleId');
    final startTime = DateTime.now();
    
    try {
      const query = '''
        *,
        course_materials (*)
      ''';
      
      print('📤 [QUERY] modules.select($query).eq(id, $moduleId).single()');
      
      final response = await client
          .from('modules')
          .select(query)
          .eq('id', moduleId)
          .single();

      final duration = DateTime.now().difference(startTime);
      print('📥 [RESPONSE] Received module data in ${duration.inMilliseconds}ms');

      final module = Module.fromJson(response);
      print('📚 [MODULE] ${module.title} with ${module.materials.length} materials');
      
      return module;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] getModuleWithMaterials failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return null;
    }
  }

  // Check module prerequisites
  static Future<bool> checkModulePrerequisites(String moduleId, String userId) async {
    print('🔍 [SUPABASE] Checking prerequisites for module: $moduleId, user: $userId');
    final startTime = DateTime.now();
    
    try {
      print('📤 [QUERY] modules.select(prerequisite_module_id).eq(id, $moduleId).single()');
      
      final response = await client
          .from('modules')
          .select('prerequisite_module_id')
          .eq('id', moduleId)
          .single();

      final duration = DateTime.now().difference(startTime);
      print('📥 [RESPONSE] Received prerequisite data in ${duration.inMilliseconds}ms');

      final prerequisiteModuleId = response['prerequisite_module_id'];
      
      if (prerequisiteModuleId == null) {
        print('✅ [PREREQ] No prerequisites required for module $moduleId');
        return true;
      }

      // Check if prerequisite module is completed by user
      final prerequisiteProgress = await client
          .from('user_module_progress')
          .select('passed')
          .eq('user_id', userId)
          .eq('module_id', prerequisiteModuleId)
          .maybeSingle();

      if (prerequisiteProgress == null) {
        print('❌ [PREREQ] No progress record found for prerequisite module');
        return false;
      }

      final isPrerequisitePassed = prerequisiteProgress['passed'] ?? false;
      print('✅ [PREREQ] Prerequisite module passed: $isPrerequisitePassed');
      
      return isPrerequisitePassed;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] checkModulePrerequisites failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return false;
    }
  }

  // Progress-related methods
  static Future<Course?> getCourseWithModulesAndProgress(String courseId, String userId) async {
    print('🔍 [SUPABASE] Getting course with modules and progress for course: $courseId, user: $userId');
    final startTime = DateTime.now();
    
    try {
      // Get course with modules and materials
      final course = await getCourseWithModulesAndMaterials(courseId);
      if (course == null) return null;

      // Get user progress for all modules in the course
      final progressResponse = await client
          .from('user_module_progress')
          .select('*')
          .eq('user_id', userId)
          .eq('course_id', courseId);

      print('📥 [PROGRESS] Loaded ${progressResponse.length} progress records');

      // Create a map of module ID to progress for easy lookup
      final progressMap = <String, Map<String, dynamic>>{};
      for (final progress in progressResponse) {
        progressMap[progress['module_id']] = progress;
      }

      final duration = DateTime.now().difference(startTime);
      print('✅ [SUCCESS] getCourseWithModulesAndProgress completed in ${duration.inMilliseconds}ms');
      
      return course; // The progress data can be accessed separately via UserProgressService

    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] getCourseWithModulesAndProgress failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return null;
    }
  }

  // Enroll user in course and initialize progress
  static Future<bool> enrollUserInCourse(String userId, String courseId) async {
    print('📝 [ENROLL] Enrolling user: $userId in course: $courseId');
    final startTime = DateTime.now();
    
    try {
      // Create course enrollment
      await client
          .from('course_enrollments')
          .insert({
            'user_id': userId,
            'course_id': courseId,
            'status': 'active',
            'enrolled_at': DateTime.now().toIso8601String(),
          });

      // Get course with modules to initialize progress
      final course = await getCourseWithModulesAndMaterials(courseId);
      if (course == null) {
        throw Exception('Course not found: $courseId');
      }

      // Initialize user progress for all modules
      final sortedModules = [...course.modules];
      sortedModules.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      final progressRecords = <Map<String, dynamic>>[];
      
      for (int i = 0; i < sortedModules.length; i++) {
        final module = sortedModules[i];
        final isFirstModule = i == 0;
        
        progressRecords.add({
          'user_id': userId,
          'course_id': courseId,
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

      await client
          .from('user_module_progress')
          .insert(progressRecords);

      final duration = DateTime.now().difference(startTime);
      print('✅ [ENROLL] User enrolled and progress initialized in ${duration.inMilliseconds}ms');
      
      return true;

    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ENROLL] Enrollment failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return false;
    }
  }

  // Check if user is enrolled in course
  static Future<bool> isUserEnrolledInCourse(String userId, String courseId) async {
    try {
      final enrollment = await client
          .from('course_enrollments')
          .select('id')
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .eq('status', 'active')
          .maybeSingle();

      return enrollment != null;
    } catch (e) {
      print('❌ [ENROLLMENT] Error checking enrollment: $e');
      return false;
    }
  }
}