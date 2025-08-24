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

class StudyStats {
  final int consistency;
  final String totalTime;
  final String topTechnique;
  final List<TechniqueUsage> techniqueUsage;

  StudyStats({
    required this.consistency,
    required this.totalTime,
    required this.topTechnique,
    required this.techniqueUsage,
  });
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
}