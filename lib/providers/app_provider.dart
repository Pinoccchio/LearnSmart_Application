import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/course.dart';
import '../models/activity.dart';
import '../services/study_analytics_service.dart';
import '../services/supabase_service.dart';

class AppProvider with ChangeNotifier {
  int _currentIndex = 0;
  StudyStats _studyStats = StudyStats.loading();
  List<Activity> _activities = [];
  bool _activitiesLoading = false;
  String? _activitiesError;
  
  // Home screen data state
  List<Course> _realCourses = [];
  Map<String, dynamic>? _homeScreenData;
  bool _homeScreenLoading = false;
  String? _homeScreenError;
  
  // Profile data state
  Map<String, dynamic>? _profileData;
  bool _profileLoading = false;
  String? _profileError;
  
  final StudyAnalyticsService _analyticsService = StudyAnalyticsService();
  
  int get currentIndex => _currentIndex;
  StudyStats get studyStats => _studyStats;
  List<Activity> get activities => _activities;
  bool get activitiesLoading => _activitiesLoading;
  bool get activitiesHasError => _activitiesError != null;
  String? get activitiesError => _activitiesError;
  
  // Home screen getters
  List<Course> get realCourses => _realCourses;
  Map<String, dynamic>? get homeScreenData => _homeScreenData;
  bool get homeScreenLoading => _homeScreenLoading;
  bool get homeScreenHasError => _homeScreenError != null;
  String? get homeScreenError => _homeScreenError;
  
  // Profile getters
  Map<String, dynamic>? get profileData => _profileData;
  bool get profileLoading => _profileLoading;
  bool get profileHasError => _profileError != null;
  String? get profileError => _profileError;
  
  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  // Mock courses data
  final List<Course> _courses = [
    Course(
      id: '1',
      title: 'Criminal Jurisprudence and Procedure',
      description: 'Learn the principles of criminal law and the legal process, including investigation, trial, and sentencing.',
      progress: 0.7,
      color: const Color(0xFF3B82F6),
      modules: [
        Module(id: '1', title: 'Module 1', courseId: '1', isCompleted: true, progress: 1.0),
        Module(id: '2', title: 'Module 2', courseId: '1', isCompleted: true, progress: 1.0),
        Module(id: '3', title: 'Module 3', courseId: '1', isCompleted: false, progress: 0.4),
        Module(id: '4', title: 'Final Quiz', courseId: '1', isCompleted: false, progress: 0.0),
      ],
    ),
    Course(
      id: '2',
      title: 'Law Enforcement Administration',
      description: 'Understand the administrative aspects of law enforcement agencies.',
      progress: 0.3,
      color: const Color(0xFF10B981),
      modules: [
        Module(id: '5', title: 'Module 1', courseId: '2', isCompleted: true, progress: 1.0),
        Module(id: '6', title: 'Module 2', courseId: '2', isCompleted: false, progress: 0.2),
      ],
    ),
    Course(
      id: '3',
      title: 'Crime Detection and Investigation',
      description: 'Learn investigative techniques and crime scene analysis.',
      progress: 0.5,
      color: const Color(0xFF8B5CF6),
      modules: [
        Module(id: '7', title: 'Module 1', courseId: '3', isCompleted: true, progress: 1.0),
        Module(id: '8', title: 'Module 2', courseId: '3', isCompleted: false, progress: 0.5),
      ],
    ),
    Course(
      id: '4',
      title: 'Criminalistics',
      description: 'Study the scientific methods used in criminal investigation.',
      progress: 0.1,
      color: const Color(0xFFEF4444),
      modules: [
        Module(id: '9', title: 'Module 1', courseId: '4', isCompleted: false, progress: 0.1),
      ],
    ),
    Course(
      id: '5',
      title: 'Correctional Administration',
      description: 'Learn about prison systems and correctional management.',
      progress: 0.0,
      color: const Color(0xFF8B5CF6),
      modules: [
        Module(id: '10', title: 'Module 1', courseId: '5', isCompleted: false, progress: 0.0),
      ],
    ),
    Course(
      id: '6',
      title: 'Criminology',
      description: 'Study the nature, causes, and prevention of criminal behavior.',
      progress: 0.2,
      color: const Color(0xFF6366F1),
      modules: [
        Module(id: '11', title: 'Module 1', courseId: '6', isCompleted: false, progress: 0.2),
      ],
    ),
  ];

