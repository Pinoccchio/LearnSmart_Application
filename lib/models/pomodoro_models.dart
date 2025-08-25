enum PomodoroSessionStatus {
  preparing,
  active,
  break_,
  completed,
  paused,
}

extension PomodoroSessionStatusExtension on PomodoroSessionStatus {
  String get value {
    switch (this) {
      case PomodoroSessionStatus.preparing:
        return 'preparing';
      case PomodoroSessionStatus.active:
        return 'active';
      case PomodoroSessionStatus.break_:
        return 'break';
      case PomodoroSessionStatus.completed:
        return 'completed';
      case PomodoroSessionStatus.paused:
        return 'paused';
    }
  }

  static PomodoroSessionStatus fromString(String value) {
    switch (value) {
      case 'preparing':
        return PomodoroSessionStatus.preparing;
      case 'active':
        return PomodoroSessionStatus.active;
      case 'break':
        return PomodoroSessionStatus.break_;
      case 'completed':
        return PomodoroSessionStatus.completed;
      case 'paused':
        return PomodoroSessionStatus.paused;
      default:
        return PomodoroSessionStatus.preparing;
    }
  }
}

enum PomodoroCycleType {
  work,
  shortBreak,
  longBreak,
}

extension PomodoroCycleTypeExtension on PomodoroCycleType {
  String get value {
    switch (this) {
      case PomodoroCycleType.work:
        return 'work';
      case PomodoroCycleType.shortBreak:
        return 'short_break';
      case PomodoroCycleType.longBreak:
        return 'long_break';
    }
  }

  static PomodoroCycleType fromString(String value) {
    switch (value) {
      case 'work':
        return PomodoroCycleType.work;
      case 'short_break':
        return PomodoroCycleType.shortBreak;
      case 'long_break':
        return PomodoroCycleType.longBreak;
      default:
        return PomodoroCycleType.work;
    }
  }
}

enum PomodoroNoteType {
  studyNote,
  reflection,
  quizAnswer,
}

extension PomodoroNoteTypeExtension on PomodoroNoteType {
  String get value {
    switch (this) {
      case PomodoroNoteType.studyNote:
        return 'study_note';
      case PomodoroNoteType.reflection:
        return 'reflection';
      case PomodoroNoteType.quizAnswer:
        return 'quiz_answer';
    }
  }

  String get displayName {
    switch (this) {
      case PomodoroNoteType.studyNote:
        return 'Study Note';
      case PomodoroNoteType.reflection:
        return 'Reflection';
      case PomodoroNoteType.quizAnswer:
        return 'Quiz Answer';
    }
  }

  static PomodoroNoteType fromString(String value) {
    switch (value) {
      case 'study_note':
        return PomodoroNoteType.studyNote;
      case 'reflection':
        return PomodoroNoteType.reflection;
      case 'quiz_answer':
        return PomodoroNoteType.quizAnswer;
      default:
        return PomodoroNoteType.studyNote;
    }
  }
}

class PomodoroSession {
  final String id;
  final String userId;
  final String moduleId;
  final PomodoroSessionStatus status;
  final int totalCyclesPlanned;
  final int cyclesCompleted;
  final int currentCycle;
  final int workDurationMinutes;
  final int shortBreakDurationMinutes;
  final int longBreakDurationMinutes;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> sessionData;
  final List<PomodoroCycle> cycles;
  final List<PomodoroNote> notes;

  PomodoroSession({
    required this.id,
    required this.userId,
    required this.moduleId,
    required this.status,
    this.totalCyclesPlanned = 4,
    this.cyclesCompleted = 0,
    this.currentCycle = 1,
    this.workDurationMinutes = 25,
    this.shortBreakDurationMinutes = 5,
    this.longBreakDurationMinutes = 15,
    required this.startedAt,
    this.completedAt,
    this.sessionData = const {},
    this.cycles = const [],
    this.notes = const [],
  });

