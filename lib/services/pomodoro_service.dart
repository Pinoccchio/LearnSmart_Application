import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/pomodoro_models.dart';
import '../models/course_models.dart';
import '../services/supabase_service.dart';
import '../services/study_analytics_service.dart';

class PomodoroService extends ChangeNotifier {
  static const int _defaultWorkDuration = 25; // minutes
  static const int _defaultShortBreakDuration = 5; // minutes
  static const int _defaultLongBreakDuration = 15; // minutes
  static const int _defaultTotalCycles = 4;

  // Timer state
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  Duration _totalTime = Duration.zero;
  bool _isRunning = false;
  
  // Session state
  PomodoroSession? _currentSession;
  PomodoroCycle? _currentCycle;
  List<PomodoroNote> _sessionNotes = [];
  
  // Getters
  PomodoroSession? get currentSession => _currentSession;
  PomodoroCycle? get currentCycle => _currentCycle;
  List<PomodoroNote> get sessionNotes => List.unmodifiable(_sessionNotes);
  Duration get remainingTime => _remainingTime;
  Duration get totalTime => _totalTime;
  bool get isRunning => _isRunning;
  bool get isPaused => _currentSession != null && !_isRunning && _remainingTime.inSeconds > 0;
  
  double get progress {
    if (_totalTime.inSeconds == 0) return 0.0;
    final elapsed = _totalTime.inSeconds - _remainingTime.inSeconds;
    return (elapsed / _totalTime.inSeconds).clamp(0.0, 1.0);
  }

  String get currentPhaseTitle {
    final session = _currentSession;
    if (session == null) return 'Pomodoro Session';
    
    switch (session.status) {
      case PomodoroSessionStatus.preparing:
        return 'Preparing Session...';
      case PomodoroSessionStatus.active:
        return 'Work Time - Cycle ${session.currentCycle}/${session.totalCyclesPlanned}';
      case PomodoroSessionStatus.break_:
        final isLongBreak = session.currentCycle % 4 == 0;
        return isLongBreak ? 'Long Break' : 'Short Break';
      case PomodoroSessionStatus.completed:
        return 'Session Complete!';
      case PomodoroSessionStatus.paused:
        return 'Session Paused';
    }
  }

  String get currentPhaseDescription {
    final session = _currentSession;
    if (session == null) return 'Get ready to focus!';
    
    switch (session.status) {
      case PomodoroSessionStatus.preparing:
        return 'Setting up your Pomodoro session...';
      case PomodoroSessionStatus.active:
        return 'Focus on your studies. Take notes and minimize distractions.';
      case PomodoroSessionStatus.break_:
        final isLongBreak = session.currentCycle % 4 == 0;
        return isLongBreak 
            ? 'Take a longer break! Reflect on what you\'ve learned.'
            : 'Take a short break. Stretch, hydrate, or rest your eyes.';
      case PomodoroSessionStatus.completed:
        return 'Great work! Review your session analytics below.';
      case PomodoroSessionStatus.paused:
        return 'Session is paused. Resume when ready.';
    }
  }

  /// Initialize a new Pomodoro session
  Future<PomodoroSession> initializeSession({
    required String userId,
    required Module module,
    int workDurationMinutes = _defaultWorkDuration,
    int shortBreakDurationMinutes = _defaultShortBreakDuration,
    int longBreakDurationMinutes = _defaultLongBreakDuration,
    int totalCycles = _defaultTotalCycles,
  }) async {
    try {
      print('🍅 [POMODORO] Initializing session for module: ${module.title}');
      
      // Create session in database
      final sessionData = {
        'user_id': userId,
        'module_id': module.id,
        'status': PomodoroSessionStatus.preparing.value,
        'total_cycles_planned': totalCycles,
        'work_duration_minutes': workDurationMinutes,
        'short_break_duration_minutes': shortBreakDurationMinutes,
        'long_break_duration_minutes': longBreakDurationMinutes,
        'session_data': {
          'module_title': module.title,
          'total_materials': module.materials.length,
        },
      };

      final response = await SupabaseService.client
          .from('pomodoro_sessions')
          .insert(sessionData)
          .select()
          .single();

      _currentSession = PomodoroSession.fromJson(response);
      _sessionNotes.clear();
      
      print('✅ [POMODORO] Session initialized with ID: ${_currentSession!.id}');
      notifyListeners();
      
      return _currentSession!;
      
    } catch (e) {
      print('❌ [POMODORO] Failed to initialize session: $e');
      rethrow;
    }
  }