  List<Course> get courses => _realCourses.isNotEmpty ? _realCourses : _courses;

  // Study techniques - IDs match database schema
  final List<StudyTechnique> _studyTechniques = [
    StudyTechnique(
      id: 'active_recall',
      name: 'Active Recall',
      description: 'Present AI-generated flashcards before showing learning material. Answer from memory before revealing correct answers.',
      icon: LucideIcons.brain,
    ),
    StudyTechnique(
      id: 'pomodoro_technique',
      name: 'Pomodoro Technique',
      description: 'Focus efficiently through timed sessions (25 minutes study + 5 minute break) with built-in timer and distraction control.',
      icon: LucideIcons.timer,
    ),
    StudyTechnique(
      id: 'feynman_technique',
      name: 'Feynman Technique',
      description: 'Explain topics in your own words using text or voice notes. Fill knowledge gaps by re-reading material after submission.',
      icon: LucideIcons.messageSquare,
    ),
    StudyTechnique(
      id: 'retrieval_practice',
      name: 'Retrieval Practice',
      description: 'Answer short quizzes and open-ended questions immediately after reading material, without notes or references.',
      icon: LucideIcons.bookOpen,
    ),
  ];

  List<StudyTechnique> get studyTechniques => _studyTechniques;

  // Load study stats from database
  Future<void> loadStudyStats({String? userId}) async {
    print('📊 [APP PROVIDER] Loading study stats...');
    
    try {
      // Set loading state
      _studyStats = StudyStats.loading();
      notifyListeners();

      // Get current user ID if not provided
      String? currentUserId = userId;
      if (currentUserId == null) {
        final currentUser = SupabaseService.currentAuthUser;
        if (currentUser == null) {
          print('⚠️ [APP PROVIDER] No authenticated user found');
          _studyStats = StudyStats.empty();
          notifyListeners();
          return;
        }
        currentUserId = currentUser.id;
      }

      print('📊 [APP PROVIDER] Loading stats for user: $currentUserId');

      // Load real study stats from service
      final statsData = await _analyticsService.getUserStudyStats(currentUserId);
      
      // Convert service data to StudyStats model
      _studyStats = StudyStats.fromServiceData(statsData);
      
      print('✅ [APP PROVIDER] Study stats loaded successfully');
      notifyListeners();
      
    } catch (e) {
      print('❌ [APP PROVIDER] Error loading study stats: $e');
      _studyStats = StudyStats.error('Failed to load study statistics. Please try again.');
      notifyListeners();
    }
  }

  // Refresh study stats
  Future<void> refreshStudyStats() async {
    await loadStudyStats();
  }

  // Load user activities from database
  Future<void> loadActivities({String? userId}) async {
    print('📚 [APP PROVIDER] Loading activities...');
    
    try {
      // Set loading state
      _activitiesLoading = true;
      _activitiesError = null;
      notifyListeners();

      // Get current user ID if not provided
      String? currentUserId = userId;
      if (currentUserId == null) {
        final currentUser = SupabaseService.currentAuthUser;
        if (currentUser == null) {
          print('⚠️ [APP PROVIDER] No authenticated user found for activities');
          _activities = [];
          _activitiesLoading = false;
          notifyListeners();
          return;
        }
        currentUserId = currentUser.id;
      }

      print('📚 [APP PROVIDER] Loading activities for user: $currentUserId');

      // Load real activities from service
      final activitiesData = await _analyticsService.getUserRecentActivities(currentUserId);
      
      // Convert service data to Activity objects
      _activities = activitiesData.map((data) => Activity.fromSessionData(data)).toList();
      
      print('✅ [APP PROVIDER] Activities loaded successfully: ${_activities.length} items');
      _activitiesLoading = false;
      notifyListeners();
      
    } catch (e) {
      print('❌ [APP PROVIDER] Error loading activities: $e');
      _activitiesError = 'Failed to load activities. Please try again.';
      _activitiesLoading = false;
      notifyListeners();
    }
  }

