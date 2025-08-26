import 'package:flutter/material.dart';

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