  /// Start the first work cycle
  Future<void> startSession() async {
    if (_currentSession == null) {
      throw Exception('No session initialized');
    }

    try {
      print('🍅 [POMODORO] Starting first work cycle');
      
      // Update session status to active
      await _updateSessionStatus(PomodoroSessionStatus.active);
      
      // Start first work cycle
      await _startWorkCycle();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to start session: $e');
      rethrow;
    }
  }

  /// Start a work cycle
  Future<void> _startWorkCycle() async {
    if (_currentSession == null) return;

    try {
      print('🍅 [POMODORO] Starting work cycle ${_currentSession!.currentCycle}');
      
      // Create new cycle in database
      final cycleData = {
        'session_id': _currentSession!.id,
        'cycle_number': _currentSession!.currentCycle,
        'type': PomodoroCycleType.work.value,
        'duration_minutes': _currentSession!.workDurationMinutes,
      };

      final response = await SupabaseService.client
          .from('pomodoro_cycles')
          .insert(cycleData)
          .select()
          .single();

      _currentCycle = PomodoroCycle.fromJson(response);
      
      // Start timer
      _startTimer(Duration(minutes: _currentSession!.workDurationMinutes));
      
      print('✅ [POMODORO] Work cycle started');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to start work cycle: $e');
      rethrow;
    }
  }

  /// Start a break cycle
  Future<void> _startBreakCycle() async {
    if (_currentSession == null) return;

    try {
      // Determine break type and duration
      final isLongBreak = _currentSession!.currentCycle % 4 == 0;
      final breakType = isLongBreak ? PomodoroCycleType.longBreak : PomodoroCycleType.shortBreak;
      final duration = isLongBreak 
          ? _currentSession!.longBreakDurationMinutes 
          : _currentSession!.shortBreakDurationMinutes;

      print('🍅 [POMODORO] Starting ${isLongBreak ? 'long' : 'short'} break');

      // Update session status
      await _updateSessionStatus(PomodoroSessionStatus.break_);
      
      // Create break cycle in database
      final cycleData = {
        'session_id': _currentSession!.id,
        'cycle_number': _currentSession!.currentCycle,
        'type': breakType.value,
        'duration_minutes': duration,
      };

      final response = await SupabaseService.client
          .from('pomodoro_cycles')
          .insert(cycleData)
          .select()
          .single();

      _currentCycle = PomodoroCycle.fromJson(response);
      
      // Start timer
      _startTimer(Duration(minutes: duration));
      
      print('✅ [POMODORO] Break started');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to start break: $e');
      rethrow;
    }
  }

