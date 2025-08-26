import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/app_colors.dart';

class Activity {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final ActivityType type;
  final IconData icon;
  final Color color;

  Activity({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    required this.icon,
    required this.color,
  });

  /// Factory constructor to create Activity from database session data
  factory Activity.fromSessionData(Map<String, dynamic> sessionData) {
    final sessionType = sessionData['session_type'] as String;
    final id = sessionData['id'] as String;
    final completedAt = DateTime.parse(sessionData['completed_at'] as String);
    final data = sessionData['session_data'] as Map<String, dynamic>? ?? {};

    // Extract course and module information from session data
    final courseTitle = data['course_title'] as String? ?? 'Unknown Course';
    final moduleTitle = data['module_title'] as String? ?? 'Unknown Module';

    switch (sessionType) {
      case 'active_recall':
        return Activity(
          id: id,
          title: 'Completed flashcard session',
          description: _formatModuleTitle(courseTitle, moduleTitle),
          timestamp: completedAt,
          type: ActivityType.studySession,
          icon: LucideIcons.brain,
          color: const Color(0xFF10B981), // Green for active recall
        );

      case 'pomodoro':
        final totalCycles = data['total_cycles'] as int? ?? 0;
        final focusScore = data['focus_score'] as double? ?? 0.0;
        return Activity(
          id: id,
          title: 'Focused study session',
          description: _formatPomodoroDescription(courseTitle, moduleTitle, totalCycles, focusScore),
          timestamp: completedAt,
          type: ActivityType.studySession,
          icon: LucideIcons.timer,
          color: const Color(0xFF3B82F6), // Blue for pomodoro
        );

      case 'feynman':
        final topicCount = data['topic_count'] as int? ?? 1;
        return Activity(
          id: id,
          title: 'Explained concepts',
          description: _formatFeynmanDescription(courseTitle, moduleTitle, topicCount),
          timestamp: completedAt,
          type: ActivityType.studySession,
          icon: LucideIcons.messageSquare,
          color: const Color(0xFFEF4444), // Red for feynman
        );

      case 'retrieval_practice':
        final questionsAnswered = data['questions_answered'] as int? ?? 0;
        final averageScore = data['average_score'] as double? ?? 0.0;
        return Activity(
          id: id,
          title: 'Completed practice quiz',
          description: _formatRetrievalDescription(courseTitle, moduleTitle, questionsAnswered, averageScore),
          timestamp: completedAt,
          type: ActivityType.quiz,
          icon: LucideIcons.bookOpen,
          color: const Color(0xFF8B5CF6), // Purple for retrieval practice
        );

      default:
        return Activity(
          id: id,
          title: 'Study session completed',
          description: _formatModuleTitle(courseTitle, moduleTitle),
          timestamp: completedAt,
          type: ActivityType.studySession,
          icon: LucideIcons.bookOpen,
          color: AppColors.bgPrimary,
        );
    }
  }

  /// Helper method to format module title consistently
  static String _formatModuleTitle(String courseTitle, String moduleTitle) {
    if (courseTitle == 'Unknown Course' && moduleTitle == 'Unknown Module') {
      return 'Study session completed';
    } else if (courseTitle == 'Unknown Course') {
      return moduleTitle;
    } else if (moduleTitle == 'Unknown Module') {
      return courseTitle;
    } else {
      // Clean up module title (remove numbers and dashes at the beginning)
      final cleanModuleTitle = moduleTitle.replaceFirst(RegExp(r'^\d+\s*-\s*'), '');
      return '$courseTitle - $cleanModuleTitle';
    }
  }

  /// Helper method to format Pomodoro session description
  static String _formatPomodoroDescription(String courseTitle, String moduleTitle, int cycles, double focusScore) {
    final baseDescription = _formatModuleTitle(courseTitle, moduleTitle);
    if (cycles > 0) {
      final focusText = focusScore > 0 ? ' (${focusScore.toInt()}% focus)' : '';
      return '$baseDescription • $cycles cycles$focusText';
    }
    return baseDescription;
  }

