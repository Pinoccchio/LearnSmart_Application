enum ModuleProgressStatus {
  locked,
  available,
  inProgress,
  completed,
}

extension ModuleProgressStatusExtension on ModuleProgressStatus {
  String get value {
    switch (this) {
      case ModuleProgressStatus.locked:
        return 'locked';
      case ModuleProgressStatus.available:
        return 'available';
      case ModuleProgressStatus.inProgress:
        return 'in_progress';
      case ModuleProgressStatus.completed:
        return 'completed';
    }
  }

  static ModuleProgressStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'locked':
        return ModuleProgressStatus.locked;
      case 'available':
        return ModuleProgressStatus.available;
      case 'in_progress':
        return ModuleProgressStatus.inProgress;
      case 'completed':
        return ModuleProgressStatus.completed;
      default:
        return ModuleProgressStatus.locked;
    }
  }
}

class UserModuleProgress {
  final String id;
  final String userId;
  final String courseId;
  final String moduleId;
  final ModuleProgressStatus status;
  final double? bestScore;
  final double? latestScore;
  final int attemptCount;
  final bool passed;
  final bool needsRemedial;
  final bool remedialCompleted;
  final int remedialSessionsCount;
  final String? bestScoreTechnique;
  final String? latestSessionId;
  final String? bestSessionId;
  final DateTime? firstAttemptAt;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final DateTime? unlockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModuleProgress({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.moduleId,
    required this.status,
    this.bestScore,
    this.latestScore,
    required this.attemptCount,
    required this.passed,
    required this.needsRemedial,
    required this.remedialCompleted,
    required this.remedialSessionsCount,
    this.bestScoreTechnique,
    this.latestSessionId,
    this.bestSessionId,
    this.firstAttemptAt,
    this.lastAttemptAt,
    this.completedAt,
    this.unlockedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModuleProgress.fromJson(Map<String, dynamic> json) {
    return UserModuleProgress(
      id: json['id'],
      userId: json['user_id'],
      courseId: json['course_id'],
      moduleId: json['module_id'],
      status: ModuleProgressStatusExtension.fromString(json['status']),
      bestScore: json['best_score']?.toDouble(),
      latestScore: json['latest_score']?.toDouble(),
      attemptCount: json['attempt_count'] ?? 0,
      passed: json['passed'] ?? false,
      needsRemedial: json['needs_remedial'] ?? false,
      remedialCompleted: json['remedial_completed'] ?? false,
      remedialSessionsCount: json['remedial_sessions_count'] ?? 0,
      bestScoreTechnique: json['best_score_technique'],
      latestSessionId: json['latest_session_id'],
      bestSessionId: json['best_session_id'],
      firstAttemptAt: json['first_attempt_at'] != null
          ? DateTime.parse(json['first_attempt_at'])
          : null,
      lastAttemptAt: json['last_attempt_at'] != null
          ? DateTime.parse(json['last_attempt_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.parse(json['unlocked_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'course_id': courseId,
      'module_id': moduleId,
      'status': status.value,
      'best_score': bestScore,
      'latest_score': latestScore,
      'attempt_count': attemptCount,
      'passed': passed,
      'needs_remedial': needsRemedial,
      'remedial_completed': remedialCompleted,
      'remedial_sessions_count': remedialSessionsCount,
      'best_score_technique': bestScoreTechnique,
      'latest_session_id': latestSessionId,
      'best_session_id': bestSessionId,
      'first_attempt_at': firstAttemptAt?.toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'unlocked_at': unlockedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModuleProgress copyWith({
    String? id,
    String? userId,
    String? courseId,
    String? moduleId,
    ModuleProgressStatus? status,
    double? bestScore,
    double? latestScore,
    int? attemptCount,
    bool? passed,
    bool? needsRemedial,
    bool? remedialCompleted,
    int? remedialSessionsCount,
    String? bestScoreTechnique,
    String? latestSessionId,
    String? bestSessionId,
    DateTime? firstAttemptAt,
    DateTime? lastAttemptAt,
    DateTime? completedAt,
    DateTime? unlockedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModuleProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      status: status ?? this.status,
      bestScore: bestScore ?? this.bestScore,
      latestScore: latestScore ?? this.latestScore,
      attemptCount: attemptCount ?? this.attemptCount,
      passed: passed ?? this.passed,
      needsRemedial: needsRemedial ?? this.needsRemedial,
      remedialCompleted: remedialCompleted ?? this.remedialCompleted,
      remedialSessionsCount: remedialSessionsCount ?? this.remedialSessionsCount,
      bestScoreTechnique: bestScoreTechnique ?? this.bestScoreTechnique,
      latestSessionId: latestSessionId ?? this.latestSessionId,
      bestSessionId: bestSessionId ?? this.bestSessionId,
      firstAttemptAt: firstAttemptAt ?? this.firstAttemptAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      completedAt: completedAt ?? this.completedAt,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  bool get isLocked => status == ModuleProgressStatus.locked;
  bool get isAvailable => status == ModuleProgressStatus.available || status == ModuleProgressStatus.inProgress;
  bool get isCompleted => status == ModuleProgressStatus.completed && passed;
  bool get hasAttempts => attemptCount > 0;
  bool get hasPassingScore => bestScore != null && bestScore! >= 80.0;
  
  double get progressPercentage {
    if (isCompleted) return 100.0;
    if (hasAttempts) return 50.0;
    if (isAvailable) return 10.0;
    return 0.0;
  }

  @override
  String toString() {
    return 'UserModuleProgress(moduleId: $moduleId, status: ${status.value}, passed: $passed, bestScore: $bestScore)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModuleProgress && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CourseProgress {
  final String courseId;
  final String userId;
  final List<UserModuleProgress> moduleProgresses;
  final int totalModules;
  final int completedModules;
  final int availableModules;
  final int lockedModules;
  final double overallProgress;

  const CourseProgress({
    required this.courseId,
    required this.userId,
    required this.moduleProgresses,
    required this.totalModules,
    required this.completedModules,
    required this.availableModules,
    required this.lockedModules,
    required this.overallProgress,
  });

  factory CourseProgress.fromModuleProgresses(
    String courseId,
    String userId,
    List<UserModuleProgress> progresses,
  ) {
    final total = progresses.length;
    final completed = progresses.where((p) => p.isCompleted).length;
    final available = progresses.where((p) => p.isAvailable).length;
    final locked = progresses.where((p) => p.isLocked).length;
    final progress = total > 0 ? (completed / total) * 100 : 0.0;

    return CourseProgress(
      courseId: courseId,
      userId: userId,
      moduleProgresses: progresses,
      totalModules: total,
      completedModules: completed,
      availableModules: available,
      lockedModules: locked,
      overallProgress: progress,
    );
  }

  UserModuleProgress? getModuleProgress(String moduleId) {
    try {
      return moduleProgresses.firstWhere((p) => p.moduleId == moduleId);
    } catch (e) {
      return null;
    }
  }

  bool isModuleCompleted(String moduleId) {
    final progress = getModuleProgress(moduleId);
    return progress?.isCompleted ?? false;
  }

  bool isModuleLocked(String moduleId) {
    final progress = getModuleProgress(moduleId);
    return progress?.isLocked ?? true;
  }

  bool canAccessModule(String moduleId) {
    final progress = getModuleProgress(moduleId);
    return progress?.isAvailable ?? false;
  }

  @override
  String toString() {
    return 'CourseProgress(courseId: $courseId, completed: $completedModules/$totalModules, progress: ${overallProgress.toStringAsFixed(1)}%)';
  }
}