  /// Start the timer with given duration
  void _startTimer(Duration duration) {
    _stopTimer(); // Stop any existing timer
    
    _totalTime = duration;
    _remainingTime = duration;
    _isRunning = true;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 0) {
        _onTimerComplete();
      } else {
        _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        notifyListeners();
      }
    });
    
    notifyListeners();
  }

  /// Handle timer completion
  Future<void> _onTimerComplete() async {
    _stopTimer();
    await _completeCurrent();
    
    if (_currentSession!.status == PomodoroSessionStatus.active) {
      // Work cycle completed, start break
      await _startBreakCycle();
    } else if (_currentSession!.status == PomodoroSessionStatus.break_) {
      // Break completed, either start next work cycle or complete session
      if (_currentSession!.currentCycle < _currentSession!.totalCyclesPlanned) {
        await _advanceToNextCycle();
        await _startWorkCycle();
      } else {
        await _completeSession();
      }
    }
  }

  /// Complete current cycle
  Future<void> _completeCurrent() async {
    if (_currentCycle == null) return;

    try {
      // Update cycle as completed
      await SupabaseService.client
          .from('pomodoro_cycles')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentCycle!.id);

      // If it was a work cycle, increment cycles completed
      if (_currentCycle!.type == PomodoroCycleType.work) {
        await SupabaseService.client
            .from('pomodoro_sessions')
            .update({
              'cycles_completed': _currentSession!.cyclesCompleted + 1,
            })
            .eq('id', _currentSession!.id);
        
        _currentSession = _currentSession!.copyWith(
          cyclesCompleted: _currentSession!.cyclesCompleted + 1,
        );
      }
      
      print('✅ [POMODORO] Cycle ${_currentCycle!.cycleNumber} completed');
      
    } catch (e) {
      print('❌ [POMODORO] Failed to complete cycle: $e');
    }
  }

  /// Advance to next cycle
  Future<void> _advanceToNextCycle() async {
    if (_currentSession == null) return;

    try {
      final nextCycle = _currentSession!.currentCycle + 1;
      
      await SupabaseService.client
          .from('pomodoro_sessions')
          .update({
            'current_cycle': nextCycle,
          })
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(currentCycle: nextCycle);
      await _updateSessionStatus(PomodoroSessionStatus.active);
      
      print('✅ [POMODORO] Advanced to cycle $nextCycle');
      
    } catch (e) {
      print('❌ [POMODORO] Failed to advance cycle: $e');
    }
  }

  /// Skip the current cycle (work or break)
  Future<void> skipCycle() async {
    if (_currentSession == null || _currentCycle == null) return;

    try {
      print('⏭️ [POMODORO] Skipping current cycle: ${_currentCycle!.cycleType.name}');
      
      // Stop the timer
      _timer?.cancel();
      _timer = null;
      
      // Mark current cycle as incomplete/skipped
      final updatedCycle = _currentCycle!.copyWith(
        completedAt: DateTime.now(),
        wasInterrupted: true,
      );
      
      // Update cycle in database
      await SupabaseService.client
          .from('pomodoro_cycles')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
            'was_interrupted': true,
          })
          .eq('id', _currentCycle!.id);
      
      _currentCycle = updatedCycle;
      
      // If it was a work cycle, we might want to record a focus score
      // But we'll let the UI handle that decision
      
      // Advance to next cycle
      await _advanceToNextCycle();
      
      print('✅ [POMODORO] Cycle skipped and advanced to next');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to skip cycle: $e');
      rethrow;
    }
  }

  /// Complete the entire session
  Future<void> _completeSession() async {
    if (_currentSession == null) return;

    try {
      await _updateSessionStatus(PomodoroSessionStatus.completed);
      
      await SupabaseService.client
          .from('pomodoro_sessions')
          .update({
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(
        status: PomodoroSessionStatus.completed,
        completedAt: DateTime.now(),
      );
      
      print('🎉 [POMODORO] Session completed!');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to complete session: $e');
    }
  }

  /// Pause the current timer
  void pauseTimer() {
    if (_isRunning) {
      _stopTimer();
      print('⏸️ [POMODORO] Timer paused');
      notifyListeners();
    }
  }

  /// Resume the paused timer
  void resumeTimer() {
    if (!_isRunning && _remainingTime.inSeconds > 0) {
      _startTimer(_remainingTime);
      print('▶️ [POMODORO] Timer resumed');
    }
  }

  /// Stop and reset the timer
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  /// Update session status in database
  Future<void> _updateSessionStatus(PomodoroSessionStatus status) async {
    if (_currentSession == null) return;

    try {
      await SupabaseService.client
          .from('pomodoro_sessions')
          .update({'status': status.value})
          .eq('id', _currentSession!.id);

      _currentSession = _currentSession!.copyWith(status: status);
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to update session status: $e');
    }
  }

  /// Add a note to the current session
  Future<PomodoroNote> addNote({
    required String content,
    PomodoroNoteType noteType = PomodoroNoteType.studyNote,
  }) async {
    if (_currentSession == null) {
      throw Exception('No active session');
    }

    try {
      final noteData = {
        'session_id': _currentSession!.id,
        'cycle_id': _currentCycle?.id,
        'content': content,
        'note_type': noteType.value,
      };

      final response = await SupabaseService.client
          .from('pomodoro_notes')
          .insert(noteData)
          .select()
          .single();

      final note = PomodoroNote.fromJson(response);
      _sessionNotes.add(note);
      
      print('📝 [POMODORO] Note added: ${noteType.value}');
      notifyListeners();
      
      return note;
      
    } catch (e) {
      print('❌ [POMODORO] Failed to add note: $e');
      rethrow;
    }
  }

  /// Add focus score to current cycle
  Future<void> addFocusScore(int score) async {
    if (_currentCycle == null) return;

    try {
      await SupabaseService.client
          .from('pomodoro_cycles')
          .update({'focus_score': score})
          .eq('id', _currentCycle!.id);

      _currentCycle = _currentCycle!.copyWith(focusScore: score);
      
      print('⭐ [POMODORO] Focus score added: $score/10');
      notifyListeners();
      
    } catch (e) {
      print('❌ [POMODORO] Failed to add focus score: $e');
    }
  }

  /// Get session results and analytics
  Future<PomodoroSessionResults> getSessionResults() async {
    if (_currentSession == null) {
      throw Exception('No session available');
    }

    try {
      // Fetch complete session data
      final sessionResponse = await SupabaseService.client
          .from('pomodoro_sessions')
          .select('''
            *,
            pomodoro_cycles(*),
            pomodoro_notes(*)
          ''')
          .eq('id', _currentSession!.id)
          .single();

      final session = PomodoroSession.fromJson(sessionResponse);
      
      // Extract cycles and notes from the response
      final cycles = (sessionResponse['pomodoro_cycles'] as List? ?? [])
          .map((c) => PomodoroCycle.fromJson(c))
          .toList();
      final notes = (sessionResponse['pomodoro_notes'] as List? ?? [])
          .map((n) => PomodoroNote.fromJson(n))
          .toList();
      
      return PomodoroSessionResults.calculate(
        session,
        cycles,
        notes,
      );
      
    } catch (e) {
      print('❌ [POMODORO] Failed to get session results: $e');
      rethrow;
    }
  }

  /// Generate comprehensive analytics for the session
  Future<void> generateSessionAnalytics({
    required String userId,
    required Module module,
    required Course course,
  }) async {
    if (_currentSession == null) return;

    try {
      print('📊 [POMODORO ANALYTICS] Generating session analytics...');
      
      // Get session results with complete data
      final sessionResponse = await SupabaseService.client
          .from('pomodoro_sessions')
          .select('''
            *,
            pomodoro_cycles(*),
            pomodoro_notes(*)
          ''')
          .eq('id', _currentSession!.id)
          .single();

      final session = PomodoroSession.fromJson(sessionResponse);
      final cycles = (sessionResponse['pomodoro_cycles'] as List? ?? [])
          .map((c) => PomodoroCycle.fromJson(c))
          .toList();
      final notes = (sessionResponse['pomodoro_notes'] as List? ?? [])
          .map((n) => PomodoroNote.fromJson(n))
          .toList();
      
      // Use the existing StudyAnalyticsService with correct parameters
      final analyticsService = StudyAnalyticsService();
      
      // Generate analytics using the correct method signature
      await analyticsService.generatePomodoroAnalytics(
        sessionId: _currentSession!.id,
        userId: userId,
        moduleId: module.id,
        session: session,
        cycles: cycles,
        notes: notes,
        course: course,
        module: module,
      );
      
      print('✅ [POMODORO ANALYTICS] Analytics generated successfully');
      
    } catch (e) {
      print('❌ [POMODORO ANALYTICS] Failed to generate analytics: $e');
    }
  }

  /// Calculate work consistency metric
  double _calculateWorkConsistency(PomodoroSessionResults results) {
    // Simple metric based on completion rate and interruptions
    final baseScore = results.completionPercentage / 100.0;
    final interruptionPenalty = results.interruptionRate * 0.2;
    return (baseScore - interruptionPenalty).clamp(0.0, 1.0);
  }

  /// Calculate break adherence metric
  double _calculateBreakAdherence(PomodoroSessionResults results) {
    // Placeholder - in real implementation, compare actual break time to planned
    return results.averageFocusScore / 10.0;
  }

  /// Determine productivity pattern
  String _determineProductivityPattern(PomodoroSessionResults results) {
    if (results.completionPercentage >= 90 && results.averageFocusScore >= 8) {
      return 'high_focus_sustained';
    } else if (results.completionPercentage >= 75 && results.interruptionRate < 0.2) {
      return 'steady_productive';
    } else if (results.interruptionRate > 0.5) {
      return 'frequently_interrupted';
    } else if (results.averageFocusScore < 5) {
      return 'low_focus_struggling';
    } else {
      return 'moderate_performance';
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  /// Force stop session (for emergencies)
  Future<void> forceStopSession() async {
    _stopTimer();
    if (_currentSession != null) {
      await _updateSessionStatus(PomodoroSessionStatus.paused);
    }
    print('🛑 [POMODORO] Session force stopped');
  }
}