  /// Helper method to format Feynman session description
  static String _formatFeynmanDescription(String courseTitle, String moduleTitle, int topicCount) {
    final baseDescription = _formatModuleTitle(courseTitle, moduleTitle);
    if (topicCount > 1) {
      return '$baseDescription • $topicCount topics explained';
    }
    return baseDescription;
  }

  /// Helper method to format Retrieval Practice session description
  static String _formatRetrievalDescription(String courseTitle, String moduleTitle, int questions, double averageScore) {
    final baseDescription = _formatModuleTitle(courseTitle, moduleTitle);
    if (questions > 0) {
      final scoreText = averageScore > 0 ? ' (${averageScore.toInt()}% avg)' : '';
      return '$baseDescription • $questions questions$scoreText';
    }
    return baseDescription;
  }
}

enum ActivityType {
  studySession,
  quiz,
  streak,
  module,
  achievement,
}

enum StudyStatsState {
  loading,
  loaded,
  error,
  empty,
}

class StudyStats {
  final StudyStatsState state;
  final int consistency;
  final String totalTime;
  final String topTechnique;
  final List<TechniqueUsage> techniqueUsage;
  final String? errorMessage;

  StudyStats({
    required this.state,
    this.consistency = 0,
    this.totalTime = '0m',
    this.topTechnique = 'None',
    this.techniqueUsage = const [],
    this.errorMessage,
  });

  // Factory constructors for different states
  factory StudyStats.loading() {
    return StudyStats(state: StudyStatsState.loading);
  }

  factory StudyStats.error(String errorMessage) {
    return StudyStats(
      state: StudyStatsState.error,
      errorMessage: errorMessage,
    );
  }

  factory StudyStats.empty() {
    return StudyStats(state: StudyStatsState.empty);
  }

  factory StudyStats.loaded({
    required int consistency,
    required String totalTime,
    required String topTechnique,
    required List<TechniqueUsage> techniqueUsage,
  }) {
    return StudyStats(
      state: StudyStatsState.loaded,
      consistency: consistency,
      totalTime: totalTime,
      topTechnique: topTechnique,
      techniqueUsage: techniqueUsage,
    );
  }

  // Factory constructor from service data
  factory StudyStats.fromServiceData(Map<String, dynamic> data) {
    final techniqueUsageData = data['techniqueUsage'] as List<Map<String, dynamic>>? ?? [];
    final techniqueUsage = techniqueUsageData.map((item) => TechniqueUsage.fromMap(item)).toList();

    if (techniqueUsage.isEmpty) {
      return StudyStats.empty();
    }

    return StudyStats.loaded(
      consistency: data['consistency'] as int? ?? 0,
      totalTime: data['totalTime'] as String? ?? '0m',
      topTechnique: data['topTechnique'] as String? ?? 'None',
      techniqueUsage: techniqueUsage,
    );
  }

  bool get isLoading => state == StudyStatsState.loading;
  bool get hasError => state == StudyStatsState.error;
  bool get isEmpty => state == StudyStatsState.empty;
  bool get hasData => state == StudyStatsState.loaded;
}

class TechniqueUsage {
  final String technique;
  final double percentage;
  final int timesUsed;
  final Color color;

  TechniqueUsage({
    required this.technique,
    required this.percentage,
    required this.timesUsed,
    required this.color,
  });

  // Factory constructor from service data
  factory TechniqueUsage.fromMap(Map<String, dynamic> map) {
    return TechniqueUsage(
      technique: map['technique'] as String? ?? '',
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      timesUsed: (map['timesUsed'] as num?)?.toInt() ?? 0,
      color: Color(map['color'] as int? ?? 0xFF000000),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'technique': technique,
      'percentage': percentage,
      'timesUsed': timesUsed,
      'color': color.value,
    };
  }
}