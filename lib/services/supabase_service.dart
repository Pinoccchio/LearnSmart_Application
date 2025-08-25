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
        })
        .select()
        .single();

    return app_user.User.fromSupabase(response);
  }

  static Future<app_user.User?> getUserProfile(String userId) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return app_user.User.fromSupabase(response);
    } catch (e) {
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
          
          // Calculate progress (simple version)
          final progress = await _calculateCourseProgress(userId, course.id);
          print('📈 [PROGRESS] Course ${course.id}: ${(progress * 100).toInt()}%');
          
          courses.add(Course(
            id: course.id,
            title: course.title,
            description: course.description,
            imageUrl: course.imageUrl,
            instructorId: course.instructorId,
            instructorName: course.instructorName,
            instructorEmail: course.instructorEmail,
            status: course.status,
            modules: course.modules,
            progress: progress,
            createdAt: course.createdAt,
          ));
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
      print('📤 [QUERY] modules.select(id).eq(course_id, $courseId)');
      final modulesResponse = await client
          .from('modules')
          .select('id')
          .eq('course_id', courseId);

      final duration = DateTime.now().difference(startTime);
      print('📥 [RESPONSE] Found ${modulesResponse.length} modules in ${duration.inMilliseconds}ms');

      if (modulesResponse.isEmpty) {
        print('⚠️ [WARNING] No modules found for course $courseId');
        return 0.0;
      }

      // Mock progress - replace with real logic later
      const mockProgress = 0.3;
      print('📊 [PROGRESS] Returning mock progress: ${(mockProgress * 100).toInt()}%');
      return mockProgress;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      print('❌ [ERROR] _calculateCourseProgress failed after ${duration.inMilliseconds}ms: $e');
      print('📍 [STACK TRACE] $stackTrace');
      return 0.0;
    }
  }
}