  // Refresh activities
  Future<void> refreshActivities() async {
    await loadActivities();
  }

  // Load home screen data from database
  Future<void> loadHomeScreenData({String? userId}) async {
    print('🏠 [APP PROVIDER] ========================================');
    print('🏠 [APP PROVIDER] Loading home screen data...');

    try {
      // Set loading state
      _homeScreenLoading = true;
      _homeScreenError = null;
      notifyListeners();

      // Get current user ID if not provided
      String? currentUserId = userId;
      if (currentUserId == null) {
        final currentUser = SupabaseService.currentAuthUser;
        if (currentUser == null) {
          print('⚠️ [APP PROVIDER] No authenticated user found for home screen');
          print('⚠️ [APP PROVIDER] User needs to sign in first');
          _realCourses = [];
          _homeScreenData = null;
          _homeScreenLoading = false;
          _homeScreenError = 'Not authenticated. Please sign in again.';
          notifyListeners();
          return;
        }
        currentUserId = currentUser.id;
        print('🏠 [APP PROVIDER] Using authenticated user: $currentUserId');
        print('🏠 [APP PROVIDER] User email: ${currentUser.email}');
      }

      print('🏠 [APP PROVIDER] Calling StudyAnalyticsService.getHomeScreenData()...');

      // Load real home screen data from service
      final data = await _analyticsService.getHomeScreenData(currentUserId);

      print('🏠 [APP PROVIDER] Received data from service');
      print('🏠 [APP PROVIDER] Data keys: ${data.keys.join(", ")}');

      // Convert courses data to Course objects
      final coursesData = data['courses'] as List<Map<String, dynamic>>? ?? [];
      print('🏠 [APP PROVIDER] Processing ${coursesData.length} courses...');

      _realCourses = coursesData.map((courseData) => Course.fromDatabaseData(courseData)).toList();
      _homeScreenData = data;

      print('✅ [APP PROVIDER] Home screen data loaded successfully');
      print('✅ [APP PROVIDER] Courses: ${_realCourses.map((c) => c.title).join(", ")}');
      print('✅ [APP PROVIDER] Total courses: ${_realCourses.length}');
      _homeScreenLoading = false;
      notifyListeners();

    } catch (e, stackTrace) {
      print('❌ [APP PROVIDER] ========================================');
      print('❌ [APP PROVIDER] ERROR loading home screen data');
      print('❌ [APP PROVIDER] Error: $e');
      print('❌ [APP PROVIDER] Error type: ${e.runtimeType}');
      print('❌ [APP PROVIDER] Stack trace: $stackTrace');
      _homeScreenError = 'Failed to load home screen data: ${e.toString()}';
      _homeScreenLoading = false;
      notifyListeners();
    }
  }

  // Refresh home screen data
  Future<void> refreshHomeScreenData() async {
    await loadHomeScreenData();
  }

