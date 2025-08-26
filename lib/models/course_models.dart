import 'package:flutter/material.dart';

class Course {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? instructorId;
  final String? instructorName;
  final String? instructorEmail;
  final String status;
  final List<Module> modules;
  final double progress;
  final DateTime createdAt;

  Course({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.instructorId,
    this.instructorName,
    this.instructorEmail,
    this.status = 'active',
    this.modules = const [],
    this.progress = 0.0,
    required this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    final instructor = json['instructor'];
    return Course(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['image_url'],
      instructorId: json['instructor_id'],
      instructorName: instructor?['name'],
      instructorEmail: instructor?['email'],
      status: json['status'] ?? 'active',
      modules: json['modules'] != null 
          ? (json['modules'] as List).map((m) => Module.fromJson(m)).toList()
          : [],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? instructorId,
    String? instructorName,
    String? instructorEmail,
    String? status,
    List<Module>? modules,
    double? progress,
    DateTime? createdAt,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      instructorEmail: instructorEmail ?? this.instructorEmail,
      status: status ?? this.status,
      modules: modules ?? this.modules,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Module {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int orderIndex;
  final List<String> availableTechniques;
  final String? prerequisiteModuleId;
  final bool isLocked;
  final List<CourseMaterial> materials;

  Module({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.orderIndex,
    this.availableTechniques = const [],
    this.prerequisiteModuleId,
    this.isLocked = false,
    this.materials = const [],
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id'],
      courseId: json['course_id'],
      title: json['title'],
      description: json['description'],
      orderIndex: json['order_index'],
      availableTechniques: json['available_techniques'] != null 
          ? List<String>.from(json['available_techniques'])
          : [],
      prerequisiteModuleId: json['prerequisite_module_id'],
      isLocked: json['is_locked'] ?? false,
      materials: json['course_materials'] != null 
          ? (json['course_materials'] as List).map((m) => CourseMaterial.fromJson(m)).toList()
          : [],
    );
  }
}

class CourseMaterial {
  final String id;
  final String moduleId;
  final String title;
  final String? description;
  final String fileUrl;
  final String fileType;
  final String fileName;
  final int orderIndex;

  CourseMaterial({
    required this.id,
    required this.moduleId,
    required this.title,
    this.description,
    required this.fileUrl,
    required this.fileType,
    required this.fileName,
    required this.orderIndex,
  });

  factory CourseMaterial.fromJson(Map<String, dynamic> json) {
    return CourseMaterial(
      id: json['id'],
      moduleId: json['module_id'],
      title: json['title'],
      description: json['description'],
      fileUrl: json['file_url'],
      fileType: json['file_type'],
      fileName: json['file_name'],
      orderIndex: json['order_index'],
    );
  }
}

class CourseEnrollment {
  final String id;
  final String userId;
  final String courseId;
  final String status;
  final DateTime enrolledAt;
  final DateTime? completedAt;

  CourseEnrollment({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.status,
    required this.enrolledAt,
    this.completedAt,
  });

  factory CourseEnrollment.fromJson(Map<String, dynamic> json) {
    return CourseEnrollment(
      id: json['id'],
      userId: json['user_id'],
      courseId: json['course_id'],
      status: json['status'],
      enrolledAt: DateTime.parse(json['enrolled_at']),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }
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