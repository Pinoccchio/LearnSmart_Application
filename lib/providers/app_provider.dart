import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/course.dart';
import '../models/activity.dart';
import '../constants/app_colors.dart';
import '../services/study_analytics_service.dart';
import '../services/supabase_service.dart';

class AppProvider with ChangeNotifier {
  int _currentIndex = 0;
  StudyStats _studyStats = StudyStats.loading();
  final StudyAnalyticsService _analyticsService = StudyAnalyticsService();
  
  int get currentIndex => _currentIndex;
  StudyStats get studyStats => _studyStats;
  
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

  List<Course> get courses => _courses;

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

  // Mock activities
  final List<Activity> _activities = [
    Activity(
      id: '1',
      title: 'Completed study session',
      description: 'Criminalistics Module 2',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: ActivityType.studySession,
      icon: LucideIcons.bookOpen,
      color: AppColors.success,
    ),
    Activity(
      id: '2',
      title: 'New streak achieved',
      description: '5 days in a row',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      type: ActivityType.streak,
      icon: LucideIcons.flame,
      color: AppColors.warning,
    ),
    Activity(
      id: '3',
      title: 'Finished quiz',
      description: 'Criminal Procedure Module',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: ActivityType.quiz,
      icon: LucideIcons.checkCircle,
      color: AppColors.bgPrimary,
    ),
  ];

  List<Activity> get activities => _activities;

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

  // Initialize provider - call this when app starts or user logs in
  Future<void> initialize() async {
    print('🚀 [APP PROVIDER] Initializing...');
    await loadStudyStats();
  }
}