  // Get today's study plan from loaded data
  List<Map<String, dynamic>> get todaysStudyPlan {
    if (_homeScreenData == null) return [];
    final studyPlan = _homeScreenData!['studyPlan'] as Map<String, dynamic>? ?? {};
    return (studyPlan['recommendations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  // Get current learning path from loaded data
  Map<String, dynamic>? get currentLearningPath {
    if (_homeScreenData == null) return null;
    return _homeScreenData!['currentLearningPath'] as Map<String, dynamic>?;
  }

  // Load profile data from database
  Future<void> loadProfileData({String? userId}) async {
    print('👤 [APP PROVIDER] Loading profile data...');
    
    try {
      // Set loading state
      _profileLoading = true;
      _profileError = null;
      notifyListeners();

      // Get current user ID if not provided
      String? currentUserId = userId;
      if (currentUserId == null) {
        final currentUser = SupabaseService.currentAuthUser;
        if (currentUser == null) {
          print('⚠️ [APP PROVIDER] No authenticated user found for profile');
          _profileData = null;
          _profileLoading = false;
          notifyListeners();
          return;
        }
        currentUserId = currentUser.id;
      }

      print('👤 [APP PROVIDER] Loading profile data for user: $currentUserId');

      // Load real profile data from service
      final data = await _analyticsService.getUserProfileData(currentUserId);
      
      _profileData = data;
      
      print('✅ [APP PROVIDER] Profile data loaded successfully');
      print('🔍 [APP PROVIDER DEBUG] Profile data keys: ${data.keys.toList()}');
      print('🔍 [APP PROVIDER DEBUG] Recommendations in data: ${(data['recommendations'] as List?)?.length ?? 0}');
      print('🔍 [APP PROVIDER DEBUG] Strengths in data: ${(data['strengths'] as List?)?.length ?? 0}');
      _profileLoading = false;
      notifyListeners();
      
    } catch (e) {
      print('❌ [APP PROVIDER] Error loading profile data: $e');
      _profileError = 'Failed to load profile data. Please try again.';
      _profileLoading = false;
      notifyListeners();
    }
  }

  // Refresh profile data
  Future<void> refreshProfileData() async {
    await loadProfileData();
  }

  // Update user profile information
  Future<bool> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      print('👤 [APP PROVIDER] Updating user profile...');

      final currentUser = SupabaseService.currentAuthUser;
      if (currentUser == null) {
        print('⚠️ [APP PROVIDER] No authenticated user found for profile update');
        return false;
      }

      // Update user profile in database
      await SupabaseService.client
          .from('users')
          .update(updates)
          .eq('id', currentUser.id);

      // Reload profile data to reflect changes
      await loadProfileData();
      
      print('✅ [APP PROVIDER] User profile updated successfully');
      return true;

    } catch (e) {
      print('❌ [APP PROVIDER] Error updating user profile: $e');
      return false;
    }
  }

  // Get personalized recommendations from profile data
  List<Map<String, dynamic>> get personalizedRecommendations {
    if (_profileData == null) {
      print('🔍 [APP PROVIDER DEBUG] personalizedRecommendations: _profileData is null');
      return [];
    }
    final recommendations = _profileData!['recommendations'] as List<dynamic>? ?? [];
    print('🔍 [APP PROVIDER DEBUG] personalizedRecommendations: returning ${recommendations.length} items');
    return recommendations.cast<Map<String, dynamic>>();
  }

  // Get user strengths from profile data
  List<Map<String, dynamic>> get userStrengths {
    if (_profileData == null) {
      print('🔍 [APP PROVIDER DEBUG] userStrengths: _profileData is null');
      return [];
    }
    final strengths = _profileData!['strengths'] as List<dynamic>? ?? [];
    print('🔍 [APP PROVIDER DEBUG] userStrengths: returning ${strengths.length} items');
    return strengths.cast<Map<String, dynamic>>();
  }

  // Get user information from profile data
  Map<String, dynamic>? get userInfo {
    if (_profileData == null) return null;
    return _profileData!['user'] as Map<String, dynamic>?;
  }

  // Initialize provider - call this when app starts or user logs in
  Future<void> initialize() async {
    print('🚀 [APP PROVIDER] Initializing...');
    await Future.wait([
      loadStudyStats(),
      loadActivities(),
      loadHomeScreenData(),
      loadProfileData(),
    ]);
  }
}