  factory PomodoroSession.fromJson(Map<String, dynamic> json) {
    return PomodoroSession(
      id: json['id'],
      userId: json['user_id'],
      moduleId: json['module_id'],
      status: PomodoroSessionStatusExtension.fromString(json['status']),
      totalCyclesPlanned: json['total_cycles_planned'] ?? 4,
      cyclesCompleted: json['cycles_completed'] ?? 0,
      currentCycle: json['current_cycle'] ?? 1,
      workDurationMinutes: json['work_duration_minutes'] ?? 25,
      shortBreakDurationMinutes: json['short_break_duration_minutes'] ?? 5,
      longBreakDurationMinutes: json['long_break_duration_minutes'] ?? 15,
      startedAt: DateTime.parse(json['started_at']),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'])
          : null,
      sessionData: json['session_data'] ?? {},
      cycles: json['pomodoro_cycles'] != null
          ? (json['pomodoro_cycles'] as List)
              .map((c) => PomodoroCycle.fromJson(c))
              .toList()
          : [],
      notes: json['pomodoro_notes'] != null
          ? (json['pomodoro_notes'] as List)
              .map((n) => PomodoroNote.fromJson(n))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'module_id': moduleId,
      'status': status.value,
      'total_cycles_planned': totalCyclesPlanned,
      'cycles_completed': cyclesCompleted,
      'current_cycle': currentCycle,
      'work_duration_minutes': workDurationMinutes,
      'short_break_duration_minutes': shortBreakDurationMinutes,
      'long_break_duration_minutes': longBreakDurationMinutes,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'session_data': sessionData,
    };
  }

  PomodoroSession copyWith({
    String? id,
    String? userId,
    String? moduleId,
    PomodoroSessionStatus? status,
    int? totalCyclesPlanned,
    int? cyclesCompleted,
    int? currentCycle,
    int? workDurationMinutes,
    int? shortBreakDurationMinutes,
    int? longBreakDurationMinutes,
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? sessionData,
    List<PomodoroCycle>? cycles,
    List<PomodoroNote>? notes,
  }) {
    return PomodoroSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      moduleId: moduleId ?? this.moduleId,
      status: status ?? this.status,
      totalCyclesPlanned: totalCyclesPlanned ?? this.totalCyclesPlanned,
      cyclesCompleted: cyclesCompleted ?? this.cyclesCompleted,
      currentCycle: currentCycle ?? this.currentCycle,
      workDurationMinutes: workDurationMinutes ?? this.workDurationMinutes,
      shortBreakDurationMinutes: shortBreakDurationMinutes ?? this.shortBreakDurationMinutes,
      longBreakDurationMinutes: longBreakDurationMinutes ?? this.longBreakDurationMinutes,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      sessionData: sessionData ?? this.sessionData,
      cycles: cycles ?? this.cycles,
      notes: notes ?? this.notes,
    );
  }

  // Helper methods
  bool get isWorkPhase => status == PomodoroSessionStatus.active;
  bool get isBreakPhase => status == PomodoroSessionStatus.break_;
  bool get isCompleted => status == PomodoroSessionStatus.completed;
  bool get isPaused => status == PomodoroSessionStatus.paused;

  Duration get totalWorkTime => Duration(minutes: cyclesCompleted * workDurationMinutes);
  Duration get totalBreakTime {
    final shortBreaks = (cyclesCompleted - 1).clamp(0, totalCyclesPlanned - 1);
    final longBreaks = cyclesCompleted > 0 && cyclesCompleted % 4 == 0 ? 1 : 0;
    return Duration(
      minutes: shortBreaks * shortBreakDurationMinutes + longBreaks * longBreakDurationMinutes,
    );
  }

  double get progressPercentage => cyclesCompleted / totalCyclesPlanned;

  // Total session duration getter for analytics
  Duration get totalDuration {
    if (completedAt != null) {
      return completedAt!.difference(startedAt);
    } else {
      // If still in progress, calculate based on elapsed time
      return DateTime.now().difference(startedAt);
    }
  }
}

class PomodoroCycle {
  final String id;
  final String sessionId;
  final int cycleNumber;
  final PomodoroCycleType type;
  final int durationMinutes;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool wasInterrupted;
  final String? notes;
  final int? focusScore;

  PomodoroCycle({
    required this.id,
    required this.sessionId,
    required this.cycleNumber,
    required this.type,
    required this.durationMinutes,
    required this.startedAt,
    this.completedAt,
    this.wasInterrupted = false,
    this.notes,
    this.focusScore,
  });

