import 'package:flutter/material.dart';

class Course {
  final String id;
  final String title;
  final String description;
  final double progress;
  final Color color;
  final List<Module> modules;
  final int completedModules;
  final int totalModules;
  final DateTime? enrolledAt;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.color,
    required this.modules,
    this.completedModules = 0,
    this.totalModules = 0,
    this.enrolledAt,
  });

  /// Factory constructor to create Course from database data
  factory Course.fromDatabaseData(Map<String, dynamic> data) {
    final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
    final completedModules = (data['completedModules'] as int?) ?? 0;
    final totalModules = (data['totalModules'] as int?) ?? 0;
    
    // Generate color based on course title/type
    final color = _getCourseColor(data['title'] as String? ?? '');
    
    // Convert modules data if available
    final modulesList = <Module>[];
    final modules = data['modules'] as List?;
    final moduleProgress = data['moduleProgress'] as Map<String, dynamic>?;
    
    if (modules != null) {
      for (final moduleData in modules) {
        final moduleId = moduleData['id'] as String;
        final progressInfo = moduleProgress?[moduleId] as Map<String, dynamic>?;
        
        modulesList.add(Module(
          id: moduleId,
          title: moduleData['title'] as String,
          courseId: data['id'] as String,
          isCompleted: progressInfo?['passed'] == true,
          progress: progressInfo?['passed'] == true ? 1.0 : 0.0,
          orderIndex: (moduleData['order_index'] as int?) ?? 0,
          needsRemedial: progressInfo?['needs_remedial'] == true,
          latestScore: (progressInfo?['latest_score'] as num?)?.toDouble(),
        ));
      }
    }

    return Course(
      id: data['id'] as String,
      title: data['title'] as String? ?? 'Unknown Course',
      description: data['description'] as String? ?? '',
      progress: progress,
      color: color,
      modules: modulesList,
      completedModules: completedModules,
      totalModules: totalModules,
      enrolledAt: data['enrolledAt'] != null 
          ? DateTime.parse(data['enrolledAt'] as String) 
          : null,
    );
  }

  /// Generate color based on course title/category
  static Color _getCourseColor(String title) {
    final titleLower = title.toLowerCase();
    
    if (titleLower.contains('criminal') || titleLower.contains('law')) {
      return const Color(0xFF3B82F6); // Blue for law courses
    } else if (titleLower.contains('investigation') || titleLower.contains('detection')) {
      return const Color(0xFF8B5CF6); // Purple for investigation
    } else if (titleLower.contains('administration') || titleLower.contains('management')) {
      return const Color(0xFF10B981); // Green for administration
    } else if (titleLower.contains('criminalistics') || titleLower.contains('forensic')) {
      return const Color(0xFFEF4444); // Red for forensics
    } else if (titleLower.contains('criminology') || titleLower.contains('behavior')) {
      return const Color(0xFF6366F1); // Indigo for psychology/behavior
    } else if (titleLower.contains('correctional') || titleLower.contains('rehabilitation')) {
      return const Color(0xFFF59E0B); // Amber for corrections
    } else {
      return const Color(0xFF6B7280); // Gray as default
    }
  }

  /// Check if this course is currently in progress
  bool get isInProgress => progress > 0.0 && progress < 1.0;
  
  /// Check if this course is completed
  bool get isCompleted => progress >= 1.0;
  
  /// Get progress percentage as integer
  int get progressPercentage => (progress * 100).round();
}

class Module {
  final String id;
  final String title;
  final String courseId;
  final bool isCompleted;
  final double progress;
  final int orderIndex;
  final bool needsRemedial;
  final double? latestScore;

  Module({
    required this.id,
    required this.title,
    required this.courseId,
    required this.isCompleted,
    required this.progress,
    this.orderIndex = 0,
    this.needsRemedial = false,
    this.latestScore,
  });
}

class StudyTechnique {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  StudyTechnique({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}