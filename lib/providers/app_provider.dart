import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/course.dart';
import '../models/activity.dart';
import '../constants/app_colors.dart';

class AppProvider with ChangeNotifier {
  int _currentIndex = 0;
  
  int get currentIndex => _currentIndex;
  
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

  // Study techniques
  final List<StudyTechnique> _studyTechniques = [
    StudyTechnique(
      id: '1',
      name: 'Active Recall',
      description: 'Strengthen memory by practicing retrieval patterns and understanding.',
      icon: LucideIcons.brain,
    ),
    StudyTechnique(
      id: '2',
      name: 'Pomodoro Technique',
      description: 'Focus efficiently through timed sessions (e.g., 25 minutes focused followed by a 5-minute break) to enhance concentration.',
      icon: LucideIcons.timer,
    ),
    StudyTechnique(
      id: '3',
      name: 'Feynman Technique',
      description: 'Enhance understanding by explaining topics in your own terms and to understand complex topics.',
      icon: LucideIcons.messageSquare,
    ),
    StudyTechnique(
      id: '4',
      name: 'Spaced Repetition',
      description: 'Boost comprehension through spaced practice and repetition.',
      icon: LucideIcons.repeat,
    ),
    StudyTechnique(
      id: '5',
      name: 'Retrieval Practice',
      description: 'Answer questions or quizzes from memory without any reference or information from notes.',
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

  // Mock study stats
  final StudyStats _studyStats = StudyStats(
    consistency: 85,
    totalTime: '1h 45m',
    topTechnique: 'Active Recall',
    techniqueUsage: [
      TechniqueUsage(
        technique: 'Pomodoro',
        percentage: 30.0,
        timesUsed: 12,
        color: const Color(0xFF3B82F6),
      ),
      TechniqueUsage(
        technique: 'Active Recall',
        percentage: 35.0,
        timesUsed: 15,
        color: const Color(0xFF10B981),
      ),
      TechniqueUsage(
        technique: 'Spaced Repetition',
        percentage: 20.0,
        timesUsed: 8,
        color: const Color(0xFF8B5CF6),
      ),
      TechniqueUsage(
        technique: 'Feynman Technique',
        percentage: 10.0,
        timesUsed: 4,
        color: const Color(0xFFEF4444),
      ),
      TechniqueUsage(
        technique: 'Retrieval Practice',
        percentage: 5.0,
        timesUsed: 2,
        color: const Color(0xFF6366F1),
      ),
    ],
  );

  StudyStats get studyStats => _studyStats;
}