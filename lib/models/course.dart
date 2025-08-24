import 'package:flutter/material.dart';

class Course {
  final String id;
  final String title;
  final String description;
  final double progress;
  final Color color;
  final List<Module> modules;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.color,
    required this.modules,
  });
}

class Module {
  final String id;
  final String title;
  final String courseId;
  final bool isCompleted;
  final double progress;

  Module({
    required this.id,
    required this.title,
    required this.courseId,
    required this.isCompleted,
    required this.progress,
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