  factory PomodoroCycle.fromJson(Map<String, dynamic> json) {
    return PomodoroCycle(
      id: json['id'],
      sessionId: json['session_id'],
      cycleNumber: json['cycle_number'],
      type: PomodoroCycleTypeExtension.fromString(json['type']),
      durationMinutes: json['duration_minutes'],
      startedAt: DateTime.parse(json['started_at']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      wasInterrupted: json['was_interrupted'] ?? false,
      notes: json['notes'],
      focusScore: json['focus_score'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'cycle_number': cycleNumber,
      'type': type.value,
      'duration_minutes': durationMinutes,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'was_interrupted': wasInterrupted,
      'notes': notes,
      'focus_score': focusScore,
    };
  }

  PomodoroCycle copyWith({
    String? id,
    String? sessionId,
    int? cycleNumber,
    PomodoroCycleType? type,
    int? durationMinutes,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? wasInterrupted,
    String? notes,
    int? focusScore,
  }) {
    return PomodoroCycle(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      cycleNumber: cycleNumber ?? this.cycleNumber,
      type: type ?? this.type,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      wasInterrupted: wasInterrupted ?? this.wasInterrupted,
      notes: notes ?? this.notes,
      focusScore: focusScore ?? this.focusScore,
    );
  }

  // Helper methods
  bool get isCompleted => completedAt != null;
  Duration get actualDuration => 
      isCompleted ? completedAt!.difference(startedAt) : Duration.zero;
  
  // Getters for analytics compatibility
  PomodoroCycleType get cycleType => type;
  Duration get plannedDuration => Duration(minutes: durationMinutes);
  
  String get typeDisplayName {
    switch (type) {
      case PomodoroCycleType.work:
        return 'Work';
      case PomodoroCycleType.shortBreak:
        return 'Short Break';
      case PomodoroCycleType.longBreak:
        return 'Long Break';
    }
  }
}

class PomodoroNote {
  final String id;
  final String sessionId;
  final String? cycleId;
  final String content;
  final PomodoroNoteType noteType;
  final DateTime createdAt;

  PomodoroNote({
    required this.id,
    required this.sessionId,
    this.cycleId,
    required this.content,
    this.noteType = PomodoroNoteType.studyNote,
    required this.createdAt,
  });

  factory PomodoroNote.fromJson(Map<String, dynamic> json) {
    return PomodoroNote(
      id: json['id'],
      sessionId: json['session_id'],
      cycleId: json['cycle_id'],
      content: json['content'],
      noteType: PomodoroNoteTypeExtension.fromString(json['note_type']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'cycle_id': cycleId,
      'content': content,
      'note_type': noteType.value,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PomodoroNote copyWith({
    String? id,
    String? sessionId,
    String? cycleId,
    String? content,
    PomodoroNoteType? noteType,
    DateTime? createdAt,
  }) {
    return PomodoroNote(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      cycleId: cycleId ?? this.cycleId,
      content: content ?? this.content,
      noteType: noteType ?? this.noteType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get typeDisplayName {
    switch (noteType) {
      case PomodoroNoteType.studyNote:
        return 'Study Note';
      case PomodoroNoteType.reflection:
        return 'Reflection';
      case PomodoroNoteType.quizAnswer:
        return 'Quiz Answer';
    }
  }
}

class PomodoroSessionResults {
  final int totalCyclesCompleted;
  final int totalCyclesPlanned;
  final Duration totalWorkTime;
  final Duration totalBreakTime;
  final int totalInterruptions;
  final double averageFocusScore;
  final int totalNotes;
  final Map<PomodoroCycleType, int> cycleTypeBreakdown;
  final List<String> reflectionNotes;

  PomodoroSessionResults({
    required this.totalCyclesCompleted,
    required this.totalCyclesPlanned,
    required this.totalWorkTime,
    required this.totalBreakTime,
    required this.totalInterruptions,
    required this.averageFocusScore,
    required this.totalNotes,
    required this.cycleTypeBreakdown,
    required this.reflectionNotes,
  });

  static PomodoroSessionResults calculate(
    PomodoroSession session,
    List<PomodoroCycle> cycles,
    List<PomodoroNote> notes,
  ) {
    print('🔍 [POMODORO RESULTS] Calculating session results...');
    print('   Total planned cycles: ${session.totalCyclesPlanned}');
    print('   Cycles completed: ${session.cyclesCompleted}');
    print('   Total cycles recorded: ${cycles.length}');
    print('   Total notes: ${notes.length}');

    final completedCycles = cycles.where((c) => c.isCompleted).toList();
    final workCycles = completedCycles.where((c) => c.type == PomodoroCycleType.work).toList();
    final interruptions = cycles.where((c) => c.wasInterrupted).length;
    
    final totalWorkTime = Duration(
      minutes: workCycles.fold(0, (sum, cycle) => sum + cycle.durationMinutes),
    );
    
    final breakCycles = completedCycles.where((c) => 
      c.type == PomodoroCycleType.shortBreak || c.type == PomodoroCycleType.longBreak
    ).toList();
    
    final totalBreakTime = Duration(
      minutes: breakCycles.fold(0, (sum, cycle) => sum + cycle.durationMinutes),
    );

    final focusScores = cycles
        .where((c) => c.focusScore != null)
        .map((c) => c.focusScore!)
        .toList();
    
    final averageFocusScore = focusScores.isNotEmpty
        ? focusScores.reduce((a, b) => a + b) / focusScores.length
        : 0.0;

    final cycleTypeBreakdown = <PomodoroCycleType, int>{};
    for (final cycle in completedCycles) {
      cycleTypeBreakdown[cycle.type] = (cycleTypeBreakdown[cycle.type] ?? 0) + 1;
    }

    final reflectionNotes = notes
        .where((n) => n.noteType == PomodoroNoteType.reflection)
        .map((n) => n.content)
        .toList();

    print('📊 [POMODORO RESULTS] Work time: ${totalWorkTime.inMinutes} minutes');
    print('📊 [POMODORO RESULTS] Break time: ${totalBreakTime.inMinutes} minutes');
    print('📊 [POMODORO RESULTS] Interruptions: $interruptions');
    print('📊 [POMODORO RESULTS] Average focus: ${averageFocusScore.toStringAsFixed(1)}/10');

    return PomodoroSessionResults(
      totalCyclesCompleted: session.cyclesCompleted,
      totalCyclesPlanned: session.totalCyclesPlanned,
      totalWorkTime: totalWorkTime,
      totalBreakTime: totalBreakTime,
      totalInterruptions: interruptions,
      averageFocusScore: averageFocusScore,
      totalNotes: notes.length,
      cycleTypeBreakdown: cycleTypeBreakdown,
      reflectionNotes: reflectionNotes,
    );
  }

  double get completionPercentage => 
      totalCyclesPlanned > 0 ? (totalCyclesCompleted / totalCyclesPlanned) * 100 : 0.0;

  Duration get totalSessionTime => totalWorkTime + totalBreakTime;

  double get interruptionRate => 
      totalCyclesCompleted > 0 ? totalInterruptions / totalCyclesCompleted : 0.0;
}

/// Pomodoro user settings for customizable timer durations and cycles
class PomodoroSettings {
  final Duration workDuration;
  final Duration shortBreakDuration;
  final Duration longBreakDuration;
  final int totalCycles;
  final String presetName;

  const PomodoroSettings({
    required this.workDuration,
    required this.shortBreakDuration,
    required this.longBreakDuration,
    required this.totalCycles,
    this.presetName = 'custom',
  });

  /// Default classic Pomodoro settings (25/5/15, 4 cycles)
  factory PomodoroSettings.classic() {
    return const PomodoroSettings(
      workDuration: Duration(minutes: 25),
      shortBreakDuration: Duration(minutes: 5),
      longBreakDuration: Duration(minutes: 15),
      totalCycles: 4,
      presetName: 'classic',
    );
  }

  /// Deep focus settings (45/10/20, 3 cycles)
  factory PomodoroSettings.deepFocus() {
    return const PomodoroSettings(
      workDuration: Duration(minutes: 45),
      shortBreakDuration: Duration(minutes: 10),
      longBreakDuration: Duration(minutes: 20),
      totalCycles: 3,
      presetName: 'deep_focus',
    );
  }

  /// Quick sprint settings (15/3/8, 6 cycles)
  factory PomodoroSettings.quickSprint() {
    return const PomodoroSettings(
      workDuration: Duration(minutes: 15),
      shortBreakDuration: Duration(minutes: 3),
      longBreakDuration: Duration(minutes: 8),
      totalCycles: 6,
      presetName: 'quick_sprint',
    );
  }

  /// Micro sessions for testing (30s/10s/20s, 2 cycles)
  factory PomodoroSettings.microTest() {
    return const PomodoroSettings(
      workDuration: Duration(seconds: 30),
      shortBreakDuration: Duration(seconds: 10),
      longBreakDuration: Duration(seconds: 20),
      totalCycles: 2,
      presetName: 'micro_test',
    );
  }

  /// Create from JSON data
  factory PomodoroSettings.fromJson(Map<String, dynamic> json) {
    return PomodoroSettings(
      workDuration: Duration(seconds: json['work_duration_seconds'] ?? 1500),
      shortBreakDuration: Duration(seconds: json['short_break_duration_seconds'] ?? 300),
      longBreakDuration: Duration(seconds: json['long_break_duration_seconds'] ?? 900),
      totalCycles: json['total_cycles'] ?? 4,
      presetName: json['preset_name'] ?? 'custom',
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'work_duration_seconds': workDuration.inSeconds,
      'short_break_duration_seconds': shortBreakDuration.inSeconds,
      'long_break_duration_seconds': longBreakDuration.inSeconds,
      'total_cycles': totalCycles,
      'preset_name': presetName,
    };
  }

  /// Create a copy with updated values
  PomodoroSettings copyWith({
    Duration? workDuration,
    Duration? shortBreakDuration,
    Duration? longBreakDuration,
    int? totalCycles,
    String? presetName,
  }) {
    return PomodoroSettings(
      workDuration: workDuration ?? this.workDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      totalCycles: totalCycles ?? this.totalCycles,
      presetName: presetName ?? this.presetName,
    );
  }

  /// Calculate estimated total session time
  Duration get estimatedSessionTime {
    // Work cycles + short breaks + long breaks
    final workTime = workDuration * totalCycles;
    final shortBreaks = shortBreakDuration * (totalCycles - 1); // Between work cycles
    final longBreaks = longBreakDuration * (totalCycles ~/ 4); // Every 4th cycle
    
    return workTime + shortBreaks + longBreaks;
  }

  /// Check if settings are within valid ranges
  bool get isValid {
    return workDuration >= const Duration(seconds: 5) &&
           workDuration <= const Duration(minutes: 90) &&
           shortBreakDuration >= const Duration(seconds: 5) &&
           shortBreakDuration <= const Duration(minutes: 30) &&
           longBreakDuration >= const Duration(seconds: 5) &&
           longBreakDuration <= const Duration(minutes: 60) &&
           totalCycles >= 1 &&
           totalCycles <= 10 &&
           estimatedSessionTime <= const Duration(hours: 8);
  }

  /// Get preset settings by name
  static PomodoroSettings getPreset(String presetName) {
    switch (presetName) {
      case 'classic':
        return PomodoroSettings.classic();
      case 'deep_focus':
        return PomodoroSettings.deepFocus();
      case 'quick_sprint':
        return PomodoroSettings.quickSprint();
      case 'micro_test':
        return PomodoroSettings.microTest();
      default:
        return PomodoroSettings.classic();
    }
  }

  /// Get all available presets
  static List<String> get availablePresets => [
    'classic',
    'deep_focus', 
    'quick_sprint',
    'micro_test',
  ];

  /// Get preset display name
  static String getPresetDisplayName(String presetName) {
    switch (presetName) {
      case 'classic':
        return 'Classic Pomodoro';
      case 'deep_focus':
        return 'Deep Focus';
      case 'quick_sprint':
        return 'Quick Sprint';
      case 'micro_test':
        return 'Micro Test';
      default:
        return 'Custom';
    }
  }

  /// Format duration for display
  static String formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      if (seconds == 0) {
        return '${minutes}m';
      } else {
        return '${minutes}m ${seconds}s';
      }
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  String toString() {
    return 'PomodoroSettings(work: ${formatDuration(workDuration)}, '
           'short break: ${formatDuration(shortBreakDuration)}, '
           'long break: ${formatDuration(longBreakDuration)}, '
           'cycles: $totalCycles, preset: $presetName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PomodoroSettings &&
           other.workDuration == workDuration &&
           other.shortBreakDuration == shortBreakDuration &&
           other.longBreakDuration == longBreakDuration &&
           other.totalCycles == totalCycles &&
           other.presetName == presetName;
  }

  @override
  int get hashCode {
    return workDuration.hashCode ^
           shortBreakDuration.hashCode ^
           longBreakDuration.hashCode ^
           totalCycles.hashCode ^
           presetName.hashCode;
  }
}